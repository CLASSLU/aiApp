## 本文档为后端接口文档

# API 接口规范

## 图像生成接口 `POST /api/generate`

### 请求示例
```json
{
  "prompt": "赛博朋克风格的城市夜景",
  "model": "black-forest-labs/FLUX.1-schnell",
  "width": 1024,
  "height": 1024,
  "batch_size": 1,
  "guidance_scale": 4.0
}
```

### 响应格式
```json
{
  "images": [{"url": "图片URL地址"}],
  "credits_used": 1
}
```

### 支持的模型
- `black-forest-labs/FLUX.1-schnell` - 默认模型（免费）
- `black-forest-labs/FLUX.1-dev` - 高质量模型（收费）
- `stabilityai/stable-diffusion-3-5-large` - SD 3.5 大模型  
- `stabilityai/stable-diffusion-3-5-large-turbo` - SD 3.5 快速版（收费）
- `deepseek-ai/Janus-Pro-7B` - 理解与生成

### 参数验证规则
```python
# 支持的分辨率
width, height: [512, 768, 1024]
# 支持的批量生成数量
batch_size: 1-4 (受账户等级限制)
# 生成质量指导比例
guidance_scale: 推荐 3.8-4.2
```

## AI聊天接口 `POST /api/chat`

### 请求示例
```json
{
  "model": "模型ID",
  "messages": [
    {"role": "user", "content": "你好，请介绍一下自己"}
  ],
  "temperature": 0.7,
  "max_tokens": 1024
}
```

### 响应格式
流式响应，每个数据块格式如下：
```
data: {"content": "响应的部分内容", "done": false}
```

最后一个数据块：
```
data: {"content": "", "done": true}
```

## 模型列表接口 `GET /api/models`

### 响应示例
```json
{
  "models": [
    {
      "id": "模型ID",
      "name": "模型名称",
      "description": "模型描述"
    }
  ]
}
```

## 错误代码
| 状态码 | 说明           |
|--------|----------------|
| 400    | 参数验证失败    |
| 429    | 请求频率过高    |
| 500    | 服务器内部错误  |
