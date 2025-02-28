// 使用统一配置
const { API_BASE_URL, endpoints, fetchApi } = window.APP_CONFIG;

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

    // 配置 marked 选项
    marked.setOptions({
        highlight: function(code, lang) {
            if (lang && hljs.getLanguage(lang)) {
                try {
                    return hljs.highlight(code, { language: lang }).value;
                } catch (err) {}
            }
            return hljs.highlightAuto(code).value;
        },
        breaks: true,
        gfm: true,
        langPrefix: 'hljs language-'
    });

    if (!sessionId) {
        createNewSession();
    }

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
            const response = await fetchApi(endpoints.models);
            
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

    function createNewSession() {
        if (confirm('确定要开始新的会话吗？当前会话记录将被清除。')) {
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
            displayMessage(welcomeMessage.content, 'ai');
        }
    }

    function displayMessage(message, role) {
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${role}`;
        
        if (role === 'ai') {
            // 配置 marked 选项
            marked.setOptions({
                highlight: function(code, lang) {
                    if (lang && hljs.getLanguage(lang)) {
                        try {
                            return hljs.highlight(code, { language: lang }).value;
                        } catch (err) {}
                    }
                    return hljs.highlightAuto(code).value;
                },
                breaks: true,
                gfm: true
            });

            // 渲染 markdown
            messageDiv.innerHTML = marked.parse(message);

            // 为所有代码块添加复制按钮
            messageDiv.querySelectorAll('pre code').forEach(function(block) {
                const pre = block.parentNode;
                const wrapper = document.createElement('div');
                wrapper.className = 'code-block-wrapper';
                
                const header = document.createElement('div');
                header.className = 'code-block-header';
                
                const langTag = document.createElement('div');
                langTag.className = 'code-lang-tag';
                const lang = block.className.replace('language-', '').toUpperCase();
                langTag.textContent = lang || 'TEXT';
                header.appendChild(langTag);
                
                const copyButton = document.createElement('button');
                copyButton.className = 'copy-button';
                copyButton.innerHTML = '<i class="fas fa-copy"></i>';
                copyButton.title = '复制代码';
                
                copyButton.addEventListener('click', function() {
                    const code = block.textContent;
                    navigator.clipboard.writeText(code).then(function() {
                        copyButton.innerHTML = '<i class="fas fa-check"></i>';
                        setTimeout(function() {
                            copyButton.innerHTML = '<i class="fas fa-copy"></i>';
                        }, 2000);
                    }).catch(function(err) {
                        console.error('复制失败:', err);
                        copyButton.innerHTML = '<i class="fas fa-times"></i>';
                    });
                });
                
                header.appendChild(copyButton);
                wrapper.appendChild(header);
                
                // 将pre元素包装在wrapper中
                pre.parentNode.insertBefore(wrapper, pre);
                wrapper.appendChild(pre);
            });

            // 添加打字机效果
            messageDiv.style.opacity = '0';
            messageDiv.style.transform = 'translateY(20px)';
            setTimeout(() => {
                messageDiv.style.transition = 'all 0.3s ease';
                messageDiv.style.opacity = '1';
                messageDiv.style.transform = 'translateY(0)';
            }, 100);
        } else {
            messageDiv.textContent = `你: ${message}`;
        }
        
        chatMessages.appendChild(messageDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
        
        return messageDiv;
    }

    function handleChat(userInput) {
        if (!userInput.trim()) return;
        
        // 显示用户消息
        displayMessage(userInput, 'user');
        
        // 创建一个新的消息容器
        const aiMessageDiv = document.createElement('div');
        aiMessageDiv.className = 'message ai';
        chatMessages.appendChild(aiMessageDiv);
        
        // 创建 EventSource 连接
        const eventSource = new EventSource(
            `${API_BASE_URL}${endpoints.chat}?session_id=${sessionId}&user_input=${encodeURIComponent(userInput)}`
        );
        
        let accumulatedContent = '';
        let inCodeBlock = false;
        let currentLang = '';
        let codeBlockContent = '';
        let currentCodeBlock = null;
        let currentPre = null;
        
        eventSource.onmessage = function(event) {
            if (event.data === '[DONE]') {
                eventSource.close();
                return;
            }
            
            try {
                const data = JSON.parse(event.data);
                if (data.reply) {
                    const content = data.reply;
                    accumulatedContent += content;
                    
                    // 检测代码块的开始
                    if (content.includes('```') && !inCodeBlock) {
                        inCodeBlock = true;
                        const parts = content.split('```');
                        if (parts[0]) {
                            // 渲染代码块前的内容
                            aiMessageDiv.innerHTML = marked.parse(accumulatedContent.slice(0, -content.length) + parts[0]);
                        }
                        
                        // 创建新的代码块容器
                        currentPre = document.createElement('pre');
                        currentCodeBlock = document.createElement('code');
                        currentPre.appendChild(currentCodeBlock);
                        
                        // 获取语言
                        const langMatch = parts[1].match(/^(\w+)\n/);
                        if (langMatch) {
                            currentLang = langMatch[1].toUpperCase();
                            currentCodeBlock.className = 'language-' + langMatch[1].toLowerCase();
                            content = parts[1].slice(langMatch[0].length);
                        } else {
                            currentLang = 'TEXT';
                            currentCodeBlock.className = 'language-text';
                            content = parts[1];
                        }
                        
                        // 创建代码块包装器
                        const wrapper = document.createElement('div');
                        wrapper.className = 'code-block-wrapper';
                        
                        const header = document.createElement('div');
                        header.className = 'code-block-header';
                        
                        const langTag = document.createElement('div');
                        langTag.className = 'code-lang-tag';
                        langTag.textContent = currentLang;
                        header.appendChild(langTag);
                        
                        const copyButton = document.createElement('button');
                        copyButton.className = 'copy-button';
                        copyButton.innerHTML = '<i class="fas fa-copy"></i>';
                        copyButton.title = '复制代码';
                        
                        copyButton.addEventListener('click', function() {
                            const code = currentCodeBlock.textContent;
                            navigator.clipboard.writeText(code).then(function() {
                                copyButton.innerHTML = '<i class="fas fa-check"></i>';
                                setTimeout(function() {
                                    copyButton.innerHTML = '<i class="fas fa-copy"></i>';
                                }, 2000);
                            }).catch(function(err) {
                                console.error('复制失败:', err);
                                copyButton.innerHTML = '<i class="fas fa-times"></i>';
                            });
                        });
                        
                        header.appendChild(copyButton);
                        wrapper.appendChild(header);
                        wrapper.appendChild(currentPre);
                        aiMessageDiv.appendChild(wrapper);
                        
                        codeBlockContent = content;
                        currentCodeBlock.textContent = content;
                        hljs.highlightElement(currentCodeBlock);
                    }
                    // 检测代码块的结束
                    else if (content.includes('```') && inCodeBlock) {
                        inCodeBlock = false;
                        const parts = content.split('```');
                        if (parts[0]) {
                            codeBlockContent += parts[0];
                            currentCodeBlock.textContent = codeBlockContent;
                            hljs.highlightElement(currentCodeBlock);
                        }
                        if (parts[1]) {
                            // 渲染代码块后的内容
                            const tempDiv = document.createElement('div');
                            tempDiv.innerHTML = marked.parse(parts[1]);
                            while (tempDiv.firstChild) {
                                aiMessageDiv.appendChild(tempDiv.firstChild);
                            }
                        }
                        currentCodeBlock = null;
                        currentPre = null;
                        codeBlockContent = '';
                    }
                    // 在代码块内
                    else if (inCodeBlock) {
                        codeBlockContent += content;
                        currentCodeBlock.textContent = codeBlockContent;
                        hljs.highlightElement(currentCodeBlock);
                    }
                    // 普通文本
                    else {
                        aiMessageDiv.innerHTML = marked.parse(accumulatedContent);
                    }
                    
                    // 滚动到底部
                    chatMessages.scrollTop = chatMessages.scrollHeight;
                }
            } catch (error) {
                console.error('处理消息时出错:', error);
            }
        };
        
        eventSource.onerror = function(error) {
            console.error('EventSource 错误:', error);
            eventSource.close();
            displayMessage('抱歉，发生了错误，请重试。', 'ai');
        };
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
    }

    // 事件监听器
    sendButton.addEventListener('click', function() {
        const message = userInput.value.trim();
        if (message) {
            handleChat(message);
            userInput.value = '';
        }
    });

    userInput.addEventListener('keypress', function(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            sendButton.click();
        }
    });

    newChatButton.addEventListener('click', createNewSession);

    modelSelect.addEventListener('change', function() {
        localStorage.setItem('selectedModel', this.value);
    });

    // 停止生成按钮事件
    if (stopButton) {
        stopButton.addEventListener('click', async function() {
            if (currentController) {
                try {
                    await fetchApi(endpoints.stop, {
                        method: 'POST',
                        body: JSON.stringify({ session_id: sessionId })
                    });
                    currentController.abort();
                    currentController = null;
                    stopButton.style.display = 'none';
                } catch (error) {
                    console.error('停止生成失败:', error);
                }
            }
        });
    }

    // 页面加载时获取模型列表
    fetchModels();
}); 