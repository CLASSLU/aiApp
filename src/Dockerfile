# 使用完整标签的Python镜像
FROM python:3.10-slim

# 设置工作目录和环境变量
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=src.app
ENV FLASK_ENV=production

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    procps \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 安装热重载工具
RUN pip install --no-cache-dir watchdog[watchmedo] gunicorn

# 复制应用代码
COPY ./src .
COPY ./.env .

# 复制热重载脚本
COPY ./hot_reload.sh /app/hot_reload.sh
RUN chmod +x /app/hot_reload.sh

# 暴露应用端口
EXPOSE 5000

# 使用热重载脚本启动应用
CMD ["/app/hot_reload.sh"] 