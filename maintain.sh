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
    echo "  -rb, --rebuild     重建所有容器"
    echo "  -d, --debug-api    调试API 500错误"
    echo ""
    echo "示例："
    echo "  $0 --all           执行完整维护流程"
    echo "  $0 --pull          仅拉取代码并修复权限"
    echo "  $0 --restart       仅重启服务"
    echo "  $0 --status        仅检查状态"
    echo "  $0 --fix-nginx     修复Nginx端口冲突"
    echo "  $0 --rebuild       重建所有容器"
    echo "  $0 --debug-api     调试API错误"
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
    fi

    log_success "Nginx端口冲突修复完成！"
}

# 重建所有容器
rebuild_containers() {
    log_info "开始重建Docker容器..."

    # 停止所有容器
    log_info "停止所有容器..."
    docker-compose down

    # 重新构建容器
    log_info "重新构建容器..."
    docker-compose build

    # 启动容器
    log_info "启动容器..."
    docker-compose up -d

    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10

    # 检查容器状态
    log_info "检查容器状态..."
    docker-compose ps

    # 检查Nginx状态
    log_info "检查Nginx状态..."
    docker exec frontend nginx -t

    # 测试API连接
    log_info "测试从前端容器连接后端API..."
    docker exec frontend curl -s http://backend:5000/api/models | head -n 30

    # 测试主机访问
    log_info "测试从主机通过Nginx代理访问API..."
    curl -s http://localhost/api/models | head -n 10

    log_success "容器重建完成！"
    log_info "请在浏览器中测试应用，确认API请求正常。"
    log_info "如果问题仍然存在，请检查Docker日志:"
    log_info "  前端日志: docker logs frontend"
    log_info "  后端日志: docker logs backend"
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

# 执行所有操作
do_all() {
    pull_latest_code
    restart_services
    check_status
}

# 主逻辑
main() {
    # 如果没有参数，显示帮助信息
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
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
            -rb | --rebuild)
                rebuild_containers
                ;;
            -d | --debug-api)
                debug_api
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