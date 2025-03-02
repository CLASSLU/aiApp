// 使用立即执行函数来避免全局变量污染
(function() {
    // API基础URL配置
    const getApiBaseUrl = () => {
        // 获取当前主机名和端口
        const hostname = window.location.hostname;
        const protocol = window.location.protocol;
        
        // 获取当前域名和端口
        const currentUrl = `${protocol}//${hostname}${window.location.port ? ':' + window.location.port : ''}`;
        
        console.log('当前访问地址:', currentUrl);
        
        // 使用相对路径，通过nginx代理访问API
        return '';
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
            // 添加请求超时处理
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 30000); // 30秒超时
            
            if (!finalOptions.signal) {
                finalOptions.signal = controller.signal;
            }
            
            // 发送请求
            const response = await fetch(url, finalOptions);
            clearTimeout(timeoutId); // 清除超时
            
            // 检查响应状态
            if (!response.ok) {
                console.error('API响应错误:', response.status, response.statusText);
                const errorText = await response.text().catch(() => '无法读取错误详情');
                console.error('错误详情:', errorText);
                throw new Error(`API请求失败: ${response.status} ${response.statusText}`);
            }
            
            return response;
        } catch (error) {
            if (error.name === 'AbortError') {
                console.error('API请求超时');
                throw new Error('API请求超时，请稍后重试');
            }
            
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