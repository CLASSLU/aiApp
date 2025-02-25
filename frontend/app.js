function showError(message) {
  alert(message); // 或者使用其他方式显示错误
}

function showResults(images) {
  const $result = $('#result');
  $result.empty().css('display', 'grid');  // 使用网格布局
  
  images.forEach((imgUrl, index) => {
    const card = `
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
  $('.btn-download').click(function() {
    const url = encodeURIComponent($(this).data('url'));
    window.open(`http://localhost:5000/api/download?url=${url}`);
  });
}

$(document).ready(function() {
  const $prompt = $('#prompt');
  const $generateBtn = $('#generateBtn');
  const $result = $('#result');
  const $model = $('#model');
  const $width = $('#width');
  const $height = $('#height');
  const $numImages = $('#numImages');
  const $guidanceScale = $('#guidanceScale');
  
  // 添加分辨率选择监听
  $('#resolution').change(function() {
      const val = $(this).val();
      $width.val(val);
      $height.val(val);
  });

  // 初始化分辨率
  $width.val(1024).trigger('change');

  $generateBtn.click(async function() {
      const params = {
          prompt: $prompt.val().trim(),
          model: $model.val(),
          width: parseInt($width.val()),
          height: parseInt($height.val()),
          num_images: parseInt($numImages.val()),
          guidance_scale: parseFloat($guidanceScale.val())
      };
      
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
      
      try {
          const payload = {
              prompt: params.prompt,
              model: params.model,
              width: params.width,
              height: params.width,
              num_images: params.num_images,
              guidance_scale: params.guidance_scale,
              steps: 4,
              batch_size: params.num_images
          };
          
          const response = await fetch('http://localhost:5000/api/generate', {
              method: 'POST',
              headers: {
                  'Content-Type': 'application/json',
                  'X-Request-Source': 'webapp/1.0.0'
              },
              body: JSON.stringify(payload)
          });
          
          if (!response.ok) {
              const errorData = await response.json();
              throw new Error(errorData.error || '生成失败');
          }
          
          const data = await response.json();
          if (data.images && data.images.length > 0) {
              showResults(data.images);
          } else {
              showError('未生成有效图片');
          }
      } catch (error) {
          showError(error.message);
      } finally {
          $generateBtn.prop('disabled', false).text('生成');
      }
  });

  // 随机选择示例提示词并填充到输入框
  const examplePrompts = [
      '赛博朋克风格的城市夜景，霓虹灯光映照在湿润的街道上，飞行汽车穿梭于摩天大楼之间',
      '中国山水画风格的太空站，云雾缭绕间露出金属结构，远处有卫星环绕',
      '蒸汽朋克风格的机械蝴蝶，黄铜齿轮精密咬合，蒸汽从关节处缓缓溢出',
      '超现实主义的沙漠绿洲，镜面湖泊倒映着扭曲的星空，棕榈树呈现水晶质感',
      '未来主义生态建筑，东京市中心垂直花园大厦，每层都有瀑布般的植物群落',
      '雪豹栖息在喜马拉雅山崖，风雪环绕中毛发细节清晰可见，背景雾霭笼罩群峰'
  ];
  const randomPrompt = examplePrompts[Math.floor(Math.random() * examplePrompts.length)];
  $prompt
    .val(randomPrompt)  // 设置输入框默认值
    .attr('placeholder', `例如：${randomPrompt}`);  // 更新占位符保持一致性

  // 添加动态提示建议
  function showPromptSuggestions() {
      const suggestions = [
          '尝试包含：材质描述（如"磨砂金属"、"玻璃质感"）',
          '建议添加：环境光线（如"晨光柔和"、"霓虹眩光"）',
          '可指定：艺术风格（如"印象派"、"赛博朋克"）',
          '推荐包含：构图视角（如"鸟瞰视角"、"微距特写"）'
      ];
      
      $('#promptSuggestions').html(`
          <div class="text-start small mt-2">
              <div class="text-muted">提示词优化建议：</div>
              ${suggestions.map(s => `<div>· ${s}</div>`).join('')}
          </div>
      `);
  }

  // 在输入框获得焦点时显示
  $prompt.focus(showPromptSuggestions);

  // 第一步：设置全局配置
  bootstrap.Tooltip.Default.sanitize = false;
  bootstrap.Tooltip.Default.allowList = {
      '*': {
          'class': true,
          'style': true,
          'data-*': true
      }
  };

  // 第二步：初始化工具提示
  const initTooltips = () => {
      document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(el => {
          new bootstrap.Tooltip(el, {
              placement: 'right',
              trigger: 'hover',
              html: true,
              sanitize: false,
              container: 'body'
          });
      });
  };
  initTooltips();

  // 添加模型切换监听
  $model.change(function() {
      const isFlux = $(this).val().includes('FLUX');
      $('#guidanceScale').prop('disabled', isFlux ? false : true)
          .closest('.form-group').toggle(isFlux);
  });

  // 保留原有的事件监听代码
  // document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(el => {
  //     el.addEventListener('shown.bs.tooltip', () => {
  //         console.log('工具提示已显示:', el);
  //     });
  //     el.addEventListener('hidden.bs.tooltip', () => {
  //         console.log('工具提示已隐藏:', el);
  //     });
  // });
});

async function generateImage() {
    const payload = {
        prompt: "A cute cat wearing sunglasses",
        model: "black-forest-labs/FLUX.1-schnell",
        width: 1024,
        height: 1024,
        num_images: 1,
        guidance_scale: 4.0
    };

    try {
        const response = await fetch('http://localhost:5000/api/generate', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Request-Source': 'webapp/1.0.0'
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || '生成失败');
        }

        const data = await response.json();
        console.log(data);
    } catch (error) {
        console.error('Error:', error);
    }
}