# -*- coding: utf-8 -*-
from flask import Flask, jsonify, request, Response, send_from_directory, stream_with_context
from dotenv import load_dotenv
from flask_cors import CORS
from .api_client import LoggingSiliconFlowClient
import os
from pathlib import Path
from datetime import datetime
import requests
import random
from werkzeug.exceptions import BadRequest
from urllib.parse import urlparse
from logging.config import dictConfig
import time
import logging
import json
from threading import Event

# 加载 .env 文件
env_path = Path('/app/.env')  # 使用绝对路径
if env_path.exists():
    load_dotenv(dotenv_path=env_path)
    print(f"已加载 .env 文件：{env_path}")
else:
    print(f"警告：.env 文件不存在：{env_path}")

print("当前工作目录:", os.getcwd())
print("环境变量SILICONFLOW_API_KEY是否存在:", 'SILICONFLOW_API_KEY' in os.environ)
print("从环境变量读取的API密钥:", os.getenv('SILICONFLOW_API_KEY'))

os.environ['SILICONFLOW_API_KEY'] = 'sk-judexvqbahpknepuihvfqhidhkdyymmwjysdikrgtievnjnv'  # 临时方案

# 配置日志
logging.basicConfig(level=logging.DEBUG)  # 设置为 DEBUG 级别
logger = logging.getLogger(__name__)

# 存储每个会话的停止事件
session_stop_events = {}

# 添加默认模型列表
DEFAULT_MODELS = {
    "models": [
        {
            "id": "deepseek-ai/DeepSeek-V3",
            "name": "DeepSeek-V3",
            "description": "综合"
        },
        {
            "id": "deepseek-ai/DeepSeek-R1",
            "name": "DeepSeek R1",
            "description": "推理"
        },
        {
            "id": "Qwen/Qwen2.5-72B-Instruct-128K",
            "name": "Qwen/Qwen2.5-72B-Instruct-128K",
            "description": "编码"
        },
        {
            "id": "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B",
            "name": "DeepSeek R1-Distill-Qwen-7B",
            "description": "免费"
        }
    ]
}

def create_app():
    app = Flask(__name__)
    
    # 修改 CORS 配置
    CORS(app, resources={
        r"/api/*": {
            "origins": [
                "http://localhost:3000",
                "http://127.0.0.1:3000",
                # 添加你的生产环境域名，例如：
                "https://113.45.251.116",
                "http://your-domain.com"
            ],
            "methods": ["GET", "POST", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization", "X-Request-Source"],
            "supports_credentials": True,
            "max_age": 600
        }
    })

    def get_request_source(request):
        """判断请求来源"""
        if request.headers.get('X-Request-Source') == 'webapp':
            return 'Frontend'
        elif request.referrer and 'localhost:3000' in request.referrer:
            return 'Frontend'
        else:
            return 'External'

    # 添加请求日志中间件
    @app.before_request
    def log_request_info():
        request.start_time = time.perf_counter()  # 记录请求开始时间
        logger.info(f"""
        [Request] {request.method} {request.path}
        Client IP: {request.remote_addr}
        Headers: {dict(request.headers)}
        Params: {dict(request.args)}
        Body: {request.get_json(silent=True) or {}}
        """)

    # 添加高精度计时中间件
    @app.before_request
    def start_timer():
        request.start_time = time.perf_counter()

    # 修改响应日志中间件
    @app.after_request
    def log_response_info(response):
        duration = (time.perf_counter() - request.start_time) * 1000  # 转换为毫秒
        
        # 只记录文本类型的响应内容
        content_type = response.headers.get('Content-Type', '')
        if 'text' in content_type or 'json' in content_type:
            body = response.get_data(as_text=True)[:500]
        else:
            body = '<binary data>'
        
        logger.info(f"""
        [Response] {request.method} {request.path} => {response.status_code}
        Duration: {duration:.2f}ms
        Headers: {dict(response.headers)}
        Body: {body}...
        """)
        return response

    @app.route('/')
    def health_check():
        return {'status': 'ready', 'service': 'image-generator'}

    @app.route('/api/generate', methods=['POST', 'OPTIONS'])
    def generate():
        if request.method == 'OPTIONS':
            return _build_cors_preflight_response()
        
        # 内容类型检查
        if 'application/json' not in request.content_type:
            return jsonify({"error": "Unsupported Media Type"}), 415

        try:
            data = request.get_json()
            
            # 构造API请求参数
            payload = {
                "prompt": data['prompt'],
                "model": data.get('model', 'black-forest-labs/FLUX.1-schnell'),
                "width": data['width'],
                "height": data['height'],
                "batch_size": data['num_images'],
                "num_inference_steps": 4,
                "guidance_scale": data.get('guidance_scale', 4.0),
                "variation_seed": random.randint(0, 999999999),
                "variation_strength": 0.7
            }
            
            # 使用LoggingSiliconFlowClient
            client = LoggingSiliconFlowClient()  # 通过环境变量自动获取API密钥
            result = client.generate_image(payload)
            
            # 返回真实图片URL
            return jsonify({
                "images": [img['url'] for img in result['images']],
                "usage": {
                    "duration": result.get('timings', {}).get('inference', 0),
                    "credits_used": result.get('credits_used', 0)
                }
            }), 200
            
        except KeyError as e:
            logger.error(f"参数错误：{str(e)}")
            return jsonify({"error": f"缺少必要参数：{str(e)}"}), 400
        except Exception as e:
            logger.error(f"生成失败：{str(e)}", exc_info=True)
            return jsonify({"error": "图像生成失败"}), 500

    @app.route('/api/download', methods=['GET'])
    def download_proxy():
        try:
            # 添加参数验证
            image_url = request.args.get('url')
            if not image_url:
                return jsonify({"error": "缺少url参数"}), 400
            
            # 添加安全验证
            allowed_domains = [
                'sc-maas.oss-cn-shanghai.aliyuncs.com',
                'cdn.siliconflow.com'
            ]
            if not any(domain in image_url for domain in allowed_domains):
                return jsonify({"error": "非法的图片地址"}), 403
            
            # 设置合理的超时时间和请求头
            response = requests.get(
                image_url,
                timeout=10,
                headers={
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                },
                stream=True
            )
            response.raise_for_status()
            
            # 获取文件名
            filename = image_url.split('/')[-1].split('?')[0]
            
            return Response(
                response.iter_content(chunk_size=8192),
                mimetype=response.headers.get('Content-Type', 'application/octet-stream'),
                headers={
                    'Content-Disposition': f'attachment; filename="{filename}"',
                    'Cache-Control': 'max-age=3600'
                }
            )
        except requests.exceptions.Timeout:
            logger.error("下载超时")
            return jsonify({"error": "下载超时"}), 504
        except requests.exceptions.RequestException as e:
            logger.error(f"下载失败: {str(e)}")
            return jsonify({"error": f"图片下载失败: {str(e)}"}), 500

    @app.route('/api/stop', methods=['POST'])
    def stop_generation():
        try:
            data = request.get_json()
            session_id = data.get('session_id')
            
            if session_id in session_stop_events:
                # 设置停止事件
                session_stop_events[session_id].set()
                # 清理事件
                del session_stop_events[session_id]
                return jsonify({"status": "success", "message": "已停止生成"})
            
            return jsonify({"status": "not_found", "message": "未找到对应的会话"}), 404
            
        except Exception as e:
            logging.error(f"停止生成时出错: {str(e)}")
            return jsonify({"status": "error", "message": str(e)}), 500

    @app.route('/api/chat', methods=['GET', 'POST', 'OPTIONS'])
    def chat():
        """处理用户的聊天请求"""
        if request.method == 'OPTIONS':
            return _build_cors_preflight_response()

        try:
            if request.method == 'GET':
                session_id = request.args.get('session_id')
                user_input = request.args.get('user_input')
            else:
                data = request.get_json()
                session_id = data.get('session_id')
                user_input = data.get('user_input')

            if not session_id or not user_input:
                return jsonify({"error": "缺少必要参数"}), 400

            # 为新会话创建停止事件
            stop_event = Event()
            session_stop_events[session_id] = stop_event

            # 构造请求参数
            payload = {
                "model": "deepseek-ai/DeepSeek-V2.5",
                "messages": [
                    {"role": "user", "content": user_input}
                ],
                "temperature": 0.7,
                "max_tokens": 2000,
                "stream": True
            }

            logger.info(f"开始聊天请求，会话ID: {session_id}")
            
            client = LoggingSiliconFlowClient()
            response = client.chat_completion(payload)

            def generate():
                try:
                    accumulated_content = ""
                    in_code_block = False
                    current_lang = None
                    code_block_content = ""
                    code_block_start = False
                    newline = "\n"  # 预定义换行符
                    
                    for chunk in response:
                        if stop_event.is_set():
                            logger.info(f"会话 {session_id} 被用户终止")
                            break

                        if chunk and 'choices' in chunk and chunk['choices']:
                            content = chunk['choices'][0].get('delta', {}).get('content', '')
                            if content:
                                # 处理代码块开始
                                if '```' in content and not in_code_block:
                                    parts = content.split('```', 1)
                                    if len(parts) > 1:
                                        # 发送代码块前的内容
                                        if parts[0]:
                                            yield f"data: {json.dumps({'reply': parts[0]}, ensure_ascii=False)}\n\n"
                                        
                                        # 处理语言标记
                                        remaining = parts[1]
                                        lang_end = remaining.find('\n')
                                        if lang_end != -1:
                                            current_lang = remaining[:lang_end].strip()
                                            code_block_content = remaining[lang_end+1:]
                                        else:
                                            current_lang = remaining.strip()
                                            code_block_content = ""
                                        
                                        in_code_block = True
                                        code_block_start = True
                                        # 发送代码块开始标记
                                        lang_marker = '```' + (current_lang if current_lang else '')
                                        yield f"data: {json.dumps({'reply': lang_marker}, ensure_ascii=False)}\n\n"
                                        # 单独发送换行符
                                        yield f"data: {json.dumps({'reply': newline}, ensure_ascii=False)}\n\n"
                                        if code_block_content:
                                            yield f"data: {json.dumps({'reply': code_block_content}, ensure_ascii=False)}\n\n"
                                        continue
                                
                                # 处理代码块结束
                                if '```' in content and in_code_block:
                                    parts = content.split('```', 1)
                                    code_block_content = parts[0]
                                    if code_block_content:
                                        yield f"data: {json.dumps({'reply': code_block_content}, ensure_ascii=False)}\n\n"
                                        # 分开发送结束标记和换行符
                                        yield f"data: {json.dumps({'reply': '```'}, ensure_ascii=False)}\n\n"
                                        yield f"data: {json.dumps({'reply': newline}, ensure_ascii=False)}\n\n"
                                        if len(parts) > 1 and parts[1]:
                                            yield f"data: {json.dumps({'reply': parts[1]}, ensure_ascii=False)}\n\n"
                                        in_code_block = False
                                        current_lang = None
                                        code_block_content = ""
                                        continue
                                
                                # 处理代码块内的内容
                                if in_code_block:
                                    code_block_content += content
                                    yield f"data: {json.dumps({'reply': content}, ensure_ascii=False)}\n\n"
                                    continue
                                
                                # 处理普通文本
                                yield f"data: {json.dumps({'reply': content}, ensure_ascii=False)}\n\n"
                                
                                logger.debug(f"生成内容: {content}")
                except Exception as e:
                    logger.error(f"流式输出错误：{str(e)}", exc_info=True)
                    yield f"data: {json.dumps({'error': str(e)}, ensure_ascii=False)}\n\n"
                finally:
                    if session_id in session_stop_events:
                        del session_stop_events[session_id]
                    yield "data: [DONE]\n\n"
                    logger.info(f"会话 {session_id} 完成")

            return Response(
                stream_with_context(generate()),
                mimetype='text/event-stream',
                headers={
                    'Cache-Control': 'no-cache',
                    'Connection': 'keep-alive',
                    'X-Accel-Buffering': 'no',
                    'Access-Control-Allow-Origin': request.headers.get('Origin', '*'),
                    'Access-Control-Allow-Credentials': 'true'
                }
            )

        except Exception as e:
            logger.error(f"聊天生成失败：{str(e)}", exc_info=True)
            return jsonify({
                "error": "对话生成失败",
                "detail": str(e)
            }), 500

    @app.route('/api/models', methods=['GET', 'OPTIONS'])
    def get_models():

        return jsonify(DEFAULT_MODELS)
        """获取可用的模型列表"""
        if request.method == 'OPTIONS':
            return _build_cors_preflight_response()

        try:
            client = LoggingSiliconFlowClient()
            logger.info("开始获取模型列表")
            
            # 记录请求环境信息
            logger.info("环境信息:")
            logger.info(f"API Key: {os.getenv('SILICONFLOW_API_KEY')[:10]}...")
            logger.info(f"Base URL: {client.base_url}")
            
            models_data = client.get_models()
            
            # 验证返回的数据结构
            if not isinstance(models_data, dict) or 'data' not in models_data:
                error_msg = f"无效的API响应格式: {json.dumps(models_data, ensure_ascii=False)}"
                logger.error(error_msg)
                return jsonify({
                    "error": "获取模型列表失败",
                    "detail": error_msg
                }), 500
            
            # 过滤和处理模型列表
            llm_models = []
            for model in models_data.get("data", []):
                model_id = model.get("id", "").lower()
                if any(name in model_id for name in [
                    "deepseek", "qwen", "llama", "gpt", "glm", "marco", 
                    "mistral", "mixtral", "yi", "baichuan"
                ]):
                    llm_models.append({
                        "id": model.get("id"),
                        "name": model.get("name", model.get("id")),
                        "description": model.get("description", ""),
                        "type": "llm"
                    })
            
            logger.info(f"成功过滤出 {len(llm_models)} 个大语言模型")
            logger.info(f"模型列表: {json.dumps(llm_models, ensure_ascii=False, indent=2)}")
            return jsonify({"models": llm_models})

        except Exception as e:
            error_msg = f"获取模型列表失败: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return jsonify({
                "error": "获取模型列表失败",
                "detail": error_msg,
                "timestamp": time.strftime('%Y-%m-%d %H:%M:%S')
            }), 500

    @app.route('/static/<path:filename>')
    def serve_static(filename):
        return send_from_directory(
            os.path.join(app.root_path, '..', 'frontend', 'static'),
            filename
        )

    def _build_cors_preflight_response():
        response = jsonify({'status': 'preflight'})
        origin = request.headers.get('Origin')
        allowed_origins = [
            "http://localhost:3000",
            "http://127.0.0.1:3000",
            "https://your-domain.com",
            "http://your-domain.com"
        ]
        if origin in allowed_origins:
            response.headers.add("Access-Control-Allow-Origin", origin)
        response.headers.add("Access-Control-Allow-Headers", "Content-Type,Authorization,X-Request-Source")
        response.headers.add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        response.headers.add("Access-Control-Allow-Credentials", "true")
        response.headers.add("Access-Control-Max-Age", "600")
        return response

    def validate_image_url(url):
        """验证图片URL是否合法"""
        try:
            parsed = urlparse(url)
            if parsed.scheme not in ('http', 'https'):
                return False
            return True
        except:
            return False

    return app

app = create_app()

if __name__ == '__main__':
    app.debug = True
    app.config['PROPAGATE_EXCEPTIONS'] = True
    app.run(host='0.0.0.0', port=5000) 