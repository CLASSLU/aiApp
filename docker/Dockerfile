# 基础构建阶段
FROM python:3.10-slim as builder

WORKDIR /app
ENV VIRTUAL_ENV=/app/venv
RUN python -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 最终运行阶段
FROM python:3.10-slim

WORKDIR /app
COPY --from=builder /app/venv ./venv
ENV PATH="/app/venv/bin:$PATH"

COPY . .

RUN pip install -r requirements.txt

EXPOSE 5000
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "src.app:app"] 