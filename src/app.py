# -*- coding: utf-8 -*-
from flask import Flask, jsonify, request, Response, send_from_directory
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

# 确保从项目根目录加载.env
env_path = Path(__file__).resolve().parent.parent / '.env'
load_dotenv(dotenv_path=env_path)
print("当前工作目录:", os.getcwd())
print("环境变量SILICONFLOW_API_KEY是否存在:", 'SILICONFLOW_API_KEY' in os.environ)
print("从环境变量读取的API密钥:", os.getenv('SILICONFLOW_API_KEY'))
print(".env文件路径:", env_path)
print(f".env文件是否存在：{env_path.exists()}")
print(f"文件内容：{env_path.read_text(encoding='utf-8')}")

os.environ['SILICONFLOW_API_KEY'] = 'sk-judexvqbahpknepuihvfqhidhkdyymmwjysdikrgtievnjnv'  # 临时方案

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_app():
    app = Flask(__name__)
    
    # 先初始化CORS
    CORS(app, resources={r"/api/*": {
        "origins": "http://localhost:3000",
        "methods": ["POST", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization", "X-Request-Source"],
        "supports_credentials": True,
        "max_age": 600
    }})

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
        logger.info(f"""
        [Response] {request.method} {request.path} => {response.status_code}
        Duration: {duration:.2f}ms
        Headers: {dict(response.headers)}
        Body: {response.get_data(as_text=True)[:500]}...
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

    @app.route('/api/chat', methods=['POST'])
    def chat():
        """处理用户的聊天请求"""

        # 检查请求的内容类型
        if request.content_type is None or 'application/json' not in request.content_type:
            return jsonify({"error": "Unsupported Media Type"}), 415

        try:
            data = request.get_json()
            session_id = data.get('session_id')
            user_input = data.get('user_input')

            if not session_id or not user_input:
                return jsonify({"error": "缺少必要参数：session_id 或 user_input"}), 400

            # 构造请求参数
            payload = {
                "model": "deepseek-ai/DeepSeek-V2.5",  # 使用的AI模型
                "messages": [
                    {"role": "user", "content": user_input}
                ],
                "temperature": 0.7,
                "max_tokens": 150
            }

            # 使用LoggingSiliconFlowClient
            client = LoggingSiliconFlowClient()  # 通过环境变量自动获取API密钥
            result = client.chat_completion(payload)

            # 返回生成的回复
            return jsonify({
                "session_id": session_id,
                "reply": result.get('choices', [{}])[0].get('message', {}).get('content', '')
            }), 200

        except KeyError as e:
            logger.error(f"参数错误：{str(e)}")
            return jsonify({"error": f"缺少必要参数：{str(e)}"}), 400
        except Exception as e:
            logger.error(f"生成失败：{str(e)}", exc_info=True)
            return jsonify({"error": "对话生成失败"}), 500

    @app.route('/static/<path:filename>')
    def serve_static(filename):
        return send_from_directory(
            os.path.join(app.root_path, '..', 'frontend', 'static'),
            filename
        )

    def _build_cors_preflight_response():
        response = jsonify({'status': 'preflight'})
        response.headers.add("Access-Control-Allow-Origin", "http://localhost:3000")
        response.headers.add("Access-Control-Allow-Headers", "Content-Type,Authorization,X-Request-Source")
        response.headers.add("Access-Control-Allow-Methods", "POST, OPTIONS")
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