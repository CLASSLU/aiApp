#!/bin/bash

# 热重载脚本 - 监控文件变化并重启 Gunicorn
# 增强版：修复监控和重启逻辑

# 设置变量
APP_MODULE="src.app:app"
GUNICORN_WORKERS=4
GUNICORN_BIND="0.0.0.0:5000"
GUNICORN_TIMEOUT=300
WATCH_DIR="/app/src"
PID_FILE="/tmp/gunicorn.pid"
LOG_DIR="/app/logs"
GUNICORN_LOG_FILE="$LOG_DIR/gunicorn.log"
HOT_RELOAD_LOG="$LOG_DIR/hot_reload.log"

# 创建日志目录
mkdir -p $LOG_DIR
chmod 777 $LOG_DIR

echo "$(date) - 热部署脚本启动" > $HOT_RELOAD_LOG

# 确保watchdog已安装（抑制pip输出消息）
if ! pip list | grep -q "watchdog"; then
    echo "安装watchdog..." >> $HOT_RELOAD_LOG
    pip install watchdog -q
fi

# 启动 Gunicorn
start_gunicorn() {
    echo "$(date) - 启动 Gunicorn 服务器..." >> $HOT_RELOAD_LOG
    
    # 杀掉可能已存在的Gunicorn进程
    pkill -f "gunicorn" 2>/dev/null
    rm -f $PID_FILE
    
    # 使用更可靠的方式启动Gunicorn并写入PID文件
    gunicorn -w $GUNICORN_WORKERS -b $GUNICORN_BIND --timeout $GUNICORN_TIMEOUT \
        --pid=$PID_FILE --log-level=info \
        --access-logfile=$LOG_DIR/gunicorn_access.log \
        --error-logfile=$LOG_DIR/gunicorn_error.log \
        --log-file=$GUNICORN_LOG_FILE \
        --reload \
        --reload-engine=auto \
        --reload-extra-file=/app/src/app.py \
        --capture-output \
        $APP_MODULE >> $HOT_RELOAD_LOG 2>&1 &
    
    # 等待PID文件生成
    sleep 3
    if [ -f "$PID_FILE" ]; then
        GUNICORN_PID=$(cat $PID_FILE)
        echo "$(date) - Gunicorn 已启动，PID: $GUNICORN_PID" >> $HOT_RELOAD_LOG
    else
        echo "$(date) - 警告：无法获取Gunicorn PID" >> $HOT_RELOAD_LOG
    fi
}

# 停止 Gunicorn
stop_gunicorn() {
    if [ -f "$PID_FILE" ]; then
        GUNICORN_PID=$(cat $PID_FILE)
        echo "$(date) - 停止 Gunicorn (PID: $GUNICORN_PID)..." >> $HOT_RELOAD_LOG
        kill -TERM $GUNICORN_PID 2>/dev/null
        sleep 3
        
        # 确保已停止
        if kill -0 $GUNICORN_PID 2>/dev/null; then
            echo "$(date) - 强制终止 Gunicorn..." >> $HOT_RELOAD_LOG
            kill -9 $GUNICORN_PID 2>/dev/null
        fi
        
        rm -f $PID_FILE
        echo "$(date) - Gunicorn 已停止" >> $HOT_RELOAD_LOG
    else
        echo "$(date) - 未找到PID文件，尝试通过进程查找" >> $HOT_RELOAD_LOG
        pkill -f "$APP_MODULE" 2>/dev/null
    fi
}

# 重启 Gunicorn
restart_gunicorn() {
    echo "$(date) - 检测到文件变化，重启 Gunicorn..." >> $HOT_RELOAD_LOG
    
    # 不重新启动整个进程，只发送HUP信号触发重载
    if [ -f "$PID_FILE" ]; then
        GUNICORN_PID=$(cat $PID_FILE)
        echo "$(date) - 发送HUP信号触发热重载 (PID: $GUNICORN_PID)..." >> $HOT_RELOAD_LOG
        kill -HUP $GUNICORN_PID 2>/dev/null
        echo "$(date) - 已触发热重载" >> $HOT_RELOAD_LOG
    else
        echo "$(date) - 未找到PID文件，重新启动Gunicorn..." >> $HOT_RELOAD_LOG
        stop_gunicorn
        sleep 2
        start_gunicorn
    fi
}

# 定义restart_cmd函数（用于watchmedo命令调用）
restart_cmd() {
    restart_gunicorn
}
export -f restart_cmd

# 文件变更处理函数
on_file_change() {
    local file=$1
    echo "$(date) - 检测到文件变更: $file" >> $HOT_RELOAD_LOG
    restart_gunicorn
}

# 清理函数
cleanup() {
    echo "$(date) - 接收到终止信号，正在清理..." >> $HOT_RELOAD_LOG
    stop_gunicorn
    exit 0
}

# 注册信号处理
trap cleanup SIGTERM SIGINT

# 处理命令行参数
if [ "$1" = "start" ]; then
    start_gunicorn
    echo "$(date) - 启动监控循环..." >> $HOT_RELOAD_LOG
elif [ "$1" = "stop" ]; then
    stop_gunicorn
    exit 0
elif [ "$1" = "restart" ]; then
    restart_gunicorn
    exit 0
elif [ "$1" = "restart_cmd" ]; then
    restart_gunicorn
    exit 0
fi

# 启动Gunicorn
start_gunicorn

# 简化监控机制，依赖Gunicorn自身的reload功能
echo "$(date) - 使用Gunicorn内置的热重载功能" >> $HOT_RELOAD_LOG

# 保持脚本运行，同时监控Gunicorn进程状态
while true; do
    sleep 10
    
    # 检查Gunicorn是否在运行
    if [ -f "$PID_FILE" ]; then
        GUNICORN_PID=$(cat $PID_FILE)
        if ! kill -0 $GUNICORN_PID 2>/dev/null; then
            echo "$(date) - Gunicorn已停止运行，重新启动..." >> $HOT_RELOAD_LOG
            start_gunicorn
        fi
    else
        echo "$(date) - PID文件不存在，重新启动Gunicorn..." >> $HOT_RELOAD_LOG
        start_gunicorn
    fi
done 