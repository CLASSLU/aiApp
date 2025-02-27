# AI应用开发项目

## 项目概述

这是一个基于Docker的AI应用项目，包含前端和后端服务：
- **后端**：基于Flask的Python应用，提供AI聊天和图像生成API
- **前端**：基于HTML/JavaScript的用户界面

## 项目文档

### 文档结构

项目文档采用以下结构，便于不同角色快速查找所需信息：

1. **核心文档**（项目根目录）
   - **README.md** (当前文件) - 项目概述和快速入门
   - **[开发环境配置.md](./开发环境配置.md)** - 开发环境详细配置说明
   - **[部署指南.md](./部署指南.md)** - 生产环境部署详细流程

2. **技术文档**（docs目录）
   - **[需求文档.md](./docs/需求文档.md)** - 系统需求规格说明书
   - **[api.md](./docs/api.md)** - 后端API接口规范
   - **[PARAMETERS.md](./docs/PARAMETERS.md)** - API参数详细说明
   - **[frontend.md](./docs/frontend.md)** - 前端开发详细文档

> **注意**：为避免文档冗余和混乱，我们将逐步整合以下文档：
> - docs/部署指南.md → 合并到根目录的部署指南.md
> - docs/AIREADME.md → 合并到根目录的README.md
> - docs/开发测试须知.md → 合并到根目录的开发环境配置.md
> - docs/前端设计文档.md → 移至docs/frontend.md

## 环境要求

- Docker与Docker Compose
- Git

## 快速开始

### 开发环境

```bash
# 克隆仓库
git clone <仓库地址>
cd aiApp

# 给开发脚本添加执行权限
chmod +x dev.sh frontend/dev-helper.sh

# 构建开发环境
./dev.sh build

# 启动开发环境
./dev.sh start
```

访问应用：
- 前端： http://localhost:3000
- 后端API： http://localhost:5000

### 环境变量配置

在项目根目录创建`.env`文件：

```
SILICONFLOW_API_KEY=你的API密钥
```

## 项目结构

```
aiApp/
├── src/                  # 后端代码
│   ├── app.py            # 应用主入口
│   ├── api_client.py     # API客户端
│   ├── Dockerfile        # 生产环境Dockerfile
│   └── Dockerfile.dev    # 开发环境Dockerfile
├── frontend/             # 前端代码
│   ├── assets/           # 静态资源
│   ├── static/           # 静态文件
│   ├── *.html            # HTML页面
│   ├── *.js              # JavaScript文件
│   ├── Dockerfile        # 生产环境Dockerfile
│   └── Dockerfile.dev    # 开发环境Dockerfile
├── docker-compose.yml    # 生产环境配置
├── docker-compose.dev.yml # 开发环境配置
├── dev.sh                # 开发辅助脚本
├── requirements.txt      # Python依赖
├── .env                  # 环境变量（需自行创建）
├── README.md             # 项目文档
├── 开发环境配置.md        # 开发环境详细文档
└── 部署指南.md            # 部署详细文档
```

## 常用命令

```bash
# 开发环境
./dev.sh start             # 启动开发环境
./dev.sh logs [服务名]      # 查看日志
./dev.sh shell [服务名]     # 进入容器Shell

# 生产环境
docker compose build       # 构建生产镜像
docker compose up -d       # 启动生产环境
docker compose logs        # 查看生产环境日志
```

## 开发流程

1. 启动开发环境：`./dev.sh start`
2. 编辑代码（支持热重载）
3. 查看日志：`./dev.sh logs backend` 或 `./dev.sh logs frontend`
4. 停止环境：`./dev.sh stop`

详细的开发指南请参考 [开发环境配置.md](./开发环境配置.md)

## 部署流程

基本部署步骤：

```bash
# 服务器上
git clone <仓库地址>
cd aiApp
cp example.env .env  # 配置环境变量
docker compose build
docker compose up -d
```

详细的部署指南请参考 [部署指南.md](./部署指南.md)

## 故障排除

常见问题的快速解决方案：

1. **热重载不工作**
   - 检查日志：`./dev.sh logs backend`
   - 重启服务：`./dev.sh restart backend`

2. **API连接错误**
   - 检查`.env`文件和API密钥
   - 检查网络连接：`curl -v http://localhost:5000/api/models`

3. **容器无法启动**
   - 检查端口占用：`netstat -tuln`
   - 检查日志：`docker compose logs`

更多故障排除方法请参考专题文档。

## 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork仓库
2. 创建功能分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -am 'Add some feature'`
4. 推送分支：`git push origin feature/your-feature`
5. 提交Pull Request 