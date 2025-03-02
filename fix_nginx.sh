#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}开始修复Nginx配置...${NC}"

# 1. 更新Nginx配置文件
echo -e "${BLUE}步骤1: 更新Nginx配置...${NC}"
./update_prod.sh frontend/nginx.conf

# 2. 更新前端配置文件
echo -e "${BLUE}步骤2: 更新前端配置...${NC}"
./update_prod.sh frontend/assets/config.js

# 3. 检查Nginx配置
echo -e "${BLUE}步骤3: 验证Nginx配置...${NC}"
docker exec frontend nginx -t

if [ $? -ne 0 ]; then
    echo -e "${RED}Nginx配置验证失败，请检查配置文件${NC}"
    exit 1
fi

# 4. 重启容器
echo -e "${BLUE}步骤4: 重启服务...${NC}"
docker restart backend
docker restart frontend

# 5. 等待服务启动
echo -e "${BLUE}步骤5: 等待服务启动...${NC}"
sleep 5

# 6. 检查Nginx是否正常运行
echo -e "${BLUE}步骤6: 检查Nginx状态...${NC}"
docker exec frontend pgrep -x nginx > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Nginx进程正常运行${NC}"
else
    echo -e "${RED}Nginx进程未运行，尝试启动...${NC}"
    docker exec frontend nginx
fi

# 7. 检查Nginx日志
echo -e "${BLUE}步骤7: 检查Nginx错误日志...${NC}"
docker exec frontend cat /var/log/nginx/error.log | tail -n 20

# 8. 测试API连接
echo -e "${BLUE}步骤8: 测试从前端容器连接后端API...${NC}"
docker exec frontend sh -c "curl -s http://backend:5000/api/models" | head -n 30

# 9. 测试从主机访问
echo -e "${BLUE}步骤9: 测试从主机直接访问后端API...${NC}"
curl -s http://localhost:5000/api/models | head -n 10

echo -e "${BLUE}步骤10: 测试从主机通过Nginx代理访问API...${NC}"
curl -s http://localhost/api/models | head -n 10

echo -e "\n${GREEN}Nginx配置修复完成！${NC}"
echo -e "请在浏览器中测试应用，确认API请求正常。"
echo -e "如果问题仍然存在，请检查以下内容："
echo -e "1. 确认后端API在端口5000上正常运行"
echo -e "2. 检查前端容器内部网络是否能访问后端容器"
echo -e "3. 查看Nginx完整错误日志: docker exec frontend cat /var/log/nginx/error.log" 