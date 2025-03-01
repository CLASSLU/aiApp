# -*- coding: utf-8 -*-
from flask import Flask, jsonify, request, Response, send_from_directory, stream_with_context, make_response, send_file
from dotenv import load_dotenv
from flask_cors import CORS
from .api_client import LoggingSiliconFlowClient
import os
from pathlib import Path
from datetime import datetime, timedelta
import requests
import random
from werkzeug.exceptions import BadRequest
from urllib.parse import urlparse
from logging.config import dictConfig
import time
import logging
import json
from threading import Event
import uuid
import sys

# 加载环境变量
load_dotenv()

# 创建日志目录
log_dir = Path("/app/logs")
log_dir.mkdir(exist_ok=True, parents=True)

# 配置日志系统
logging_config = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'standard': {
            'format': '%(asctime)s [%(levelname)s] [%(name)s] %(message)s'
        },
        'detailed': {
            'format': '%(asctime)s [%(levelname)s] [%(name)s:%(lineno)d] %(message)s'
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'level': 'INFO',
            'formatter': 'standard',
            'stream': 'ext://sys.stdout'
        },
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'level': 'DEBUG',
            'formatter': 'detailed',
            'filename': '/app/logs/app.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 5,
            'encoding': 'utf8'
        },
        'error_file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'level': 'ERROR',
            'formatter': 'detailed',
            'filename': '/app/logs/error.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 5,
            'encoding': 'utf8'
        },
        'api_file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'level': 'DEBUG',
            'formatter': 'detailed',
            'filename': '/app/logs/api.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 5,
            'encoding': 'utf8'
        },
        'chat_file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'level': 'DEBUG',
            'formatter': 'detailed',
            'filename': '/app/logs/chat.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 5,
            'encoding': 'utf8'
        }
    },
    'loggers': {
        '': {  # root logger
            'handlers': ['console', 'file', 'error_file'],
            'level': 'DEBUG',
            'propagate': True
        },
        'werkzeug': {
            'level': 'INFO',
            'propagate': True,
        },
        'api': {
            'handlers': ['console', 'api_file', 'error_file'],
            'level': 'DEBUG',
            'propagate': False,
        },
        'chat': {
            'handlers': ['console', 'chat_file', 'error_file'],
            'level': 'DEBUG',
            'propagate': False,
        }
    }
}

# 应用日志配置
logging.config.dictConfig(logging_config)
logger = logging.getLogger(__name__)

logger.info("应用启动中...")

# 创建 Flask 应用
app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})  

# 设置 session secret key
app.secret_key = os.getenv('SESSION_SECRET_KEY', 'default_session_secret_key')
app.config['SESSION_TYPE'] = 'filesystem'
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=31)  # 会话保持31天

# 存储每个会话的停止事件
session_stop_events = {}

# 添加会话历史记录存储
chat_histories = {}

# 会话配置
CHAT_CONFIG = {
    'max_history_length': 20,  # 每个会话最多保存多少条消息
    'session_timeout': 3600,   # 会话超时时间（秒）
    'max_sessions': 1000       # 最大会话数
}

# 会话最后活动时间
session_last_active = {}

def cleanup_old_sessions():
    """清理过期的会话"""
    current_time = time.time()
    expired_sessions = []
    
    for session_id, last_active in session_last_active.items():
        if current_time - last_active > CHAT_CONFIG['session_timeout']:
            expired_sessions.append(session_id)
    
    for session_id in expired_sessions:
        if session_id in chat_histories:
            del chat_histories[session_id]
        if session_id in session_last_active:
            del session_last_active[session_id]
        if session_id in session_stop_events:
            del session_stop_events[session_id]

def update_session_activity(session_id):
    """更新会话的最后活动时间"""
    session_last_active[session_id] = time.time()
    
    # 如果会话数超过限制，清理最旧的会话
    if len(chat_histories) > CHAT_CONFIG['max_sessions']:
        oldest_session = min(session_last_active.items(), key=lambda x: x[1])[0]
        del chat_histories[oldest_session]
        del session_last_active[oldest_session]
        if oldest_session in session_stop_events:
            del session_stop_events[oldest_session]

def trim_chat_history(session_id):
    """限制会话历史记录长度"""
    if session_id in chat_histories and len(chat_histories[session_id]) > CHAT_CONFIG['max_history_length']:
        # 保留最新的消息
        chat_histories[session_id] = chat_histories[session_id][-CHAT_CONFIG['max_history_length']:]

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
    """创建Flask应用实例并配置"""
    app = Flask(__name__)

    # 配置
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'default_secret_key')
    app.config['SESSION_TYPE'] = 'filesystem'
    app.config['SESSION_PERMANENT'] = False
    app.config['SESSION_USE_SIGNER'] = True
    app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=1)

    # 配置日志系统
    logging_config = {
        'version': 1,
        'disable_existing_loggers': False,
        'formatters': {
            'standard': {
                'format': '%(asctime)s [%(levelname)s] [%(name)s] %(message)s'
            },
            'detailed': {
                'format': '%(asctime)s [%(levelname)s] [%(name)s:%(lineno)d] %(message)s'
            },
        },
        'handlers': {
            'console': {
                'class': 'logging.StreamHandler',
                'level': 'INFO',
                'formatter': 'standard',
                'stream': 'ext://sys.stdout'
            },
            'file': {
                'class': 'logging.handlers.RotatingFileHandler',
                'level': 'DEBUG',
                'formatter': 'detailed',
                'filename': '/app/logs/app.log',
                'maxBytes': 10485760,  # 10MB
                'backupCount': 5,
                'encoding': 'utf8'
            },
            'error_file': {
                'class': 'logging.handlers.RotatingFileHandler',
                'level': 'ERROR',
                'formatter': 'detailed',
                'filename': '/app/logs/error.log',
                'maxBytes': 10485760,  # 10MB
                'backupCount': 5,
                'encoding': 'utf8'
            },
            'api_file': {
                'class': 'logging.handlers.RotatingFileHandler',
                'level': 'DEBUG',
                'formatter': 'detailed',
                'filename': '/app/logs/api.log',
                'maxBytes': 10485760,  # 10MB
                'backupCount': 5,
                'encoding': 'utf8'
            },
            'chat_file': {
                'class': 'logging.handlers.RotatingFileHandler',
                'level': 'DEBUG',
                'formatter': 'detailed',
                'filename': '/app/logs/chat.log',
                'maxBytes': 10485760,  # 10MB
                'backupCount': 5,
                'encoding': 'utf8'
            },
        },
        'loggers': {
            '': {  # root logger
                'handlers': ['console', 'file', 'error_file'],
                'level': 'DEBUG',
                'propagate': True
            },
            'werkzeug': {
                'level': 'INFO',
                'propagate': True,
            },
            'api': {
                'handlers': ['console', 'api_file', 'error_file'],
                'level': 'DEBUG',
                'propagate': False,
            },
            'chat': {
                'handlers': ['console', 'chat_file', 'error_file'],
                'level': 'DEBUG',
                'propagate': False,
            }
        }
    }

    # 应用日志配置
    logging.config.dictConfig(logging_config)
    logger = logging.getLogger(__name__)
    
    # 获取API专用日志记录器
    api_logger = logging.getLogger('api')

    # 修复中间件顺序问题
    @app.after_request
    def finalize_response(response):
        """统一处理响应头的中间件"""
        # 先执行其他中间件
        response = add_cors_headers(response)
        return response

    def add_cors_headers(response):
        origin = request.headers.get('Origin')
        # 放宽CORS限制，允许更多的来源
        allowed_origins = [
            "http://113.45.251.116", 
            "http://113.45.251.116:80",
            "http://113.45.251.116:3000",
            "http://localhost",
            "http://localhost:3000",
            "http://localhost:80"
        ]
        
        # 精确匹配协议+域名+端口
        if origin in allowed_origins:
            response.headers['Access-Control-Allow-Origin'] = origin
        else:
            # 如果域名相同但端口不同，也允许访问（生产环境常见情况）
            parsed_origin = urlparse(origin or "")
            if parsed_origin.netloc and parsed_origin.netloc.startswith('113.45.251.116'):
                response.headers['Access-Control-Allow-Origin'] = origin
            else:
                # 默认允许当前域名
                response.headers['Access-Control-Allow-Origin'] = origin or '*'
                
        response.headers['Vary'] = 'Origin'
        # 添加更多允许的Headers
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, X-Requested-With, X-Request-Source, Authorization'
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS, PUT, DELETE'
        response.headers['Access-Control-Allow-Credentials'] = 'true'
        response.headers['Access-Control-Max-Age'] = '86400'
        return response

    # 修复OPTIONS处理
    @app.route('/api/<path:path>', methods=['OPTIONS'])
    def handle_options(path):
        response = make_response()
        response.headers['Content-Length'] = '0'
        response.headers['Content-Type'] = 'text/plain'
        return response, 204

    # 响应日志中间件
    @app.after_request
    def after_request(response):
        # 记录响应信息
        duration = (time.perf_counter() - request.start_time) * 1000
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
        """记录每个请求的详细信息"""
        if request.path.startswith('/api/'):
            api_logger.info(f"收到API请求 | 方法: {request.method} | 路径: {request.path} | IP: {request.remote_addr}")
            # 记录查询参数（GET请求）或JSON数据（POST请求）
            if request.method == 'GET' and request.args:
                # 隐藏敏感信息
                safe_args = {k: v if k not in ['api_key', 'token', 'password'] else '***' 
                             for k, v in request.args.items()}
                api_logger.debug(f"请求参数: {safe_args}")
            elif request.is_json:
                # 记录适当长度的JSON数据，隐藏敏感字段
                try:
                    data = request.get_json()
                    if isinstance(data, dict):
                        # 隐藏敏感信息
                        safe_data = {k: (v if k not in ['api_key', 'token', 'password', 'user_input'] 
                                      else ('***' if k in ['api_key', 'token', 'password'] 
                                           else f"{v[:100]}..." if isinstance(v, str) and len(v) > 100 else v))
                                   for k, v in data.items()}
                        api_logger.debug(f"请求数据: {safe_data}")
                except Exception as e:
                    api_logger.warning(f"无法解析JSON数据: {str(e)}")

    # 添加高精度计时中间件
    @app.before_request
    def start_timer():
        request.start_time = time.perf_counter()

    @app.route('/')
    def health_check():
        return {'status': 'ready', 'service': 'image-generator'}

    @app.route('/api/generate', methods=['POST'])
    def generate():
        # 记录请求内容类型
        content_type = request.headers.get('Content-Type', '未指定')
        logger.info(f"收到图像生成请求，Content-Type: {content_type}")
        
        # 内容类型检查 - 处理不同的内容类型
        try:
            # 检查内容类型
            if 'text/plain' in content_type:
                # 如果是 text/plain，先获取原始文本，然后解析为 JSON
                raw_data = request.get_data(as_text=True)
                data = json.loads(raw_data)
            else:
                # 尝试从请求体中解析 JSON，无论内容类型如何
                data = request.get_json(force=True)
                
            if not data:
                logger.error("请求体为空或不是有效的 JSON")
                return jsonify({"error": "请求体为空或不是有效的 JSON"}), 400
        except Exception as e:
            logger.error(f"无法解析请求体为 JSON: {str(e)}")
            # 记录原始请求数据以便调试
            try:
                raw_data = request.get_data(as_text=True)
                logger.error(f"原始请求数据: {raw_data[:500]}")
            except:
                logger.error("无法获取原始请求数据")
            return jsonify({"error": f"无法解析请求体: {str(e)}"}), 400
        
        try:
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

    @app.route('/api/chat', methods=['GET', 'POST'])
    def chat():
        """处理用户的聊天请求"""
        start_time = time.time()
        
        # 创建专门的聊天日志记录器
        chat_logger = logging.getLogger('chat')
        
        try:
            if request.method == 'GET':
                session_id = request.args.get('session_id')
                user_input = request.args.get('user_input')
                history = None
            else:
                data = request.get_json()
                session_id = data.get('session_id')
                user_input = data.get('user_input')
                history = data.get('history')

            if not session_id or not user_input:
                return jsonify({"error": "缺少必要参数"}), 400

            # 更新会话活动时间
            update_session_activity(session_id)
            
            # 为新会话创建停止事件
            stop_event = Event()
            session_stop_events[session_id] = stop_event

            # 构建消息历史
            messages = []
            
            # 如果前端传来了历史记录，使用前端的历史
            history_source = "none"
            if history:
                history_source = "frontend"
                for msg in history:
                    messages.append({
                        "role": msg.get("role"),
                        "content": msg.get("content")
                    })
            # 否则从服务器存储的历史中获取
            elif session_id in chat_histories:
                history_source = "server"
                messages = [{"role": msg["role"], "content": msg["content"]} for msg in chat_histories[session_id]]
            
            # 添加当前用户消息
            messages.append({"role": "user", "content": user_input})
            
            # 构造请求参数
            payload = {
                "model": "deepseek-ai/DeepSeek-V2.5",
                "messages": messages,
                "temperature": 0.7,
                "max_tokens": 2000,
                "stream": True
            }

            # 详细记录聊天请求
            chat_logger.info(f"开始聊天请求 | 会话ID: {session_id} | 历史来源: {history_source} | 消息数量: {len(messages)}")
            chat_logger.debug(f"用户输入: {user_input[:100]}{'...' if len(user_input) > 100 else ''}")
            chat_logger.debug(f"历史消息数: {len(messages) - 1}")
            
            client = LoggingSiliconFlowClient()
            response = client.chat_completion(payload)

            def generate():
                try:
                    # 首先返回用户的消息
                    yield f"data: {json.dumps({'type': 'user', 'content': user_input}, ensure_ascii=False)}\n\n"
                    
                    accumulated_content = ""
                    in_code_block = False
                    current_lang = None
                    code_block_content = ""
                    code_block_start = False
                    newline = "\n"  # 预定义换行符
                    response_start_time = time.time()
                    last_log_time = time.time()
                    chunk_count = 0
                    
                    for chunk in response:
                        chunk_count += 1
                        current_time = time.time()
                        
                        # 每隔5秒或每100个块记录一次进度
                        if chunk_count % 100 == 0 or current_time - last_log_time > 5:
                            chat_logger.debug(f"会话 {session_id} 生成中，已处理 {chunk_count} 个块，累积内容长度: {len(accumulated_content)}")
                            last_log_time = current_time
                            
                        if stop_event.is_set():
                            chat_logger.info(f"会话 {session_id} 被用户终止，已生成 {len(accumulated_content)} 字符")
                            break

                        if chunk and 'choices' in chunk and chunk['choices']:
                            content = chunk['choices'][0].get('delta', {}).get('content', '')
                            if content:
                                accumulated_content += content
                                
                                # 处理代码块开始
                                if '```' in content and not in_code_block:
                                    parts = content.split('```', 1)
                                    if len(parts) > 1:
                                        # 发送代码块前的内容
                                        if parts[0]:
                                            yield f"data: {json.dumps({'type': 'assistant', 'reply': parts[0]}, ensure_ascii=False)}\n\n"
                                        
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
                                        
                                        # 记录代码块开始
                                        chat_logger.debug(f"会话 {session_id} 开始代码块，语言: {current_lang}")
                                        
                                        # 发送代码块开始标记
                                        lang_marker = '```' + (current_lang if current_lang else '')
                                        yield f"data: {json.dumps({'type': 'assistant', 'reply': lang_marker}, ensure_ascii=False)}\n\n"
                                        # 单独发送换行符
                                        yield f"data: {json.dumps({'type': 'assistant', 'reply': newline}, ensure_ascii=False)}\n\n"
                                        if code_block_content:
                                            yield f"data: {json.dumps({'type': 'assistant', 'reply': code_block_content}, ensure_ascii=False)}\n\n"
                                        continue
                                
                                # 处理代码块结束
                                if '```' in content and in_code_block:
                                    parts = content.split('```', 1)
                                    code_block_content = parts[0]
                                    if code_block_content:
                                        yield f"data: {json.dumps({'type': 'assistant', 'reply': code_block_content}, ensure_ascii=False)}\n\n"
                                        # 分开发送结束标记和换行符
                                        yield f"data: {json.dumps({'type': 'assistant', 'reply': '```'}, ensure_ascii=False)}\n\n"
                                        yield f"data: {json.dumps({'type': 'assistant', 'reply': newline}, ensure_ascii=False)}\n\n"
                                        if len(parts) > 1 and parts[1]:
                                            yield f"data: {json.dumps({'type': 'assistant', 'reply': parts[1]}, ensure_ascii=False)}\n\n"
                                        
                                        # 记录代码块结束
                                        chat_logger.debug(f"会话 {session_id} 结束代码块，代码长度: {len(code_block_content)}")
                                        
                                        in_code_block = False
                                        current_lang = None
                                        code_block_content = ""
                                        continue
                                
                                # 处理代码块内的内容
                                if in_code_block:
                                    code_block_content += content
                                    yield f"data: {json.dumps({'type': 'assistant', 'reply': content}, ensure_ascii=False)}\n\n"
                                    continue
                                
                                # 处理普通文本
                                yield f"data: {json.dumps({'type': 'assistant', 'reply': content}, ensure_ascii=False)}\n\n"
                    
                    response_time = time.time() - response_start_time
                    
                    # 获取最后的AI回复并保存到聊天历史
                    if accumulated_content:
                        # 初始化会话历史（如果不存在）
                        if session_id not in chat_histories:
                            chat_histories[session_id] = []
                        
                        # 添加用户消息和AI回复到历史
                        chat_histories[session_id].append({"role": "user", "content": user_input})
                        chat_histories[session_id].append({"role": "assistant", "content": accumulated_content})
                        
                        # 限制历史记录长度
                        trim_chat_history(session_id)
                        
                        # 详细记录完成的聊天
                        chat_logger.info(f"会话 {session_id} 完成 | 响应时间: {response_time:.2f}秒 | 生成字符: {len(accumulated_content)} | 历史长度: {len(chat_histories[session_id])}")
                        
                except Exception as e:
                    chat_logger.error(f"会话 {session_id} 流式输出错误：{str(e)}", exc_info=True)
                    yield f"data: {json.dumps({'error': str(e)}, ensure_ascii=False)}\n\n"
                finally:
                    if session_id in session_stop_events:
                        del session_stop_events[session_id]
                    yield "data: [DONE]\n\n"
                    total_time = time.time() - start_time
                    chat_logger.info(f"会话 {session_id} 总处理时间: {total_time:.2f}秒")

            return Response(
                stream_with_context(generate()),
                mimetype='text/event-stream',
                headers={
                    'Cache-Control': 'no-cache',
                    'Connection': 'keep-alive',
                    'X-Accel-Buffering': 'no'
                }
            )

        except Exception as e:
            logger.error(f"聊天生成失败：{str(e)}", exc_info=True)
            return jsonify({
                "error": "对话生成失败",
                "detail": str(e)
            }), 500

    # 添加清除会话历史的接口
    @app.route('/api/chat/clear', methods=['POST'])
    def clear_chat_history():
        try:
            data = request.get_json()
            session_id = data.get('session_id')
            
            if session_id in chat_histories:
                del chat_histories[session_id]
                return jsonify({"status": "success", "message": "会话历史已清除"})
            
            return jsonify({"status": "not_found", "message": "未找到对应的会话"}), 404
            
        except Exception as e:
            logger.error(f"清除会话历史失败: {str(e)}")
            return jsonify({"error": "清除会话历史失败", "detail": str(e)}), 500

    @app.route('/api/models', methods=['GET'])
    def get_models():
        """获取可用模型列表"""
        return jsonify(DEFAULT_MODELS)

    @app.route('/static/<path:filename>')
    def serve_static(filename):
        return send_from_directory(
            os.path.join(app.root_path, '..', 'frontend', 'static'),
            filename
        )

    def validate_image_url(url):
        """验证图片URL是否合法"""
        try:
            parsed = urlparse(url)
            if parsed.scheme not in ('http', 'https'):
                return False
            return True
        except:
            return False

    @app.route('/health', methods=['GET'])
    def health_check():
        """健康检查接口"""
        logger.debug("健康检查请求")
        return jsonify({"status": "ok", "timestamp": datetime.datetime.now().isoformat()})

    @app.route('/api/logs/<log_type>/download', methods=['GET'])
    def download_log(log_type):
        """下载指定类型的日志文件"""
        # 获取API日志记录器
        api_logger = logging.getLogger('api')
        api_logger.info(f"请求下载日志文件: {log_type}")
        
        # 验证日志类型
        valid_log_types = ['app', 'error', 'api', 'chat']
        if log_type not in valid_log_types:
            api_logger.warning(f"无效的日志类型下载请求: {log_type}")
            return jsonify({"error": f"无效的日志类型: {log_type}，可用类型为: {', '.join(valid_log_types)}"}), 400
        
        # 构建日志文件路径
        log_file_path = f"/app/logs/{log_type}.log"
        
        try:
            if not os.path.exists(log_file_path):
                api_logger.warning(f"日志文件不存在: {log_file_path}")
                return jsonify({"error": f"日志文件 {log_type}.log 不存在"}), 404
            
            # 生成带有时间戳的文件名
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            download_filename = f"{log_type}_{timestamp}.log"
            
            # 设置响应头以触发下载
            return send_file(
                log_file_path,
                mimetype='text/plain',
                as_attachment=True,
                download_name=download_filename
            )
            
        except Exception as e:
            api_logger.error(f"下载日志失败: {str(e)}", exc_info=True)
            return jsonify({"error": f"下载日志失败: {str(e)}"}), 500

    @app.route('/api/logs/<log_type>', methods=['GET'])
    def get_logs(log_type):
        """获取指定类型的日志文件内容"""
        # 获取API日志记录器用于记录此API自身的调用
        api_logger = logging.getLogger('api')
        api_logger.info(f"请求获取日志文件: {log_type}")
        
        # 验证日志类型
        valid_log_types = ['app', 'error', 'api', 'chat']
        if log_type not in valid_log_types:
            api_logger.warning(f"无效的日志类型请求: {log_type}")
            return jsonify({"error": f"无效的日志类型: {log_type}，可用类型为: {', '.join(valid_log_types)}"}), 400
        
        # 获取请求参数
        lines = request.args.get('lines', default=100, type=int)
        lines = min(max(10, lines), 1000)  # 限制行数在10-1000行内
        
        start_line = request.args.get('start_line', default=0, type=int)
        start_line = max(0, start_line)  # 确保不是负数
        
        # 构建日志文件路径
        log_file_path = f"/app/logs/{log_type}.log"
        
        try:
            if not os.path.exists(log_file_path):
                api_logger.warning(f"日志文件不存在: {log_file_path}")
                return jsonify({"error": f"日志文件 {log_type}.log 不存在"}), 404
            
            # 获取文件的总行数
            with open(log_file_path, 'r', encoding='utf-8') as f:
                total_lines = sum(1 for _ in f)
            
            # 如果请求的起始行超过了文件总行数，则从文件末尾开始读取
            if start_line >= total_lines:
                start_line = max(0, total_lines - lines)
            
            # 读取指定行数的日志
            if start_line == 0 and lines >= total_lines:
                # 请求读取整个文件
                with open(log_file_path, 'r', encoding='utf-8') as f:
                    log_content = f.read()
                    line_count = total_lines
            else:
                # 读取指定的行
                result_lines = []
                current_line = 0
                with open(log_file_path, 'r', encoding='utf-8') as f:
                    for line in f:
                        if current_line >= start_line:
                            result_lines.append(line)
                            if len(result_lines) >= lines:
                                break
                        current_line += 1
                log_content = ''.join(result_lines)
                line_count = len(result_lines)
            
            # 返回日志内容和元数据
            response_data = {
                "log_type": log_type,
                "content": log_content,
                "lines_read": line_count,
                "total_lines": total_lines,
                "start_line": start_line,
                "next_start_line": start_line + line_count if start_line + line_count < total_lines else None,
                "file_size": os.path.getsize(log_file_path),
                "timestamp": datetime.now().isoformat()
            }
            
            api_logger.info(f"成功读取日志 {log_type}，返回 {line_count}/{total_lines} 行")
            return jsonify(response_data)
            
        except Exception as e:
            api_logger.error(f"获取日志失败: {str(e)}", exc_info=True)
            return jsonify({"error": f"获取日志失败: {str(e)}"}), 500

    @app.after_request
    def log_response_info(response):
        """记录响应信息"""
        if request.path.startswith('/api/'):
            status_code = response.status_code
            response_size = response.calculate_content_length() if hasattr(response, 'calculate_content_length') else len(response.get_data(as_text=True))
            
            # 根据状态码确定日志级别
            if status_code >= 500:
                log_method = api_logger.error
            elif status_code >= 400:
                log_method = api_logger.warning
            else:
                log_method = api_logger.info
                
            log_method(f"API响应 | 方法: {request.method} | 路径: {request.path} | 状态码: {status_code} | 大小: {response_size} 字节")
            
            # 对于错误响应，记录更多详情
            if status_code >= 400 and response.is_json:
                try:
                    error_data = json.loads(response.get_data(as_text=True))
                    api_logger.debug(f"错误响应: {error_data}")
                except Exception:
                    pass
        
        return response

    return app

app = create_app()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_ENV') == 'development'
    logger.info(f"应用启动: 端口={port}, 调试模式={debug}")
    app.run(host='0.0.0.0', port=port, debug=debug) 