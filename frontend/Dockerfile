# 构建阶段
FROM alpine:latest as builder

# 安装必要的工具
RUN apk add --no-cache wget bash ca-certificates

# 设置工作目录
WORKDIR /build

# 设置DNS和超时
ENV WGET_OPTS="--timeout=30 --tries=3 --retry-connrefused --retry-on-host-error --retry-on-http-error=429,500-599"

# 复制下载脚本和必要的文件
COPY download_deps.sh .
COPY . .

# 执行下载脚本（添加重试机制）
RUN chmod +x download_deps.sh && \
    for i in $(seq 1 3); do \
        echo "尝试下载依赖 (attempt $i/3)..." && \
        ./download_deps.sh && break || \
        if [ $i -eq 3 ]; then exit 1; fi && \
        echo "下载失败，等待10秒后重试..." && \
        sleep 10; \
    done

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