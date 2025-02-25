# AI 多媒体生成平台

基于 SiliconFlow 接口开发的多模态内容生成 Web 应用

## 项目背景

本项目是一个使用AI辅助基于siliconFlow接口开发的ai web应用，前端使用基本的html+js+样式库组成，为了保证稳定与简洁暂时不引入其他框架。后端使用的是flash框架，源码都放在src中，其中api_client.py是请求硅基流动接口的代码，app.py是本地接口代码。tests中是测试代码。本项目将来会实现：

1. 有记忆ai文本聊天功能
2. 根据ai生成的提示词生成图片功能
3. 根据大语言模型文本生成语言
4. 根据语言图片文本生成视频功能
5. 终极：根据人工输入直接产出高质量视频

其他细节功能待细化。本项目代码力求规范整洁，对于技术栈的引入务必谨慎，开发需遵循项目结构。项目有重大变更需及时自动维护本文档。

### 技术架构

**前端架构**  
- 核心：原生 HTML5 + ES6 + CSS3  
- 样式库：Bootstrap 5.3 + Font Awesome 6  
- 交互：jQuery 3.7 + Bootstrap 工具提示  
- 特点：无构建工具/无打包的轻量级架构  

**后端架构**  
- 框架：Python Flask  
- 核心模块：  
  - `api_client.py`: SiliconFlow 接口封装  
  - `app.py`: RESTful API 服务  
- 测试：`tests/` 单元测试套件  

## 项目结构

├── frontend/ # 前端资源
│ ├── assets/ # 静态资源
│ │ └── style.css # 核心样式
│ ├── app.js # 前端逻辑
│ └── index.html # 主入口
├── src/ # 后端源码
│ ├── api_client.py # 硅基流动接口客户端
│ └── app.py # Flask 应用
├── tests/ # 测试套件
│ ├── local/ # 本地接口测试
│ │ ├── test_local_api.py # 本地API测试
│ │ └── test_validation.py # 参数验证测试
│ └── remote/ # 远程接口测试
│   └── test_siliconflow_api.py # 硅基流动API测试
├── docker-compose.yml # 容器编排
├── .gitignore
└── AIREADME.md # AI迅速了解背景须知

.
