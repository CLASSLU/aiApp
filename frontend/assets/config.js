// 使用立即执行函数来避免全局变量污染
(function() {
    // API基础URL配置
    const getApiBaseUrl = () => {
        // 获取当前主机名和端口
        const hostname = window.location.hostname;
        
        // 直接使用当前主机的API路径，通过nginx反向代理
        return '';  // 空字符串表示相对路径，这样API请求会发送到同一域名下
    };

    // 获取API基础URL
    const API_BASE_URL = getApiBaseUrl();
    console.log('当前API基础URL:', API_BASE_URL); // 调试信息

    // API端点配置
    const endpoints = {
        chat: '/api/chat',
        models: '/api/models',
        generate: '/api/generate',
        download: '/api/download',
        stop: '/api/stop'
    };

    // 统一的API请求函数
    async function fetchApi(endpoint, options = {}) {
        const url = API_BASE_URL + endpoint;
        console.log('发起API请求:', url); // 调试信息
        
        // 构建完整的选项
        const defaultOptions = {
            credentials: 'include',  // 携带cookie
            headers: {
                'Content-Type': 'application/json',
                'X-Request-Source': 'webapp'
            }
        };
        
        // 组合选项
        const finalOptions = {
            ...defaultOptions,
            ...options
        };
        
        try {
            // 发送请求
            const response = await fetch(url, finalOptions);
            
            // 检查响应状态
            if (!response.ok) {
                console.error('API响应错误:', response.status, response.statusText);
                const errorText = await response.text().catch(() => '无法读取错误详情');
                console.error('错误详情:', errorText);
                throw new Error(`API请求失败: ${response.status} ${response.statusText}`);
            }
            
            return response;
        } catch (error) {
            console.error('API请求失败:', error);
            throw error;
        }
    }

    // 导出全局配置
    window.APP_CONFIG = {
        API_BASE_URL,
        endpoints,
        fetchApi
    };
})(); 