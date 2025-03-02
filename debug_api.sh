#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}开始调试API 500错误...${NC}"

# 获取详细后端日志
echo -e "${BLUE}步骤1: 检查详细后端日志...${NC}"
docker logs backend --tail 50

# 检查后端Flask应用运行状态
echo -e "${BLUE}步骤2: 检查后端进程...${NC}"
docker exec backend ps aux

# 检查环境变量
echo -e "${BLUE}步骤3: 检查后端环境变量...${NC}"
docker exec backend env | grep -E 'FLASK|PYTHON|PATH|API'

# 直接测试后端API
echo -e "${BLUE}步骤4: 直接测试后端API...${NC}"
echo "从后端容器内部测试:"
docker exec backend curl -v http://localhost:5000/api/models

echo "从主机直接测试后端:"
curl -v http://localhost:5000/api/models

# 检查API路由和配置
echo -e "${BLUE}步骤5: 检查API路由...${NC}"
docker exec backend python -c "
import sys
sys.path.append('/app')
try:
    from src.app import create_app
    app = create_app()
    print('\\n注册的路由:')
    for rule in app.url_map.iter_rules():
        print(f'{rule.endpoint}: {rule.methods} - {rule}')
except Exception as e:
    print(f'导入应用失败: {e}')
"

# 检查常见错误
echo -e "${BLUE}步骤6: 测试常见依赖项...${NC}"
docker exec backend python -c "
try:
    import flask
    print(f'Flask版本: {flask.__version__}')
    
    # 检查其他关键依赖
    for module in ['requests', 'numpy', 'json', 'os']:
        try:
            __import__(module)
            print(f'{module} 已安装')
        except ImportError:
            print(f'{module} 未安装')
            
except Exception as e:
    print(f'依赖检查失败: {e}')
"

echo -e "\n${GREEN}调试完成！${NC}"
echo -e "请检查上面的日志，特别关注以下内容:"
echo -e "1. 后端应用错误日志"
echo -e "2. API路由是否正确注册"
echo -e "3. 依赖项是否都已正确安装"
echo -e "4. 环境变量是否正确设置"
echo -e ""
echo -e "如果看到具体错误，请修复应用代码中的相关问题。"
echo -e "常见解决方法:"
echo -e "1. 检查数据库连接"
echo -e "2. 检查API密钥或配置文件"
echo -e "3. 检查日志中的Python错误堆栈" 