## 支持的模型列表

- `FLUX.1-schnell` (生产版)
- `stable-diffusion-v2.1` (基础版) 

## 请求参数
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|-----|
| model  | string | 是 | 支持的模型: `FLUX.1-schnell` |
| negative_prompt | string | 否 | 负面提示词，默认值: "low quality" |

## 限流策略
- 免费用户：5次/分钟
- 付费用户：根据套餐等级提升 