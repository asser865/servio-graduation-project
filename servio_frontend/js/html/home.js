document.addEventListener('DOMContentLoaded', () => {
  // ── Hero search navigation ─────────────────────────────────────────────
  const heroInput = document.querySelector('.hero-search__input');
  const heroBtn   = document.querySelector('.hero-search__btn');

  function navigateToMarketplace() {
    const q = heroInput ? heroInput.value.trim() : '';
    window.location.href = q
      ? `./services-marketplace.html?q=${encodeURIComponent(q)}`
      : './services-marketplace.html';
  }

  if (heroBtn)   heroBtn.addEventListener('click', navigateToMarketplace);
  if (heroInput) heroInput.addEventListener('keydown', e => { if (e.key === 'Enter') navigateToMarketplace(); });

  // ── Elite Network carousel ────────────────────────────────────────────
  const eliteScroll = document.querySelector('#elite-scroll');
  const elitePrev = document.querySelector('.elite-carousel__btn--prev');
  const eliteNext = document.querySelector('.elite-carousel__btn--next');

  function eliteScrollStep() {
    if (!eliteScroll) return 360;
    const card = eliteScroll.querySelector('.elite-card');
    if (!card) return 360;
    const gapStr = getComputedStyle(eliteScroll).gap;
    const gap = parseFloat(gapStr) || 24;
    return card.offsetWidth + gap;
  }

  function updateEliteCarouselButtons() {
    if (!eliteScroll || !elitePrev || !eliteNext) return;
    const el = eliteScroll;
    const max = Math.max(0, el.scrollWidth - el.clientWidth);
    if (max <= 0) {
      elitePrev.disabled = true;
      eliteNext.disabled = true;
      return;
    }
    const sl = el.scrollLeft;
    const rtl = getComputedStyle(el).direction === 'rtl';
    const tol = 6;
    let atStart;
    let atEnd;
    if (rtl && sl <= 0) {
      atStart = sl >= -tol;
      atEnd = sl <= -max + tol;
    } else if (rtl && sl > 0) {
      atStart = sl <= tol;
      atEnd = sl >= max - tol;
    } else {
      atStart = sl <= tol;
      atEnd = sl >= max - tol;
    }
    elitePrev.disabled = atStart;
    eliteNext.disabled = atEnd;
  }

  function scrollElite(direction) {
    if (!eliteScroll) return;
    const step = eliteScrollStep();
    const rtl = getComputedStyle(eliteScroll).direction === 'rtl';
    const delta = (rtl ? -direction : direction) * step;
    eliteScroll.scrollBy({ left: delta, behavior: 'smooth' });
  }

  if (eliteScroll && elitePrev && eliteNext) {
    elitePrev.addEventListener('click', () => scrollElite(-1));
    eliteNext.addEventListener('click', () => scrollElite(1));
    eliteScroll.addEventListener('scroll', () => requestAnimationFrame(updateEliteCarouselButtons), { passive: true });
    window.addEventListener('resize', () => requestAnimationFrame(updateEliteCarouselButtons), { passive: true });
    updateEliteCarouselButtons();
  }

  // Section indicator scroll spy
  const indicatorLinks = Array.from(document.querySelectorAll('[data-home-indicator-link]'));
  const sectionMap = indicatorLinks
    .map(link => {
      const id = link.getAttribute('href');
      if (!id || !id.startsWith('#')) return null;
      const section = document.querySelector(id);
      return section ? { link, section } : null;
    })
    .filter(Boolean);

  function setActiveIndicator(activeLink) {
    indicatorLinks.forEach(link => {
      const isActive = link === activeLink;
      link.classList.toggle('is-active', isActive);
      if (isActive) {
        link.setAttribute('aria-current', 'true');
      } else {
        link.removeAttribute('aria-current');
      }
    });
  }

  if (sectionMap.length) {
    const observer = new IntersectionObserver(entries => {
      const visibleEntries = entries
        .filter(entry => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio);

      if (!visibleEntries.length) return;

      const activeEntry = visibleEntries[0];
      const activeItem = sectionMap.find(item => item.section === activeEntry.target);
      if (activeItem) setActiveIndicator(activeItem.link);
    }, {
      root: null,
      threshold: [0.3, 0.5, 0.7],
      rootMargin: '-18% 0px -32% 0px'
    });

    sectionMap.forEach(item => observer.observe(item.section));

    indicatorLinks.forEach(link => {
      link.addEventListener('click', () => setActiveIndicator(link));
    });
  }
});

// .
