#!/bin/bash

# 创建必要的目录
mkdir -p assets/lib/highlight/styles
mkdir -p assets/lib/highlight/languages
mkdir -p assets/lib/font-awesome/css
mkdir -p assets/lib/marked

# 下载 highlight.js 相关文件
wget -O assets/lib/highlight/styles/atom-one-dark.min.css https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.8.0/build/styles/atom-one-dark.min.css
wget -O assets/lib/highlight/highlight.min.js https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.8.0/build/highlight.min.js

# 下载 highlight.js 语言包
languages=("python" "javascript" "typescript" "json" "bash" "html" "css" "dockerfile" "yaml")
for lang in "${languages[@]}"; do
    wget -O assets/lib/highlight/languages/${lang}.min.js https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.8.0/build/languages/${lang}.min.js
done

# 下载 Font Awesome
wget -O assets/lib/font-awesome/css/all.min.css https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.1.0/css/all.min.css

# 下载 marked
wget -O assets/lib/marked/marked.min.js https://cdn.jsdelivr.net/npm/marked@4.0.0/marked.min.js

echo "所有依赖下载完成！" 