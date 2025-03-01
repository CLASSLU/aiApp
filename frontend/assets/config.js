// 使用立即执行函数来避免全局变量污染
(function() {
    // API基础URL配置
    const getApiBaseUrl = () => {
        // 生产环境使用绝对路径（必须包含端口）
        return window.location.hostname === '113.45.251.116' 
            ? 'http://113.45.251.116:5000' 
            : 'http://localhost:5000';
    };

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
            credentials: 'include',  // 携带cookie
            mode: 'cors',           // 强制CORS模式
            headers: {
                'Content-Type': 'application/json',
                'X-Request-Source': 'webapp'
            }
        };
        
        try {
            const response = await fetch(API_BASE_URL + endpoint, {
                ...defaultOptions,
                ...options
            });
            
            // 检查CORS头
            if (!response.headers.get('access-control-allow-origin')) {
                console.warn('CORS头缺失，请检查服务器配置');
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