import pytest
import json
from src.app import create_app  # 确保路径正确

@pytest.fixture
def client():
    app = create_app()
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_chat_completion_success(client):
    """测试正常对话请求"""
    payload = {
        "model": "Qwen/Qwen2-7B-Instruct",
        "messages": [
            {"role": "user", "content": "用三句话介绍量子计算"}
        ],
        "temperature": 0.8,
        "max_tokens": 200
    }
    
    response = client.post('/api/chat', json=payload)
    assert response.status_code == 200
    data = response.json
    
    assert 'id' in data
    assert 'choices' in data and len(data['choices']) > 0
    assert 'usage' in data
    assert data['choices'][0]['message']['role'] == 'assistant'

def test_missing_parameters(client):
    """测试缺少必要参数"""
    # 缺少model
    response1 = client.post('/api/chat', json={
        "messages": [{"role": "user", "content": "test"}]
    })
    assert response1.status_code == 400
    
    # 消息格式错误
    response2 = client.post('/api/chat', json={
        "model": "Qwen/Qwen2-7B-Instruct",
        "messages": [{"content": "没有role字段"}]
    })
    assert response2.status_code == 400

def test_parameter_validation(client):
    """测试参数边界值"""
    # temperature超过范围
    payload = {
        "model": "Qwen/Qwen2-7B-Instruct",
        "messages": [{"role": "user", "content": "test"}],
        "temperature": 2.5
    }
    response = client.post('/api/chat', json=payload)
    assert response.status_code == 200  # 服务端会自动钳制值
    
    # max_tokens过小
    payload["max_tokens"] = 0
    response = client.post('/api/chat', json=payload)
    assert response.status_code == 400, f"实际响应: {response.json}" 