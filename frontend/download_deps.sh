#!/bin/bash

# 设置错误处理
set -e
echo "开始下载依赖..."

# 创建必要的目录
mkdir -p assets/lib/highlight/styles
mkdir -p assets/lib/highlight/languages
mkdir -p assets/lib/font-awesome/{css,webfonts}
mkdir -p assets/lib/marked

# 下载 highlight.js 相关文件
echo "下载 highlight.js 文件..."
wget -q --show-progress -O assets/lib/highlight/styles/atom-one-dark.min.css https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.8.0/build/styles/atom-one-dark.min.css
wget -q --show-progress -O assets/lib/highlight/highlight.min.js https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.8.0/build/highlight.min.js

# 下载 highlight.js 语言包
echo "下载 highlight.js 语言包..."
languages=("python" "javascript" "typescript" "json" "bash" "html" "css" "dockerfile" "yaml")
for lang in "${languages[@]}"; do
    echo "下载 ${lang} 语言包..."
    wget -q --show-progress -O assets/lib/highlight/languages/${lang}.min.js https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.8.0/build/languages/${lang}.min.js
done

# 下载 Font Awesome
echo "下载 Font Awesome 文件..."
wget -q --show-progress -O assets/lib/font-awesome/css/all.min.css https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.1.0/css/all.min.css

# 下载 Font Awesome 字体文件
echo "下载 Font Awesome 字体文件..."
webfonts=("fa-solid-900.woff2" "fa-regular-400.woff2" "fa-brands-400.woff2")
for font in "${webfonts[@]}"; do
    echo "下载 ${font}..."
    wget -q --show-progress -O assets/lib/font-awesome/webfonts/${font} https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.1.0/webfonts/${font}
done

# 下载 marked
echo "下载 marked.js..."
wget -q --show-progress -O assets/lib/marked/marked.min.js https://cdn.jsdelivr.net/npm/marked@4.0.0/marked.min.js

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