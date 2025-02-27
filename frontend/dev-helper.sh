#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

case "$1" in
  install)
    echo -e "${BLUE}安装前端依赖...${NC}"
    # 如果有package.json，则执行npm install
    if [ -f "package.json" ]; then
      npm install
      echo -e "${GREEN}依赖安装完成!${NC}"
    else
      echo -e "${YELLOW}警告: 没有找到package.json文件${NC}"
    fi
    ;;
    
  build)
    echo -e "${BLUE}构建前端生产版本...${NC}"
    # 如果有package.json，则执行npm run build
    if [ -f "package.json" ]; then
      npm run build
      echo -e "${GREEN}构建完成!${NC}"
    else
      echo -e "${RED}错误: 没有找到package.json文件${NC}"
      exit 1
    fi
    ;;
    
  lint)
    echo -e "${BLUE}检查代码格式...${NC}"
    # 检查JavaScript文件
    for file in $(find . -name "*.js" -not -path "./node_modules/*"); do
      echo -e "检查 ${YELLOW}$file${NC}"
      npx eslint --fix "$file" || echo -e "${RED}$file 有错误${NC}"
    done
    echo -e "${GREEN}检查完成!${NC}"
    ;;
    
  livereload)
    echo -e "${BLUE}启动实时重载服务器...${NC}"
    # 如果安装了live-server则使用它
    if command -v npx &> /dev/null; then
      npx live-server --port=3000 --host=0.0.0.0 --no-browser
    else
      echo -e "${RED}错误: 需要安装node和npx${NC}"
      echo -e "运行 ${YELLOW}npm install -g live-server${NC} 来安装"
      exit 1
    fi
    ;;
    
  *)
    echo "用法: ./dev-helper.sh [命令]"
    echo "命令:"
    echo "  install    - 安装前端依赖"
    echo "  build      - 构建生产版本"
    echo "  lint       - 检查代码格式"
    echo "  livereload - 启动实时重载服务器"
    ;;
esac 