#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
图像生成API测试工具
用于测试SiliconFlow API和本地API服务的图像生成功能
"""

import os
import sys
import json
import argparse
import logging
import requests
import time
from datetime import datetime
from pathlib import Path

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

class ImageAPITester:
    """图像生成API测试工具"""
    
    def __init__(self, api_key=None, local=False, local_url="http://localhost/api/generate"):
        """初始化测试工具
        
        Args:
            api_key: SiliconFlow API密钥，默认从环境变量获取
            local: 是否测试本地API
            local_url: 本地API URL
        """
        self.api_key = api_key or os.getenv('SILICONFLOW_API_KEY')
        self.local = local
        self.local_url = local_url
        self.remote_url = "https://api.siliconflow.com/v1/images/generations"
        
        if not local and not self.api_key:
            logger.warning("未设置API密钥，无法测试远程API")
            logger.info("可以设置SILICONFLOW_API_KEY环境变量或使用--api-key参数")
        
        # 保存测试结果
        self.results = []
    
    def test_connection(self):
        """测试API连接状态"""
        logger.info("开始测试API连接...")
        
        if self.local:
            url = self.local_url
            headers = {"Content-Type": "application/json"}
            message = "测试本地API连接"
        else:
            url = self.remote_url
            if not self.api_key:
                logger.error("缺少API密钥，无法测试远程API连接")
                return False
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            }
            message = "测试远程API连接"
        
        try:
            # 使用OPTIONS请求或者HEAD请求测试连接
            if self.local:
                # 对于本地API，先测试前端主页
                logger.info("测试前端主页连接...")
                front_response = requests.get("http://localhost/", timeout=5)
                logger.info(f"前端连接状态: {front_response.status_code}")
                
                # 再测试API端点
                response = requests.options(url, timeout=5)
            else:
                # 对于远程API，直接发送OPTIONS请求
                response = requests.options(url, headers=headers, timeout=5)
            
            status_code = response.status_code
            logger.info(f"API连接状态: {status_code}")
            
            if status_code in (200, 204, 404):  # 404也可能表示端点存在但不支持OPTIONS
                logger.info(f"✅ {message}成功!")
                return True
            else:
                logger.error(f"❌ {message}失败! 状态码: {status_code}")
                return False
                
        except requests.exceptions.ConnectionError:
            logger.error(f"❌ {message}失败! 无法连接到服务器")
            return False
        except requests.exceptions.Timeout:
            logger.error(f"❌ {message}失败! 连接超时")
            return False
        except Exception as e:
            logger.error(f"❌ {message}失败! 错误: {str(e)}")
            return False
    
    def generate_image(self, model=None, prompt=None, width=1024, height=1024, num_images=1):
        """测试图像生成
        
        Args:
            model: 模型名称
            prompt: 图像提示词
            width: 图像宽度
            height: 图像高度
            num_images: 生成图像数量
        
        Returns:
            dict: 包含测试结果的字典
        """
        start_time = time.time()
        
        if not prompt:
            prompt = "一只可爱的猫咪在阳光下玩耍，高清照片"
        
        result = {
            "timestamp": datetime.now().isoformat(),
            "success": False,
            "duration": 0,
            "prompt": prompt,
            "model": model,
            "images": [],
            "error": None
        }
        
        if self.local:
            url = self.local_url
            headers = {"Content-Type": "application/json"}
            payload = {
                "prompt": prompt,
                "model": model or "black-forest-labs/FLUX.1-schnell",
                "width": width,
                "height": height,
                "num_images": num_images
            }
            logger.info(f"本地API调用: {url}")
        else:
            if not self.api_key:
                error_msg = "缺少API密钥，无法进行图像生成测试"
                logger.error(f"❌ {error_msg}")
                result["error"] = error_msg
                return result
                
            url = self.remote_url
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            }
            payload = {
                "model": model or "black-forest-labs/FLUX.1-schnell",
                "prompt": prompt,
                "width": width,
                "height": height,
                "batch_size": num_images,
                "num_inference_steps": 20,
                "guidance_scale": 7.5,
                "use_fast_sampler": True
            }
            logger.info(f"远程API调用: {url}")
        
        logger.info(f"提示词: '{prompt}'")
        logger.info(f"图像尺寸: {width}x{height}, 数量: {num_images}")
        
        try:
            logger.info("发送API请求...")
            response = requests.post(
                url,
                headers=headers,
                json=payload,
                timeout=60  # 增加超时时间到60秒
            )
            
            duration = time.time() - start_time
            result["duration"] = round(duration, 2)
            
            logger.info(f"状态码: {response.status_code}")
            logger.info(f"响应时间: {duration:.2f}秒")
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    
                    # 处理本地API和远程API的不同响应格式
                    if self.local:
                        if "images" in data:
                            image_urls = data["images"]
                            result["images"] = image_urls
                            result["success"] = True
                            logger.info(f"✅ 成功生成 {len(image_urls)} 张图像!")
                            for i, url in enumerate(image_urls):
                                logger.info(f"图像 {i+1}: {url}")
                        else:
                            error_msg = data.get("error", "未知错误")
                            logger.error(f"❌ 图像生成失败: {error_msg}")
                            result["error"] = error_msg
                    else:
                        if "data" in data and len(data["data"]) > 0:
                            image_urls = [img["url"] for img in data["data"]]
                            result["images"] = image_urls
                            result["success"] = True
                            logger.info(f"✅ 成功生成 {len(image_urls)} 张图像!")
                            for i, url in enumerate(image_urls):
                                logger.info(f"图像 {i+1}: {url}")
                        else:
                            error_msg = "API响应中没有图像数据"
                            logger.error(f"❌ {error_msg}")
                            result["error"] = error_msg
                except ValueError:
                    error_msg = "无法解析API响应为JSON"
                    logger.error(f"❌ {error_msg}")
                    logger.error(f"原始响应: {response.text[:500]}")
                    result["error"] = error_msg
            else:
                try:
                    error_data = response.json()
                    error_msg = f"API请求失败 (HTTP {response.status_code}): {json.dumps(error_data)}"
                except:
                    error_msg = f"API请求失败 (HTTP {response.status_code}): {response.text[:200]}"
                
                logger.error(f"❌ {error_msg}")
                result["error"] = error_msg
                
        except requests.exceptions.Timeout:
            error_msg = "API请求超时，可能是因为图像生成耗时较长"
            logger.error(f"❌ {error_msg}")
            result["error"] = error_msg
        except requests.exceptions.ConnectionError:
            error_msg = "无法连接到API服务器，请检查网络连接"
            logger.error(f"❌ {error_msg}")
            result["error"] = error_msg
        except Exception as e:
            error_msg = f"测试过程中发生错误: {str(e)}"
            logger.error(f"❌ {error_msg}")
            result["error"] = error_msg
        
        # 保存结果
        self.results.append(result)
        return result
    
    def save_results(self, filename=None):
        """保存测试结果到文件
        
        Args:
            filename: 保存的文件名，默认为"image_api_test_结果_{timestamp}.json"
        """
        if not self.results:
            logger.warning("没有测试结果可保存")
            return
        
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"image_api_test_results_{timestamp}.json"
        
        try:
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump({
                    "timestamp": datetime.now().isoformat(),
                    "results": self.results
                }, f, ensure_ascii=False, indent=2)
            
            logger.info(f"✅ 测试结果已保存到 {filename}")
        except Exception as e:
            logger.error(f"❌ 保存测试结果失败: {str(e)}")

def main():
    parser = argparse.ArgumentParser(description='图像生成API测试工具')
    parser.add_argument('--api-key', help='SiliconFlow API密钥')
    parser.add_argument('--local', action='store_true', help='测试本地API而不是远程API')
    parser.add_argument('--test-connection', action='store_true', help='只测试API连接')
    parser.add_argument('--model', help='使用的模型名称')
    parser.add_argument('--prompt', help='图像生成提示词')
    parser.add_argument('--width', type=int, default=1024, help='图像宽度')
    parser.add_argument('--height', type=int, default=1024, help='图像高度')
    parser.add_argument('--num-images', type=int, default=1, help='生成图像数量')
    parser.add_argument('--save', help='保存测试结果到指定文件')
    parser.add_argument('--verbose', action='store_true', help='显示更详细的日志')
    
    args = parser.parse_args()
    
    # 设置日志级别
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    # 初始化测试工具
    tester = ImageAPITester(api_key=args.api_key, local=args.local)
    
    # 测试连接
    if args.test_connection:
        tester.test_connection()
    else:
        # 先测试连接，再生成图像
        connection_ok = tester.test_connection()
        if connection_ok or args.local:
            tester.generate_image(
                model=args.model,
                prompt=args.prompt,
                width=args.width,
                height=args.height,
                num_images=args.num_images
            )
    
    # 保存测试结果
    if args.save:
        tester.save_results(args.save)

if __name__ == "__main__":
    main() 