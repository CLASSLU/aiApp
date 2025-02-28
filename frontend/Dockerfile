# 使用nginx作为前端服务器
FROM node

# 复制静态文件到nginx服务目录
COPY . /usr/share/nginx/html/

# 复制自定义nginx配置（如果需要）
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露80端口
EXPOSE 80

CMD ["http-server", "./", "-p", "80"] 