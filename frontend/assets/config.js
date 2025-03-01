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
    const API_BASE_URL = getApiBaseUrl();

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
            credentials: 'include',  // 改为include以支持跨域请求
            mode: 'cors'  // 明确指定CORS模式
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
        
        // 确保 POST 请求带有正确的 Content-Type
        if (options.method === 'POST' && options.body) {
            mergedOptions.headers['Content-Type'] = 'application/json';
        }
        
        const url = API_BASE_URL + endpoint;
        
        console.log('发送请求到:', url);
        console.log('请求选项:', JSON.stringify(mergedOptions));
        console.log('请求头:', JSON.stringify(mergedOptions.headers));
        
        try {
            const response = await fetch(url, mergedOptions);
            if (!response.ok) {
                console.error(`API请求失败: ${response.status} ${response.statusText}`);
                const errorText = await response.text().catch(() => '无法获取错误详情');
                throw new Error(`API请求失败: ${response.status} - ${errorText}`);
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