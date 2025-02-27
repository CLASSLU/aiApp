#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

case "$1" in
  start)
    echo -e "${GREEN}启动开发环境...${NC}"
    docker compose -f docker-compose.dev.yml up -d
    echo -e "${GREEN}开发服务已启动!${NC}"
    echo -e "${BLUE}后端服务: http://localhost:5000${NC}"
    echo -e "${BLUE}前端服务: http://localhost:3000${NC}"
    ;;
    
  stop)
    echo -e "${YELLOW}停止开发环境...${NC}"
    docker compose -f docker-compose.dev.yml down
    echo -e "${GREEN}开发服务已停止!${NC}"
    ;;
    
  logs)
    if [ "$2" == "backend" ]; then
      echo -e "${BLUE}显示后端日志...${NC}"
      docker compose -f docker-compose.dev.yml logs -f backend
    elif [ "$2" == "frontend" ]; then
      echo -e "${BLUE}显示前端日志...${NC}"
      docker compose -f docker-compose.dev.yml logs -f frontend
    else
      echo -e "${BLUE}显示所有日志...${NC}"
      docker compose -f docker-compose.dev.yml logs -f
    fi
    ;;
    
  restart)
    if [ "$2" == "backend" ]; then
      echo -e "${YELLOW}重启后端服务...${NC}"
      docker compose -f docker-compose.dev.yml restart backend
      echo -e "${GREEN}后端服务已重启!${NC}"
    elif [ "$2" == "frontend" ]; then
      echo -e "${YELLOW}重启前端服务...${NC}"
      docker compose -f docker-compose.dev.yml restart frontend
      echo -e "${GREEN}前端服务已重启!${NC}"
    else
      echo -e "${YELLOW}重启所有服务...${NC}"
      docker compose -f docker-compose.dev.yml down
      docker compose -f docker-compose.dev.yml up -d
      echo -e "${GREEN}所有服务已重启!${NC}"
    fi
    ;;
    
  build)
    if [ "$2" == "backend" ]; then
      echo -e "${YELLOW}构建后端环境...${NC}"
      docker compose -f docker-compose.dev.yml build backend
      echo -e "${GREEN}后端环境已构建!${NC}"
    elif [ "$2" == "frontend" ]; then
      echo -e "${YELLOW}构建前端环境...${NC}"
      docker compose -f docker-compose.dev.yml build frontend
      echo -e "${GREEN}前端环境已构建!${NC}"
    else
      echo -e "${YELLOW}构建所有环境...${NC}"
      docker compose -f docker-compose.dev.yml build
      echo -e "${GREEN}所有环境已构建!${NC}"
    fi
    ;;
    
  prod)
    echo -e "${YELLOW}启动生产环境...${NC}"
    docker compose up -d
    echo -e "${GREEN}生产服务已启动!${NC}"
    ;;
    
  shell)
    if [ "$2" == "frontend" ]; then
      echo -e "${BLUE}进入前端容器Shell...${NC}"
      docker compose -f docker-compose.dev.yml exec frontend /bin/sh
    elif [ "$2" == "backend" ]; then
      echo -e "${BLUE}进入后端容器Shell...${NC}"
      docker compose -f docker-compose.dev.yml exec backend /bin/bash
    else
      echo -e "${RED}错误: 请指定容器 (frontend 或 backend)${NC}"
      exit 1
    fi
    ;;
    
  *)
    echo "用法: ./dev.sh [命令] [服务]"
    echo "命令:"
    echo "  start   - 启动开发环境"
    echo "  stop    - 停止开发环境"
    echo "  logs    - 查看日志 (可选: backend|frontend)"
    echo "  restart - 重启服务 (可选: backend|frontend)"
    echo "  build   - 构建环境 (可选: backend|frontend)"
    echo "  shell   - 进入容器Shell (必选: backend|frontend)"
    echo "  prod    - 启动生产环境"
    ;;
esac 