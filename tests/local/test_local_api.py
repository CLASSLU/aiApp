import pytest
import requests
from src.app import create_app
import sys

@pytest.mark.local
class TestLocalAPI:
    """本地服务接口测试套件"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        self.app = create_app()
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()
        self.base_url = "http://localhost:5000/api"

    def test_image_generation(self):
        """测试本地图像生成接口"""
        payload = {
            "prompt": "A cute cat wearing sunglasses",
            "model": "black-forest-labs/FLUX.1-schnell",
            "width": 1024,
            "height": 1024,
            "num_images": 1,
            "guidance_scale": 3.0
        }
        
        response = self.client.post(f"{self.base_url}/generate", json=payload)
        assert response.status_code == 200
        data = response.json
        assert 'images' in data
        assert len(data['images']) == 1

    def test_invalid_parameters(self):
        """测试参数验证"""
        invalid_payloads = [
            {"prompt": "test", "width": 256},  # 分辨率过小
            {"prompt": "test", "num_images": 5},  # 生成数量超限
            {"prompt": "test", "model": "invalid_model"}  # 无效模型
        ]
        
        for payload in invalid_payloads:
            response = self.client.post(f"{self.base_url}/generate", json=payload)
            assert response.status_code == 400

    def test_rate_limiting(self):
        """测试速率限制"""
        valid_payload = {
            "prompt": "valid request",
            "model": "black-forest-labs/FLUX.1-schnell",
            "width": 512,
            "height": 512,
            "num_images": 1
        }
        
        # 连续发送10个请求
        responses = []
        for _ in range(10):
            response = self.client.post(f"{self.base_url}/generate", json=valid_payload)
            responses.append(response.status_code)
        
        assert 429 in responses, "未触发速率限制"

    def test_response_format(self):
        """测试响应格式规范"""
        payload = {
            "prompt": "格式测试用图片",
            "model": "black-forest-labs/FLUX.1-schnell",
            "width": 1024,
            "num_images": 1
        }
        
        response = self.client.post(f"{self.base_url}/generate", json=payload)
        data = response.json
        
        # 验证标准响应结构
        assert all(key in data for key in ['request_id', 'created', 'images', 'usage'])
        assert isinstance(data['usage']['duration'], float)
        assert data['usage']['credits_used'] > 0

    def test_response_metadata(self):
        """测试响应元数据完整性"""
        payload = {
            "prompt": "元数据测试",
            "model": "black-forest-labs/FLUX.1-schnell",
            "width": 1024,
            "num_images": 1
        }
        
        response = self.client.post(f"{self.base_url}/generate", json=payload)
        data = response.json
        
        # 验证标准元数据字段
        assert all(key in data['usage'] for key in ['duration', 'credits_used', 'model'])
        assert isinstance(data['created'], int)
        assert len(data['request_id']) == 32  # 验证UUID格式 

print(sys.path)  # 查看Python路径 