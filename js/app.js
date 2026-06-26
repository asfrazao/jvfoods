document.addEventListener('DOMContentLoaded', () => {
  const yearElement = document.getElementById('currentYear');
  const header = document.querySelector('[data-header]');
  const nav = document.getElementById('menu-principal');
  const navToggle = document.querySelector('.nav-toggle');
  const slides = Array.from(document.querySelectorAll('.hero-slide'));
  const prevButton = document.querySelector('[data-slider-prev]');
  const nextButton = document.querySelector('[data-slider-next]');
  const dotsContainer = document.querySelector('[data-slider-dots]');

  if (yearElement) {
    yearElement.textContent = new Date().getFullYear();
  }

  const setHeaderState = () => {
    if (!header) return;
    header.classList.toggle('is-scrolled', window.scrollY > 20);
  };

  setHeaderState();
  window.addEventListener('scroll', setHeaderState, { passive: true });

  if (nav && navToggle) {
    const closeMenu = () => {
      document.body.classList.remove('nav-open');
      nav.classList.remove('is-open');
      navToggle.setAttribute('aria-expanded', 'false');
      navToggle.setAttribute('aria-label', 'Abrir menu');
    };

    navToggle.addEventListener('click', () => {
      const isOpen = navToggle.getAttribute('aria-expanded') === 'true';

      document.body.classList.toggle('nav-open', !isOpen);
      nav.classList.toggle('is-open', !isOpen);
      navToggle.setAttribute('aria-expanded', String(!isOpen));
      navToggle.setAttribute('aria-label', isOpen ? 'Abrir menu' : 'Fechar menu');
    });

    nav.querySelectorAll('a').forEach((link) => {
      link.addEventListener('click', closeMenu);
    });

    window.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        closeMenu();
      }
    });
  }

  if (slides.length > 1 && dotsContainer) {
    let activeSlide = 0;
    let sliderTimer;

    const dots = slides.map((_, index) => {
      const dot = document.createElement('button');
      dot.type = 'button';
      dot.className = 'slider-dot';
      dot.setAttribute('aria-label', `Ir para o slide ${index + 1}`);
      dot.addEventListener('click', () => {
        showSlide(index);
        restartSlider();
      });
      dotsContainer.appendChild(dot);
      return dot;
    });

    const updateDots = () => {
      dots.forEach((dot, index) => {
        dot.classList.toggle('is-active', index === activeSlide);
        dot.setAttribute('aria-current', index === activeSlide ? 'true' : 'false');
      });
    };

    function showSlide(index) {
      activeSlide = (index + slides.length) % slides.length;
      slides.forEach((slide, slideIndex) => {
        slide.classList.toggle('is-active', slideIndex === activeSlide);
      });
      updateDots();
    }

    const nextSlide = () => showSlide(activeSlide + 1);
    const prevSlide = () => showSlide(activeSlide - 1);

    const restartSlider = () => {
      window.clearInterval(sliderTimer);
      sliderTimer = window.setInterval(nextSlide, 6000);
    };

    nextButton?.addEventListener('click', () => {
      nextSlide();
      restartSlider();
    });

    prevButton?.addEventListener('click', () => {
      prevSlide();
      restartSlider();
    });

    showSlide(0);
    restartSlider();
  }
});
