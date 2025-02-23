import requests
import json
import time
import os
from siliconflow import SiliconFlowClient

def test_local_service():
    """测试本地服务接口"""
    base_url = "http://localhost:5000/api/generate"
    
    # 测试正常请求
    valid_payload = {
        "prompt": "A cute cat wearing sunglasses",
        "model": "black-forest-labs/FLUX.1-schnell",
        "width": 1024,
        "height": 1024,
        "num_images": 1,
        "guidance_scale": 3.0,
        "steps": 50,
        "negative_prompt": "low quality, blurry",
        "seed": 123456  # 添加种子参数
    }
    
    try:
        # 测试正常生成
        start_time = time.time()
        response = requests.post(base_url, json=valid_payload, timeout=30)
        response.raise_for_status()
        data = response.json()
        
        assert 'images' in data, "响应缺少images字段"
        assert len(data['images']) == 1, "生成图片数量不符"
        print(f"\033[32m✅ 正常生成测试通过 耗时: {time.time()-start_time:.2f}s\033[0m")
        
        # 测试元数据
        assert 'usage' in data, "响应缺少usage字段"
        assert isinstance(data['usage']['duration'], float), "生成耗时应为浮点数"
        assert data['usage']['credits_used'] > 0, "消耗积分应大于0"
        print(f"\033[32m✅ 元数据验证通过 生成耗时: {data['usage']['duration']}s\033[0m")
        
        return True
    except Exception as e:
        print(f"\033[31m❌ 测试失败: {str(e)}\033[0m")
        return False

def check_account_level():
    client = SiliconFlowClient()
    resp = client.get("/account/info")
    print(f"当前账户级别: L{resp['data']['level']}")
    assert resp['data']['level'] >= 1, "需要账户级别≥L1才能批量生成"

if __name__ == "__main__":
    print("🚀 开始本地接口测试...")
    if test_local_service():
        print("🎉 本地接口测试通过")
    else:
        print("🔥 本地接口测试失败") 