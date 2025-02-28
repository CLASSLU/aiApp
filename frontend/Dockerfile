# 使用nginx作为前端服务器
FROM node


WORKDIR /app
COPY package*.json ./
RUN npm install -g http-server

# 复制自定义nginx配置（如果需要）
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露80端口
EXPOSE 80

CMD ["http-server", "./", "-p", "80"] 