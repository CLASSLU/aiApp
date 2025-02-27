# 使用nginx作为前端服务器
FROM nginx:1.24

# 复制静态文件到nginx服务目录
COPY . /usr/share/nginx/html/

# 复制自定义nginx配置（如果需要）
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露80端口
EXPOSE 80

# nginx默认会自动启动，无需额外命令 