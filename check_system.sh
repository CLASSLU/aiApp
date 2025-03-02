#!/bin/bash
# 文件名: check_system.sh

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}开始系统健康检查...${NC}"

# 检查容器状态
echo -e "${BLUE}检查容器状态...${NC}"
BACKEND_RUNNING=$(docker ps | grep -q "backend" && echo "是" || echo "否")
FRONTEND_RUNNING=$(docker ps | grep -q "frontend" && echo "是" || echo "否")

echo -e "后端容器运行: ${GREEN}$BACKEND_RUNNING${NC}"
echo -e "前端容器运行: ${GREEN}$FRONTEND_RUNNING${NC}"

# 验证后端API可访问性
echo -e "\n${BLUE}验证后端API可访问性...${NC}"
BACKEND_API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/models)
if [ "$BACKEND_API_STATUS" == "200" ]; then
    echo -e "后端API状态: ${GREEN}可访问 (200 OK)${NC}"
else
    echo -e "后端API状态: ${RED}不可访问 (状态码: $BACKEND_API_STATUS)${NC}"
fi

# 验证前端可访问性
echo -e "\n${BLUE}验证前端可访问性...${NC}"
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
if [ "$FRONTEND_STATUS" == "200" ]; then
    echo -e "前端状态: ${GREEN}可访问 (200 OK)${NC}"
else
    echo -e "前端状态: ${RED}不可访问 (状态码: $FRONTEND_STATUS)${NC}"
fi

# 通过前端Nginx代理验证API访问
echo -e "\n${BLUE}通过Nginx代理验证API访问...${NC}"
PROXY_API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/models)
if [ "$PROXY_API_STATUS" == "200" ]; then
    echo -e "通过Nginx代理的API状态: ${GREEN}可访问 (200 OK)${NC}"
else
    echo -e "通过Nginx代理的API状态: ${RED}不可访问 (状态码: $PROXY_API_STATUS)${NC}"
fi

# 验证CORS配置
echo -e "\n${BLUE}验证CORS配置...${NC}"
CORS_STATUS=$(curl -s -I -X OPTIONS "http://localhost/api/models" \
  -H "Origin: http://example.com" \
  -H "Access-Control-Request-Method: GET" | grep -i "Access-Control-Allow-Origin")

if [ ! -z "$CORS_STATUS" ]; then
    echo -e "CORS配置: ${GREEN}正常${NC}"
    echo -e "$CORS_STATUS"
else
    echo -e "CORS配置: ${RED}异常 (未找到CORS头)${NC}"
fi

echo -e "\n${YELLOW}系统健康检查完成${NC}"
