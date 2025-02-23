# AI图像生成平台

## 技术栈
- 后端：Python Flask + SiliconFlow API
- 前端：Vue3 + Element Plus
- 部署：Docker + Nginx

## 环境变量配置
```bash
# .env
SILICONFLOW_API_KEY=your_api_key_here
LOG_LEVEL=DEBUG  # 可选 INFO/WARNING/ERROR
```

## API接口规范

### 生成接口 `/api/generate`
**请求参数：**
```json
{
  "prompt": "描述文字",
  "model": "black-forest-labs/FLUX.1-schnell",
  "width": 1024,
  "height": 1024,
  "num_images": 1,
  "guidance_scale": 3.0,
  "steps": 50,
  "negative_prompt": "低质量",
  "seed": 123456
}
```

**成功响应：**
```json
{
  "images": [{
    "url": "https://image-url.png",
    "seed": 123456
  }],
  "usage": {
    "duration": 4.2,
    "credits_used": 0.2
  }
}
```

### 图片生成API
`POST /api/generate`

**请求示例：**
```json
{
  "prompt": "赛博朋克风格的城市夜景",
  "width": 1024,
  "height": 1024,
  "num_images": 2,
  "guidance_scale": 4.0
}
```

**参数说明：**
| 参数名       | 类型   | 必填 | 说明                     |
|--------------|--------|------|-------------------------|
| prompt       | string | 是   | 图片描述文本             |
| width        | int    | 是   | 图片宽度(512/768/1024)  |
| height       | int    | 是   | 图片高度(需与宽度相同)    |
| num_images   | int    | 是   | 生成数量(1-4)           |
| guidance_scale | float | 否   | 提示词相关性(3.8-4.2)   |

### 对话API（新增）
`POST /api/chat`

**请求示例：**
```json
{
  "model": "Qwen/Qwen2-7B-Instruct",
  "messages": [
    {"role": "user", "content": "如何学习人工智能？"}
  ],
  "temperature": 0.7,
  "max_tokens": 500
}
```

**参数说明：**
| 参数名       | 类型   | 必填 | 说明                     |
|--------------|--------|------|-------------------------|
| model        | string | 是   | 模型标识符               |
| messages     | array  | 是   | 消息历史数组             |
| temperature  | float  | 否   | 生成随机性(0-2,默认0.7) |
| max_tokens   | int    | 否   | 最大生成token数(默认1024)|

**消息格式要求：**
```json
{
  "role": "user|assistant|system",
  "content": "消息内容"
}
```

### 通用响应格式
```json
{
  "id": "请求ID",
  "data": [],      // 图片/对话结果
  "usage": {       // 资源消耗
    "duration": 2.5,
    "credits_used": 0.8
  },
  "error": null    // 错误信息
}
```

## 本地开发
```bash
# 后端
flask run --port=5000 --debug

# 前端
cd frontend && npm run dev

# 运行测试
python -m tests.local_test
python -m tests.api_test
```

## 部署指南
```bash
docker-compose up -d --build
```

## 常见问题
Q: 出现400错误怎么办？
A: 检查以下参数：
1. 模型名称是否包含命名空间
2. 分辨率是否在允许范围内
3. 种子值是否≥0

Q: 如何获取API密钥？
A: 访问 [硅流控制台](https://cloud.siliconflow.cn) → 账号设置 → API密钥

## 项目结构
```tree
frontend/
├─ src/
│  ├─ components/    # 全局组件
│  │  ├─ BasicLayout.vue
│  │  └─ NavMenu.vue
│  │  └─ ChatInterface.vue
│  │  └─ MessageBubble.vue
│  │  └─ TypingIndicator.vue
│  │  └─ HomeView.vue
│  │  └─ GenerateView.vue
│  │  └─ ChatView.vue
│  ├─ views/         # 页面视图
│  │  ├─ HomeView.vue
│  │  └─ GenerateView.vue
│  │  └─ ChatView.vue
│  ├─ router/        # 路由配置
│  │  └─ index.ts
│  │  └─ ChatInterface.vue
│  │  └─ ChatView.vue
│  ├─ App.vue        # 根组件
│  └─ main.ts        # 入口文件
```

## 开发指南
```bash
# 安装依赖
npm install

# 启动开发服务器
npm run dev

# 生产构建
npm run build
```

## 样式规范
- 主色：#409EFF
- 辅助色：#79bbff
- 文字色：#303133
- 成功色：#67C23A
- 警告色：#E6A23C
- 错误色：#F56C6C

## 本地运行
1. 使用VSCode Live Server扩展
2. 或通过Python快速启动：
   ```bash
   cd frontend
   python3 -m http.server 3000
   ```
3. 访问 http://localhost:3000

## 功能规划
- [x] 基础页面布局
- [ ] 图像生成接口对接
- [ ] 历史记录管理
- [ ] 用户认证系统

## 项目背景
基于SiliconFlow API构建的AI图像生成平台，目标是为设计师提供快速原型创作工具。当前阶段重点验证核心生成流程。

## 对AI的要求
1. **准确性**: 所有代码修改必须基于项目实际信息
2. **可追溯性**: 每次修改需明确记录变更文件
3. **简洁性**: 仅保留必要技术细节
4. **安全性**: 代码中禁止暴露敏感信息

## 核心需求
### 当前迭代目标
```diff
! 优先级排序（2024-03-29）
1. 实现稳定的图像生成流程
2. 完善参数配置界面交互
3. 优化生成历史加载性能
```

### 功能清单
```markdown
- [x] API基础调用验证（3/25）
- [x] 前端参数配置面板（3/27）
- [ ] 生成结果预览优化（进行中）
```

## 当前问题
```diff
! 2024-03-29 更新
- [高] 生成历史图片加载失败
- [中] 移动端布局适配问题
- [低] 状态管理冗余代码
```

## 问题跟踪
| 问题描述 | 优先级 | 状态 |
|---------|--------|------|
| Vite命令缺失 | 紧急 | 已解决 |
| 生成历史加载失败 | 高 | 待修复 |
| 移动端布局错位 | 中 | 进行中 |
| 状态管理冗余 | 低 | 待优化 |

## 开发说明
### 环境
```bash
# 初始化
python -m venv .venv && .\.venv\Scripts\Activate
pip install -r requirements.txt
cd frontend && npm install

# Windows清理命令
Remove-Item -Recurse -Force node_modules
```

### 启停命令
```bash
# 启动后端
$env:SILICONFLOW_API_KEY="your_key"; flask run

# 启动前端
cd frontend && npm run dev

# 使用国内镜像源
npm install --registry=https://registry.npmmirror.com

# 常见问题处理
## Vite命令未找到
1. 确保已安装依赖：npm install
2. 检查package.json中vite版本是否有效
3. 清理node_modules后重新安装
```

## 开发进展
**2024-03-29**
1. 文档优化
   - 明确对AI的开发要求
   - 移除冗余接口文档
   - 简化技术栈说明
2. 问题跟踪
   - 新增3个优先级问题

## 技术栈
| 模块         | 技术方案               | 版本   |
|--------------|-----------------------|-------|
| 后端框架     | Python Flask         | 3.0.0 |
| API客户端    | requests + 自定义封装| 2.31.0| 
| 容器化       | Docker + Docker Compose| 24.0 |
| 测试框架     | pytest + requests    | 8.0.2 |
| 前端框架     | React 18 + TypeScript  | 18.2  |
| 状态管理     | Redux Toolkit         | 1.9.5 |
| UI组件库     | Ant Design Pro       | 2.8.6 |
| 可视化       | ECharts + react-for-echarts | 5.4.3+3.0.2 |
| 路由管理     | React Router 6        | 6.23.1|
| 构建工具     | Vite                 | 5.2.0 |

## 生产环境要求
- 服务器配置：4核CPU / 8GB内存+
- 网络要求：10Mbps+带宽
- 依赖服务：SiliconFlow API访问权限

## 当前阶段
**聚焦任务**: API基础调用验证

## 已完成
1. 本地开发环境搭建（Python 3.10 + 虚拟环境）
2. 基础服务框架（Flask 5000端口）
3. API客户端原型（requests实现）
4. 集成测试套件

## 最新测试结果
**2024-03-25 21:30**
- API密钥已成功加载
- 服务端收到请求并调用API
- 修正API端点路径和请求参数
- 修正模型参数为stable-diffusion-v2.1

## 待解决问题
1. [紧急] API密钥无效或权限不足（401错误）
2. [高] 依赖安装不完整（pip版本过旧）
3. [中] 需要API响应样例数据

## 下一步行动
1. 升级pip并安装依赖
2. 验证API密钥有效性
3. 获取首个测试图片生成结果

## 核心需求
**项目目标**: 构建基于SiliconFlow API的AI图像生成Web应用

**关键功能**：
- [ ] 基础图片生成（输入文本/参数 → 调用API → 展示结果）
- [ ] 生成参数配置界面（尺寸/风格/质量等）
- [ ] 生成历史记录浏览
- [ ] 用户认证系统（第三方登录+邮箱注册）

## 当前问题
1. 需要建立稳定的API调用机制
- API基础通信已建立，需完善错误处理
2. 图片生成结果需要优化展示效果
3. 用户生成历史存储方案待确定

## 开发进展
**2024-03-25** 
- 需求文档初版建立
- 本地虚拟环境配置完成
- 基础服务验证通过
- 技术栈确认：
  • 前端：React + Ant Design
  • 后端：Python Flask + Gunicorn
  • 存储：MongoDB（历史记录）+ 本地缓存（临时图片）

## 快速开始

### 环境准备
1. Python 3.10+
2. 有效SiliconFlow API密钥
3. Docker 20.10+（可选）

### 本地开发
```powershell
# 创建并激活虚拟环境
python -m venv .venv
.\venv\Scripts\Activate

# 升级pip并设置默认编码
python -m pip install --upgrade pip
$env:PYTHONUTF8="1"

# 安装依赖
pip install -r requirements.txt

# 启动开发服务器（热重载）
$env:SILICONFLOW_API_KEY="your_key_here"
$env:FLASK_APP="src/app.py"
flask run --port=5000 --debug

# 新终端运行测试（保持服务运行）
$env:SILICONFLOW_API_KEY="your_key_here"
pytest tests/ -v

# 或直接运行测试脚本
python -m tests.local_test
```

### 前端开发
```bash
# 前端开发
cd frontend
npm install
npm run dev
```

## 项目结构
```
myapp/
├── .venv/           # Python虚拟环境（建议.gitignore）
├── frontend/        # 前端源码
│   ├── src/
│   │   ├── components/  # 公共组件
│   │   ├── pages/       # 页面组件
│   │   ├── store/       # 状态管理
├── src/              # 后端源码
│   ├── app.py        # Flask服务入口
└── tests/            # 测试套件
```

## 使用模型
**FLUX.1 Schnell** 技术参数：
- 分辨率: 1024×1024
- 推荐步数: 30-50 steps
- 推荐CFG: 2.0-4.0
- 支持格式: PNG/JPEG
- 生成耗时: ≈8秒/张

## 前置条件
1. 在SiliconFlow控制台开通「FLUX.1 Schnell」模型服务
2. 完成实名认证
3. 确保账户有足够额度 

## 注意事项
1. API密钥需通过环境变量注入
2. 生成默认尺寸1024x1024（支持调整）
3. 开发环境使用临时测试密钥（生产环境需更换） 

## 编码问题解决方案
```powershell
# 临时设置UTF-8编码
$env:PYTHONUTF8="1"

# 或永久设置（需要管理员权限）
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name ACP -Value 65001
``` 

## 当前迭代
```diff
! 优先级（2024-03-29）
1. 修复生成历史加载问题
2. 移动端布局适配
3. 优化Redux状态管理
```

## 问题跟踪
| 问题描述 | 优先级 | 状态 |
|---------|--------|------|
| Vite命令缺失 | 紧急 | 已解决 |
| 生成历史加载失败 | 高 | 待修复 |
| 移动端布局错位 | 中 | 进行中 |
| 状态管理冗余 | 低 | 待优化 |
| ProLayout配置缺失 | 高 | 已修复 |
| Ant Design样式未加载 | 中 | 处理中 | 
```

## 使用限制
- 分辨率限制：512x512 / 768x768 / 1024x1024
- 单次最多生成4张图片

## 前端功能说明

### 新增功能模块
- **智能对话界面**
  - 支持多轮对话上下文
  - 实时响应流式输出
  - 消息历史持久化存储
  - 支持Markdown格式渲染

### 组件说明
| 组件 | 功能 |
|------|------|
| `ChatInterface` | 核心对话界面，包含消息列表和输入框 |
| `MessageBubble` | 消息气泡组件，支持不同角色样式 |
| `TypingIndicator` | 加载状态指示器 |

### 运行前端
```bash
cd frontend
npm install
npm run dev

# 生产构建
npm run build
```

### 环境变量配置
```env
VITE_API_BASE=http://localhost:5000
VITE_DEFAULT_MODEL=Qwen/Qwen2-7B-Instruct
```

### 关键依赖版本
- Node.js: v18.16.0
- Vue: 3.4.27
- Pinia: 2.1.7
- Element Plus: 2.6.3
- Vite: 5.2.0
```

## 已知问题

### 路由异常
- **现象**：点击导航菜单报`parentNode`错误
- **相关文件**：
  - `src/router/index.js`
  - `src/components/NavMenu.vue`
- **尝试方案**：
  - 路由懒加载
  - 添加导航守卫
  - 更新Element Plus到2.6.3

### Pinia初始化警告
- **日志**：`getActivePinia() was called but no active Pinia`
- **影响文件**：
  - `src/stores/chat.js`
  - `src/components/ChatInterface.vue`

## 明日计划
```

## 稳定性保障措施
1. 依赖版本锁定：所有前端依赖均使用精确版本号
2. 类型安全：启用严格模式并配置完整类型声明
3. 推荐使用pnpm：`npm install -g pnpm && pnpm install`

## AI图片生成器技术文档

### 前端依赖
| 依赖项                | 版本     | 作用                  | CDN链接                                                                 |
|----------------------|---------|----------------------|-------------------------------------------------------------------------|
| Bootstrap           | 5.3.0   | UI框架               | `https://cdn.bootcdn.net/ajax/libs/bootstrap/5.3.0/css/bootstrap.min.css` |
| Bootstrap Icons     | 1.11.3  | 图标库                | `https://cdn.bootcdn.net/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css` |
| Popper.js           | 2.11.8  | 定位计算              | `https://cdn.bootcdn.net/ajax/libs/popper.js/2.11.8/umd/popper.min.js`    |
| jQuery              | 3.7.1   | DOM操作              | `https://cdn.bootcdn.net/ajax/libs/jquery/3.7.1/jquery.min.js`            |

### 关键配置
```javascript
// 工具提示初始化配置
new bootstrap.Tooltip(element, {
  placement: 'right',    // 提示位置
  trigger: 'hover',      // 触发方式
  html: true,            // 支持HTML内容
  container: 'body',     // 挂载容器
  delay: { show: 500 }   // 显示延迟
});
```

### 编码规范
1. **文件编码**  
   所有文本文件必须使用`UTF-8`编码
   ```html
   <!-- 在HTML头部声明 -->
   <meta charset="UTF-8">
   ```

2. **浏览器兼容性**  
   | 浏览器       | 最低支持版本 | 注意事项              |
   |-------------|------------|----------------------|
   | Chrome      | 90+        | 推荐使用最新版         |
   | Firefox     | 88+        | 需启用ES6支持         |
   | Edge        | 91+        | Chromium内核版本      |
   | Safari      | 14.1+      | 需启用JavaScript     |

### 维护建议
1. **依赖更新**  
   每月检查一次CDN资源版本：
   ```bash
   # 检查Bootstrap版本
   curl -I https://cdn.bootcdn.net/ajax/libs/bootstrap/5.3.0/css/bootstrap.min.css | grep -i "content-encoding"
   ```

2. **版本锁定**  
   在URL中添加版本参数避免缓存问题：
   ```html
   <link rel="stylesheet" 
         href="https://cdn.bootcdn.net/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css?v=1.11.3">
   ```

3. **调试提示**  
   遇到工具提示不显示时：
   ```javascript
   // 在控制台执行诊断命令
   console.log('Bootstrap状态:', {
     tooltip: typeof bootstrap?.Tooltip !== 'undefined',
     icons: document.querySelector('.bi') !== null,
     popper: typeof Popper !== 'undefined'
   });
   ```

### 常见问题解决方案
| 问题现象         | 解决方案                         | 相关文件              |
|------------------|--------------------------------|----------------------|
| 工具提示不显示    | 1. 检查Bootstrap Icons是否加载  | index.html, app.js   |
| 提示内容乱码      | 确保文件编码为UTF-8             | 所有文本文件           |
| 移动端无反应      | 添加`touch: true`配置           | app.js               |
| 提示位置偏移      | 检查父元素overflow设置          | style.css            |