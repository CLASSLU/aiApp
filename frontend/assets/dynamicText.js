// 动态文字效果
const texts = [
    "让AI为你开启无限可能",
    "智能对话，实时响应",
    "创意生成，一键成型",
    "24小时智能助手随时待命"
];

let textIndex = 0;
let charIndex = 0;
let isDeleting = false;
let isPaused = false;

function typeWriter() {
    const welcomeText = document.querySelector('.welcome-text p');
    if (!welcomeText) return; // 确保元素存在

    const currentText = texts[textIndex];
    const typingSpeed = isDeleting ? 50 : 150; // 删除速度快一些
    const pauseTime = 2000; // 完整显示后暂停时间

    if (!isDeleting && !isPaused && charIndex < currentText.length) {
        // 正在输入
        welcomeText.textContent = currentText.substring(0, charIndex + 1);
        charIndex++;
    } else if (isDeleting && charIndex > 0) {
        // 正在删除
        welcomeText.textContent = currentText.substring(0, charIndex - 1);
        charIndex--;
    } else if (!isDeleting && charIndex >= currentText.length && !isPaused) {
        // 输入完成，暂停
        isPaused = true;
        setTimeout(() => {
            isPaused = false;
            isDeleting = true;
        }, pauseTime);
    } else if (isDeleting && charIndex === 0) {
        // 删除完成，切换到下一句
        isDeleting = false;
        textIndex = (textIndex + 1) % texts.length;
    }

    // 继续动画
    setTimeout(typeWriter, typingSpeed);
}

// 页面加载后开始动画
window.addEventListener('load', () => {
    // 确保欢迎文本区域已加载
    setTimeout(() => {
        const welcomeText = document.querySelector('.welcome-text p');
        if (welcomeText) {
            welcomeText.textContent = ''; // 清空初始文本
            typeWriter();
        }
    }, 1000); // 给页面加载一些时间
}); 