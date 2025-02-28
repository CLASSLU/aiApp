#!/bin/bash

# 热重载脚本 - 监控文件变化并重启 Gunicorn

# 设置变量
APP_MODULE="src.app:app"
GUNICORN_WORKERS=4
GUNICORN_BIND="0.0.0.0:5000"
GUNICORN_TIMEOUT=300
WATCH_DIR="/app/src"

# 启动 Gunicorn
start_gunicorn() {
    echo "启动 Gunicorn 服务器..."
    gunicorn -w $GUNICORN_WORKERS -b $GUNICORN_BIND --timeout $GUNICORN_TIMEOUT $APP_MODULE &
    GUNICORN_PID=$!
    echo "Gunicorn 已启动，PID: $GUNICORN_PID"
}

# 停止 Gunicorn
stop_gunicorn() {
    if [ ! -z "$GUNICORN_PID" ]; then
        echo "停止 Gunicorn (PID: $GUNICORN_PID)..."
        kill -TERM $GUNICORN_PID
        wait $GUNICORN_PID 2>/dev/null
        echo "Gunicorn 已停止"
    fi
}

# 重启 Gunicorn
restart_gunicorn() {
    echo "检测到文件变化，重启 Gunicorn..."
    stop_gunicorn
    start_gunicorn
}

# 清理函数
cleanup() {
    echo "接收到终止信号，正在清理..."
    stop_gunicorn
    exit 0
}

# 注册信号处理
trap cleanup SIGTERM SIGINT

# 首次启动 Gunicorn
start_gunicorn

# 使用 watchmedo 监控文件变化
echo "开始监控 $WATCH_DIR 目录的文件变化..."
watchmedo auto-restart --directory=$WATCH_DIR --pattern="*.py" --recursive -- bash -c "kill -HUP $GUNICORN_PID"

# 保持脚本运行
wait $GUNICORN_PID 