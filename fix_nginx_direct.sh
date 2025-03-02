#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}开始修复Nginx配置...${NC}"

# 1. 重新加载Nginx配置（不依赖update_prod.sh）
echo -e "${BLUE}步骤1: 重新加载Nginx配置...${NC}"
docker exec frontend nginx -s reload 2>/dev/null || echo "Nginx可能未运行，将在重启容器后启动"

# 2. 检查Nginx配置
echo -e "${BLUE}步骤2: 验证Nginx配置...${NC}"
docker exec frontend nginx -t

if [ $? -ne 0 ]; then
    echo -e "${RED}Nginx配置验证失败，请检查配置文件${NC}"
    exit 1
fi

# 3. 检查谁占用了80端口
echo -e "${BLUE}步骤3: 检查80端口占用情况...${NC}"
docker exec frontend sh -c "command -v netstat >/dev/null && netstat -tulpn | grep :80 || echo '容器内未安装netstat'"
echo "主机80端口占用情况:"
netstat -tulpn 2>/dev/null | grep :80 || echo "需要安装net-tools工具"

# 4. 尝试停止现有Nginx进程
echo -e "${BLUE}步骤4: 尝试停止现有Nginx进程...${NC}"
docker exec frontend sh -c "pkill nginx || echo 'Nginx进程未运行或无法停止'"
sleep 2

# 5. 重启容器
echo -e "${BLUE}步骤5: 重启服务...${NC}"
docker restart backend
docker restart frontend

# 6. 等待服务启动
echo -e "${BLUE}步骤6: 等待服务启动...${NC}"
sleep 5

# 7. 检查Nginx是否正常运行
echo -e "${BLUE}步骤7: 检查Nginx状态...${NC}"
docker exec frontend pgrep -x nginx > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Nginx进程正常运行${NC}"
else
    echo -e "${RED}Nginx进程未运行，尝试启动...${NC}"
    docker exec frontend sh -c "pkill -9 nginx 2>/dev/null || true"
    sleep 1
    docker exec frontend nginx
fi

# 8. 检查Nginx日志
echo -e "${BLUE}步骤8: 检查Nginx错误日志...${NC}"
docker exec frontend cat /var/log/nginx/error.log | tail -n 20

# 9. 测试API连接
echo -e "${BLUE}步骤9: 测试从前端容器连接后端API...${NC}"
docker exec frontend sh -c "curl -s http://backend:5000/api/models" | head -n 30

# 10. 测试从主机访问
echo -e "${BLUE}步骤10: 测试从主机直接访问后端API...${NC}"
curl -s http://localhost:5000/api/models | head -n 10

echo -e "${BLUE}步骤11: 测试从主机通过Nginx代理访问API...${NC}"
curl -s http://localhost/api/models | head -n 10

echo -e "\n${GREEN}Nginx配置修复完成！${NC}"
echo -e "请在浏览器中测试应用，确认API请求正常。"
echo -e "如果问题仍然存在，请检查以下内容："
echo -e "1. 确认后端API在端口5000上正常运行"
echo -e "2. 检查前端容器内部网络是否能访问后端容器"
echo -e "3. 查看Nginx完整错误日志: docker exec frontend cat /var/log/nginx/error.log"
echo -e "4. 检查宿主机80端口是否被占用: netstat -tulpn | grep :80"
echo -e "5. 检查docker-compose.yml中端口映射配置是否正确" 