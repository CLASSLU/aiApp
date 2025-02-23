import os
import requests
from dotenv import load_dotenv
from pathlib import Path
import pytest

# 加载环境变量
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(env_path)

@pytest.fixture
def api_key():
    return os.getenv('SILICONFLOW_API_KEY')

def test_image_generation():
    """API集成测试脚本"""
    url = "https://api.siliconflow.com/v1/images/generations"
    headers = {
        "Authorization": f"Bearer {os.getenv('SILICONFLOW_API_KEY')}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "model": "black-forest-labs/FLUX.1-schnell",
        "prompt": "A cute cat wearing sunglasses",
        "num_images": 1,
        "width": 512,
        "height": 512,
        "steps": 50,
        "negative_prompt": "low quality, blurry",
        "guidance_scale": 3.0,
        "safety_checker": True
    }

    try:
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        response.raise_for_status()  # 自动抛出4xx/5xx错误
        print("\033[32m✅ 测试通过\033[0m")
        print("响应数据:", response.json())
        return True
    except requests.exceptions.HTTPError as e:
        print(f"\033[31m❌ HTTP错误: {e.response.status_code}\033[0m")
        print("错误详情:", e.response.text)
    except Exception as e:
        print(f"\033[31m❌ 其他错误: {str(e)}\033[0m")
    return False

def test_real_api(api_key):
    url = "https://api.siliconflow.cn/v1/images/generations"
    headers = {"Authorization": f"Bearer {api_key}"}
    
    payload = {
        "model": "black-forest-labs/FLUX.1-schnell",
        "prompt": "测试用可爱猫咪",
        "width": 1024,
        "height": 1024,
        "num_images": 1,
        "guidance_scale": 3.0,
        "steps": 50
    }
    
    response = requests.post(url, json=payload, headers=headers)
    assert response.status_code == 200
    assert 'data' in response.json()

if __name__ == "__main__":
    print("🚀 开始执行API集成测试...")
    if test_image_generation():
        print("🎉 所有测试用例通过")
    else:
        print("🔥 测试未通过，请检查错误日志") 