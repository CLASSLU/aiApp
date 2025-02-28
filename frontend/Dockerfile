FROM node:18-alpine

# 安装http-server
RUN npm install -g http-server

WORKDIR /app

# 复制前端文件
COPY . .

# 暴露80端口
EXPOSE 80

# 启动http-server，添加CORS支持
CMD ["http-server", ".", "-p", "80", "--cors"]