import os
import requests
from typing import Optional, Dict
import logging
import json

logger = logging.getLogger(__name__)

class SiliconFlowClient:
    def __init__(self):
        self.base_url = os.getenv("SILICONFLOW_BASE_URL", "https://api.siliconflow.cn/v1")
        self.api_key = os.getenv('SILICONFLOW_API_KEY')
        self.timeout = 30
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

    def generate_image(self, payload, custom_headers=None):
        """调用生图API"""
        headers = {**self.headers, **(custom_headers or {})}
        
        # 脱敏处理日志信息
        safe_headers = {
            k: ('***' if 'Authorization' in k else v)
            for k, v in headers.items()
        }
        
        # 硅流API要求的参数结构
        formatted_payload = {
            "model": payload["model"],
            "prompt": payload["prompt"],
            "width": int(payload["width"]),
            "height": int(payload["height"]),
            "batch_size": payload["batch_size"],
            "num_inference_steps": 4,
            "guidance_scale": 4.0,
            "use_fast_sampler": True,
            "variation_seed": payload.get("variation_seed", 0),
            "variation_strength": 0.7
        }
        
        try:
            logger.info("准备发送请求到硅流API")
            logger.debug(f"请求地址: {self.base_url}/images/generations")
            logger.debug(f"请求头: {safe_headers}")
            logger.debug(f"请求参数: {formatted_payload}")
            logger.debug(f"模型专用参数: batch_size={formatted_payload['batch_size']}, variation_strength={formatted_payload.get('variation_strength')}")
            logger.debug(f"完整参数结构验证: {json.dumps(formatted_payload, indent=2)}")
            
            response = requests.post(
                f"{self.base_url}/images/generations",
                headers=headers,
                json=formatted_payload,
                timeout=self.timeout
            )
            
            logger.info(f"收到响应 状态码: {response.status_code}")
            logger.debug(f"响应头: {dict(response.headers)}")
            logger.debug(f"响应内容: {response.text[:200]}...")  # 截断长内容
            
            response.raise_for_status()
            response_data = response.json()
            logger.debug(f"解析后的响应数据: {response_data}")
            logger.debug(f"实际图片数量: {len(response_data.get('data', []))}")
            return {
                "images": [
                    {"url": img["url"], "seed": img.get("seed", 0)}
                    for img in response_data.get('data', [])
                ],
                "timings": response_data['timings'],
                "credits_used": response_data.get('credits_used', 0.2)
            }
        except requests.exceptions.RequestException as e:
            logger.error(f"API请求异常: {str(e)}")
            if e.response:
                logger.error(f"错误响应内容: {e.response.text[:200]}...")
                error_msg = f"API请求失败: {str(e)} [状态码: {e.response.status_code}]"
                raise RuntimeError(error_msg) from e
            else:
                raise RuntimeError(f"API请求失败: {str(e)}") from e

    def _check_model_access(self):
        check_url = f"{self.base_url}/models/{self.model_path}"
        try:
            response = requests.get(check_url, headers=self.headers, timeout=10)
            if response.status_code == 200:
                return True
            # 处理不同状态码
            print(f"模型访问检查失败: {response.status_code} - {response.text}")
            return False
        except Exception as e:
            print(f"模型访问检查异常: {str(e)}")
            return False

    def chat_completion(self, payload):
        """调用对话API"""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        formatted_payload = {
            "model": payload["model"],
            "messages": payload["messages"],
            "temperature": max(0.0, min(2.0, float(payload.get("temperature", 0.7)))),
            "max_tokens": int(payload.get("max_tokens", 1024)),
            "stream": False
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=headers,
                json=formatted_payload,
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            error_msg = f"API请求失败: {str(e)}"
            if e.response:
                status_code = e.response.status_code
                error_msg += f" [状态码: {status_code}]"
                raise RuntimeError(error_msg) from e
            else:
                raise RuntimeError(error_msg) from e 