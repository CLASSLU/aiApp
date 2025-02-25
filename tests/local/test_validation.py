import pytest
from flask import Flask
from app import create_app

@pytest.mark.local
class TestParameterValidation:
    """参数验证专项测试"""
    
    @pytest.fixture
    def client(self):
        app = create_app()
        app.config['TESTING'] = True
        return app.test_client()
    
    @pytest.mark.parametrize("width,valid", [
        (512, True),
        (768, True),
        (1024, True),
        (256, False),
        (2048, False)
    ])
    def test_resolution_validation(self, client, width, valid):
        """测试分辨率验证逻辑"""
        payload = {
            "prompt": "validation test",
            "width": width,
            "height": width,
            "num_images": 1
        }
        response = client.post("/api/generate", json=payload)
        assert response.status_code == 200 if valid else 400
    
    @pytest.mark.parametrize("guidance_scale,valid", [
        (3.8, True),
        (4.2, True),
        (3.7, False),
        (4.3, False)
    ])
    def test_guidance_scale_validation(self, client, guidance_scale, valid):
        """测试引导比例验证"""
        payload = {
            "prompt": "validation test",
            "model": "black-forest-labs/FLUX.1-schnell",
            "guidance_scale": guidance_scale,
            "num_images": 1
        }
        response = client.post("/api/generate", json=payload)
        assert response.status_code == 200 if valid else 400
    
    @pytest.mark.parametrize("num_images,valid", [
        (1, True),
        (4, True),
        (0, False),
        (5, False)
    ])
    def test_num_images_validation(self, client, num_images, valid):
        """测试生成数量验证"""
        payload = {
            "prompt": "数量验证测试",
            "num_images": num_images
        }
        response = client.post("/api/generate", json=payload)
        assert response.status_code == 200 if valid else 400 