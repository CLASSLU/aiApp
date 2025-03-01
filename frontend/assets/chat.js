// 使用统一配置
const { API_BASE_URL, endpoints, fetchApi } = window.APP_CONFIG;

document.addEventListener('DOMContentLoaded', function() {
    const chatMessages = document.getElementById('chat-messages');
    const userInput = document.getElementById('user-input');
    const sendButton = document.getElementById('send-button');
    const stopButton = document.getElementById('stop-button');
    const newChatButton = document.querySelector('.new-chat-btn');
    const newChatSidebarButton = document.querySelector('.new-chat-sidebar-btn'); // 添加侧边栏新建按钮引用
    const modelSelect = document.getElementById('model-select');
    const promptSelect = document.getElementById('prompt-select');
    const sessionsList = document.getElementById('sessions-list');
    const chatContainer = document.getElementById('chat-container');
    const mainContent = document.querySelector('.main-content'); // 主内容区域

    // 添加全屏切换按钮
    const fullscreenBtn = document.createElement('button');
    fullscreenBtn.id = 'fullscreen-btn';
    fullscreenBtn.className = 'fullscreen-btn';
    fullscreenBtn.innerHTML = '<i class="fas fa-expand"></i>';
    fullscreenBtn.title = '全屏模式';
    
    // 直接添加到body中以确保可见
    document.body.appendChild(fullscreenBtn);
    
    // 全屏状态标志
    let isFullscreen = false;

    // 存储所有会话的数据
    let allSessions = JSON.parse(localStorage.getItem('allChatSessions') || '{}');
    let sessionId = localStorage.getItem('currentChatSessionId');
    let messageHistory = [];
    let currentController = null; // 用于存储当前的 AbortController
    let aiResponseInProgress = false; // 标记AI是否正在响应
    let currentResponseText = ''; // 当前累积的响应文本
    
    // 添加页面可见性监听
    let pageIsVisible = true;
    
    // 添加缓存相关的常量
    const CACHE_KEY = 'modelListCache';
    const CACHE_DURATION = 5 * 60 * 1000; // 5分钟的缓存时间
    const PENDING_REQUEST_KEY = 'pendingChatRequest'; // 用于存储正在处理的请求

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
        // 技术领域
        programmer_backend: "我是一名后端开发工程师，请您作为专业的后端开发顾问，帮助我解决服务器架构、API设计、数据库优化、性能调优、安全问题等方面的技术难题。请提供符合行业最佳实践的建议，并考虑可扩展性、可维护性和安全性。",
        programmer_frontend: "我是一名前端开发工程师，请您作为专业的前端技术顾问，帮助我解决UI/UX实现、响应式设计、前端框架使用、性能优化、浏览器兼容性等方面的问题。请提供符合现代前端开发标准的建议，并注重用户体验和页面性能。",
        programmer_devops: "我是一名DevOps/运维工程师，请您作为DevOps专家，帮助我解决CI/CD流程、自动化部署、容器化管理、云服务配置、监控告警、系统稳定性等方面的问题。请提供符合DevOps最佳实践的建议，注重自动化、可靠性和安全性。",
        programmer_ai: "我是一名AI/机器学习工程师，请您作为AI领域专家，帮助我解决模型训练、算法选择、数据处理、模型优化、AI系统部署等方面的问题。请提供符合AI研发最佳实践的建议，考虑算法效率、模型性能和实际应用价值。",
        data_scientist: "我是一名数据科学家，请您作为数据分析专家，帮助我解决数据清洗、特征工程、统计分析、数据可视化、预测模型构建等方面的问题。请提供专业的数据科学方法论指导，注重数据洞察的准确性和可行性。",
        security_expert: "我是一名网络安全专家，请您作为安全顾问，帮助我解决系统漏洞评估、安全架构设计、威胁检测、安全审计、渗透测试等方面的问题。请提供符合网络安全最佳实践的建议，保障系统和数据的完整性、机密性和可用性。",
        
        // 商业领域
        product_manager: "我是一名产品经理，请您作为产品管理顾问，帮助我解决产品规划、需求分析、用户调研、功能优先级、产品路线图、市场定位等方面的问题。请提供符合产品经理思维的专业建议，注重产品价值和用户体验。",
        marketing_specialist: "我是一名市场营销专家，请您作为营销顾问，帮助我解决市场策略、品牌建设、营销活动、用户增长、市场分析、竞品研究等方面的问题。请提供符合现代营销理念的专业建议，关注ROI和用户转化。",
        financial_analyst: "我是一名金融分析师，请您作为财务顾问，帮助我解决财务分析、投资评估、风险管理、预算规划、财务报表解读等方面的问题。请提供符合财务专业规范的建议，考虑风险控制和收益最大化。",
        business_consultant: "我是一名商业顾问，请您作为管理咨询专家，帮助我解决业务战略、组织优化、流程再造、企业转型、商业模式创新等方面的问题。请提供符合管理咨询最佳实践的建议，关注企业价值和可持续发展。",
        hr_professional: "我是一名人力资源专家，请您作为HR顾问，帮助我解决人才招聘、员工培训、绩效管理、文化建设、薪酬体系、团队发展等方面的问题。请提供符合现代人力资源管理理念的专业建议，平衡企业需求和员工发展。",
        
        // 医疗健康
        physician: "我是一名临床医生，请您作为医学顾问，帮助我讨论疾病诊疗思路、治疗方案选择、医学研究进展、临床指南解读等方面的问题。请基于循证医学提供专业意见，同时明确您不能替代实际医疗诊断，建议患者及时就医。",
        medical_researcher: "我是一名医学研究员，请您作为医学研究顾问，帮助我讨论研究设计、数据分析方法、文献综述、研究伦理、成果转化等方面的问题。请提供符合科学研究规范的专业建议，注重研究的严谨性和临床价值。",
        pharmacist: "我是一名药剂师，请您作为药学顾问，帮助我讨论药物相互作用、给药方案、药物不良反应、药物经济学、处方审核等方面的问题。请提供符合药学专业规范的建议，注重用药安全和有效性。",
        nutritionist: "我是一名营养学家，请您作为营养顾问，帮助我讨论膳食规划、营养评估、特殊人群饮食、营养干预、体重管理等方面的问题。请提供符合营养学科学依据的专业建议，注重个体化的营养方案。",
        mental_health: "我是一名心理健康顾问，请您作为心理学专家，帮助我讨论心理疾病、情绪管理、压力应对、心理干预技术、潜能开发等方面的问题。请提供符合心理学专业规范的建议，同时强调严重心理问题需寻求专业医疗机构帮助。",
        
        // 教育领域
        teacher_k12: "我是一名中小学教师，请您作为教育专家，帮助我解决课程设计、教学方法、学生管理、差异化教学、家校沟通、教育评估等方面的问题。请提供符合现代教育理念的专业建议，注重学生全面发展。",
        professor: "我是一名大学教授/研究员，请您作为高等教育专家，帮助我讨论学术研究、教学创新、科研项目、学科建设、研究生培养等方面的问题。请提供符合学术规范的专业建议，注重研究的原创性和教学的有效性。",
        education_admin: "我是一名教育管理者，请您作为教育管理顾问，帮助我解决教育政策解读、学校管理、教师发展、课程规划、教育评价、资源配置等方面的问题。请提供符合教育管理最佳实践的建议，注重教育质量和公平性。",
        career_counselor: "我是一名职业规划顾问，请您作为职业发展专家，帮助我解决职业定位、能力评估、简历制作、面试技巧、职业转型、继续教育等方面的问题。请提供符合职业发展规律的专业建议，助力职业成长和自我实现。",
        
        // 法律政务
        legal_advisor: "我是一名法律顾问，请您作为法律专家，帮助我分析法律问题、合同审查、风险防范、法规解读、合规建设等方面的问题。请提供基于法律专业知识的建议，同时明确您不能替代正式的法律意见，复杂法律问题建议咨询执业律师。",
        civil_servant: "我是一名公务员，请您作为行政事务顾问，帮助我解决政策研究、文件起草、公共管理、行政程序、政务服务等方面的问题。请提供符合行政工作规范的专业建议，注重依法行政和公共服务质量。",
        policy_analyst: "我是一名政策分析师，请您作为政策研究专家，帮助我解决政策评估、趋势分析、影响预测、方案比较、建议提炼等方面的问题。请提供基于系统思维的政策分析框架，注重政策的可行性和有效性。",
        patent_attorney: "我是一名专利律师，请您作为知识产权专家，帮助我解决专利检索、专利申请、知识产权保护、侵权分析、IP战略等方面的问题。请提供符合知识产权专业规范的建议，关注创新保护和风险防范。",
        
        // 创意艺术
        content_creator: "我是一名内容创作者，请您作为创意顾问，帮助我解决内容策划、受众分析、创意构思、叙事技巧、传播策略等方面的问题。请提供具有创意性和专业性的建议，注重内容的原创性和传播效果。",
        designer: "我是一名设计师，请您作为设计专家，帮助我解决设计理念、美学表达、用户体验、设计趋势、作品集构建等方面的问题。请提供符合设计原则的专业建议，平衡美学价值和功能需求。",
        writer: "我是一名作家/编剧，请您作为文学创作顾问，帮助我解决情节构思、角色塑造、场景描写、对白设计、叙事节奏等方面的问题。请提供符合文学创作规律的专业建议，注重故事的感染力和艺术价值。",
        journalist: "我是一名记者/媒体工作者，请您作为新闻传播专家，帮助我解决新闻写作、信息验证、采访技巧、媒体伦理、数据新闻等方面的问题。请提供符合新闻专业规范的建议，坚持真实、客观、平衡的新闻价值观。"
    };

    // 检查是否有未完成的请求
    function checkPendingRequest() {
        const pendingRequest = localStorage.getItem(PENDING_REQUEST_KEY);
        if (pendingRequest) {
            try {
                const requestData = JSON.parse(pendingRequest);
                if (requestData.sessionId === sessionId) {
                    // 确认是否要恢复之前的请求
                    if (confirm('发现您之前有一个未完成的对话，是否要继续？')) {
                        // 如果用户确认，将消息添加到输入框并触发发送
                        userInput.value = requestData.message;
                        setTimeout(() => handleChat(), 500);
                    }
                }
                // 无论如何都清除这个记录
                localStorage.removeItem(PENDING_REQUEST_KEY);
            } catch (e) {
                console.error('解析未完成请求数据失败:', e);
                localStorage.removeItem(PENDING_REQUEST_KEY);
            }
        }
    }

    // 监听页面可见性变化
    document.addEventListener('visibilitychange', function() {
        pageIsVisible = document.visibilityState === 'visible';
        console.log('页面可见性变化：', pageIsVisible ? '可见' : '不可见');
        
        // 如果页面重新变为可见，并且之前有未完成的响应，可以显示状态提示
        if (pageIsVisible && aiResponseInProgress) {
            // 显示一个提示，告知用户响应仍在继续
            displayStatusMessage('AI响应正在继续处理...', 'status');
        }
    });

    // 在页面即将卸载时保存请求状态
    window.addEventListener('beforeunload', function() {
        // 如果正在处理请求，保存当前状态
        if (aiResponseInProgress && userInput.value.trim()) {
            const pendingData = {
                sessionId: sessionId,
                message: userInput.value.trim(),
                timestamp: Date.now()
            };
            localStorage.setItem(PENDING_REQUEST_KEY, JSON.stringify(pendingData));
        }
    });

    // 显示状态消息
    function displayStatusMessage(message, type) {
        const statusDiv = document.createElement('div');
        statusDiv.className = `message ${type}`;
        statusDiv.textContent = message;
        chatMessages.appendChild(statusDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
        
        // 状态消息在2秒后自动移除
        setTimeout(() => {
            statusDiv.remove();
        }, 2000);
    }

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
        langPrefix: 'hljs language-',
        headerIds: false,
        mangle: false,
        // 禁用自动链接转换，防止代码中的URL被转换
        smartypants: false
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
            // 检查是否有未完成的请求
            checkPendingRequest();
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
        
        // 如果正在获取AI回复，先取消
        if (currentController) {
            currentController.abort();
            currentController = null;
            aiResponseInProgress = false;
            stopButton.style.display = 'none';
            sendButton.disabled = false;
        }
        
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
        console.log('创建新会话');
        
        // 如果正在获取AI回复，先取消
        if (currentController) {
            currentController.abort();
            currentController = null;
            aiResponseInProgress = false;
            stopButton.style.display = 'none';
            sendButton.disabled = false;
        }
        
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
        
        console.log('新会话创建完成：', id);
    }

    // 复制消息内容到剪贴板
    function copyMessageToClipboard(message) {
        navigator.clipboard.writeText(message).then(function() {
            displayStatusMessage('已复制到剪贴板', 'status');
        }).catch(function(err) {
            console.error('复制失败:', err);
            displayStatusMessage('复制失败', 'error');
        });
    }

    // 重发消息
    function resendMessage(message) {
        userInput.value = message;
        userInput.style.height = 'auto';
        userInput.style.height = (userInput.scrollHeight) + 'px';
        handleChat();
    }

    // 处理特殊markdown格式，预处理一些可能导致渲染问题的模式
    function preprocessMarkdown(markdown) {
        if (!markdown) return '';
        
        // 保护代码块中的内容，防止被错误解析
        let codeBlocks = [];
        let processedMarkdown = markdown.replace(/```([a-z]*)\n([\s\S]*?)```/g, function(match, language, code) {
            // 存储代码块，替换为占位符
            const placeholder = `__CODE_BLOCK_${codeBlocks.length}__`;
            codeBlocks.push({ language, code, placeholder });
            return placeholder;
        });
        
        // 处理其他可能导致问题的模式
        // 例如，确保markdown分隔符不会被错误解析
        processedMarkdown = processedMarkdown
            .replace(/\[VISION-START\]/g, '\\[VISION-START\\]')
            .replace(/\[VISION-END\]/g, '\\[VISION-END\\]');
        
        // 还原代码块
        codeBlocks.forEach(block => {
            processedMarkdown = processedMarkdown.replace(
                block.placeholder, 
                '```' + block.language + '\n' + block.code + '```'
            );
        });
        
        return processedMarkdown;
    }

    function displayMessage(message, role) {
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${role}`;
        
        if (role === 'ai') {
            // 预处理markdown内容，处理特殊情况
            const preprocessedMarkdown = preprocessMarkdown(message);
            
            // 渲染markdown
            const renderedContent = marked.parse(preprocessedMarkdown);
            messageDiv.innerHTML = renderedContent;

            // 为所有代码块添加复制按钮
            messageDiv.querySelectorAll('pre code').forEach(function(block) {
                const pre = block.parentNode;
                // 检查是否已经被包装
                if (pre.parentNode.className === 'code-block-wrapper') {
                    return;
                }
                
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
            // 创建消息内容容器
            const contentDiv = document.createElement('div');
            contentDiv.className = 'message-content';
            contentDiv.textContent = message;
            messageDiv.appendChild(contentDiv);
            
            // 创建消息操作按钮容器
            const actionsDiv = document.createElement('div');
            actionsDiv.className = 'message-actions';
            
            // 复制按钮
            const copyBtn = document.createElement('button');
            copyBtn.className = 'message-action-btn copy-message-btn';
            copyBtn.innerHTML = '<i class="fas fa-copy"></i>';
            copyBtn.title = '复制消息';
            copyBtn.addEventListener('click', () => copyMessageToClipboard(message));
            
            // 重发按钮
            const resendBtn = document.createElement('button');
            resendBtn.className = 'message-action-btn resend-message-btn';
            resendBtn.innerHTML = '<i class="fas fa-redo-alt"></i>';
            resendBtn.title = '重新发送';
            resendBtn.addEventListener('click', () => resendMessage(message));
            
            actionsDiv.appendChild(copyBtn);
            actionsDiv.appendChild(resendBtn);
            messageDiv.appendChild(actionsDiv);
        }
        
        // 添加到聊天界面
        chatMessages.appendChild(messageDiv);
        
        // 滚动到最新消息
        chatMessages.scrollTop = chatMessages.scrollHeight;
    }

    // 更新AI响应流式显示
    function updateAIResponse(aiMessageDiv, content) {
        // 预处理markdown内容
        const preprocessedMarkdown = preprocessMarkdown(content);
        
        // 使用完整配置的marked解析，确保代码块正确渲染
        const renderedContent = marked.parse(preprocessedMarkdown);
        aiMessageDiv.innerHTML = renderedContent;
        
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
        userInput.style.height = 'auto';
        
        // 禁用发送按钮，显示停止按钮
        sendButton.disabled = true;
        stopButton.style.display = 'inline-block';
        
        // 创建一个AI消息div用于显示打字效果
        const aiMessageDiv = document.createElement('div');
        aiMessageDiv.className = 'message ai typing';
        chatMessages.appendChild(aiMessageDiv);
        
        // 添加正在输入的指示
        aiMessageDiv.innerHTML = '<div class="typing-indicator"><span></span><span></span><span></span></div>';
        chatMessages.scrollTop = chatMessages.scrollHeight;
        
        // 保存当前请求状态到 localStorage
        const pendingData = {
            sessionId: sessionId,
            message: message,
            timestamp: Date.now()
        };
        localStorage.setItem(PENDING_REQUEST_KEY, JSON.stringify(pendingData));
        
        // 重置当前响应文本
        currentResponseText = '';
        aiResponseInProgress = true;
        
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
            
            // 获取场景提示词
            const selectedPrompt = promptSelect.value;
            if (selectedPrompt && PROMPT_TEMPLATES[selectedPrompt]) {
                requestData.system_prompt = PROMPT_TEMPLATES[selectedPrompt];
            }
            
            // 发起聊天请求
            const response = await fetch(`${API_BASE_URL}${endpoints.chat}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(requestData),
                signal: currentController.signal
            });
            
            if (!response.ok) {
                throw new Error(`请求失败: ${response.status}`);
            }
            
            const reader = response.body.getReader();
            const decoder = new TextDecoder('utf-8');
            
            // 移除等待指示器
            aiMessageDiv.classList.remove('typing');
            aiMessageDiv.innerHTML = '';
            
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
                            currentResponseText += parsed.reply;
                            
                            // 检测是否在代码块内
                            if (parsed.reply.includes('```')) {
                                inCodeBlock = !inCodeBlock;
                            }
                            
                            // 更新AI响应显示
                            updateAIResponse(aiMessageDiv, currentResponseText);
                        }
                    } catch (e) {
                        console.error('解析消息失败:', e, line);
                    }
                }
                
                // 如果页面不可见但流仍在继续，在控制台记录一下
                if (!pageIsVisible) {
                    console.log('页面不可见，但流式响应仍在继续...');
                }
            }
            
            // 流式响应完成
            aiResponseInProgress = false;
            
            // 清除正在处理的请求记录
            localStorage.removeItem(PENDING_REQUEST_KEY);
            
            // 添加到历史记录
            if (currentResponseText) {
                messageHistory.push({
                    role: 'assistant',
                    content: currentResponseText
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
                // 移除打字指示器，显示已取消
                aiMessageDiv.classList.remove('typing');
                aiMessageDiv.textContent = '对话已取消';
                // 清除正在处理的请求记录
                localStorage.removeItem(PENDING_REQUEST_KEY);
            } else {
                console.error('聊天请求失败:', error);
                // 移除打字指示器，显示错误
                aiMessageDiv.classList.remove('typing');
                aiMessageDiv.textContent = `发生错误: ${error.message}`;
            }
            aiResponseInProgress = false;
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
        if (!selectedTemplate || !PROMPT_TEMPLATES[selectedTemplate]) {
            // 如果没有选择场景，仅显示提示
            promptSelect.title = "选择专业场景可以获得更专业的回答";
            return;
        }
        
        // 获取提示词模板
        const templateText = PROMPT_TEMPLATES[selectedTemplate];
        
        // 设置工具提示，展示部分提示词内容
        promptSelect.title = templateText.substring(0, 100) + "...";
    }

    // 事件监听
    if (newChatButton) {
        console.log('绑定主要新建聊天按钮事件');
        newChatButton.addEventListener('click', createNewSession);
    }
    
    if (newChatSidebarButton) {
        console.log('绑定侧边栏新建聊天按钮事件');
        newChatSidebarButton.addEventListener('click', createNewSession);
    }
    
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
            // 清除正在处理的请求记录
            localStorage.removeItem(PENDING_REQUEST_KEY);
        }
    });
    
    promptSelect.addEventListener('change', applyPromptTemplate);

    // 添加全屏按钮点击事件
    fullscreenBtn.addEventListener('click', toggleFullscreen);

    // 添加输入框自动调整高度
    userInput.addEventListener('input', function() {
        this.style.height = 'auto';
        this.style.height = (this.scrollHeight) + 'px';
    });

    // 添加CSS样式
    const style = document.createElement('style');
    style.textContent = `
        /* 分别设置AI消息和用户消息的背景样式 */
        .message.ai {
            /* 保持AI消息的原始样式 */
        }
        
        .message.user {
            background-color: rgba(40, 44, 52, 0.7) !important;
            color: #abb2bf !important;
            border: 1px solid rgba(60, 64, 72, 0.6) !important;
            box-shadow: 0 2px 6px rgba(0, 0, 0, 0.3) !important;
            position: relative;
            padding-right: 35px; /* 为操作按钮留出空间 */
        }
        
        /* 消息内容区域保持透明 */
        .message-content {
            background-color: transparent !important;
            white-space: pre-wrap; /* 保留用户消息中的换行 */
            word-break: break-word;
            color: #abb2bf !important;
        }

        .typing-indicator {
            display: inline-flex;
            align-items: center;
        }
        
        .typing-indicator span {
            height: 8px;
            width: 8px;
            margin: 0 2px;
            background-color: #abb2bf;
            border-radius: 50%;
            display: inline-block;
            animation: bounce 1.3s ease infinite;
        }
        
        .typing-indicator span:nth-child(2) {
            animation-delay: 0.15s;
        }
        
        .typing-indicator span:nth-child(3) {
            animation-delay: 0.3s;
        }
        
        @keyframes bounce {
            0%, 100% { transform: translateY(0); }
            50% { transform: translateY(-5px); }
        }
        
        .message.status {
            background-color: rgba(255, 193, 7, 0.2);
            color: #ffc107;
            font-style: italic;
            padding: 5px 10px;
            margin: 5px 0;
            border-radius: 4px;
            font-size: 0.9em;
        }

        .message.error {
            background-color: rgba(231, 76, 60, 0.2);
            color: #e74c3c;
            font-style: italic;
            padding: 5px 10px;
            margin: 5px 0;
            border-radius: 4px;
            font-size: 0.9em;
        }

        .message-actions {
            position: absolute;
            right: 8px;
            top: 50%;
            transform: translateY(-50%);
            display: flex;
            flex-direction: column;
            gap: 5px;
            opacity: 0;
            transition: opacity 0.2s ease;
        }

        .message.user:hover .message-actions {
            opacity: 1;
        }

        .message-action-btn {
            width: 24px;
            height: 24px;
            border-radius: 50%;
            border: none;
            background-color: rgba(255, 255, 255, 0.2);
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: all 0.2s ease;
        }

        .copy-message-btn:hover {
            background-color: rgba(52, 152, 219, 0.7);
        }

        .resend-message-btn:hover {
            background-color: rgba(46, 204, 113, 0.7);
        }

        /* 全屏相关样式 */
        .fullscreen-btn {
            position: fixed;
            right: 20px;
            bottom: 30px;
            z-index: 10000;
            width: 45px;
            height: 45px;
            border-radius: 50%;
            background-color: rgba(61, 90, 254, 0.8);
            border: 2px solid rgba(255, 255, 255, 0.5);
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
            font-size: 18px;
        }
        
        .fullscreen-btn:hover {
            background-color: rgba(61, 90, 254, 1);
            transform: scale(1.1);
            box-shadow: 0 6px 16px rgba(0, 0, 0, 0.5);
        }
        
        .fullscreen-btn i {
            text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
        }
        
        /* 全屏模式样式，保留页头页脚 */
        body.chat-fullscreen .sidebar {
            display: none !important;
        }
        
        body.chat-fullscreen .chat-content {
            width: 100% !important;
            max-width: 100% !important;
            padding: 0 !important;
        }
        
        /* 去除页面各部分之间的间距，但保留页头页脚 */
        .main-content {
            padding: 0 !important;
            display: flex;
            flex-direction: column;
            height: calc(100vh - 120px) !important; /* 减去页头页脚的高度 */
        }
        
        .chat-content {
            flex-grow: 1;
            padding: 0 !important;
            width: 100% !important;
            max-width: 100% !important;
        }
        
        #chat-container {
            margin: 0 !important;
            border-radius: 0 !important;
            height: 100% !important;
            display: flex;
            flex-direction: column;
        }
        
        #chat-messages {
            flex: 1;
            height: auto !important;
            overflow-y: auto;
        }
        
        .input-area {
            padding: 10px !important;
            border-top: 1px solid rgba(255, 255, 255, 0.1);
            background-color: rgba(30, 34, 42, 0.95);
        }
        
        /* 确保输入区域中的按钮正确显示 */
        .input-buttons {
            display: flex;
            align-items: center;
            margin-left: 10px;
        }
        
        .input-actions {
            display: flex;
            align-items: center;
        }
        
        /* 响应式调整 */
        @media (max-width: 768px) {
            .message.user {
                padding-right: 40px;
            }
            
            .message-actions {
                right: 5px;
            }
            
            .message-action-btn {
                width: 22px;
                height: 22px;
                font-size: 0.8em;
            }
            
            .fullscreen-btn {
                width: 32px;
                height: 32px;
            }
            
            .main-content {
                height: calc(100vh - 100px) !important; /* 移动设备上可能页头页脚更小 */
            }
        }

        /* 增强代码块样式 */
        .code-block-wrapper {
            margin: 10px 0;
            border-radius: 6px;
            overflow: hidden;
            background-color: #282c34;
        }
        
        .code-block-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            background-color: #21252b;
            padding: 5px 10px;
            border-bottom: 1px solid #181a1f;
        }
        
        .code-lang-tag {
            font-size: 0.8em;
            color: #abb2bf;
        }
        
        .copy-button {
            background-color: transparent;
            border: 1px solid #4d78cc;
            color: #4d78cc;
            border-radius: 4px;
            padding: 2px 8px;
            font-size: 0.8em;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .copy-button:hover {
            background-color: #4d78cc;
            color: white;
        }
        
        pre {
            margin: 0;
            padding: 15px;
            overflow-x: auto;
            background-color: #282c34 !important;
        }
        
        pre code {
            background-color: transparent !important;
            padding: 0 !important;
            border: none !important;
            white-space: pre-wrap !important;
            font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, Courier, monospace !important;
        }
        
        /* 确保代码中的注释文字不会被错误解析 */
        pre code .hljs-comment {
            color: #5c6370;
            font-style: italic;
        }
        
        /* 自定义特殊标记样式 */
        .message code {
            background-color: rgba(40, 44, 52, 0.5);
            padding: 2px 4px;
            border-radius: 3px;
            font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, Courier, monospace;
        }
        
        /* 确保markdown中的表格正确显示 */
        .message table {
            border-collapse: collapse;
            margin: 15px 0;
            width: 100%;
        }
        
        .message th, .message td {
            border: 1px solid #4d5666;
            padding: 8px 12px;
            text-align: left;
        }
        
        .message th {
            background-color: #2c313a;
        }
        
        .message tr:nth-child(even) {
            background-color: #2c313a;
        }
        
        /* 适配响应式布局中的代码块 */
        @media (max-width: 768px) {
            .code-block-wrapper {
                margin: 8px 0;
            }
            
            pre {
                padding: 10px;
                font-size: 0.9em;
            }
            
            .code-block-header {
                padding: 4px 8px;
            }
        }
        
        /* 确保重发和复制按钮始终可见 */
        .message.user:hover .message-actions {
            opacity: 1;
        }
        
        .message-actions {
            position: absolute;
            right: 8px;
            top: 50%;
            transform: translateY(-50%);
            display: flex;
            flex-direction: column;
            gap: 5px;
            opacity: 0;
            transition: opacity 0.2s ease;
        }
    `;
    document.head.appendChild(style);

    // 处理全屏切换
    function toggleFullscreen() {
        isFullscreen = !isFullscreen;
        
        if (isFullscreen) {
            // 进入全屏模式
            document.body.classList.add('chat-fullscreen');
            fullscreenBtn.innerHTML = '<i class="fas fa-compress"></i>';
            fullscreenBtn.title = '退出全屏';
            
            // 如果存在侧边栏，隐藏它
            const sidebar = document.querySelector('.sidebar');
            if (sidebar) {
                sidebar.dataset.originalDisplay = sidebar.style.display || 'block';
                sidebar.style.display = 'none';
            }
            
            console.log('进入全屏模式');
        } else {
            // 退出全屏模式
            document.body.classList.remove('chat-fullscreen');
            fullscreenBtn.innerHTML = '<i class="fas fa-expand"></i>';
            fullscreenBtn.title = '全屏模式';
            
            // 恢复侧边栏显示
            const sidebar = document.querySelector('.sidebar');
            if (sidebar) {
                // 确保使用有效的显示值
                const originalDisplay = sidebar.dataset.originalDisplay || 'block';
                sidebar.style.display = originalDisplay !== 'none' ? originalDisplay : 'block';
                console.log('恢复侧边栏显示:', originalDisplay);
            }
            
            // 确保其他样式恢复
            const chatContent = document.querySelector('.chat-content');
            if (chatContent) {
                // 重置可能被修改的样式
                chatContent.style.width = '';
                chatContent.style.maxWidth = '';
            }
            
            console.log('退出全屏模式');
        }
        
        // 重新滚动到底部
        if (chatMessages) {
            chatMessages.scrollTop = chatMessages.scrollHeight;
        }
        
        // 等待DOM更新后再次检查样式恢复情况
        setTimeout(() => {
            if (!isFullscreen) {
                const sidebar = document.querySelector('.sidebar');
                if (sidebar && sidebar.style.display === 'none') {
                    console.log('强制恢复侧边栏显示');
                    sidebar.style.display = 'block';
                }
            }
        }, 100);
    }
    
    // 监听ESC键退出全屏
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && isFullscreen) {
            toggleFullscreen();
        }
    });

    // 初始化
    fetchModels();
    initSessionsManagement();

    console.log('聊天功能初始化完成');
});