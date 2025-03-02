#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}开始重建Docker容器...${NC}"

# 停止所有容器
echo -e "${BLUE}步骤1: 停止所有容器...${NC}"
docker-compose down

# 重新构建容器
echo -e "${BLUE}步骤2: 重新构建容器...${NC}"
docker-compose build

# 启动容器
echo -e "${BLUE}步骤3: 启动容器...${NC}"
docker-compose up -d

# 等待服务启动
echo -e "${BLUE}步骤4: 等待服务启动...${NC}"
sleep 10

# 检查容器状态
echo -e "${BLUE}步骤5: 检查容器状态...${NC}"
docker-compose ps

# 检查Nginx状态
echo -e "${BLUE}步骤6: 检查Nginx状态...${NC}"
docker exec frontend nginx -t

# 测试API连接
echo -e "${BLUE}步骤7: 测试从前端容器连接后端API...${NC}"
docker exec frontend curl -s http://backend:5000/api/models | head -n 30

# 测试主机访问
echo -e "${BLUE}步骤8: 测试从主机通过Nginx代理访问API...${NC}"
curl -s http://localhost/api/models | head -n 10

echo -e "\n${GREEN}容器重建完成！${NC}"
echo -e "请在浏览器中测试应用，确认API请求正常。"
echo -e "如果问题仍然存在，请检查Docker日志:"
echo -e "  前端日志: docker logs frontend"
echo -e "  后端日志: docker logs backend" 