// 使用统一配置
const { API_BASE_URL, endpoints, fetchApi } = window.APP_CONFIG;

document.addEventListener('DOMContentLoaded', function() {
    const chatMessages = document.getElementById('chat-messages');
    const userInput = document.getElementById('user-input');
    const sendButton = document.getElementById('send-button');
    const stopButton = document.getElementById('stop-button');
    const newChatButton = document.querySelector('.new-chat-btn');
    const modelSelect = document.getElementById('model-select');
    const promptSelect = document.getElementById('prompt-select');
    const sessionsList = document.getElementById('sessions-list');

    // 存储所有会话的数据
    let allSessions = JSON.parse(localStorage.getItem('allChatSessions') || '{}');
    let sessionId = localStorage.getItem('currentChatSessionId');
    let messageHistory = [];
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

    // 场景提示词模板
    const PROMPT_TEMPLATES = {
        programmer: "我是一名开发者，需要您作为编程助手帮助我。请以程序员的视角回答我的问题。",
        product_manager: "我是一名产品经理，需要您协助我进行产品设计和规划。请从产品管理的角度提供专业建议。",
        doctor: "我需要一些医疗方面的建议，请以医疗专业人士的角度回答我的问题，但请注明您不能替代真实的医生诊断。",
        civil_servant: "我是一名公务员，需要您协助我处理政策研究和文件起草工作。请从行政管理的角度提供专业建议。"
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

    // 显示当前会话的历史记录
    function loadChatHistory() {
        chatMessages.innerHTML = ''; // 清空现有内容
        if (sessionId && allSessions[sessionId]) {
            messageHistory = allSessions[sessionId].messages || [];
            messageHistory.forEach(msg => {
                displayMessage(msg.content, msg.role === 'user' ? 'user' : 'ai');
            });
        } else {
            messageHistory = [];
        }
    }

    // 初始化会话管理
    function initSessionsManagement() {
        // 如果没有当前会话ID或该ID不存在于已保存的会话中，创建一个新会话
        if (!sessionId || !allSessions[sessionId]) {
            createNewSession();
        } else {
            // 加载当前会话
            loadChatHistory();
            // 更新会话列表UI，标记当前会话为激活状态
            updateSessionsList();
        }
    }

    // 更新会话列表UI
    function updateSessionsList() {
        sessionsList.innerHTML = '';
        
        // 按最后更新时间排序（最新的在前面）
        const sortedSessions = Object.entries(allSessions)
            .sort(([, a], [, b]) => b.lastUpdated - a.lastUpdated);
        
        if (sortedSessions.length === 0) {
            const emptyItem = document.createElement('li');
            emptyItem.textContent = '暂无会话，点击「新建」开始';
            emptyItem.className = 'session-item empty';
            sessionsList.appendChild(emptyItem);
            return;
        }
        
        sortedSessions.forEach(([id, session]) => {
            const item = document.createElement('li');
            item.className = `session-item ${id === sessionId ? 'active' : ''}`;
            item.dataset.id = id;
            
            const titleSpan = document.createElement('span');
            titleSpan.className = 'session-title';
            titleSpan.textContent = session.title || '新会话';
            
            const actionsDiv = document.createElement('div');
            actionsDiv.className = 'session-actions';
            
            const renameBtn = document.createElement('button');
            renameBtn.className = 'rename-session-btn';
            renameBtn.innerHTML = '<i class="fas fa-edit"></i>';
            renameBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                renameSession(id);
            });
            
            const deleteBtn = document.createElement('button');
            deleteBtn.className = 'delete-session-btn';
            deleteBtn.innerHTML = '<i class="fas fa-trash"></i>';
            deleteBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                deleteSession(id);
            });
            
            actionsDiv.appendChild(renameBtn);
            actionsDiv.appendChild(deleteBtn);
            
            item.appendChild(titleSpan);
            item.appendChild(actionsDiv);
            
            // 点击会话项切换到该会话
            item.addEventListener('click', () => {
                switchSession(id);
            });
            
            sessionsList.appendChild(item);
        });
    }

    // 切换到指定会话
    function switchSession(id) {
        if (id === sessionId) return; // 已经是当前会话
        
        // 保存当前会话数据
        if (sessionId && allSessions[sessionId]) {
            allSessions[sessionId].messages = messageHistory;
            saveAllSessions();
        }
        
        // 切换会话
        sessionId = id;
        localStorage.setItem('currentChatSessionId', id);
        
        // 加载新会话的历史记录
        loadChatHistory();
        
        // 更新UI
        updateSessionsList();
    }

    // 重命名会话
    function renameSession(id) {
        const session = allSessions[id];
        if (!session) return;
        
        const newTitle = prompt('请输入新的会话名称:', session.title || '新会话');
        if (newTitle !== null) {
            session.title = newTitle.trim() || '新会话';
            session.lastUpdated = Date.now();
            saveAllSessions();
            updateSessionsList();
        }
    }

    // 删除会话
    function deleteSession(id) {
        if (!confirm('确定要删除这个会话吗？此操作不可撤销。')) return;
        
        delete allSessions[id];
        saveAllSessions();
        
        // 如果删除的是当前会话，切换到其他会话或创建新会话
        if (id === sessionId) {
            const remainingSessions = Object.keys(allSessions);
            if (remainingSessions.length > 0) {
                switchSession(remainingSessions[0]);
            } else {
                createNewSession();
            }
        } else {
            updateSessionsList();
        }
    }

    // 保存所有会话数据
    function saveAllSessions() {
        localStorage.setItem('allChatSessions', JSON.stringify(allSessions));
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
        const id = 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        
        // 创建新会话对象
        allSessions[id] = {
            title: '新会话',
            created: Date.now(),
            lastUpdated: Date.now(),
            messages: []
        };
        
        // 更新当前会话ID和消息历史
        sessionId = id;
        messageHistory = [];
        
        // 保存会话数据
        localStorage.setItem('currentChatSessionId', id);
        saveAllSessions();
        
        // 清空聊天记录显示
        chatMessages.innerHTML = '';
        
        // 添加初始的 AI 欢迎消息
        const welcomeMessage = {
            role: 'assistant',
            content: '你好！我是 AI 助手，有什么我可以帮你的吗？'
        };
        messageHistory.push(welcomeMessage);
        allSessions[id].messages = messageHistory;
        saveAllSessions();
        
        // 显示欢迎消息
        displayMessage(welcomeMessage.content, 'ai');
        
        // 更新会话列表
        updateSessionsList();
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
                
                // 获取语言
                const langMatch = block.className.match(/language-(\w+)/);
                const lang = langMatch ? langMatch[1] : '';
                
                // 创建代码块头部
                const header = document.createElement('div');
                header.className = 'code-block-header';
                
                const langTag = document.createElement('div');
                langTag.className = 'code-lang-tag';
                langTag.textContent = lang || 'code';
                
                const copyBtn = document.createElement('button');
                copyBtn.className = 'copy-button';
                copyBtn.innerHTML = '<i class="fas fa-copy"></i> 复制';
                copyBtn.onclick = function() {
                    navigator.clipboard.writeText(block.textContent).then(function() {
                        const originalText = copyBtn.innerHTML;
                        copyBtn.innerHTML = '<i class="fas fa-check"></i> 已复制';
                        setTimeout(function() {
                            copyBtn.innerHTML = originalText;
                        }, 2000);
                    });
                };
                
                header.appendChild(langTag);
                header.appendChild(copyBtn);
                
                // 将原始pre包装在wrapper中
                pre.parentNode.insertBefore(wrapper, pre);
                wrapper.appendChild(header);
                wrapper.appendChild(pre);
            });
        } else {
            // 用户消息直接显示文本
            messageDiv.textContent = message;
        }
        
        // 添加到聊天界面
        chatMessages.appendChild(messageDiv);
        
        // 滚动到最新消息
        chatMessages.scrollTop = chatMessages.scrollHeight;
    }

    function updateModelSelect(data) {
        modelSelect.innerHTML = '';
        
        if (!data || !data.models || !Array.isArray(data.models)) {
            console.error('模型数据格式错误:', data);
            return;
        }
        
        data.models.forEach(model => {
            const option = document.createElement('option');
            option.value = model.id;
            option.textContent = `${model.name} - ${model.description || ''}`;
            modelSelect.appendChild(option);
        });
        
        // 选择默认模型
        if (data.models.length > 0) {
            // 首选通用对话模型
            const defaultModel = data.models.find(m => 
                m.name.includes("Chat") || m.description.includes("通用")
            );
            
            if (defaultModel) {
                modelSelect.value = defaultModel.id;
            } else {
                modelSelect.value = data.models[0].id;
            }
        }
    }

    async function handleChat() {
        const message = userInput.value.trim();
        if (!message) return;
        
        // 显示用户消息
        displayMessage(message, 'user');
        
        // 添加到历史记录
        messageHistory.push({
            role: 'user',
            content: message
        });
        
        // 更新会话数据
        if (allSessions[sessionId]) {
            allSessions[sessionId].messages = messageHistory;
            allSessions[sessionId].lastUpdated = Date.now();
            
            // 如果会话开头几条消息，用第一条用户消息作为会话标题
            if (messageHistory.length <= 3) {
                const userMessages = messageHistory.filter(msg => msg.role === 'user');
                if (userMessages.length === 1) {
                    // 使用第一条消息的前20个字符作为会话标题
                    const title = userMessages[0].content.substring(0, 20) + (userMessages[0].content.length > 20 ? '...' : '');
                    allSessions[sessionId].title = title;
                }
            }
            
            saveAllSessions();
            updateSessionsList();
        }
        
        // 清空输入框
        userInput.value = '';
        
        // 禁用发送按钮，显示停止按钮
        sendButton.disabled = true;
        stopButton.style.display = 'inline-block';
        
        try {
            // 创建一个AbortController来处理取消请求
            currentController = new AbortController();
            
            // 构建请求数据，包含历史记录
            const requestData = {
                session_id: sessionId,
                user_input: message,
                history: messageHistory.slice(0, -1) // 排除最新的用户消息
            };
            
            // 获取选定的模型
            const selectedModel = modelSelect.value;
            if (selectedModel) {
                requestData.model = selectedModel;
            }
            
            // 发起聊天请求
            const response = await fetch(`${API_BASE_URL}${endpoints.chat}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Request-Source': 'webapp'
                },
                body: JSON.stringify(requestData),
                signal: currentController.signal
            });
            
            if (!response.ok) {
                throw new Error(`请求失败: ${response.status}`);
            }
            
            const reader = response.body.getReader();
            const decoder = new TextDecoder('utf-8');
            
            // 创建一个新的AI消息div
            const aiMessageDiv = document.createElement('div');
            aiMessageDiv.className = 'message ai';
            chatMessages.appendChild(aiMessageDiv);
            
            let accumulatedContent = '';
            let inCodeBlock = false;
            
            // 处理流式响应
            while (true) {
                const { value, done } = await reader.read();
                if (done) break;
                
                const chunk = decoder.decode(value, { stream: true });
                const lines = chunk.split('\n');
                
                for (const line of lines) {
                    if (!line.trim() || !line.startsWith('data:')) continue;
                    
                    try {
                        const data = line.substring(5).trim();
                        if (data === '[DONE]') continue;
                        
                        const parsed = JSON.parse(data);
                        
                        if (parsed.type === 'assistant') {
                            // 添加到当前消息
                            accumulatedContent += parsed.reply;
                            
                            // 检测是否在代码块内
                            if (parsed.reply.includes('```')) {
                                inCodeBlock = !inCodeBlock;
                            }
                            
                            // 使用 marked 渲染 markdown
                            aiMessageDiv.innerHTML = marked.parse(accumulatedContent);
                            
                            // 为所有代码块添加复制按钮
                            aiMessageDiv.querySelectorAll('pre code').forEach(function(block) {
                                // 检查是否已添加了复制按钮
                                if (block.parentNode.parentNode.className === 'code-block-wrapper') {
                                    return;
                                }
                                
                                const pre = block.parentNode;
                                const wrapper = document.createElement('div');
                                wrapper.className = 'code-block-wrapper';
                                
                                // 获取语言
                                const langMatch = block.className.match(/language-(\w+)/);
                                const lang = langMatch ? langMatch[1] : '';
                                
                                // 创建代码块头部
                                const header = document.createElement('div');
                                header.className = 'code-block-header';
                                
                                const langTag = document.createElement('div');
                                langTag.className = 'code-lang-tag';
                                langTag.textContent = lang || 'code';
                                
                                const copyBtn = document.createElement('button');
                                copyBtn.className = 'copy-button';
                                copyBtn.innerHTML = '<i class="fas fa-copy"></i> 复制';
                                copyBtn.onclick = function() {
                                    navigator.clipboard.writeText(block.textContent).then(function() {
                                        const originalText = copyBtn.innerHTML;
                                        copyBtn.innerHTML = '<i class="fas fa-check"></i> 已复制';
                                        setTimeout(function() {
                                            copyBtn.innerHTML = originalText;
                                        }, 2000);
                                    });
                                };
                                
                                header.appendChild(langTag);
                                header.appendChild(copyBtn);
                                
                                // 将原始pre包装在wrapper中
                                pre.parentNode.insertBefore(wrapper, pre);
                                wrapper.appendChild(header);
                                wrapper.appendChild(pre);
                            });
                            
                            // 滚动到最新消息
                            chatMessages.scrollTop = chatMessages.scrollHeight;
                        }
                    } catch (e) {
                        console.error('解析消息失败:', e, line);
                    }
                }
            }
            
            // 添加到历史记录
            if (accumulatedContent) {
                messageHistory.push({
                    role: 'assistant',
                    content: accumulatedContent
                });
                
                // 更新会话数据
                if (allSessions[sessionId]) {
                    allSessions[sessionId].messages = messageHistory;
                    allSessions[sessionId].lastUpdated = Date.now();
                    saveAllSessions();
                }
            }
            
        } catch (error) {
            if (error.name === 'AbortError') {
                console.log('请求被用户取消');
            } else {
                console.error('聊天请求失败:', error);
                displayMessage(`发生错误: ${error.message}`, 'ai');
            }
        } finally {
            // 恢复界面状态
            sendButton.disabled = false;
            stopButton.style.display = 'none';
            currentController = null;
        }
    }

    // 应用场景提示词
    function applyPromptTemplate() {
        const selectedTemplate = promptSelect.value;
        if (!selectedTemplate || !PROMPT_TEMPLATES[selectedTemplate]) return;
        
        // 获取提示词模板
        const templateText = PROMPT_TEMPLATES[selectedTemplate];
        
        // 添加到输入框
        userInput.value = templateText;
        
        // 聚焦到输入框末尾
        userInput.focus();
        userInput.setSelectionRange(templateText.length, templateText.length);
    }

    // 事件监听
    newChatButton.addEventListener('click', createNewSession);
    
    sendButton.addEventListener('click', handleChat);
    
    userInput.addEventListener('keydown', function(e) {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleChat();
        }
    });
    
    stopButton.addEventListener('click', function() {
        if (currentController) {
            currentController.abort();
            stopButton.style.display = 'none';
            sendButton.disabled = false;
        }
    });
    
    promptSelect.addEventListener('change', applyPromptTemplate);

    // 初始化
    fetchModels();
    initSessionsManagement();
});