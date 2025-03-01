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
    echo -e "      ./update_prod.sh all        # 更新所有后端文件"
    exit 1
fi

# 容器名称
CONTAINER_NAME="backend"

# 检查容器是否运行
if ! docker ps | grep -q $CONTAINER_NAME; then
    echo -e "${RED}错误: 容器 $CONTAINER_NAME 未运行${NC}"
    echo -e "请先启动容器: docker compose up -d"
    exit 1
fi

# 特殊参数 "all" 处理 - 更新所有后端文件
if [ "$1" == "all" ]; then
    echo -e "${YELLOW}正在更新所有后端文件...${NC}"
    
    # 更新src目录
    echo -e "${BLUE}更新src目录...${NC}"
    docker cp -a "./src/." "$CONTAINER_NAME:/app/src"
    
    # 更新热部署脚本
    echo -e "${BLUE}更新热部署脚本...${NC}"
    docker cp "./hot_reload.sh" "$CONTAINER_NAME:/app/hot_reload.sh"
    
    # 确保脚本有执行权限
    docker exec $CONTAINER_NAME chmod +x /app/hot_reload.sh
    
    echo -e "${GREEN}全部文件更新成功${NC}"
    
    # 检查是否有CORS配置
    if docker exec $CONTAINER_NAME grep -q "Access-Control-Allow-Origin" /app/src/app.py; then
        echo -e "${GREEN}CORS配置已更新${NC}"
    else
        echo -e "${RED}警告: 未检测到CORS配置，可能会出现跨域问题${NC}"
    fi
    
    # 重启应用
    echo -e "${BLUE}正在重启应用...${NC}"
    docker exec $CONTAINER_NAME bash -c "pkill -f gunicorn || true && bash /app/hot_reload.sh" &
    
    echo -e "${GREEN}应用正在重启，请稍候...${NC}"
    exit 0
fi

# 更新指定文件
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
    elif [[ $path == "hot_reload.sh" ]]; then
        # 热部署脚本直接放在/app目录
        target_path="/app/hot_reload.sh"
        # 确保脚本有执行权限
        need_chmod=true
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
        
        # 如果需要添加执行权限
        if [ "$need_chmod" = true ]; then
            docker exec $CONTAINER_NAME chmod +x "$target_path"
            echo -e "${BLUE}已添加执行权限: $target_path${NC}"
        fi
    else
        echo -e "${RED}更新失败: $path${NC}"
        exit 1
    fi
done

# 检查是否更新了app.py文件，如果是则检查CORS配置
if [[ "$*" == *"app.py"* ]]; then
    echo -e "${BLUE}检查CORS配置...${NC}"
    if docker exec $CONTAINER_NAME grep -q "Access-Control-Allow-Origin" /app/src/app.py; then
        echo -e "${GREEN}CORS配置已存在${NC}"
    else
        echo -e "${RED}警告: 未检测到CORS配置，可能会出现跨域问题${NC}"
    fi
fi

echo -e "${BLUE}文件已更新，正在触发应用重启...${NC}"

# 主动触发重启
if [[ "$*" == *"hot_reload.sh"* ]]; then
    # 如果更新了热部署脚本，需要重启整个热部署机制
    docker exec $CONTAINER_NAME bash -c "pkill -f gunicorn || true && bash /app/hot_reload.sh" &
    echo -e "${YELLOW}热部署脚本已更新，正在重启整个后端服务...${NC}"
else
    # 否则只触发文件更新
    docker exec $CONTAINER_NAME bash -c "touch /app/src/app.py"
    echo -e "${YELLOW}触发热部署重载完成${NC}"
fi

echo -e "${GREEN}更新流程已完成${NC}"
echo -e "${BLUE}提示: 如果应用没有自动重启，请运行: docker exec $CONTAINER_NAME bash /app/hot_reload.sh${NC}" 