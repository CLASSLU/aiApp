# -*- coding: utf-8 -*-
from flask import Flask, jsonify, request, Response
from dotenv import load_dotenv
from flask_cors import CORS
from .api_client import SiliconFlowClient
import os
from pathlib import Path
from datetime import datetime
import requests
import random

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

def create_app():
    app = Flask(__name__)
    CORS(app, resources={r"/api/*": {
        "origins": "http://localhost:3000",
        "methods": ["POST", "OPTIONS"],
        "allow_headers": "Content-Type",
        "supports_credentials": True
    }})

    @app.route('/')
    def health_check():
        return {'status': 'ready', 'service': 'image-generator'}

    @app.route('/api/generate', methods=['POST', 'OPTIONS'])
    def generate():
        if request.method == 'OPTIONS':
            return _build_cors_preflight_response()
        try:
            if not request.get_data():
                return jsonify({"error": "请求体不能为空"}), 400
            app.logger.info(f"收到生成请求: {request.json}")
            
            # 参数验证逻辑
            data = request.json
            required_fields = ['prompt', 'model', 'width', 'height', 'num_images']
            if not all(field in data for field in required_fields):
                app.logger.error(f"缺少必要参数: {data}")
                return jsonify({"error": "缺少必要参数"}), 400
            
            if data['width'] not in [512, 768, 1024] or data['height'] not in [512, 768, 1024]:
                return jsonify({"error": "分辨率只支持512x512, 768x768, 1024x1024"}), 400
            
            if data['num_images'] < 1 or data['num_images'] > 4:
                return jsonify({"error": "生成数量需在1-4张之间"}), 400
            
            # 验证FLUX模型专用参数
            if data.get('model') == 'black-forest-labs/FLUX.1-schnell':
                if data.get('steps', 50) != 4:
                    return jsonify({"error": "FLUX模型必须使用4步推理"}), 400
                if not (3.8 <= float(data.get('guidance_scale', 3.0)) <= 4.2):
                    return jsonify({"error": "FLUX模型CFG Scale需在3.8-4.2之间"}), 400
            
            # 验证guidance_scale范围
            guidance_scale = float(data.get('guidance_scale', 3.0))
            if not (2.0 <= guidance_scale <= 10.0):
                return jsonify({"error": "CFG Scale需在2.0到10.0之间"}), 400
            
            # 验证参数类型
            try:
                width = int(data['width'])
                height = int(data['height'])
                if (width, height) not in [(512,512), (768,768), (1024,1024)]:
                    return jsonify({"error": "仅支持512x512, 768x768, 1024x1024分辨率"}), 400
                seed = int(data.get('seed', 0))
                if seed < 0:
                    return jsonify({"error": "种子值必须≥0"}), 400
            except ValueError:
                return jsonify({"error": "参数必须为整数"}), 400
            
            # 构造API请求体
            payload = {
                "prompt": data['prompt'],
                "model": "black-forest-labs/FLUX.1-schnell",
                "width": data['width'],
                "height": data['height'],
                "batch_size": data['num_images'],
                "num_inference_steps": 4,
                "guidance_scale": 4.0,
                "use_fast_sampler": True,
                "variation_seed": random.randint(0, 999999999),
                "variation_strength": 0.7
            }
            
            # 添加硅流要求的请求头
            headers = {
                "X-Request-Source": "myapp/1.0.0",
                "X-Request-ID": request.headers.get('X-Request-ID', '')
            }
            
            # 调用API时添加头信息
            client = SiliconFlowClient()
            result = client.generate_image(payload, headers)
            return jsonify({
                "images": result['images'],
                "usage": {
                    "duration": result['timings']['inference'],
                    "credits_used": result['credits_used']
                }
            })
        except Exception as e:
            app.logger.error(f"生成失败: {str(e)}", exc_info=True)
            return jsonify({"error": str(e)}), 500

    @app.route('/api/download', methods=['GET'])
    def download_proxy():
        try:
            image_url = request.args.get('url')
            if not image_url:
                return jsonify({"error": "缺少图片URL参数"}), 400
            
            # 设置合理的超时时间
            response = requests.get(image_url, timeout=10)
            response.raise_for_status()
            
            return Response(
                response.content,
                mimetype=response.headers['Content-Type'],
                headers={
                    'Content-Disposition': f'attachment; filename="generated-image.png"'
                }
            )
        except Exception as e:
            app.logger.error(f"下载失败: {str(e)}")
            return jsonify({"error": "图片下载失败"}), 500

    @app.route('/api/chat', methods=['POST'])
    def chat():
        # 确保路由存在
        return jsonify({"status": "ok"})

    @app.after_request
    def add_cors_headers(response):
        response.headers['Access-Control-Allow-Origin'] = 'http://localhost:3000'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization'
        response.headers['Access-Control-Allow-Methods'] = 'GET,PUT,POST,DELETE,OPTIONS'
        response.headers['Access-Control-Expose-Headers'] = 'Content-Disposition'
        return response

    return app

app = create_app()

if __name__ == '__main__':
    app.debug = True
    app.config['PROPAGATE_EXCEPTIONS'] = True
    app.run(host='0.0.0.0')

def _build_cors_preflight_response():
    response = jsonify({'status': 'preflight'})
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
    response.headers.add('Access-Control-Allow-Methods', 'POST')
    return response 