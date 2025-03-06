#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[信息] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[成功] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[警告] $1${NC}"
}

log_error() {
    echo -e "${RED}[错误] $1${NC}"
}

# 检查命令是否成功执行
check_result() {
    if [ $? -ne 0 ]; then
        log_error "$1"
        if [ "$2" == "exit" ]; then
            exit 1
        fi
    else
        log_success "$3"
    fi
}

# 显示帮助信息
show_help() {
    echo -e "${YELLOW}项目维护脚本${NC}"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help         显示此帮助信息"
    echo "  -p, --pull         拉取最新代码并更新"
    echo "  -r, --restart      重启服务"
    echo "  -s, --status       检查服务状态"
    echo "  -a, --all          执行所有操作（拉取、更新权限、重启、检查状态）"
    echo "  -f, --fix-perms    仅修复文件权限"
    echo "  -n, --fix-nginx    修复Nginx端口冲突问题"
    echo "  -nc, --nginx-config 检查Nginx配置并验证API代理"
    echo "  -rb, --rebuild     重建所有容器"
    echo "  -d, --debug-api    调试API 500错误"
    echo "  -l, --logs [类型]   查看详细日志（类型：backend|frontend|api|error|all）"
    echo ""
    echo "示例："
    echo "  $0 --all           执行完整维护流程"
    echo "  $0 --pull          仅拉取代码并修复权限"
    echo "  $0 --restart       仅重启服务"
    echo "  $0 --status        仅检查状态"
    echo "  $0 --fix-nginx     修复Nginx端口冲突"
    echo "  $0 --nginx-config  检查Nginx配置"
    echo "  $0 --rebuild       重建所有容器"
    echo "  $0 --debug-api     调试API错误"
    echo "  $0 --logs backend  查看后端完整日志"
    echo "  $0 --logs api      查看API详细日志"
    echo "  $0 --logs error    查看错误日志"
}

# 拉取最新代码
pull_latest_code() {
    log_info "拉取最新代码..."
    git pull
    check_result "代码拉取失败" "continue" "代码拉取成功"
    
    fix_permissions
}

# 修复文件权限
fix_permissions() {
    log_info "修复脚本文件权限..."
    
    # 为所有.sh文件添加执行权限
    find . -name "*.sh" -exec chmod +x {} \;
    check_result "修复.sh文件权限失败" "continue" "修复.sh文件权限成功"
    
    # 为特定目录添加适当权限
    if [ -d "./src" ]; then
        chmod -R 755 ./src
    fi
    
    if [ -d "./frontend" ]; then
        chmod -R 755 ./frontend
    fi
    
    log_success "所有文件权限修复完成"
}

# 重启服务
restart_services() {
    log_info "重启服务..."
    
    # 检查dev.sh脚本是否存在
    if [ -f "./dev.sh" ]; then
        log_info "使用dev.sh脚本重启服务..."
        ./dev.sh prod restart backend
        check_result "后端服务重启失败" "continue" "后端服务重启成功"
        
        ./dev.sh prod restart frontend
        check_result "前端服务重启失败" "continue" "前端服务重启成功"
    else
        # 使用docker-compose命令重启
        log_info "使用docker-compose重启服务..."
        docker-compose restart
        check_result "服务重启失败" "continue" "服务重启成功"
    fi
    
    # 等待服务启动
    log_info "等待服务启动完成..."
    sleep 5
}

# 检查服务状态
check_status() {
    log_info "检查服务状态..."
    
    # 检查Docker容器状态
    log_info "检查Docker容器状态:"
    docker ps
    
    # 检查前端Nginx配置
    log_info "验证Nginx配置..."
    docker exec frontend nginx -t 2>&1
    
    # 检查前端到后端的连接
    log_info "测试前端容器到后端API的连接..."
    docker exec frontend curl -s http://backend:5000/api/models -o /dev/null
    if [ $? -eq 0 ]; then
        log_success "前端容器可以成功连接到后端API"
    else
        log_error "前端容器无法连接到后端API，请检查网络配置"
    fi
    
    # 检查从主机访问前端
    log_info "测试从主机访问前端服务..."
    curl -s -I http://localhost/ | head -n 1
    if [ $? -eq 0 ]; then
        log_success "可以从主机访问前端服务"
    else
        log_error "无法从主机访问前端服务，请检查80端口映射"
    fi
    
    # 检查从主机通过前端代理访问后端API
    log_info "测试从主机通过前端代理访问后端API..."
    curl -s http://localhost/api/models -o /dev/null
    if [ $? -eq 0 ]; then
        log_success "可以从主机通过前端代理访问后端API"
    else
        log_error "无法从主机通过前端代理访问后端API，请检查Nginx代理配置"
    fi
    
    # 检查日志
    log_info "获取容器最新日志..."
    echo -e "\n${YELLOW}前端容器最新日志:${NC}"
    docker logs --tail 10 frontend
    
    echo -e "\n${YELLOW}后端容器最新日志:${NC}"
    docker logs --tail 10 backend
}

# 修复Nginx端口冲突问题
fix_nginx_conflict() {
    log_info "开始修复Nginx端口冲突问题..."

    # 1. 检查端口占用情况
    log_info "检查80端口占用情况..."
    NET_TOOLS_INSTALLED=$(command -v netstat > /dev/null && echo "yes" || echo "no")

    if [ "$NET_TOOLS_INSTALLED" = "yes" ]; then
        OCCUPIED_BY=$(netstat -tulpn | grep ":80 " | awk '{print $7}' | cut -d'/' -f1)
        if [ -n "$OCCUPIED_BY" ]; then
            log_warning "80端口被进程ID: $OCCUPIED_BY 占用"
        else
            log_success "80端口未被占用"
        fi
    else
        log_warning "未安装netstat工具，无法检查端口占用"
    fi

    # 2. 检查Docker端口映射
    log_info "检查Docker端口映射..."
    docker ps | grep -E '80->|->80' || echo "没有找到映射到80端口的容器"

    # 3. 停止并删除前端容器
    log_info "尝试停止前端容器..."
    docker stop frontend
    docker rm frontend

    # 4. 检查并结束宿主机上占用80端口的进程
    log_info "尝试结束占用80端口的进程..."
    if [ "$NET_TOOLS_INSTALLED" = "yes" ]; then
        OCCUPIED_BY=$(netstat -tulpn | grep ":80 " | awk '{print $7}' | cut -d'/' -f1)
        if [ -n "$OCCUPIED_BY" ]; then
            log_warning "尝试结束进程ID: $OCCUPIED_BY"
            kill -15 $OCCUPIED_BY
            sleep 2
            # 如果进程仍然存在，强制结束
            if kill -0 $OCCUPIED_BY 2>/dev/null; then
                log_warning "进程仍在运行，尝试强制结束..."
                kill -9 $OCCUPIED_BY
            fi
        fi
    fi

    # 5. 重新启动前端容器
    log_info "重新启动前端容器..."
    if [ -f "./dev.sh" ]; then
        ./dev.sh prod up frontend -d
    else
        docker-compose up -d frontend
    fi

    # 6. 等待服务启动
    log_info "等待服务启动..."
    sleep 5

    # 7. 验证前端服务
    log_info "验证前端服务..."
    curl -s -I http://localhost/ | head -n 1
    if [ $? -eq 0 ]; then
        log_success "前端服务已恢复"
    else
        log_error "前端服务未正常运行"
    fi

    # 8. 验证API代理
    log_info "验证API代理..."
    curl -s http://localhost/api/models -o /dev/null
    if [ $? -eq 0 ]; then
        log_success "API代理已正常工作"
    else
        log_error "API代理未正常工作"
        
        # 显示nginx配置和错误日志
        log_info "检查Nginx配置..."
        docker exec frontend nginx -t
        
        log_info "查看Nginx错误日志..."
        docker exec frontend cat /var/log/nginx/error.log | tail -n 20
        
        # 添加对Nginx配置的更深入检查
        log_info "检查Nginx API代理配置..."
        docker exec frontend cat /etc/nginx/conf.d/default.conf | grep -A 10 "location /api" || echo "未找到API代理配置"
        
        # 添加测试API可用性的直接检查
        log_info "直接测试后端API可用性..."
        curl -s http://backend:5000/api/models > /dev/null
        if [ $? -eq 0 ]; then
            log_success "后端API可用，问题可能在Nginx配置"
        else
            log_error "后端API不可用，请检查后端服务"
        fi
    fi

    log_success "Nginx端口冲突修复完成！"
}

# 添加新函数：检查Nginx配置
check_nginx_config() {
    log_info "开始检查Nginx配置..."
    
    # 检查frontend容器是否存在
    if ! docker ps | grep -q frontend; then
        log_error "前端容器不存在或未运行"
        return 1
    fi
    
    # 检查Nginx配置语法
    log_info "检查Nginx配置语法..."
    docker exec frontend nginx -t
    check_result "Nginx配置语法检查失败" "continue" "Nginx配置语法正确"
    
    # 检查API代理配置
    log_info "检查API代理配置..."
    if docker exec frontend cat /etc/nginx/conf.d/default.conf | grep -q "location /api"; then
        log_success "找到API代理配置"
        docker exec frontend cat /etc/nginx/conf.d/default.conf | grep -A 10 "location /api"
    else
        log_error "没有找到API代理配置，这可能导致API请求失败"
        
        # 提供修复建议
        log_info "建议在Nginx配置中添加以下API代理设置:"
        echo '
location /api {
    proxy_pass http://backend:5000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 90;
    proxy_connect_timeout 90;
}
'
    fi
    
    # 检查静态文件配置
    log_info "检查静态文件配置..."
    if docker exec frontend cat /etc/nginx/conf.d/default.conf | grep -q "location /static"; then
        log_success "找到静态文件配置"
        docker exec frontend cat /etc/nginx/conf.d/default.conf | grep -A 5 "location /static"
    else
        log_warning "没有找到明确的静态文件配置，可能使用了默认配置"
    fi
    
    # 检查环境变量
    log_info "检查前端容器环境变量..."
    docker exec frontend env | grep -i api
    
    # 检查网络连接
    log_info "检查前端到后端的网络连接..."
    if docker exec frontend ping -c 2 backend &>/dev/null; then
        log_success "前端可以通过主机名'backend'连接到后端"
    else
        log_error "前端无法通过主机名'backend'连接到后端"
        log_info "检查Docker网络配置..."
        docker network ls
        log_info "检查容器IP地址..."
        docker inspect -f '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -q)
    fi
    
    # 测试API连接
    log_info "从前端容器测试后端API..."
    if docker exec frontend curl -s http://backend:5000/api/models > /dev/null; then
        log_success "从前端容器可以访问后端API"
    else
        log_error "从前端容器无法访问后端API"
        # 尝试使用IP直接访问
        BACKEND_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' backend)
        log_info "尝试直接通过IP访问后端: ${BACKEND_IP}..."
        if [ -n "$BACKEND_IP" ]; then
            if docker exec frontend curl -s http://${BACKEND_IP}:5000/api/models > /dev/null; then
                log_success "通过IP地址可以访问后端API，请检查Docker网络配置"
            else
                log_error "即使通过IP也无法访问后端API，请检查后端服务是否正常运行"
            fi
        fi
    fi
    
    # 检查日志
    log_info "检查Nginx错误日志..."
    docker exec frontend cat /var/log/nginx/error.log | tail -n 20
    
    # 检查后端状态
    log_info "检查后端API状态..."
    if docker ps | grep -q backend; then
        log_success "后端容器正在运行"
        # 检查后端日志
        log_info "查看后端最近日志..."
        docker logs --tail 20 backend
    else
        log_error "后端容器未运行"
    fi
    
    log_info "Nginx配置检查完成"
}

# 重建所有容器
rebuild_services() {
    log_info "开始重建所有容器..."
    
    # 停止并删除所有容器
    log_info "停止并删除现有容器..."
    docker-compose down
    check_result "停止容器失败" "continue" "停止容器成功"
    
    # 删除所有相关镜像
    log_info "删除旧镜像..."
    docker images | grep "aiapp" | awk '{print $3}' | xargs -r docker rmi -f
    
    # 处理前端依赖
    log_info "处理前端依赖..."
    cd frontend
    chmod +x download_deps.sh
    ./download_deps.sh
    cd ..
    check_result "前端依赖处理失败" "continue" "前端依赖处理成功"
    
    # 强制重新构建
    log_info "强制重新构建所有容器..."
    docker-compose build --no-cache
    check_result "构建容器失败" "continue" "构建容器成功"
    
    # 启动服务
    log_info "启动新构建的容器..."
    docker-compose up -d
    check_result "启动容器失败" "continue" "启动容器成功"
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    check_status
}

# 调试API错误
debug_api() {
    log_info "开始调试API 500错误..."

    # 获取详细后端日志
    log_info "检查详细后端日志..."
    docker logs backend --tail 50
    
    # 检查后端Flask应用运行状态
    log_info "检查后端进程..."
    docker exec backend ps aux
    
    # 检查环境变量
    log_info "检查后端环境变量..."
    docker exec backend env | grep -E 'FLASK|PYTHON|PATH|API'
    
    # 直接测试后端API
    log_info "直接测试后端API..."
    echo "从后端容器内部测试:"
    docker exec backend curl -sv http://localhost:5000/api/models
    
    echo -e "\n从主机直接测试后端:"
    curl -sv http://localhost:5000/api/models
    
    # 检查API路由和配置
    log_info "检查API路由..."
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
    log_info "测试常见依赖项..."
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

    # 尝试启用更详细的后端日志
    log_info "启用详细的Flask调试信息..."
    docker exec backend bash -c "export FLASK_DEBUG=1 && export LOG_LEVEL=DEBUG"
    
    # 检查后端日志文件
    log_info "检查后端日志文件..."
    docker exec backend ls -la /app/logs 2>/dev/null || echo "无日志目录"
    docker exec backend find /app -name "*.log" 2>/dev/null || echo "未找到日志文件"
    
    log_success "API调试完成！"
    log_info "请检查上面的日志，特别关注以下内容:"
    log_info "1. 后端应用错误日志"
    log_info "2. API路由是否正确注册"
    log_info "3. 依赖项是否都已正确安装"
    log_info "4. 环境变量是否正确设置"
    log_info ""
    log_info "常见解决方法:"
    log_info "1. 检查数据库连接"
    log_info "2. 检查API密钥或配置文件"
    log_info "3. 重启后端服务：./maintain.sh --restart"
}

# 查看详细日志功能
view_logs() {
    local log_type="$1"
    
    if [ -z "$log_type" ]; then
        log_error "请指定要查看的日志类型: backend, frontend, api, error, all"
        return 1
    fi
    
    case "$log_type" in
        "backend")
            log_info "查看后端服务日志..."
            docker exec backend tail -n 100 /app/logs/app.log
            ;;
        "frontend")
            log_info "查看前端服务日志..."
            docker logs -n 100 frontend
            ;;
        "api")
            log_info "查看API请求日志..."
            docker exec backend tail -n 100 /app/logs/api.log
            ;;
        "error")
            log_info "查看错误日志..."
            docker exec backend tail -n 100 /app/logs/error.log
            ;;
        "all")
            log_info "查看所有重要日志..."
            log_info "=== 后端错误日志 ==="
            docker exec backend tail -n 50 /app/logs/error.log
            echo ""
            log_info "=== API请求日志 ==="
            docker exec backend tail -n 50 /app/logs/api.log
            echo ""
            log_info "=== 应用程序日志 ==="
            docker exec backend tail -n 50 /app/logs/app.log
            ;;
        *)
            log_error "未知的日志类型: $log_type"
            log_info "可用的日志类型: backend, frontend, api, error, all"
            return 1
            ;;
    esac
    
    return 0
}

# 执行所有操作
do_all() {
    pull_latest_code
    restart_services
    check_status
}

# 检查Docker是否运行
check_docker_running() {
    log_info "检查Docker是否正在运行..."
    
    # 尝试执行一个简单的Docker命令来测试Docker是否运行
    if ! docker info > /dev/null 2>&1; then
        log_warning "Docker未运行，尝试启动Docker..."
        
        # 检测操作系统类型
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
            # Windows环境
            log_info "检测到Windows系统，尝试启动Docker Desktop..."
            
            # 使用多种方法尝试启动Docker Desktop
            STARTED=false
            
            # 方法1: 使用开始菜单中的快捷方式(以管理员权限)
            log_info "方法1: 尝试通过快捷方式启动Docker Desktop..."
            if command -v powershell.exe &>/dev/null; then
                powershell.exe -Command "Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe' -Verb RunAs" &
                sleep 5
                
                if docker info > /dev/null 2>&1; then
                    log_success "Docker已通过方法1成功启动!"
                    STARTED=true
                else
                    log_warning "方法1未能启动Docker, 尝试方法2..."
                fi
            fi
            
            # 方法2: 尝试启动Docker服务
            if [ "$STARTED" = false ] && command -v powershell.exe &>/dev/null; then
                log_info "方法2: 尝试启动Docker服务..."
                # 以管理员权限启动Docker服务
                powershell.exe -Command "Start-Process powershell -ArgumentList '-Command Get-Service *docker* | Start-Service' -Verb RunAs" &
                sleep 10
                
                if docker info > /dev/null 2>&1; then
                    log_success "Docker已通过方法2成功启动!"
                    STARTED=true
                else
                    log_warning "方法2未能启动Docker, 尝试方法3..."
                fi
            fi
            
            # 方法3: 使用cmd.exe直接启动应用程序
            if [ "$STARTED" = false ] && command -v cmd.exe &>/dev/null; then
                log_info "方法3: 尝试用CMD启动Docker Desktop..."
                cmd.exe /c "start \"\" \"C:\Program Files\Docker\Docker\Docker Desktop.exe\"" &
                sleep 5
                
                if docker info > /dev/null 2>&1; then
                    log_success "Docker已通过方法3成功启动!"
                    STARTED=true
                else
                    log_warning "方法3未能启动Docker, 尝试方法4..."
                fi
            fi
            
            # 方法4: 尝试使用WindowsApps直接启动
            if [ "$STARTED" = false ]; then
                log_info "方法4: 尝试通过Windows应用启动器启动Docker..."
                powershell.exe -Command "Start-Process shell:AppsFolder\Docker.DockerDesktop" &
                sleep 5
                
                if docker info > /dev/null 2>&1; then
                    log_success "Docker已通过方法4成功启动!"
                    STARTED=true
                else
                    log_warning "方法4未能启动Docker..."
                fi
            fi
            
            # 如果上述方法都没有立即启动Docker，等待一段时间看是否启动
            if [ "$STARTED" = false ]; then
                log_warning "正在等待Docker启动 (最多90秒)..."
                for i in {1..45}; do
                    sleep 2
                    if docker info > /dev/null 2>&1; then
                        log_success "Docker已成功启动!"
                        return 0
                    fi
                    echo -n "."
                done
                
                # 尝试显示一些诊断信息
                echo ""
                log_warning "收集Docker诊断信息..."
                
                # 检查Docker相关服务
                if command -v powershell.exe &>/dev/null; then
                    log_info "Docker服务状态:"
                    powershell.exe -Command "Get-Service *docker* | Select-Object Name, Status, StartType" || echo "无法获取服务信息"
                fi
                
                # 检查Docker Desktop安装情况
                if [ -f "/c/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
                    log_info "Docker Desktop已安装在C盘"
                elif [ -f "/d/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
                    log_info "Docker Desktop已安装在D盘"
                elif [ -f "/e/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
                    log_info "Docker Desktop已安装在E盘"
                else
                    log_error "找不到Docker Desktop安装文件"
                fi
                
                log_error "无法自动启动Docker Desktop，请手动启动后重试"
                log_warning "若首次安装Docker Desktop，可能需要完成初始设置"
                return 1
            fi
            
            return 0
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS环境
            log_info "检测到macOS系统，尝试启动Docker..."
            open -a Docker 2>/dev/null
            
            # 等待Docker启动
            log_warning "等待Docker启动 (最多60秒)..."
            for i in {1..30}; do
                sleep 2
                if docker info > /dev/null 2>&1; then
                    log_success "Docker已成功启动!"
                    return 0
                fi
                echo -n "."
            done
            
            echo ""
            log_error "等待Docker启动超时，请手动启动Docker后重试"
            return 1
        else
            # Linux环境
            log_info "检测到Linux系统，尝试启动Docker服务..."
            sudo systemctl start docker
            
            # 等待Docker启动
            log_warning "等待Docker启动 (最多30秒)..."
            for i in {1..15}; do
                sleep 2
                if docker info > /dev/null 2>&1; then
                    log_success "Docker已成功启动!"
                    return 0
                fi
                echo -n "."
            done
            
            echo ""
            log_error "Docker启动失败，请确保Docker已安装并手动启动后重试"
            return 1
        fi
    else
        log_success "Docker正在运行"
        return 0
    fi
}

# 主逻辑
main() {
    # 如果没有参数，显示帮助信息
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    # 检查Docker是否运行
    check_docker_running || exit 1
    
    # 解析命令行参数
    while [ "$1" != "" ]; do
        case $1 in
            -h | --help)
                show_help
                exit 0
                ;;
            -p | --pull)
                pull_latest_code
                ;;
            -r | --restart)
                restart_services
                ;;
            -s | --status)
                check_status
                ;;
            -a | --all)
                do_all
                ;;
            -f | --fix-perms)
                fix_permissions
                ;;
            -n | --fix-nginx)
                fix_nginx_conflict
                ;;
            -nc | --nginx-config)
                check_nginx_config
                ;;
            -rb | --rebuild)
                rebuild_services
                ;;
            -d | --debug-api)
                debug_api
                ;;
            -l | --logs)
                if [ -n "$2" ] && [[ "$2" != -* ]]; then
                    view_logs "$2"
                    shift
                else
                    log_error "缺少日志类型参数"
                    show_help
                    exit 1
                fi
                ;;
            *)
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# 执行主逻辑
main "$@" 