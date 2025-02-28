# 使用完整标签的Python镜像
FROM python:3.10-slim

# 设置工作目录和环境变量
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=src.app
ENV FLASK_ENV=production

# 复制依赖文件
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY ./src .
COPY ./.env .

# 暴露应用端口
EXPOSE 5000

# 启动应用
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "--timeout", "300", "src.app:app"] 