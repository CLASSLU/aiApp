#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查脚本文件格式，修复可能的行尾问题
check_script_format() {
    local script=$1
    if [ -f "$script" ]; then
        # 检查和修复行尾
        if grep -q $'\r' "$script" 2>/dev/null; then
            echo -e "${YELLOW}警告: 脚本 $script 包含Windows风格换行符，正在修复...${NC}"
            sed -i 's/\r$//' "$script"
            echo -e "${GREEN}行尾修复完成${NC}"
        fi
        
        # 修复执行权限
        if [ ! -x "$script" ]; then
            echo -e "${YELLOW}警告: 脚本 $script 缺少执行权限，正在修复...${NC}"
            chmod +x "$script"
            echo -e "${GREEN}权限修复完成${NC}"
        fi
    else
        echo -e "${YELLOW}警告: 脚本 $script 不存在，跳过检查${NC}"
    fi
}

# 检查Docker是否运行
check_docker_running() {
    echo -e "${BLUE}检查Docker是否正在运行...${NC}"
    
    # 尝试执行一个简单的Docker命令来测试Docker是否运行
    if ! docker info > /dev/null 2>&1; then
        echo -e "${YELLOW}Docker未运行，尝试启动Docker...${NC}"
        
        # 检测操作系统类型
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
            # Windows环境
            echo -e "${BLUE}检测到Windows系统，尝试启动Docker Desktop...${NC}"
            
            # 检查Docker服务是否存在
            echo -e "${BLUE}检查Docker服务状态...${NC}"
            
            # 使用多种方法尝试启动Docker Desktop
            STARTED=false
            
            # 方法1: 使用开始菜单中的快捷方式
            echo -e "${BLUE}方法1: 尝试通过快捷方式启动Docker Desktop...${NC}"
            if command -v powershell.exe &>/dev/null; then
                powershell.exe -Command "Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe' -Verb RunAs" &
                sleep 5
                
                if docker info > /dev/null 2>&1; then
                    echo -e "${GREEN}Docker已通过方法1成功启动!${NC}"
                    STARTED=true
                else
                    echo -e "${YELLOW}方法1未能启动Docker, 尝试方法2...${NC}"
                fi
            fi
            
            # 方法2: 尝试启动Docker服务
            if [ "$STARTED" = false ] && command -v powershell.exe &>/dev/null; then
                echo -e "${BLUE}方法2: 尝试启动Docker服务...${NC}"
                # 以管理员权限启动Docker服务
                powershell.exe -Command "Start-Process powershell -ArgumentList '-Command Get-Service *docker* | Start-Service' -Verb RunAs" &
                sleep 10
                
                if docker info > /dev/null 2>&1; then
                    echo -e "${GREEN}Docker已通过方法2成功启动!${NC}"
                    STARTED=true
                else
                    echo -e "${YELLOW}方法2未能启动Docker, 尝试方法3...${NC}"
                fi
            fi
            
            # 方法3: 使用cmd.exe直接启动应用程序
            if [ "$STARTED" = false ] && command -v cmd.exe &>/dev/null; then
                echo -e "${BLUE}方法3: 尝试用CMD启动Docker Desktop...${NC}"
                cmd.exe /c "start \"\" \"C:\Program Files\Docker\Docker\Docker Desktop.exe\"" &
                sleep 5
                
                if docker info > /dev/null 2>&1; then
                    echo -e "${GREEN}Docker已通过方法3成功启动!${NC}"
                    STARTED=true
                else
                    echo -e "${YELLOW}方法3未能启动Docker, 尝试方法4...${NC}"
                fi
            fi
            
            # 方法4: 尝试使用WindowsApps直接启动
            if [ "$STARTED" = false ]; then
                echo -e "${BLUE}方法4: 尝试通过Windows应用启动器启动Docker...${NC}"
                powershell.exe -Command "Start-Process shell:AppsFolder\Docker.DockerDesktop" &
                sleep 5
                
                if docker info > /dev/null 2>&1; then
                    echo -e "${GREEN}Docker已通过方法4成功启动!${NC}"
                    STARTED=true
                else
                    echo -e "${YELLOW}方法4未能启动Docker...${NC}"
                fi
            fi
            
            # 如果上述方法都没有立即启动Docker，等待一段时间看是否启动
            if [ "$STARTED" = false ]; then
                echo -e "${YELLOW}正在等待Docker启动 (最多90秒)...${NC}"
                for i in {1..45}; do
                    sleep 2
                    if docker info > /dev/null 2>&1; then
                        echo -e "${GREEN}Docker已成功启动!${NC}"
                        return 0
                    fi
                    echo -n "."
                done
                
                # 尝试显示一些诊断信息
                echo -e "\n${YELLOW}收集Docker诊断信息...${NC}"
                
                # 检查Docker相关服务
                if command -v powershell.exe &>/dev/null; then
                    echo -e "${BLUE}Docker服务状态:${NC}"
                    powershell.exe -Command "Get-Service *docker* | Select-Object Name, Status, StartType" || echo "无法获取服务信息"
                fi
                
                # 检查Docker Desktop安装情况
                if [ -f "/c/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
                    echo -e "${BLUE}Docker Desktop已安装在C盘${NC}"
                elif [ -f "/d/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
                    echo -e "${BLUE}Docker Desktop已安装在D盘${NC}"
                elif [ -f "/e/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
                    echo -e "${BLUE}Docker Desktop已安装在E盘${NC}"
                else
                    echo -e "${RED}找不到Docker Desktop安装文件${NC}"
                fi
                
                echo -e "\n${RED}无法自动启动Docker Desktop，请手动启动后重试${NC}"
                echo -e "${YELLOW}若首次安装Docker Desktop，可能需要完成初始设置${NC}"
                return 1
            fi
            
            return 0
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS环境
            echo -e "${BLUE}检测到macOS系统，尝试启动Docker...${NC}"
            open -a Docker
            
            # 等待Docker启动
            echo -e "${YELLOW}等待Docker启动 (最多60秒)...${NC}"
            for i in {1..30}; do
                sleep 2
                if docker info > /dev/null 2>&1; then
                    echo -e "${GREEN}Docker已成功启动!${NC}"
                    return 0
                fi
                echo -n "."
            done
            
            echo -e "\n${RED}等待Docker启动超时，请手动启动Docker后重试${NC}"
            return 1
        else
            # Linux环境
            echo -e "${BLUE}检测到Linux系统，尝试启动Docker服务...${NC}"
            sudo systemctl start docker
            
            # 等待Docker启动
            echo -e "${YELLOW}等待Docker启动 (最多30秒)...${NC}"
            for i in {1..15}; do
                sleep 2
                if docker info > /dev/null 2>&1; then
                    echo -e "${GREEN}Docker已成功启动!${NC}"
                    return 0
                fi
                echo -n "."
            done
            
            echo -e "\n${RED}Docker启动失败，请确保Docker已安装并手动启动后重试${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}Docker正在运行${NC}"
        return 0
    fi
}

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
    echo -e "\n${GREEN}开发环境命令: (默认)${NC}"
    echo "  start   - 启动开发环境"
    echo "  stop    - 停止开发环境"
    echo "  logs    - 查看日志 (可选: backend|frontend)"
    echo "  restart - 重启服务 (可选: backend|frontend)"
    echo "  rebuild - 重新构建服务 (可选: backend|frontend)"
    echo "  build   - 构建环境 (可选: backend|frontend)"
    echo "  shell   - 进入容器Shell (必选: backend|frontend)"
    echo -e "\n${GREEN}生产环境命令: (需要加 prod 前缀)${NC}"
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

# 设置默认的 compose 文件
COMPOSE_FILE=$DEV_COMPOSE_FILE
ENV_TYPE="开发环境"

# 确保Docker运行，如果启动Docker失败则退出
check_docker_running || exit 1

case "$1" in
  prod)
    COMPOSE_FILE=$PROD_COMPOSE_FILE
    ENV_TYPE="生产环境"
    if [ -z "$2" ]; then
        echo -e "${RED}错误: 请指定生产环境子命令${NC}"
        show_help
        exit 1
    fi
    validate_prod_subcommand "$2" || exit 1
    case "$2" in
      start)
        # 检查热重载脚本格式
        check_script_format "hot_reload.sh"
        
        echo -e "${YELLOW}启动${ENV_TYPE}...${NC}"
        docker compose -f $COMPOSE_FILE up -d
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${ENV_TYPE}服务已启动!${NC}"
        else
            echo -e "${RED}启动失败!${NC}"
            exit 1
        fi
        ;;
      stop)
        echo -e "${YELLOW}停止${ENV_TYPE}...${NC}"
        docker compose -f $COMPOSE_FILE down
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${ENV_TYPE}服务已停止!${NC}"
        else
            echo -e "${RED}停止失败!${NC}"
            exit 1
        fi
        ;;
      restart)
        validate_service "$3" || exit 1
        # 检查热重载脚本格式
        check_script_format "hot_reload.sh"
        
        if [ "$3" == "backend" ] || [ "$3" == "frontend" ]; then
          echo -e "${YELLOW}重启${ENV_TYPE}${3}服务...${NC}"
          docker compose -f $COMPOSE_FILE restart $3
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}${ENV_TYPE}${3}服务已重启!${NC}"
          else
              echo -e "${RED}重启失败!${NC}"
              exit 1
          fi
        else
          echo -e "${YELLOW}重启${ENV_TYPE}...${NC}"
          docker compose -f $COMPOSE_FILE down
          docker compose -f $COMPOSE_FILE up -d
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}${ENV_TYPE}已重启!${NC}"
          else
              echo -e "${RED}重启失败!${NC}"
              exit 1
          fi
        fi
        ;;
      rebuild)
        validate_service "$3" || exit 1
        # 检查热重载脚本格式
        check_script_format "hot_reload.sh"
        
        if [ "$3" == "backend" ] || [ "$3" == "frontend" ]; then
          echo -e "${YELLOW}重新构建${ENV_TYPE}${3}...${NC}"
          docker compose -f $COMPOSE_FILE build --no-cache $3
          docker compose -f $COMPOSE_FILE up -d --force-recreate $3
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}${ENV_TYPE}${3}已重新构建!${NC}"
          else
              echo -e "${RED}重建失败!${NC}"
              exit 1
          fi
        else
          echo -e "${YELLOW}重新构建${ENV_TYPE}...${NC}"
          docker compose -f $COMPOSE_FILE build --no-cache
          docker compose -f $COMPOSE_FILE up -d --force-recreate
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}${ENV_TYPE}已重新构建!${NC}"
          else
              echo -e "${RED}重建失败!${NC}"
              exit 1
          fi
        fi
        ;;
      logs)
        validate_service "$3" || exit 1
        if [ "$3" == "backend" ] || [ "$3" == "frontend" ]; then
          echo -e "${BLUE}显示${ENV_TYPE}${3}日志...${NC}"
          docker compose -f $COMPOSE_FILE logs -f $3
        else
          echo -e "${BLUE}显示${ENV_TYPE}所有日志...${NC}"
          docker compose -f $COMPOSE_FILE logs -f
        fi
        ;;
    esac
    ;;
    
  start|stop|logs|restart|rebuild|build|shell)
    case "$1" in
      start)
        echo -e "${YELLOW}启动${ENV_TYPE}...${NC}"
        docker compose -f $COMPOSE_FILE up -d
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${ENV_TYPE}服务已启动!${NC}"
            echo -e "${BLUE}后端服务: http://localhost:5000${NC}"
            echo -e "${BLUE}前端服务: http://localhost:3000${NC}"
        else
            echo -e "${RED}启动失败!${NC}"
            exit 1
        fi
        ;;
      stop)
        echo -e "${YELLOW}停止${ENV_TYPE}...${NC}"
        docker compose -f $COMPOSE_FILE down
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${ENV_TYPE}服务已停止!${NC}"
        else
            echo -e "${RED}停止失败!${NC}"
            exit 1
        fi
        ;;
      logs)
        validate_service "$2" || exit 1
        if [ "$2" == "backend" ] || [ "$2" == "frontend" ]; then
          echo -e "${BLUE}显示${ENV_TYPE}${2}日志...${NC}"
          docker compose -f $COMPOSE_FILE logs -f $2
        else
          echo -e "${BLUE}显示${ENV_TYPE}所有日志...${NC}"
          docker compose -f $COMPOSE_FILE logs -f
        fi
        ;;
      restart)
        validate_service "$2" || exit 1
        # 检查热重载脚本格式（开发环境不需要，但为了一致性也加上）
        if [ "$2" == "backend" ]; then
          check_script_format "hot_reload.sh"
        fi
        
        if [ "$2" == "backend" ] || [ "$2" == "frontend" ]; then
          echo -e "${YELLOW}重启${ENV_TYPE}${2}服务...${NC}"
          docker compose -f $COMPOSE_FILE restart $2
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}${ENV_TYPE}${2}服务已重启!${NC}"
          else
              echo -e "${RED}重启失败!${NC}"
              exit 1
          fi
        else
          echo -e "${YELLOW}重启${ENV_TYPE}...${NC}"
          docker compose -f $COMPOSE_FILE down
          # 检查热重载脚本格式
          check_script_format "hot_reload.sh"
          docker compose -f $COMPOSE_FILE up -d
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}${ENV_TYPE}已重启!${NC}"
          else
              echo -e "${RED}重启失败!${NC}"
              exit 1
          fi
        fi
        ;;
      rebuild)
        validate_service "$2" || exit 1
        # 检查热重载脚本格式
        if [ "$2" == "backend" ] || [ -z "$2" ]; then
          check_script_format "hot_reload.sh"
        fi
        
        if [ "$2" == "backend" ] || [ "$2" == "frontend" ]; then
          echo -e "${YELLOW}重新构建${ENV_TYPE}${2}...${NC}"
          docker compose -f $COMPOSE_FILE build --no-cache $2
          docker compose -f $COMPOSE_FILE up -d --force-recreate $2
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}${ENV_TYPE}${2}已重新构建!${NC}"
          else
              echo -e "${RED}重建失败!${NC}"
              exit 1
          fi
        else
          echo -e "${YELLOW}重新构建${ENV_TYPE}...${NC}"
          docker compose -f $COMPOSE_FILE build --no-cache
          docker compose -f $COMPOSE_FILE up -d --force-recreate
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}${ENV_TYPE}已重新构建!${NC}"
          else
              echo -e "${RED}重建失败!${NC}"
              exit 1
          fi
        fi
        ;;
      build)
        validate_service "$2" || exit 1
        # 检查热重载脚本格式
        if [ "$2" == "backend" ] || [ -z "$2" ]; then
          check_script_format "hot_reload.sh"
        fi
        
        if [ "$2" == "backend" ] || [ "$2" == "frontend" ]; then
          echo -e "${YELLOW}构建${ENV_TYPE}${2}...${NC}"
          docker compose -f $COMPOSE_FILE build $2
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}${ENV_TYPE}${2}已构建!${NC}"
          else
              echo -e "${RED}构建失败!${NC}"
              exit 1
          fi
        else
          echo -e "${YELLOW}构建${ENV_TYPE}...${NC}"
          docker compose -f $COMPOSE_FILE build
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}${ENV_TYPE}已构建!${NC}"
          else
              echo -e "${RED}构建失败!${NC}"
              exit 1
          fi
        fi
        ;;
      shell)
        if [ -z "$2" ]; then
            echo -e "${RED}错误: shell 命令需要指定服务名 (frontend 或 backend)${NC}"
            exit 1
        fi
        validate_service "$2" || exit 1
        if [ "$2" == "frontend" ]; then
          echo -e "${BLUE}进入前端容器Shell...${NC}"
          docker compose -f $COMPOSE_FILE exec frontend /bin/sh
        elif [ "$2" == "backend" ]; then
          echo -e "${BLUE}进入后端容器Shell...${NC}"
          docker compose -f $COMPOSE_FILE exec backend /bin/bash
        fi
        ;;
    esac
    ;;
  *)
    show_help
    ;;
esac 