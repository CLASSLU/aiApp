import os
import requests
from typing import Optional, Dict
import logging
import json
import time
import uuid
from functools import wraps

logger = logging.getLogger(__name__)

def log_api_call(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        logger.info(f"调用 API: {func.__name__}")
        try:
            result = func(*args, **kwargs)
            logger.info(f"API 调用成功: {func.__name__}")
            return result
        except Exception as e:
            logger.error(f"API 调用失败: {func.__name__}, 错误: {str(e)}")
            raise
    return wrapper

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
        """调用SiliconFlow API生成图像。

        Args:
            payload: 包含请求参数的字典，必须包含:
                model: 模型名称
                prompt: 图像生成提示词
                width, height: 图像尺寸
                batch_size: 要生成的图像数量
                其他可选参数
            custom_headers: 可选的自定义HTTP头信息

        Returns:
            dict: 包含图像URL的响应数据或错误信息
        """
        logger.debug("进入generate_image方法")
        
        try:
            # 检查API密钥是否存在
            if not self.headers.get("Authorization"):
                logger.error("缺少API密钥，无法进行图像生成")
                return {"error": "缺少API密钥", "images": []}
                
            # 构造请求头
            headers = {**self.headers, **(custom_headers or {})}
            
            # 记录请求信息
            api_url = f"{self.base_url}/images/generations"
            logger.debug(f"图像生成API请求URL: {api_url}")
            
            # 构造请求负载
            formatted_payload = {
                "model": payload.get("model", "black-forest-labs/FLUX.1-schnell"),
                "prompt": payload.get("prompt", ""),
                "width": payload.get("width", 1024),
                "height": payload.get("height", 1024),
                "batch_size": payload.get("batch_size", 1),
                "num_inference_steps": payload.get("num_inference_steps", 20),
                "guidance_scale": payload.get("guidance_scale", 7.5),
                "use_fast_sampler": payload.get("use_fast_sampler", True),
                "variation_seed": payload.get("variation_seed", 0),
                "variation_strength": payload.get("variation_strength", 0.0),
            }
            
            # 记录请求参数
            logger.debug(f"图像生成请求参数: {json.dumps(formatted_payload, ensure_ascii=False)}")
            
            # 发起POST请求
            logger.info(f"正在调用图像生成API，模型: {formatted_payload['model']}, 提示词: '{formatted_payload['prompt'][:50]}...'")
            response = requests.post(
                api_url,
                headers=headers,
                json=formatted_payload,
                timeout=60  # 增加超时时间到60秒
            )
            
            # 检查HTTP状态码
            if response.status_code != 200:
                logger.error(f"API请求失败，状态码: {response.status_code}, 响应: {response.text[:500]}")
                return {"error": f"API请求失败 (HTTP {response.status_code}): {response.text[:100]}", "images": []}
            
            # 解析响应
            try:
                data = response.json()
                logger.debug(f"API响应成功，数据大小: {len(str(data))} 字节")
                
                # 验证响应中是否有图像
                if not data.get("data") or len(data["data"]) == 0:
                    logger.warning("API响应中没有图像数据")
                    return {"error": "API响应中没有图像数据", "images": []}
                    
                logger.info(f"成功生成 {len(data.get('data', []))} 张图像")
                return {
                    "images": [{"url": img["url"]} for img in data.get('data', [])],
                    "credits_used": data.get('credits_used', 0)
                }
            except ValueError as e:
                logger.error(f"无法解析API响应为JSON: {str(e)}", exc_info=True)
                logger.error(f"原始响应: {response.text[:500]}")
                return {"error": "无法解析API响应", "images": []}
                
        except requests.exceptions.ConnectTimeout as e:
            logger.error(f"连接API超时: {str(e)}", exc_info=True)
            return {"error": "连接API服务器超时，请检查网络连接和API服务器状态", "images": []}
        except requests.exceptions.ReadTimeout as e:
            logger.error(f"读取API响应超时: {str(e)}", exc_info=True)
            return {"error": "等待API响应超时，可能是由于图像生成耗时过长或服务器繁忙", "images": []}
        except requests.exceptions.ConnectionError as e:
            logger.error(f"连接API服务器错误: {str(e)}", exc_info=True)
            return {"error": "无法连接到API服务器，请检查网络连接和API服务器地址", "images": []}
        except Exception as e:
            logger.error(f"图像生成过程中发生未预期的错误: {str(e)}", exc_info=True)
            return {"error": f"图像生成失败: {str(e)}", "images": []}

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

    @log_api_call
    def chat_completion(self, payload):
        """调用聊天接口"""
        try:
            # 确保 payload 是字典格式
            if isinstance(payload, tuple):
                payload = payload[0]
            
            # 格式化请求参数
            formatted_payload = {
                "model": payload["model"],
                "messages": payload["messages"],
                "temperature": max(0.0, min(2.0, float(payload.get("temperature", 0.7)))),
                "max_tokens": int(payload.get("max_tokens", 1024)),
                "stream": True  # 强制使用流式输出
            }

            logger.info(f"发送聊天请求，模型: {formatted_payload['model']}")
            logger.info(f"消息历史: {json.dumps(formatted_payload['messages'], ensure_ascii=False)}")

            # 发送请求
            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=self.headers,
                json=formatted_payload,
                timeout=self.timeout,
                stream=True  # 强制使用流式响应
            )
            response.raise_for_status()

            # 处理流式响应
            def generate():
                for line in response.iter_lines():
                    if not line:
                        continue
                    try:
                        line = line.decode('utf-8')
                        if line.startswith('data: '):
                            line = line[6:]  # 移除 "data: " 前缀
                            if line == '[DONE]':
                                logger.info("聊天完成")
                                break
                            data = json.loads(line)
                            logger.debug(f"收到数据: {json.dumps(data, ensure_ascii=False)}")
                            yield data
                    except json.JSONDecodeError as e:
                        logger.warning(f"解析响应数据失败: {e}, 原始数据: {line}")
                        continue
                    except Exception as e:
                        logger.error(f"处理响应数据时出错: {e}")
                        raise

            return generate()

        except requests.exceptions.RequestException as e:
            error_msg = f"API请求失败: {str(e)}"
            if hasattr(e, 'response') and e.response:
                error_msg += f" [状态码: {e.response.status_code}]"
                try:
                    error_details = e.response.json()
                    error_msg += f" [错误信息: {error_details}]"
                except:
                    if e.response.text:
                        error_msg += f" [响应内容: {e.response.text[:200]}...]"
            logger.error(error_msg)
            raise RuntimeError(error_msg) from e

    def _safe_headers(self, headers):
        """处理敏感头信息"""
        return {
            k: ('***' if 'Authorization' in k else v)
            for k, v in headers.items()
        }

    def _generate_request_id(self):
        return uuid.uuid4().hex[:8]

class LoggingClient:
    def __init__(self, client):
        self.client = client

    def _log_request(self, method_name, payload):
        request_id = uuid.uuid4().hex[:8]
        logger.info(f"[Remote Request] ID:{request_id} Calling {method_name}")
        logger.info(f"请求参数: {payload}")
        start_time = time.perf_counter()
        return request_id, start_time

    def _log_response(self, request_id, method_name, duration, response):
        logger.info(f"[Remote Response] ID:{request_id} {method_name} completed in {duration:.2f}s")
        return response

    def __getattr__(self, method_name):
        # 代理方法调用
        original_method = getattr(self.client, method_name)

        def wrapper(*args, **kwargs):
            request_id, start_time = self._log_request(method_name, args)
            try:
                response = original_method(*args, **kwargs)
                duration = time.perf_counter() - start_time
                return self._log_response(request_id, method_name, duration, response)
            except Exception as e:
                logger.error(f"[Remote Error] ID:{request_id} {str(e)}")
                raise

        return wrapper

class LoggingSiliconFlowClient:
    _instance = None
    _session = None

    def __init__(self):
        if not LoggingSiliconFlowClient._instance:
            # 验证环境变量
            api_key = os.getenv('SILICONFLOW_API_KEY')
            if not api_key:
                raise ValueError("未设置 SILICONFLOW_API_KEY 环境变量")
            if not api_key.startswith('sk-'):
                raise ValueError("API Key 格式不正确，应以 'sk-' 开头")

            # 初始化客户端
            self.base_url = "https://api.siliconflow.com/v1"  # 或其他正确的基础URL
            self.headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "Accept": "application/json"  # 明确指定接受 JSON 响应
            }
            self.timeout = 30
            
            
            LoggingSiliconFlowClient._instance = self
            LoggingSiliconFlowClient._session = requests.Session()
            logger.info(f"SiliconFlow客户端初始化完成")
        else:
            self.base_url = LoggingSiliconFlowClient._instance.base_url
            self.headers = LoggingSiliconFlowClient._instance.headers
            self.timeout = LoggingSiliconFlowClient._instance.timeout

   
    def generate_response(self, data, stop_event):
        """处理流式响应生成，支持中途停止"""
        try:
            user_input = data.get('user_input')
            messages = data.get('messages', [])

            if not user_input:
                raise ValueError("缺少必要参数")

            # 构造请求参数
            payload = {
                "model": "deepseek-ai/DeepSeek-V2.5",
                "messages": [
                    *messages[-10:],  # 保留最近10条消息
                    {"role": "user", "content": user_input}
                ],
                "temperature": 0.7,
                "max_tokens": 150,
                "stream": True
            }

            # 发起请求
            self._current_request = self._session.post(
                f"{self.base_url}/v1/chat/completions",
                json=payload,
                headers=self.headers,
                stream=True
            )

            for chunk in self._current_request.iter_lines():
                # 检查是否需要停止
                if stop_event.is_set():
                    if self._current_request:
                        self._current_request.close()
                    break

                if chunk:
                    try:
                        chunk_data = json.loads(chunk.decode('utf-8').replace('data: ', ''))
                        if 'choices' in chunk_data and chunk_data['choices']:
                            content = chunk_data['choices'][0].get('delta', {}).get('content', '')
                            if content:
                                yield content
                    except json.JSONDecodeError:
                        continue

        except Exception as e:
            logger.error(f"生成响应时出错: {str(e)}")
            raise
        finally:
            self._current_request = None

    def stop_request(self):
        """停止当前正在进行的请求"""
        if self._current_request:
            try:
                self._current_request.close()
            except:
                pass
            self._current_request = None

    def generate_image(self, payload, custom_headers=None):
        """调用SiliconFlow API生成图像。

        Args:
            payload: 包含请求参数的字典，必须包含:
                model: 模型名称
                prompt: 图像生成提示词
                width, height: 图像尺寸
                batch_size: 要生成的图像数量
                其他可选参数
            custom_headers: 可选的自定义HTTP头信息

        Returns:
            dict: 包含图像URL的响应数据或错误信息
        """
        logger.debug("进入generate_image方法")
        
        try:
            # 检查API密钥是否存在
            if not self.headers.get("Authorization"):
                logger.error("缺少API密钥，无法进行图像生成")
                return {"error": "缺少API密钥", "images": []}
                
            # 构造请求头
            headers = {**self.headers, **(custom_headers or {})}
            
            # 记录请求信息
            api_url = f"{self.base_url}/images/generations"
            logger.debug(f"图像生成API请求URL: {api_url}")
            
            # 构造请求负载
            formatted_payload = {
                "model": payload.get("model", "black-forest-labs/FLUX.1-schnell"),
                "prompt": payload.get("prompt", ""),
                "width": payload.get("width", 1024),
                "height": payload.get("height", 1024),
                "batch_size": payload.get("batch_size", 1),
                "num_inference_steps": payload.get("num_inference_steps", 20),
                "guidance_scale": payload.get("guidance_scale", 7.5),
                "use_fast_sampler": payload.get("use_fast_sampler", True),
                "variation_seed": payload.get("variation_seed", 0),
                "variation_strength": payload.get("variation_strength", 0.0),
            }
            
            # 记录请求参数
            logger.debug(f"图像生成请求参数: {json.dumps(formatted_payload, ensure_ascii=False)}")
            
            # 发起POST请求
            logger.info(f"正在调用图像生成API，模型: {formatted_payload['model']}, 提示词: '{formatted_payload['prompt'][:50]}...'")
            response = requests.post(
                api_url,
                headers=headers,
                json=formatted_payload,
                timeout=60  # 增加超时时间到60秒
            )
            
            # 检查HTTP状态码
            if response.status_code != 200:
                logger.error(f"API请求失败，状态码: {response.status_code}, 响应: {response.text[:500]}")
                return {"error": f"API请求失败 (HTTP {response.status_code}): {response.text[:100]}", "images": []}
            
            # 解析响应
            try:
                data = response.json()
                logger.debug(f"API响应成功，数据大小: {len(str(data))} 字节")
                
                # 验证响应中是否有图像
                if not data.get("data") or len(data["data"]) == 0:
                    logger.warning("API响应中没有图像数据")
                    return {"error": "API响应中没有图像数据", "images": []}
                    
                logger.info(f"成功生成 {len(data.get('data', []))} 张图像")
                return {
                    "images": [{"url": img["url"]} for img in data.get('data', [])],
                    "credits_used": data.get('credits_used', 0)
                }
            except ValueError as e:
                logger.error(f"无法解析API响应为JSON: {str(e)}", exc_info=True)
                logger.error(f"原始响应: {response.text[:500]}")
                return {"error": "无法解析API响应", "images": []}
                
        except requests.exceptions.ConnectTimeout as e:
            logger.error(f"连接API超时: {str(e)}", exc_info=True)
            return {"error": "连接API服务器超时，请检查网络连接和API服务器状态", "images": []}
        except requests.exceptions.ReadTimeout as e:
            logger.error(f"读取API响应超时: {str(e)}", exc_info=True)
            return {"error": "等待API响应超时，可能是由于图像生成耗时过长或服务器繁忙", "images": []}
        except requests.exceptions.ConnectionError as e:
            logger.error(f"连接API服务器错误: {str(e)}", exc_info=True)
            return {"error": "无法连接到API服务器，请检查网络连接和API服务器地址", "images": []}
        except Exception as e:
            logger.error(f"图像生成过程中发生未预期的错误: {str(e)}", exc_info=True)
            return {"error": f"图像生成失败: {str(e)}", "images": []}

    @log_api_call
    def chat_completion(self, payload):
        """调用聊天接口"""
        try:
            # 确保 payload 是字典格式
            if isinstance(payload, tuple):
                payload = payload[0]
            
            # 格式化请求参数
            formatted_payload = {
                "model": payload["model"],
                "messages": payload["messages"],
                "temperature": max(0.0, min(2.0, float(payload.get("temperature", 0.7)))),
                "max_tokens": int(payload.get("max_tokens", 1024)),
                "stream": True  # 强制使用流式输出
            }

            logger.info(f"发送聊天请求，模型: {formatted_payload['model']}")
            logger.info(f"消息历史: {json.dumps(formatted_payload['messages'], ensure_ascii=False)}")

            # 发送请求
            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=self.headers,
                json=formatted_payload,
                timeout=self.timeout,
                stream=True  # 强制使用流式响应
            )
            response.raise_for_status()

            # 处理流式响应
            def generate():
                for line in response.iter_lines():
                    if not line:
                        continue
                    try:
                        line = line.decode('utf-8')
                        if line.startswith('data: '):
                            line = line[6:]  # 移除 "data: " 前缀
                            if line == '[DONE]':
                                logger.info("聊天完成")
                                break
                            data = json.loads(line)
                            logger.debug(f"收到数据: {json.dumps(data, ensure_ascii=False)}")
                            yield data
                    except json.JSONDecodeError as e:
                        logger.warning(f"解析响应数据失败: {e}, 原始数据: {line}")
                        continue
                    except Exception as e:
                        logger.error(f"处理响应数据时出错: {e}")
                        raise

            return generate()

        except requests.exceptions.RequestException as e:
            error_msg = f"API请求失败: {str(e)}"
            if hasattr(e, 'response') and e.response:
                error_msg += f" [状态码: {e.response.status_code}]"
                try:
                    error_details = e.response.json()
                    error_msg += f" [错误信息: {error_details}]"
                except:
                    if e.response.text:
                        error_msg += f" [响应内容: {e.response.text[:200]}...]"
            logger.error(error_msg)
            raise RuntimeError(error_msg) from e

    def _safe_headers(self, headers):
        """处理敏感头信息"""
        safe_headers = headers.copy()
        if 'Authorization' in safe_headers:
            safe_headers['Authorization'] = safe_headers['Authorization'][:15] + '...'
        return safe_headers

    def _generate_request_id(self):
        return uuid.uuid4().hex[:8]

    @log_api_call
    def get_models(self):
        """获取可用的模型列表"""
        try:
            logger.info("正在请求模型列表，URL: %s/models", self.base_url)
            logger.info("请求头: %s", self._safe_headers(self.headers))
            
            response = requests.get(
                f"{self.base_url}/models",
                headers=self.headers,
                timeout=self.timeout
            )
            
            logger.info(f"模型列表响应状态码: {response.status_code}")
            
            # 记录响应内容
            try:
                response_data = response.json()
                logger.info(f"API响应内容: {json.dumps(response_data, ensure_ascii=False, indent=2)}")
            except json.JSONDecodeError:
                logger.warning(f"API响应内容(非JSON): {response.text[:200]}")
            
            response.raise_for_status()  # 确保请求成功
            
            return response.json()
            
        except requests.exceptions.RequestException as e:
            error_msg = f"获取模型列表失败: {str(e)}"
            if hasattr(e, 'response') and e.response:
                try:
                    error_details = e.response.json()
                    error_msg += f"\n错误详情: {json.dumps(error_details, ensure_ascii=False)}"
                except:
                    error_msg += f"\n响应内容: {e.response.text[:200]}"
            logger.error(error_msg)
            raise RuntimeError(error_msg) from e
