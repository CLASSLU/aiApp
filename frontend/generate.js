// 使用统一配置
const { API_BASE_URL, endpoints, fetchApi } = window.APP_CONFIG;

function getApiBaseUrl() {
    // 优先使用环境变量中配置的 API URL
    if (window.API_URL) {
        return window.API_URL;
    }
    
    // 开发环境配置
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        return 'http://localhost:5000';
    }
    
    // 生产环境配置
    return window.location.origin;  // 使用当前域名，假设API和前端在同一域名下
}

function showError(message) {
    const errorDiv = document.getElementById('error-message');
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
    setTimeout(() => {
        errorDiv.style.display = 'none';
    }, 5000);
}

function showResults(images) {
    var $result = $('#result');
    $result.empty().css('display', 'grid');
    
    images.forEach(function(imgUrl, index) {
        var card = `
            <div class="image-card">
                <img src="${imgUrl}" class="generated-image">
                <div class="image-actions">
                    <button class="btn-download" data-url="${imgUrl}">
                        <i class="fas fa-download"></i>
                    </button>
                    <button class="btn-share" data-url="${imgUrl}">
                        <i class="fas fa-share"></i>
                    </button>
                </div>
                <span class="image-number">#${index + 1}</span>
            </div>
        `;
        $result.append(card);
    });
    
    // 添加下载事件监听
    $('.btn-download').click(function(e) {
        e.preventDefault();
        var imgUrl = $(this).data('url');
        downloadImage(imgUrl);
    });
}

// 统一的图片下载函数
async function downloadImage(imgUrl) {
    try {
        // 显示下载中的状态
        showError('正在准备下载...');
        
        // 创建一个隐藏的 iframe 来处理下载
        // 这样可以避免跨域问题并直接触发浏览器的下载行为
        const downloadUrl = `${API_BASE_URL}/api/download?url=${encodeURIComponent(imgUrl)}`;
        
        // 方法1：使用窗口打开方式（最简单可靠）
        window.open(downloadUrl, '_blank');
        
        // 更新状态
        showError('下载已开始，请检查您的下载文件夹');
    } catch (error) {
        console.error('下载出错:', error);
        showError('下载失败，请重试');
    }
}

// 添加下载按钮到图片旁边
function addDownloadButton(imgUrl) {
    const img = document.createElement('img');
    img.src = imgUrl;
    
    const downloadBtn = document.createElement('a');
    downloadBtn.href = '#';
    downloadBtn.className = 'download-btn';
    downloadBtn.innerHTML = '<i class="fas fa-download"></i>';
    downloadBtn.onclick = (e) => {
        e.preventDefault();
        downloadImage(imgUrl);
    };

    const wrapper = document.createElement('div');
    wrapper.className = 'image-wrapper';
    wrapper.appendChild(img);
    wrapper.appendChild(downloadBtn);
    
    document.getElementById('result').appendChild(wrapper);
}

$(document).ready(function() {
    var $prompt = $('#prompt');
    var $generateBtn = $('#generateBtn');
    var $model = $('#model');
    var $width = $('#width');
    var $height = $('#height');
    var $numImages = $('#numImages');
    var $guidanceScale = $('#guidanceScale');
    
    // 添加分辨率选择监听
    $('#resolution').change(function() {
        var val = $(this).val();
        $width.val(val);
        $height.val(val);
    });

    // 初始化分辨率
    $width.val(1024).trigger('change');

    $generateBtn.click(function() {
        var params = {
            prompt: $prompt.val().trim(),
            model: $model.val(),
            width: parseInt($width.val()),
            height: parseInt($height.val()),
            num_images: parseInt($numImages.val()),
            guidance_scale: parseFloat($guidanceScale.val())
        };
        
        // 参数验证
        if (!params.prompt) {
            showError('请输入图片描述');
            return;
        }
        if ([512, 768, 1024].indexOf(params.width) === -1) {
            showError('分辨率只支持512/768/1024');
            return;
        }
        if (params.num_images < 1 || params.num_images > 4) {
            showError('生成数量需在1-4之间');
            return;
        }
        if (params.width !== params.height) {
            showError('宽高必须相同');
            return;
        }
        if (!params.model.includes('/')) {
            showError('模型格式不正确');
            return;
        }
        if ($model.val().includes('FLUX') && (params.guidance_scale < 3.8 || params.guidance_scale > 4.2)) {
            showError('FLUX模型的引导比例需在3.8-4.2之间');
            return;
        }
        
        $generateBtn.prop('disabled', true).text('生成中...');
        
        fetchApi(endpoints.generate, {
            method: 'POST',
            headers: {
                'X-Request-Source': 'webapp',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(params)
        }).then(function(response) {
            if (!response.ok) {
                return response.json().then(data => {
                    throw new Error(data.error || '生成失败');
                });
            }
            return response.json();
        }).then(function(data) {
            if (data.images && data.images.length > 0) {
                showResults(data.images);
            } else {
                showError('未生成有效图片');
            }
        }).catch(function(error) {
            showError(error.message);
        }).finally(function() {
            $generateBtn.prop('disabled', false).text('生成');
        });
    });

    // 示例提示词
    var examplePrompts = [
        '赛博朋克风格的城市夜景，霓虹灯光映照在湿润的街道上，飞行汽车穿梭于摩天大楼之间',
        '中国山水画风格的太空站，云雾缭绕间露出金属结构，远处有卫星环绕',
        '蒸汽朋克风格的机械蝴蝶，黄铜齿轮精密咬合，蒸汽从关节处缓缓溢出',
        '超现实主义的沙漠绿洲，镜面湖泊倒映着扭曲的星空，棕榈树呈现水晶质感',
        '未来主义生态建筑，东京市中心垂直花园大厦，每层都有瀑布般的植物群落',
        '雪豹栖息在喜马拉雅山崖，风雪环绕中毛发细节清晰可见，背景雾霭笼罩群峰'
    ];
    
    var randomPrompt = examplePrompts[Math.floor(Math.random() * examplePrompts.length)];
    $prompt
        .val(randomPrompt)
        .attr('placeholder', '例如：' + randomPrompt);

    // 提示词建议
    function showPromptSuggestions() {
        var suggestions = [
            '尝试包含：材质描述（如"磨砂金属"、"玻璃质感"）',
            '建议添加：环境光线（如"晨光柔和"、"霓虹眩光"）',
            '可指定：艺术风格（如"印象派"、"赛博朋克"）',
            '推荐包含：构图视角（如"鸟瞰视角"、"微距特写"）'
        ];
        
        $('#promptSuggestions').html([
            '<div class="text-start small mt-2">',
            '<div class="text-muted">提示词优化建议：</div>',
            suggestions.map(function(s) { return '<div>· ' + s + '</div>'; }).join(''),
            '</div>'
        ].join(''));
    }

    $prompt.focus(showPromptSuggestions);

    // 初始化工具提示
    bootstrap.Tooltip.Default.sanitize = false;
    bootstrap.Tooltip.Default.allowList = {
        '*': {
            'class': true,
            'style': true,
            'data-*': true
        }
    };

    function initTooltips() {
        document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(function(el) {
            new bootstrap.Tooltip(el, {
                placement: 'right',
                trigger: 'hover',
                html: true,
                sanitize: false,
                container: 'body'
            });
        });
    }
    initTooltips();

    // 模型相关事件监听
    $model.change(function() {
        var isFlux = $(this).val().includes('FLUX');
        $('#guidanceScale').prop('disabled', !isFlux)
            .closest('.form-group').toggle(isFlux);
    });

    // 回车事件监听
    $prompt.keypress(function(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            $generateBtn.click();
        }
    });
});

// 添加回车事件监听
document.getElementById('prompt').addEventListener('keypress', function (event) {
    if (event.key === 'Enter') {
        event.preventDefault(); // 防止默认行为
        document.getElementById('generateBtn').click(); // 触发生成按钮的点击事件
    }
});

// 更新生成图片的显示方式
function displayImages(images) {
    const resultDiv = document.getElementById('result');
    resultDiv.innerHTML = '';
    images.forEach(imgUrl => addDownloadButton(imgUrl));
}