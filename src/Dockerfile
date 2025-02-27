# 使用完整标签的Python镜像
FROM python:3.10 as builder

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# 复制并安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# 确保安装gunicorn
RUN pip install gunicorn

# 多阶段构建 - 运行阶段
FROM python:3.10

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# 设置Python路径，使其能找到模块
ENV PYTHONPATH=/app

# 从构建阶段复制安装好的包
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
# 复制gunicorn可执行文件
COPY --from=builder /usr/local/bin/gunicorn /usr/local/bin/

# 创建一个空的.env文件
RUN touch /app/.env

# 复制应用代码
# 将src目录内容复制到app目录，保持包结构
COPY ./src /app/src
# 创建空的__init__.py文件确保src被视为包
RUN touch /app/src/__init__.py

# 暴露应用端口
EXPOSE 5000

# 启动应用，使用正确的模块路径
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "src.app:app"] 