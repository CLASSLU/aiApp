document.addEventListener('DOMContentLoaded', function() {
    const chatMessages = document.getElementById('chat-messages');
    const userInput = document.getElementById('user-input');
    const sendButton = document.getElementById('send-button');
    const stopButton = document.getElementById('stop-button');
    const newChatButton = document.querySelector('.new-chat-btn');
    const modelSelect = document.getElementById('model-select');

    let sessionId = localStorage.getItem('chatSessionId');
    let messageHistory = JSON.parse(localStorage.getItem('messageHistory') || '[]');
    let currentController = null; // 用于存储当前的 AbortController
    
    // 添加缓存相关的常量
    const CACHE_KEY = 'modelListCache';
    const CACHE_DURATION = 5 * 60 * 1000; // 5分钟的缓存时间

    // 添加默认模型列表
    const DEFAULT_MODELS = {
        models: [
            {
                id: "deepseek-ai/deepseek-coder-33b-instruct",
                name: "DeepSeek Coder",
                description: "代码助手模型"
            },
            {
                id: "deepseek-ai/deepseek-math-7b-instruct",
                name: "DeepSeek Math",
                description: "数学助手模型"
            },
            {
                id: "deepseek-ai/deepseek-moe-16b-chat",
                name: "DeepSeek Chat",
                description: "通用对话模型"
            }
        ]
    };

    // 获取模型列表并填充选择框
    async function fetchModels() {
        try {
            // 尝试从缓存获取数据
            const cachedData = localStorage.getItem(CACHE_KEY);
            if (cachedData) {
                const { data, timestamp } = JSON.parse(cachedData);
                // 检查缓存是否过期
                if (Date.now() - timestamp < CACHE_DURATION) {
                    console.log('使用缓存的模型列表数据');
                    updateModelSelect(data);
                    return;
                }
            }

            // 缓存不存在或已过期，发起新请求
            const response = await fetch('http://localhost:5000/api/models', {
                method: 'GET',
                headers: {
                    'X-Request-Source': 'webapp'
                },
                credentials: 'include'
            });

            if (!response.ok) {
                throw new Error(`获取模型列表失败: ${response.status}`);
            }
            
            const data = await response.json();
            
            // 检查返回的数据是否有效
            if (!data || !Array.isArray(data.models)) {
                throw new Error('返回的模型数据格式无效');
            }

            // 更新缓存
            localStorage.setItem(CACHE_KEY, JSON.stringify({
                data: data,
                timestamp: Date.now()
            }));

            // 更新选择框
            updateModelSelect(data);

        } catch (error) {
            console.error('获取模型列表失败:', error);
            // 使用默认模型列表
            console.log('使用默认模型列表');
            updateModelSelect(DEFAULT_MODELS);
            
            // 如果缓存存在，使用缓存数据
            const cachedData = localStorage.getItem(CACHE_KEY);
            if (cachedData) {
                try {
                    const { data } = JSON.parse(cachedData);
                    updateModelSelect(data);
                    console.log('使用缓存的模型列表');
                    return;
                } catch (e) {
                    console.error('解析缓存数据失败:', e);
                }
            }
        }
    }

    // 更新模型选择框的函数
    function updateModelSelect(data) {
        // 清空现有选项
        modelSelect.innerHTML = '';
        
        // 添加模型选项
        data.models.forEach(model => {
            const option = document.createElement('option');
            option.value = model.id;
            // 显示模型名称和描述（如果有）
            option.textContent = model.description ? 
                `${model.name} - ${model.description}` : 
                model.name;
            modelSelect.appendChild(option);
        });

        // 如果没有模型选项，添加提示
        if (data.models.length === 0) {
            const option = document.createElement('option');
            option.value = "";
            option.textContent = "暂无可用模型";
            modelSelect.appendChild(option);
            modelSelect.disabled = true;
        } else {
            modelSelect.disabled = false;
            // 设置保存的选择或默认值
            const savedModel = localStorage.getItem('selectedModel');
            if (savedModel && modelSelect.querySelector(`option[value="${savedModel}"]`)) {
                modelSelect.value = savedModel;
            } else {
                localStorage.setItem('selectedModel', modelSelect.value);
            }
        }

        // 添加模型选择变化监听
        modelSelect.addEventListener('change', function() {
            localStorage.setItem('selectedModel', this.value);
        });
    }

    // 页面加载时获取模型列表
    fetchModels();

    if (!sessionId) {
        createNewSession();
    }

    function createNewSession() {
        if (confirm('确定要开始新的会话吗？当前会话记录将被清除。')) {
            const chatMessages = document.getElementById('chat-messages');
            sessionId = 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
            messageHistory = [];
            
            // 清空聊天记录显示
            chatMessages.innerHTML = '';
            
            // 更新本地存储
            localStorage.setItem('chatSessionId', sessionId);
            localStorage.setItem('messageHistory', JSON.stringify(messageHistory));
            
            // 添加初始的 AI 欢迎消息
            const welcomeMessage = {
                role: 'assistant',
                content: '你好！我是 AI 助手，有什么我可以帮你的吗？'
            };
            messageHistory.push(welcomeMessage);
            
            // 显示欢迎消息
            const welcomeDiv = document.createElement('div');
            welcomeDiv.className = 'message ai-message';
            welcomeDiv.textContent = welcomeMessage.content;
            chatMessages.appendChild(welcomeDiv);
        }
    }

    function addMessage(message, isUser = false) {
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${isUser ? 'user-message' : 'ai-message'}`;
        messageDiv.textContent = message;
        chatMessages.appendChild(messageDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;

        if (!isUser) {
            messageDiv.style.opacity = '0';
            messageDiv.style.transform = 'translateY(20px)';
            setTimeout(() => {
                messageDiv.style.transition = 'all 0.3s ease';
                messageDiv.style.opacity = '1';
                messageDiv.style.transform = 'translateY(0)';
            }, 100);
        }

        messageHistory.push({
            role: isUser ? "user" : "assistant",
            content: message
        });
        localStorage.setItem('messageHistory', JSON.stringify(messageHistory));
        return messageDiv;
    }

    function updateMessage(messageDiv, text) {
        // 清除可能存在的旧定时器
        if (messageDiv._typeTimer) {
            clearInterval(messageDiv._typeTimer);
            messageDiv._typeTimer = null;
        }

        // 如果是第一次更新，直接显示第一个字符
        if (!messageDiv.textContent) {
            messageDiv.textContent = text[0] || '';
            return;
        }

        // 获取新增的文本
        const currentLength = messageDiv.textContent.length;
        const newText = text.slice(currentLength);
        
        if (newText) {
            let i = 0;
            // 保存定时器引用
            messageDiv._typeTimer = setInterval(() => {
                if (i < newText.length) {
                    messageDiv.textContent = text.slice(0, currentLength + i + 1);
                    chatMessages.scrollTop = chatMessages.scrollHeight;
                    i++;
                } else {
                    clearInterval(messageDiv._typeTimer);
                    messageDiv._typeTimer = null;
                }
            }, 30);
        }
    }

    function restoreMessages() {
        const chatMessages = document.getElementById('chat-messages');
        const messageHistory = JSON.parse(localStorage.getItem('messageHistory') || '[]');
        
        // 清空现有的聊天记录
        chatMessages.innerHTML = '';
        
        // 重新渲染消息历史
        messageHistory.forEach(message => {
            const messageDiv = document.createElement('div');
            messageDiv.className = `message ${message.role === 'user' ? 'user-message' : 'ai-message'}`;
            
            // 使用 white-space: pre-wrap 来保持换行
            messageDiv.style.whiteSpace = 'pre-wrap';
            messageDiv.textContent = message.content;
            
            chatMessages.appendChild(messageDiv);
        });
        
        // 滚动到底部
        chatMessages.scrollTop = chatMessages.scrollHeight;
    }

    // 添加停止生成的函数
    async function stopGeneration() {
        if (currentController) {
            currentController.abort();
            currentController = null;
            
            // 通知后端停止生成
            try {
                await fetch('http://localhost:5000/api/stop', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Request-Source': 'webapp'
                    },
                    credentials: 'include',
                    body: JSON.stringify({
                        session_id: sessionId
                    })
                });
            } catch (error) {
                console.warn('通知后端停止生成失败:', error);
            }
        }
        
        stopButton.style.display = 'none';
        sendButton.style.display = 'block';
    }

    async function sendMessage() {
        const message = userInput.value.trim();
        if (!message) return;

        userInput.value = '';
        addMessage(message, true);
        const aiMessageDiv = addMessage('', false);
        let fullResponse = '';

        // 显示停止按钮，隐藏发送按钮
        sendButton.style.display = 'none';
        stopButton.style.display = 'block';

        // 创建新的 AbortController
        currentController = new AbortController();

        try {
            const response = await fetch('http://localhost:5000/api/chat', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Request-Source': 'webapp'
                },
                credentials: 'include',
                signal: currentController.signal,
                body: JSON.stringify({
                    session_id: sessionId,
                    user_input: message,
                    messages: messageHistory.slice(0, -1),
                    model: modelSelect.value
                })
            });

            if (!response.ok) throw new Error('网络响应不正常');

            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let buffer = '';

            while (true) {
                const {done, value} = await reader.read();
                if (done) break;

                const chunk = decoder.decode(value, {stream: true});
                buffer += chunk;

                const lines = buffer.split('\n');
                buffer = lines.pop() || '';

                for (const line of lines) {
                    if (line.startsWith('data: ')) {
                        const data = line.slice(5).trim();
                        
                        // 检查是否是结束标记
                        if (data === '[DONE]') {
                            continue;  // 跳过结束标记
                        }

                        try {
                            const parsed = JSON.parse(data);
                            if (parsed.reply) {
                                fullResponse += parsed.reply;
                                updateMessage(aiMessageDiv, fullResponse);
                            }
                        } catch (e) {
                            console.warn('解析响应数据失败:', e, '原始数据:', data);
                        }
                    }
                }
            }

            // 处理缓冲区中剩余的数据
            if (buffer) {
                const lines = buffer.split('\n');
                for (const line of lines) {
                    if (line.startsWith('data: ')) {
                        const data = line.slice(5).trim();
                        if (data === '[DONE]') continue;  // 跳过结束标记

                        try {
                            const parsed = JSON.parse(data);
                            if (parsed.reply) {
                                fullResponse += parsed.reply;
                                updateMessage(aiMessageDiv, fullResponse);
                            }
                        } catch (e) {
                            console.warn('解析最后的响应数据失败:', e, '原始数据:', data);
                        }
                    }
                }
            }

            // 更新消息历史
            messageHistory[messageHistory.length - 1].content = fullResponse;
            localStorage.setItem('messageHistory', JSON.stringify(messageHistory));

        } catch (error) {
            if (error.name === 'AbortError') {
                console.log('生成被用户终止');
            } else {
                console.error('发送消息出错:', error);
                aiMessageDiv.textContent = '抱歉，发生了一些错误，请稍后重试。';
                messageHistory.pop();
            }
        } finally {
            // 恢复按钮状态
            stopButton.style.display = 'none';
            sendButton.style.display = 'block';
            currentController = null;
        }
    }

    restoreMessages();

    sendButton.addEventListener('click', sendMessage);
    userInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    newChatButton.addEventListener('click', () => {
        if (confirm('确定要开始新的会话吗？当前会话记录将被清除。')) {
            createNewSession();
        }
    });

    // 添加停止按钮事件监听
    stopButton.addEventListener('click', stopGeneration);
}); 