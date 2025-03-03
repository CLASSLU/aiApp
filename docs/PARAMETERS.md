## 参数说明手册

### 核心参数
| 参数名       | 类型   | 必填 | 说明                                                                 |
|--------------|--------|------|--------------------------------------------------------------------|
| prompt       | string | 是   | 描述生成图片内容的文本，支持中文和英文                              |
| model        | string | 是   | 使用的模型版本，具体见下方支持模型列表                             |
| width        | int    | 是   | 图片宽度，支持512/768/1024三种尺寸                                  |
| height       | int    | 是   | 图片高度，需与宽度相同                                             |
| batch_size   | int    | 是   | 生成数量(1-4)，实际数量受账户等级限制                              |

### 高级参数
| 参数名            | 类型   | 默认值 | 有效范围      | 说明                                                                 |
|-------------------|--------|--------|-------------|--------------------------------------------------------------------|
| guidance_scale    | float  | 4.0    | 3.8-4.2     | 控制生成与提示词的相关性，值越大越严格                                |
| steps             | int    | 4      | 固定4       | FLUX模型专用参数，控制生成迭代次数                                   |
| variation_seed    | int    | 随机   | 0-999999999 | 生成变体的基础种子，批量生成时自动生成序列种子                         |
| variation_strength| float  | 0.7    | 0.5-0.9     | 控制批量生成图片的差异性，值越大差异越明显                            |

## 支持的模型列表

### 图像生成模型

| 模型ID                                   | 类型       | 收费  | 特点                       |
|------------------------------------------|------------|-------|----------------------------|
| black-forest-labs/FLUX.1-schnell         | FLUX       | 免费  | 基础模型，速度较快         |
| black-forest-labs/FLUX.1-dev             | FLUX       | 收费  | 高质量，细节更丰富         |
| stabilityai/stable-diffusion-3-5-large   | SD 3.5     | 收费  | 高质量大模型               |
| stabilityai/stable-diffusion-3-5-large-turbo | SD 3.5  | 收费  | 高质量快速版              |
| deepseek-ai/Janus-Pro-7B                 | 多模态     | 收费  | 具备理解与生成能力         |

### 聊天模型

| 模型ID                      | 类型      | 特点                             |
|-----------------------------|-----------|----------------------------------|
| GLM-4                       | 中文模型  | 适合中文对话，支持复杂指令       |
| deepseek-llm               | 基础模型  | 擅长代码和逻辑推理               |
| llama-3                     | 开源模型  | 通用对话能力，开源可商用         |

## 模型专用参数说明 (FLUX.1-schnell)

| 参数               | 类型   | 必填 | 约束条件                         | 计费影响                 |
|--------------------|--------|------|--------------------------------|-------------------------|
| num_inference_steps| int    | 是   | 固定值4 (不可调整)               | 按张计费，与步数无关       |
| guidance_scale     | float  | 是   | 3.8-4.2 (推荐4.0)              | 影响生成质量，不计费差异   |
| variation_strength| float  | 否   | 0.5-0.9 (默认0.7)              | 影响变体差异度，不计费差异 |
| batch_size         | int    | 是   | 1-4 (需L1+账户)                | 每张独立计费              |

**账户级别要求：**
- L0 (免费)：仅支持单张生成
- L1 (¥50+/月)：支持最多4张/次
- 查看[账户级别](https://cloud.siliconflow.cn/package) 