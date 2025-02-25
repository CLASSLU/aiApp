import os
import pytest
import requests
from dotenv import load_dotenv
from pathlib import Path

# 加载环境变量
env_path = Path(__file__).parent.parent.parent / '.env'
load_dotenv(env_path)

@pytest.mark.remote
class TestSiliconFlowAPI:
    """硅基流动远程接口测试套件"""
    
    @pytest.fixture
    def auth_header(self):
        return {"Authorization": f"Bearer {os.getenv('SILICONFLOW_API_KEY')}"}

    def test_image_generation(self, auth_header):
        """测试图像生成接口"""
        url = "https://api.siliconflow.cn/v1/images/generations"
        payload = {
            "model": "black-forest-labs/FLUX.1-schnell",
            "prompt": "测试用可爱猫咪",
            "width": 1024,
            "height": 1024,
            "num_images": 1,
            "guidance_scale": 3.0,
            "steps": 50
        }
        
        response = requests.post(url, headers=auth_header, json=payload, timeout=30)
        assert response.status_code == 200
        assert 'data' in response.json()

    def test_account_info(self, auth_header):
        """测试账户信息接口"""
        url = "https://api.siliconflow.cn/v1/account/info"
        response = requests.get(url, headers=auth_header)
        assert response.status_code == 200
        data = response.json()
        assert 'level' in data['data']
        assert isinstance(data['data']['credits'], int)

    def test_model_list(self, auth_header):
        """测试模型列表接口"""
        url = "https://api.siliconflow.cn/v1/models"
        response = requests.get(url, headers=auth_header)
        assert response.status_code == 200
        models = response.json()['data']
        assert any(m['id'] == 'black-forest-labs/FLUX.1-schnell' for m in models)

    def test_credit_usage(self, auth_header):
        """测试积分消耗准确性"""
        # 获取初始积分
        initial_credits = requests.get(
            "https://api.siliconflow.cn/v1/account/info", 
            headers=auth_header
        ).json()['data']['credits']
        
        # 执行生成请求
        self.test_image_generation(auth_header)
        
        # 验证积分变化
        updated_credits = requests.get(
            "https://api.siliconflow.cn/v1/account/info", 
            headers=auth_header
        ).json()['data']['credits']
        
        assert updated_credits < initial_credits, "积分未正确扣除"

    def test_batch_generation(self, auth_header):
        """测试批量图片生成"""
        url = "https://api.siliconflow.cn/v1/images/generations"
        payload = {
            "model": "black-forest-labs/FLUX.1-schnell",
            "prompt": "四只不同品种的猫咪",
            "num_images": 4,
            "width": 512,
            "height": 512
        }
        
        response = requests.post(url, headers=auth_header, json=payload)
        assert response.status_code == 200
        data = response.json()
        assert len(data['data']) == 4 