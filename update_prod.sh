#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查参数
if [ "$#" -lt 1 ]; then
    echo -e "${RED}错误: 请指定要更新的文件或目录${NC}"
    echo -e "用法: ./update_prod.sh <文件或目录路径>"
    echo -e "示例: ./update_prod.sh src/app.py"
    echo -e "      ./update_prod.sh src/api_client.py"
    echo -e "      ./update_prod.sh src/templates/"
    exit 1
fi

# 容器名称
CONTAINER_NAME="backend"

# 检查容器是否运行
if ! docker ps | grep -q $CONTAINER_NAME; then
    echo -e "${RED}错误: 容器 $CONTAINER_NAME 未运行${NC}"
    echo -e "请先启动容器: ./dev.sh prod start"
    exit 1
fi

# 更新文件
for path in "$@"; do
    # 检查文件是否存在
    if [ ! -e "$path" ]; then
        echo -e "${RED}错误: 文件或目录不存在: $path${NC}"
        continue
    fi
    
    # 获取目标路径
    if [[ $path == src/* ]]; then
        # 如果是 src 目录下的文件，直接复制到容器的 /app/src 目录
        target_path="/app/${path}"
    else
        # 其他文件复制到容器的根目录
        target_path="/app/${path}"
    fi
    
    echo -e "${YELLOW}正在更新: $path -> $target_path${NC}"
    
    # 确保目标目录存在
    target_dir=$(dirname "$target_path")
    docker exec $CONTAINER_NAME mkdir -p "$target_dir"
    
    # 复制文件到容器
    if [ -d "$path" ]; then
        # 如果是目录，使用 -r 参数
        docker cp -a "$path/." "$CONTAINER_NAME:$target_path"
    else
        # 如果是文件
        docker cp "$path" "$CONTAINER_NAME:$target_path"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}更新成功: $path${NC}"
    else
        echo -e "${RED}更新失败: $path${NC}"
        exit 1
    fi
done

echo -e "${BLUE}文件已更新，热重载将自动检测变化并重启应用${NC}"
echo -e "${YELLOW}如果应用没有自动重启，可以手动触发: docker exec $CONTAINER_NAME touch /app/src/app.py${NC}" 