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
    echo -e "示例: ./update_prod.sh src/app.py          # 更新后端文件"
    echo -e "      ./update_prod.sh frontend/chat.html  # 更新前端文件"
    echo -e "      ./update_prod.sh frontend/assets     # 更新前端目录"
    echo -e "      ./update_prod.sh all                 # 更新所有后端文件"
    echo -e "      ./update_prod.sh frontend-all        # 更新所有前端文件"
    exit 1
fi

# 容器名称
BACKEND_CONTAINER="backend"
FRONTEND_CONTAINER="frontend"

# 检查容器是否运行
check_container() {
    local container=$1
    if ! docker ps | grep -q $container; then
        echo -e "${RED}错误: 容器 $container 未运行${NC}"
        echo -e "请先启动容器: docker compose up -d"
        exit 1
    fi
}

# 检查后端容器
check_container $BACKEND_CONTAINER

# 特殊参数 "frontend-all" 处理 - 更新所有前端文件
if [ "$1" == "frontend-all" ]; then
    echo -e "${YELLOW}正在更新所有前端文件...${NC}"
    
    # 检查前端容器
    check_container $FRONTEND_CONTAINER
    
    # 更新整个前端目录
    echo -e "${BLUE}更新前端目录...${NC}"
    
    # 复制前端文件到容器
    docker cp -a "./frontend/." "$FRONTEND_CONTAINER:/usr/share/nginx/html"
    
    # 如果存在nginx配置文件，复制它
    if [ -f "./frontend/nginx.conf" ]; then
        echo -e "${BLUE}更新Nginx配置...${NC}"
        docker cp "./frontend/nginx.conf" "$FRONTEND_CONTAINER:/etc/nginx/conf.d/default.conf"
        
        # 检查nginx配置是否有效
        if docker exec $FRONTEND_CONTAINER nginx -t &>/dev/null; then
            echo -e "${GREEN}Nginx配置有效${NC}"
            # 重新加载Nginx配置
            docker exec $FRONTEND_CONTAINER nginx -s reload
        else
            echo -e "${RED}警告: Nginx配置无效，请检查配置文件${NC}"
            docker exec $FRONTEND_CONTAINER nginx -t
        fi
    fi
    
    echo -e "${GREEN}前端文件更新成功${NC}"
    
    # 重启前端容器
    echo -e "${BLUE}正在重启前端容器...${NC}"
    docker restart $FRONTEND_CONTAINER
    
    echo -e "${GREEN}前端已重启，请稍候几秒钟后刷新浏览器${NC}"
    exit 0
fi

# 特殊参数 "all" 处理 - 更新所有后端文件
if [ "$1" == "all" ]; then
    echo -e "${YELLOW}正在更新所有后端文件...${NC}"
    
    # 更新src目录
    echo -e "${BLUE}更新src目录...${NC}"
    docker cp -a "./src/." "$BACKEND_CONTAINER:/app/src"
    
    # 更新热部署脚本
    echo -e "${BLUE}更新热部署脚本...${NC}"
    docker cp "./hot_reload.sh" "$BACKEND_CONTAINER:/app/hot_reload.sh"
    
    # 确保脚本有执行权限
    docker exec $BACKEND_CONTAINER chmod +x /app/hot_reload.sh
    
    echo -e "${GREEN}全部后端文件更新成功${NC}"
    
    # 检查是否有CORS配置
    if docker exec $BACKEND_CONTAINER grep -q "Access-Control-Allow-Origin" /app/src/app.py; then
        echo -e "${GREEN}CORS配置已更新${NC}"
    else
        echo -e "${RED}警告: 未检测到CORS配置，可能会出现跨域问题${NC}"
    fi
    
    # 重启应用
    echo -e "${BLUE}正在重启后端应用...${NC}"
    docker exec $BACKEND_CONTAINER bash -c "pkill -f gunicorn || true && bash /app/hot_reload.sh" &
    
    echo -e "${GREEN}后端应用正在重启，请稍候...${NC}"
    exit 0
fi

# 检查路径是前端还是后端
is_frontend=false
if [[ "$1" == frontend/* ]]; then
    is_frontend=true
    # 检查前端容器
    check_container $FRONTEND_CONTAINER
fi

# 更新指定文件
for path in "$@"; do
    # 检查文件是否存在
    if [ ! -e "$path" ]; then
        echo -e "${RED}错误: 文件或目录不存在: $path${NC}"
        continue
    fi
    
    # 根据路径判断是前端还是后端文件
    if [[ "$path" == frontend/* ]]; then
        # 前端文件
        container=$FRONTEND_CONTAINER
        # 去掉路径前缀frontend/
        relative_path=${path#frontend/}
        target_path="/usr/share/nginx/html/$relative_path"
        is_frontend=true
    elif [[ $path == src/* ]]; then
        # 如果是 src 目录下的文件，直接复制到容器的 /app/src 目录
        container=$BACKEND_CONTAINER
        target_path="/app/${path}"
    elif [[ $path == "hot_reload.sh" ]]; then
        # 热部署脚本直接放在/app目录
        container=$BACKEND_CONTAINER
        target_path="/app/hot_reload.sh"
        # 确保脚本有执行权限
        need_chmod=true
    else
        # 其他文件复制到容器的根目录
        container=$BACKEND_CONTAINER
        target_path="/app/${path}"
    fi
    
    echo -e "${YELLOW}正在更新: $path -> $container:$target_path${NC}"
    
    # 确保目标目录存在
    target_dir=$(dirname "$target_path")
    docker exec $container mkdir -p "$target_dir"
    
    # 复制文件到容器
    if [ -d "$path" ]; then
        # 如果是目录，使用 -r 参数
        docker cp -a "$path/." "$container:$target_path"
    else
        # 如果是文件
        docker cp "$path" "$container:$target_path"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}更新成功: $path${NC}"
        
        # 如果需要添加执行权限
        if [ "$need_chmod" = true ]; then
            docker exec $container chmod +x "$target_path"
            echo -e "${BLUE}已添加执行权限: $target_path${NC}"
        fi
    else
        echo -e "${RED}更新失败: $path${NC}"
        exit 1
    fi
done

# 如果是前端文件，重启前端容器
if [ "$is_frontend" = true ]; then
    echo -e "${BLUE}前端文件已更新，正在重启前端容器...${NC}"
    docker restart $FRONTEND_CONTAINER
    echo -e "${GREEN}前端容器已重启，请稍候几秒钟后刷新浏览器${NC}"
    exit 0
fi

# 后端文件更新，检查是否更新了app.py文件，如果是则检查CORS配置
if [[ "$*" == *"app.py"* ]]; then
    echo -e "${BLUE}检查CORS配置...${NC}"
    if docker exec $BACKEND_CONTAINER grep -q "Access-Control-Allow-Origin" /app/src/app.py; then
        echo -e "${GREEN}CORS配置已存在${NC}"
    else
        echo -e "${RED}警告: 未检测到CORS配置，可能会出现跨域问题${NC}"
    fi
fi

echo -e "${BLUE}后端文件已更新，正在触发应用重启...${NC}"

# 主动触发重启
if [[ "$*" == *"hot_reload.sh"* ]]; then
    # 如果更新了热部署脚本，需要重启整个热部署机制
    docker exec $BACKEND_CONTAINER bash -c "pkill -f gunicorn || true && bash /app/hot_reload.sh" &
    echo -e "${YELLOW}热部署脚本已更新，正在重启整个后端服务...${NC}"
else
    # 否则只触发文件更新
    docker exec $BACKEND_CONTAINER bash -c "touch /app/src/app.py"
    echo -e "${YELLOW}触发热部署重载完成${NC}"
fi

echo -e "${GREEN}更新流程已完成${NC}"
echo -e "${BLUE}提示: 如果应用没有自动重启，请运行: docker exec $BACKEND_CONTAINER bash /app/hot_reload.sh${NC}"

# 处理单个文件更新
SRC_FILE=$1
echo -e "${YELLOW}正在更新: $SRC_FILE ${NC}"

# 确定目标容器
if [[ "$SRC_FILE" == frontend/* ]]; then
    # 前端文件
    CONTAINER=$FRONTEND_CONTAINER
    check_container $CONTAINER
    
    # 对于前端文件，确定容器中的目标路径
    if [[ "$SRC_FILE" == frontend/nginx.conf ]]; then
        # 特殊处理nginx.conf文件
        DEST_PATH="/etc/nginx/conf.d/default.conf"
    else
        # 其他前端文件
        DEST_PATH="/usr/share/nginx/html/${SRC_FILE#frontend/}"
    fi
    
    # 确保目标目录存在
    DEST_DIR=$(dirname "$DEST_PATH")
    docker exec $CONTAINER mkdir -p "$DEST_DIR"
    
    # 复制文件
    docker cp "$SRC_FILE" "$CONTAINER:$DEST_PATH"
    echo -e "${GREEN}已更新: $DEST_PATH${NC}"
    
    # 如果更新的是nginx配置，需要重新加载
    if [[ "$SRC_FILE" == frontend/nginx.conf ]]; then
        if docker exec $CONTAINER nginx -t &>/dev/null; then
            echo -e "${GREEN}Nginx配置有效，正在重新加载...${NC}"
            docker exec $CONTAINER nginx -s reload
            echo -e "${GREEN}Nginx配置已重新加载${NC}"
        else
            echo -e "${RED}警告: Nginx配置无效，请检查配置文件${NC}"
            docker exec $CONTAINER nginx -t
        fi
    fi
fi

# 验证前端目录挂载
check_frontend_mount() {
    echo -e "${BLUE}验证前端目录挂载...${NC}"
    # 创建测试文件
    TEST_FILE="mount_test_$(date +%s).txt"
    echo "test" > "./frontend/$TEST_FILE"
    
    # 检查容器内是否存在该文件
    if docker exec $FRONTEND_CONTAINER test -f "/usr/share/nginx/html/$TEST_FILE"; then
        echo -e "${GREEN}前端目录挂载正常${NC}"
        # 清理测试文件
        rm "./frontend/$TEST_FILE"
        docker exec $FRONTEND_CONTAINER rm "/usr/share/nginx/html/$TEST_FILE" 2>/dev/null || true
        return 0
    else
        echo -e "${RED}警告: 前端目录挂载异常${NC}"
        echo -e "${YELLOW}本地文件未同步到容器，更新可能不会立即生效${NC}"
        echo -e "${YELLOW}建议修改docker-compose.yml文件，确保挂载配置正确${NC}"
        # 清理测试文件
        rm "./frontend/$TEST_FILE"
        return 1
    fi
} 