// Тема: сохранение в localStorage + системная по умолчанию
(function initTheme() {
  const saved = localStorage.getItem('wp-theme');
  const system = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  document.documentElement.dataset.theme = saved || system;
})();

document.getElementById('themeToggle').addEventListener('click', () => {
  const next = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
  document.documentElement.dataset.theme = next;
  localStorage.setItem('wp-theme', next);
});

// Reveal-анимации при скролле
const observer = new IntersectionObserver(
  (entries) => {
    for (const e of entries) {
      if (e.isIntersecting) {
        e.target.classList.add('visible');
        observer.unobserve(e.target);
      }
    }
  },
  { threshold: 0.12, rootMargin: '0px 0px -40px 0px' }
);
document.querySelectorAll('.reveal').forEach((el) => observer.observe(el));

// Лёгкий parallax для орбов в hero
const hero = document.querySelector('.hero');
if (hero && matchMedia('(pointer: fine)').matches) {
  hero.addEventListener('mousemove', (e) => {
    const { innerWidth: w, innerHeight: h } = window;
    const x = (e.clientX / w - 0.5) * 24;
    const y = (e.clientY / h - 0.5) * 24;
    hero.querySelector('.orb-blue').style.translate = `${x}px ${y}px`;
    hero.querySelector('.orb-teal').style.translate = `${-x}px ${-y}px`;
  });
}
