#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检测操作系统并设置环境变量
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    export COMPOSE_CONVERT_WINDOWS_PATHS=1
fi

# 生产环境配置文件
PROD_COMPOSE_FILE="docker-compose.yml"
# 开发环境配置文件
DEV_COMPOSE_FILE="docker-compose.dev.yml"

# 有效命令列表
VALID_COMMANDS=("start" "stop" "logs" "restart" "rebuild" "build" "prod" "shell")
VALID_SERVICES=("frontend" "backend")
VALID_PROD_SUBCOMMANDS=("start" "stop" "restart" "rebuild" "logs")

# 参数校验函数
validate_command() {
    local cmd=$1
    for valid_cmd in "${VALID_COMMANDS[@]}"; do
        if [ "$cmd" == "$valid_cmd" ]; then
            return 0
        fi
    done
    echo -e "${RED}错误: 无效的命令 '$cmd'${NC}"
    echo -e "有效的命令: ${YELLOW}${VALID_COMMANDS[*]}${NC}"
    return 1
}

validate_service() {
    local service=$1
    if [ -z "$service" ]; then
        return 0
    fi
    for valid_service in "${VALID_SERVICES[@]}"; do
        if [ "$service" == "$valid_service" ]; then
            return 0
        fi
    done
    echo -e "${RED}错误: 无效的服务名 '$service'${NC}"
    echo -e "有效的服务: ${YELLOW}${VALID_SERVICES[*]}${NC}"
    return 1
}

validate_prod_subcommand() {
    local subcmd=$1
    for valid_subcmd in "${VALID_PROD_SUBCOMMANDS[@]}"; do
        if [ "$subcmd" == "$valid_subcmd" ]; then
            return 0
        fi
    done
    echo -e "${RED}错误: 无效的生产环境子命令 '$subcmd'${NC}"
    echo -e "有效的子命令: ${YELLOW}${VALID_PROD_SUBCOMMANDS[*]}${NC}"
    return 1
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}用法: ./dev.sh [命令] [服务]${NC}"
    echo -e "\n${GREEN}开发环境命令:${NC}"
    echo "  start   - 启动开发环境"
    echo "  stop    - 停止开发环境"
    echo "  logs    - 查看日志 (可选: backend|frontend)"
    echo "  restart - 重启服务 (可选: backend|frontend)"
    echo "  rebuild - 重新构建服务 (可选: backend|frontend)"
    echo "  build   - 构建环境 (可选: backend|frontend)"
    echo "  shell   - 进入容器Shell (必选: backend|frontend)"
    echo -e "\n${GREEN}生产环境命令:${NC}"
    echo "  prod start   - 启动生产环境"
    echo "  prod stop    - 停止生产环境"
    echo "  prod restart - 重启生产环境 (可选: backend|frontend)"
    echo "  prod rebuild - 重新构建生产环境 (可选: backend|frontend)"
    echo "  prod logs    - 查看生产环境日志 (可选: backend|frontend)"
    echo -e "\n${YELLOW}示例:${NC}"
    echo "  ./dev.sh start                  # 启动开发环境"
    echo "  ./dev.sh prod rebuild frontend  # 重建生产环境前端服务"
    echo "  ./dev.sh logs backend          # 查看开发环境后端日志"
}

# 主命令校验
if [ -z "$1" ]; then
    echo -e "${RED}错误: 请指定命令${NC}"
    show_help
    exit 1
fi

validate_command "$1" || exit 1

case "$1" in
  start)
    echo -e "${GREEN}启动开发环境...${NC}"
    docker compose -f $DEV_COMPOSE_FILE up -d
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}开发服务已启动!${NC}"
        echo -e "${BLUE}后端服务: http://localhost:5000${NC}"
        echo -e "${BLUE}前端服务: http://localhost:3000${NC}"
    else
        echo -e "${RED}启动失败!${NC}"
        exit 1
    fi
    ;;
    
  stop)
    echo -e "${YELLOW}停止开发环境...${NC}"
    docker compose -f $DEV_COMPOSE_FILE down
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}开发服务已停止!${NC}"
    else
        echo -e "${RED}停止失败!${NC}"
        exit 1
    fi
    ;;
    
  logs)
    validate_service "$2" || exit 1
    if [ "$2" == "backend" ]; then
      echo -e "${BLUE}显示后端日志...${NC}"
      docker compose -f $DEV_COMPOSE_FILE logs -f backend
    elif [ "$2" == "frontend" ]; then
      echo -e "${BLUE}显示前端日志...${NC}"
      docker compose -f $DEV_COMPOSE_FILE logs -f frontend
    else
      echo -e "${BLUE}显示所有日志...${NC}"
      docker compose -f $DEV_COMPOSE_FILE logs -f
    fi
    ;;
    
  restart)
    validate_service "$2" || exit 1
    if [ "$2" == "backend" ]; then
      echo -e "${YELLOW}重启后端服务...${NC}"
      docker compose -f $DEV_COMPOSE_FILE restart backend
      if [ $? -eq 0 ]; then
          echo -e "${GREEN}后端服务已重启!${NC}"
      else
          echo -e "${RED}重启失败!${NC}"
          exit 1
      fi
    elif [ "$2" == "frontend" ]; then
      echo -e "${YELLOW}重启前端服务...${NC}"
      docker compose -f $DEV_COMPOSE_FILE restart frontend
      if [ $? -eq 0 ]; then
          echo -e "${GREEN}前端服务已重启!${NC}"
      else
          echo -e "${RED}重启失败!${NC}"
          exit 1
      fi
    else
      echo -e "${YELLOW}重启所有服务...${NC}"
      docker compose -f $DEV_COMPOSE_FILE down
      docker compose -f $DEV_COMPOSE_FILE up -d
      if [ $? -eq 0 ]; then
          echo -e "${GREEN}所有服务已重启!${NC}"
      else
          echo -e "${RED}重启失败!${NC}"
          exit 1
      fi
    fi
    ;;

  rebuild)
    validate_service "$2" || exit 1
    if [ "$2" == "backend" ]; then
      echo -e "${YELLOW}重新构建后端环境...${NC}"
      docker compose -f $DEV_COMPOSE_FILE build --no-cache backend
      docker compose -f $DEV_COMPOSE_FILE up -d --force-recreate backend
      if [ $? -eq 0 ]; then
          echo -e "${GREEN}后端环境已重新构建!${NC}"
      else
          echo -e "${RED}重建失败!${NC}"
          exit 1
      fi
    elif [ "$2" == "frontend" ]; then
      echo -e "${YELLOW}重新构建前端环境...${NC}"
      docker compose -f $DEV_COMPOSE_FILE build --no-cache frontend
      docker compose -f $DEV_COMPOSE_FILE up -d --force-recreate frontend
      if [ $? -eq 0 ]; then
          echo -e "${GREEN}前端环境已重新构建!${NC}"
      else
          echo -e "${RED}重建失败!${NC}"
          exit 1
      fi
    else
      echo -e "${YELLOW}重新构建所有环境...${NC}"
      docker compose -f $DEV_COMPOSE_FILE build --no-cache
      docker compose -f $DEV_COMPOSE_FILE up -d --force-recreate
      if [ $? -eq 0 ]; then
          echo -e "${GREEN}所有环境已重新构建!${NC}"
      else
          echo -e "${RED}重建失败!${NC}"
          exit 1
      fi
    fi
    ;;
    
  build)
    validate_service "$2" || exit 1
    if [ "$2" == "backend" ]; then
      echo -e "${YELLOW}构建后端环境...${NC}"
      docker compose -f $DEV_COMPOSE_FILE build backend
      if [ $? -eq 0 ]; then
          echo -e "${GREEN}后端环境已构建!${NC}"
      else
          echo -e "${RED}构建失败!${NC}"
          exit 1
      fi
    elif [ "$2" == "frontend" ]; then
      echo -e "${YELLOW}构建前端环境...${NC}"
      docker compose -f $DEV_COMPOSE_FILE build frontend
      if [ $? -eq 0 ]; then
          echo -e "${GREEN}前端环境已构建!${NC}"
      else
          echo -e "${RED}构建失败!${NC}"
          exit 1
      fi
    else
      echo -e "${YELLOW}构建所有环境...${NC}"
      docker compose -f $DEV_COMPOSE_FILE build
      if [ $? -eq 0 ]; then
          echo -e "${GREEN}所有环境已构建!${NC}"
      else
          echo -e "${RED}构建失败!${NC}"
          exit 1
      fi
    fi
    ;;
    
  prod)
    if [ -z "$2" ]; then
        echo -e "${RED}错误: 请指定生产环境子命令${NC}"
        show_help
        exit 1
    fi
    validate_prod_subcommand "$2" || exit 1
    case "$2" in
      start)
        echo -e "${YELLOW}启动生产环境...${NC}"
        docker compose -f $PROD_COMPOSE_FILE up -d
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}生产服务已启动!${NC}"
        else
            echo -e "${RED}启动失败!${NC}"
            exit 1
        fi
        ;;
      stop)
        echo -e "${YELLOW}停止生产环境...${NC}"
        docker compose -f $PROD_COMPOSE_FILE down
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}生产服务已停止!${NC}"
        else
            echo -e "${RED}停止失败!${NC}"
            exit 1
        fi
        ;;
      restart)
        validate_service "$3" || exit 1
        if [ "$3" == "backend" ]; then
          echo -e "${YELLOW}重启生产环境后端服务...${NC}"
          docker compose -f $PROD_COMPOSE_FILE restart backend
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}生产环境后端服务已重启!${NC}"
          else
              echo -e "${RED}重启失败!${NC}"
              exit 1
          fi
        elif [ "$3" == "frontend" ]; then
          echo -e "${YELLOW}重启生产环境前端服务...${NC}"
          docker compose -f $PROD_COMPOSE_FILE restart frontend
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}生产环境前端服务已重启!${NC}"
          else
              echo -e "${RED}重启失败!${NC}"
              exit 1
          fi
        else
          echo -e "${YELLOW}重启生产环境...${NC}"
          docker compose -f $PROD_COMPOSE_FILE down
          docker compose -f $PROD_COMPOSE_FILE up -d
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}生产服务已重启!${NC}"
          else
              echo -e "${RED}重启失败!${NC}"
              exit 1
          fi
        fi
        ;;
      rebuild)
        validate_service "$3" || exit 1
        if [ "$3" == "backend" ]; then
          echo -e "${YELLOW}重新构建生产环境后端...${NC}"
          docker compose -f $PROD_COMPOSE_FILE build --no-cache backend
          docker compose -f $PROD_COMPOSE_FILE up -d --force-recreate backend
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}生产环境后端已重新构建!${NC}"
          else
              echo -e "${RED}重建失败!${NC}"
              exit 1
          fi
        elif [ "$3" == "frontend" ]; then
          echo -e "${YELLOW}重新构建生产环境前端...${NC}"
          docker compose -f $PROD_COMPOSE_FILE build --no-cache frontend
          docker compose -f $PROD_COMPOSE_FILE up -d --force-recreate frontend
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}生产环境前端已重新构建!${NC}"
          else
              echo -e "${RED}重建失败!${NC}"
              exit 1
          fi
        else
          echo -e "${YELLOW}重新构建生产环境...${NC}"
          docker compose -f $PROD_COMPOSE_FILE build --no-cache
          docker compose -f $PROD_COMPOSE_FILE up -d --force-recreate
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}生产环境已重新构建!${NC}"
          else
              echo -e "${RED}重建失败!${NC}"
              exit 1
          fi
        fi
        ;;
      logs)
        validate_service "$3" || exit 1
        if [ "$3" == "backend" ]; then
          echo -e "${BLUE}显示生产环境后端日志...${NC}"
          docker compose -f $PROD_COMPOSE_FILE logs -f backend
        elif [ "$3" == "frontend" ]; then
          echo -e "${BLUE}显示生产环境前端日志...${NC}"
          docker compose -f $PROD_COMPOSE_FILE logs -f frontend
        else
          echo -e "${BLUE}显示生产环境所有日志...${NC}"
          docker compose -f $PROD_COMPOSE_FILE logs -f
        fi
        ;;
    esac
    ;;
    
  shell)
    if [ -z "$2" ]; then
        echo -e "${RED}错误: shell 命令需要指定服务名 (frontend 或 backend)${NC}"
        exit 1
    fi
    validate_service "$2" || exit 1
    if [ "$2" == "frontend" ]; then
      echo -e "${BLUE}进入前端容器Shell...${NC}"
      docker compose -f $DEV_COMPOSE_FILE exec frontend /bin/sh
    elif [ "$2" == "backend" ]; then
      echo -e "${BLUE}进入后端容器Shell...${NC}"
      docker compose -f $DEV_COMPOSE_FILE exec backend /bin/bash
    fi
    ;;
    
  *)
    show_help
    ;;
esac 