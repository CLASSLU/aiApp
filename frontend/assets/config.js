// 使用立即执行函数来避免全局变量污染
(function() {
    // API基础URL配置
    const getApiBaseUrl = () => {
        // 获取当前主机名
        const hostname = window.location.hostname;
        const port = window.location.port;
        
        // 生产环境时自动适配
        if (hostname === '113.45.251.116') {
            // 使用相同的主机名但不同的端口
            return `http://${hostname}:5000`;
        } else if (hostname === 'localhost' || hostname === '127.0.0.1') {
            // 本地开发环境
            return 'http://localhost:5000';
        } else {
            // 其他情况下尝试使用相对路径，或者回退到当前主机的5000端口
            return port ? `http://${hostname}:5000` : '/api';
        }
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
        
        const defaultOptions = {
            credentials: 'include',  // 携带cookie
            mode: 'cors',           // 强制CORS模式
            headers: {
                'Content-Type': 'application/json',
                'X-Request-Source': 'webapp'
            }
        };
        
        try {
            const response = await fetch(url, {
                ...defaultOptions,
                ...options
            });
            
            // 检查响应状态
            if (!response.ok) {
                console.error('API响应错误:', response.status, response.statusText);
                const errorText = await response.text().catch(() => '无法读取错误详情');
                console.error('错误详情:', errorText);
                throw new Error(`API请求失败: ${response.status} ${response.statusText}`);
            }
            
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