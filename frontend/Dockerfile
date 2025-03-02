FROM nginx:alpine

# 安装必要的工具
RUN apk add --no-cache bash curl

# 创建应用目录
WORKDIR /usr/share/nginx/html

# 复制前端文件
COPY . .

# 复制Nginx配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露80端口
EXPOSE 80

# 启动Nginx
CMD ["nginx", "-g", "daemon off;"]