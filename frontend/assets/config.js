// 使用立即执行函数来避免全局变量污染
(function() {
    // API基础URL配置
    function getApiBaseUrl() {
        // 开发环境判断
        const isDev = window.location.hostname === 'localhost' || 
                     window.location.hostname === '127.0.0.1';
                     
        if (isDev) {
            // 开发环境使用本地后端
            return 'http://localhost:5000';
        }
        
        // 生产环境：使用相同的域名和端口
        // 因为前端和后端服务都暴露在同一个域名下
        return window.location.origin;
    }

    // 获取API基础URL
    const API_BASE_URL = getApiBaseUrl()+':5000';

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
        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
                'X-Requested-With': 'XMLHttpRequest'
            },
            credentials: 'same-origin'  // 同源请求
        };
        
        // 确保合并后的 headers 包含 Content-Type
        const mergedOptions = { 
            ...defaultOptions, 
            ...options,
            headers: {
                ...defaultOptions.headers,
                ...(options.headers || {})
            }
        };
        
        const url = API_BASE_URL + endpoint;
        
        try {
            const response = await fetch(url, mergedOptions);
            if (!response.ok) {
                throw new Error(`API请求失败: ${response.status}`);
            }
            return response;
        } catch (error) {
            console.error('API请求出错:', error);
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