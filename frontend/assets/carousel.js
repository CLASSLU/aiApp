let currentIndex = 0;
const items = document.querySelectorAll('.carousel-item');

function showNextItem() {
  items[currentIndex].style.transform = 'translateX(-100%)';
  currentIndex = (currentIndex + 1) % items.length;
  items[currentIndex].style.transform = 'translateX(0)';
}

setInterval(showNextItem, 3000);