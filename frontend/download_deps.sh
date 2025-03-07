#!/bin/bash

# 设置错误处理
set -e
set -o pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[信息] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[警告] $1${NC}"
}

log_error() {
    echo -e "${RED}[错误] $1${NC}"
}

# 检查网络连接
check_network() {
    log_info "检查网络连接..."
    if ping -c 1 cdn.bootcdn.net > /dev/null 2>&1; then
        log_info "网络连接正常"
        return 0
    else
        log_warn "无法连接到 cdn.bootcdn.net，尝试使用备用CDN..."
        return 1
    fi
}

# 创建必要的目录
create_directories() {
    log_info "创建目录结构..."
    mkdir -p assets/lib/highlight/styles
    mkdir -p assets/lib/highlight/languages
    mkdir -p assets/lib/font-awesome/{css,webfonts}
    mkdir -p assets/lib/marked
}

# 定义下载函数
download_with_retry() {
    local url="$1"
    local output="$2"
    local backup_url="$3"
    local retries=3
    local wait=5
    local count=0
    
    log_info "下载 $output ..."
    
    # 确保输出目录存在
    mkdir -p $(dirname "$output")
    
    while [ $count -lt $retries ]; do
        if wget $WGET_OPTS -q --show-progress --timeout=30 -O "$output.tmp" "$url"; then
            mv "$output.tmp" "$output"
            log_info "成功下载: $output"
            return 0
        fi
        
        count=$((count + 1))
        if [ -n "$backup_url" ] && [ $count -eq 2 ]; then
            log_warn "主CDN下载失败，尝试备用CDN..."
            url="$backup_url"
        fi
        
        if [ $count -lt $retries ]; then
            log_warn "下载失败，${wait}秒后重试 ($count/$retries)..."
            sleep $wait
        fi
    done
    
    log_error "下载失败: $url"
    return 1
}

# 主要下载逻辑
main() {
    log_info "开始下载依赖..."
    
    create_directories
    check_network
    
    # 使用国内CDN镜像，提供备用链接
    log_info "下载 highlight.js 文件..."
    download_with_retry \
        "https://cdn.bootcdn.net/ajax/libs/highlight.js/11.8.0/styles/atom-one-dark.min.css" \
        "assets/lib/highlight/styles/atom-one-dark.min.css" \
        "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/styles/atom-one-dark.min.css"
        
    download_with_retry \
        "https://cdn.bootcdn.net/ajax/libs/highlight.js/11.8.0/highlight.min.js" \
        "assets/lib/highlight/highlight.min.js" \
        "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/highlight.min.js"

    # 下载 highlight.js 语言包
    log_info "下载 highlight.js 语言包..."
    languages=("python" "javascript" "typescript" "json" "bash" "html" "css" "dockerfile" "yaml")
    for lang in "${languages[@]}"; do
        download_with_retry \
            "https://cdn.bootcdn.net/ajax/libs/highlight.js/11.8.0/languages/${lang}.min.js" \
            "assets/lib/highlight/languages/${lang}.min.js" \
            "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/languages/${lang}.min.js"
    done

    # 下载 Font Awesome
    log_info "下载 Font Awesome 文件..."
    download_with_retry \
        "https://cdn.bootcdn.net/ajax/libs/font-awesome/6.1.0/css/all.min.css" \
        "assets/lib/font-awesome/css/all.min.css" \
        "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.1.0/css/all.min.css"

    # 下载 Font Awesome 字体文件
    log_info "下载 Font Awesome 字体文件..."
    webfonts=("fa-solid-900.woff2" "fa-regular-400.woff2" "fa-brands-400.woff2")
    for font in "${webfonts[@]}"; do
        download_with_retry \
            "https://cdn.bootcdn.net/ajax/libs/font-awesome/6.1.0/webfonts/${font}" \
            "assets/lib/font-awesome/webfonts/${font}" \
            "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.1.0/webfonts/${font}"
    done

    # 下载 marked
    log_info "下载 marked.js..."
    download_with_retry \
        "https://cdn.bootcdn.net/ajax/libs/marked/4.0.0/marked.min.js" \
        "assets/lib/marked/marked.min.js" \
        "https://cdnjs.cloudflare.com/ajax/libs/marked/4.0.0/marked.min.js"

    # 设置文件权限
    log_info "设置文件权限..."
    chmod -R 755 assets/lib

    # 验证文件完整性
    log_info "验证文件完整性..."
    files_to_check=(
        "assets/lib/highlight/styles/atom-one-dark.min.css"
        "assets/lib/highlight/highlight.min.js"
        "assets/lib/font-awesome/css/all.min.css"
        "assets/lib/marked/marked.min.js"
    )

    for file in "${files_to_check[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "文件不存在: $file"
            exit 1
        fi
        if [ ! -s "$file" ]; then
            log_error "文件为空: $file"
            exit 1
        fi
        log_info "文件验证通过: $file"
    done

    log_info "所有依赖下载完成！"
}

# 执行主函数
main "$@" 