#!/bin/bash

# 设置错误处理
set -e
echo "开始下载依赖..."

# 创建必要的目录
mkdir -p assets/lib/highlight/styles
mkdir -p assets/lib/highlight/languages
mkdir -p assets/lib/font-awesome/{css,webfonts}
mkdir -p assets/lib/marked

# 定义下载函数
download_with_retry() {
    local url="$1"
    local output="$2"
    local retries=3
    local wait=5
    local count=0
    
    echo "下载 $output ..."
    while [ $count -lt $retries ]; do
        if wget -q --show-progress --timeout=10 -O "$output.tmp" "$url"; then
            mv "$output.tmp" "$output"
            return 0
        fi
        
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            echo "下载失败，${wait}秒后重试 ($count/$retries)..."
            sleep $wait
        fi
    done
    
    echo "下载失败: $url"
    return 1
}

# 使用国内CDN镜像
echo "下载 highlight.js 文件..."
download_with_retry "https://cdn.bootcdn.net/ajax/libs/highlight.js/11.8.0/styles/atom-one-dark.min.css" "assets/lib/highlight/styles/atom-one-dark.min.css"
download_with_retry "https://cdn.bootcdn.net/ajax/libs/highlight.js/11.8.0/highlight.min.js" "assets/lib/highlight/highlight.min.js"

# 下载 highlight.js 语言包
echo "下载 highlight.js 语言包..."
languages=("python" "javascript" "typescript" "json" "bash" "html" "css" "dockerfile" "yaml")
for lang in "${languages[@]}"; do
    echo "下载 ${lang} 语言包..."
    download_with_retry "https://cdn.bootcdn.net/ajax/libs/highlight.js/11.8.0/languages/${lang}.min.js" "assets/lib/highlight/languages/${lang}.min.js"
done

# 下载 Font Awesome（使用国内CDN）
echo "下载 Font Awesome 文件..."
download_with_retry "https://cdn.bootcdn.net/ajax/libs/font-awesome/6.1.0/css/all.min.css" "assets/lib/font-awesome/css/all.min.css"

# 下载 Font Awesome 字体文件
echo "下载 Font Awesome 字体文件..."
webfonts=("fa-solid-900.woff2" "fa-regular-400.woff2" "fa-brands-400.woff2")
for font in "${webfonts[@]}"; do
    echo "下载 ${font}..."
    download_with_retry "https://cdn.bootcdn.net/ajax/libs/font-awesome/6.1.0/webfonts/${font}" "assets/lib/font-awesome/webfonts/${font}"
done

# 下载 marked（使用国内CDN）
echo "下载 marked.js..."
download_with_retry "https://cdn.bootcdn.net/ajax/libs/marked/4.0.0/marked.min.js" "assets/lib/marked/marked.min.js"

# 设置文件权限
echo "设置文件权限..."
chmod -R 755 assets/lib

echo "所有依赖下载完成！"

# 验证文件是否存在
echo "验证文件完整性..."
files_to_check=(
    "assets/lib/highlight/styles/atom-one-dark.min.css"
    "assets/lib/highlight/highlight.min.js"
    "assets/lib/font-awesome/css/all.min.css"
    "assets/lib/marked/marked.min.js"
)

for file in "${files_to_check[@]}"; do
    if [ ! -f "$file" ]; then
        echo "错误: 文件 $file 不存在!"
        exit 1
    fi
done

echo "文件完整性验证通过！" 