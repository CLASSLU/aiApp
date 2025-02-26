document.addEventListener('DOMContentLoaded', function() {
    let currentIndex = 0;
    const items = document.querySelectorAll('.carousel-item');
    
    // 初始化第一张图片
    items[0].classList.add('active');
    items[1].classList.add('next');
    items[items.length - 1].classList.add('prev');

    function showNextItem() {
        // 移除所有类
        items.forEach(item => {
            item.classList.remove('active', 'prev', 'next');
        });

        // 设置新的类
        items[currentIndex].classList.add('active');
        items[(currentIndex + 1) % items.length].classList.add('next');
        items[(currentIndex - 1 + items.length) % items.length].classList.add('prev');

        // 更新索引
        currentIndex = (currentIndex + 1) % items.length;
    }

    // 每3秒切换一次
    setInterval(showNextItem, 3000);
});