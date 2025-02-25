import os
import requests
from typing import Optional, Dict
import logging
import json
import time
import uuid

logger = logging.getLogger(__name__)

class SiliconFlowClient:
    def __init__(self, base_url="https://api.siliconflow.com/v1", api_key=None):
        self.base_url = base_url
        self.headers = {
            "Authorization": f"Bearer {api_key or os.getenv('SILICONFLOW_API_KEY')}",
            "Content-Type": "application/json"
        }
        self.timeout = 30
        logger.info("SiliconFlow客户端初始化完成，版本：1.2.0")

    def generate_image(self, payload, custom_headers=None):
        logger.info("进入generate_image方法")
        """调用生图API"""
        headers = {**self.headers, **(custom_headers or {})}
        
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
           
            response = requests.post(
                f"{self.base_url}/images/generations",
                headers=headers,
                json=formatted_payload,
                timeout=self.timeout
            )
                    
            response.raise_for_status()
            response_data = response.json()
            
            return {
                "images": [{"url": img["url"] for img in response_data.get('data', [])}],
                "credits_used": response_data.get('credits_used', 0)
            }
        except requests.exceptions.RequestException as e:
            
            raise

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

    def _safe_headers(self, headers):
        """处理敏感头信息"""
        return {
            k: ('***' if 'Authorization' in k else v)
            for k, v in headers.items()
        }

    def _generate_request_id(self):
        return uuid.uuid4().hex[:8]

class LoggingSiliconFlowClient:
    def __init__(self, base_url="https://api.siliconflow.com/v1", api_key=None):
        self.client = SiliconFlowClient(base_url, api_key)

    def generate_image(self, payload, custom_headers=None):
        request_id = uuid.uuid4().hex[:8]  # 生成请求ID
        logger.info(f"[Remote Request] ID:{request_id} POST /images/generations")
        
        start_time = time.perf_counter()
        try:
            response_data = self.client.generate_image(payload, custom_headers)
            duration = time.perf_counter() - start_time
            
            logger.info(f"[Remote Response] ID:{request_id} 200 (Duration: {duration:.2f}s)")
            return response_data
        except requests.exceptions.RequestException as e:
            logger.error(f"[Remote Error] ID:{request_id} {str(e)}")
            raise 