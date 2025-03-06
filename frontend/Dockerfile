# 构建阶段
FROM alpine:latest as builder

# 安装必要的工具
RUN apk add --no-cache wget bash

# 设置工作目录
WORKDIR /build

# 复制下载脚本和必要的文件
COPY download_deps.sh .
COPY . .

# 执行下载脚本
RUN chmod +x download_deps.sh && \
    ./download_deps.sh

# 最终阶段
FROM nginx:alpine

# 复制Nginx配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 从构建阶段复制文件
COPY --from=builder /build /usr/share/nginx/html

# 设置正确的权限
RUN chmod -R 755 /usr/share/nginx/html/assets/lib

# 暴露80端口
EXPOSE 80

# 启动Nginx
CMD ["nginx", "-g", "daemon off;"]