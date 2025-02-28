// 使用全局配置
const { endpoints, fetchApi } = window.API_CONFIG;

async function loadModels() {
    try {
        const response = await fetchApi(endpoints.models);
        const models = await response.json();
        
        const modelSelect = document.getElementById('model-select');
        modelSelect.innerHTML = ''; // 清空现有选项
        
        models.forEach(model => {
            const option = document.createElement('option');
            option.value = model.id;
            option.textContent = model.name;
            modelSelect.appendChild(option);
        });
    } catch (error) {
        console.error('加载模型列表时出错:', error);
        alert('无法加载模型列表，请刷新页面重试');
    }
}

// 页面加载时获取模型列表
document.addEventListener('DOMContentLoaded', loadModels); 