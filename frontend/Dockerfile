# 使用nginx作为前端服务器
FROM node:20-alpine  

WORKDIR /app
COPY package*.json ./
RUN npm install && npm run build  # 增加构建步骤
RUN npm install -g http-server


# 暴露80端口
EXPOSE 80

CMD ["http-server", "dist", "-p", "3000"]  # 正确调用全局命令