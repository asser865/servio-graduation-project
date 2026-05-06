import { getServices } from '../api/services.js';

// ── 6 main service categories shown on the homepage ───────────────────────
const HOME_CATEGORIES = [
  {
    key: 'plumbing',
    cssClass: 'category-card--plumbing',
    label: 'Plumbing',
    desc: 'Pipe repairs, leak fixes & water systems',
    emoji: '🔧',
    icon: `<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z"></path><path d="M12.56 6.6A10.97 10.97 0 0 0 14 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 0 1-11.91 4.97"></path></svg>`,
  },
  {
    key: 'electrical',
    cssClass: 'category-card--electrical',
    label: 'Electrical',
    desc: 'Wiring, panels, outlets & lighting',
    emoji: '⚡',
    icon: `<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"></path></svg>`,
  },
  {
    key: 'hvac',
    cssClass: 'category-card--ac',
    label: 'HVAC & Climate',
    desc: 'AC installation, repair & maintenance',
    emoji: '❄️',
    icon: `<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12h20"></path><path d="M12 2v20"></path><path d="m20 16-4-4 4-4"></path><path d="m4 8 4 4-4 4"></path><path d="m16 4-4 4-4-4"></path><path d="m8 20 4-4 4 4"></path></svg>`,
  },
  {
    key: 'cleaning',
    cssClass: 'category-card--cleaning',
    label: 'Cleaning',
    desc: 'Deep cleaning, maid services & sanitising',
    emoji: '✨',
    icon: `<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"></path><path d="M20 3v4"></path><path d="M22 5h-4"></path><path d="M4 17v2"></path><path d="M5 18H3"></path></svg>`,
  },
  {
    key: 'painting',
    cssClass: 'category-card--painting',
    label: 'Painting',
    desc: 'Interior & exterior painting & finishing',
    emoji: '🎨',
    icon: `<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9.06 11.9 8.07-8.06a2.85 2.85 0 1 1 4.03 4.03l-8.06 8.08"></path><path d="M7.07 14.94c-1.66 0-3 1.35-3 3.02 0 1.33-2.5 1.52-2 2.02 1.08 1.1 2.49 2.02 4 2.02 2.2 0 4-1.8 4-4.04a3.01 3.01 0 0 0-3-3.02z"></path></svg>`,
  },
  {
    key: 'carpentry',
    cssClass: 'category-card--carpentry',
    label: 'Carpentry',
    desc: 'Custom woodwork, cabinets & furniture',
    emoji: '🪵',
    icon: `<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 12-8.373 8.373a1 1 0 1 1-3-3L12 9"></path><path d="m18 15 4-4"></path><path d="m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172V7l-2.26-2.26a6 6 0 0 0-4.202-1.756L9 2.96l.92.82A6.18 6.18 0 0 1 12 8.4V10l2 2h1.172a2 2 0 0 1 1.414.586L18 14"></path></svg>`,
  },
];

// Keep for autocomplete emoji lookup
const CATEGORY_META = Object.fromEntries(
  HOME_CATEGORIES.map(c => [c.key, { cssClass: c.cssClass, emoji: c.emoji }])
);

const ARROW_SVG = `<svg class="category-card__arrow" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>`;

function loadServicesGrid() {
  const grid = document.getElementById('home-services-grid');
  if (!grid) return;

  grid.innerHTML = '';
  HOME_CATEGORIES.forEach((cat, i) => {
    const a = document.createElement('a');
    a.href = `./services-marketplace.html?category=${cat.key}`;
    a.className = `category-card ${cat.cssClass}`;
    a.setAttribute('data-reveal', '');
    a.setAttribute('data-reveal-delay', String(i * 80));
    a.innerHTML = `
      <div class="category-card__icon">${cat.icon}</div>
      <h3 class="category-card__title">${cat.label}</h3>
      <p class="category-card__count">${cat.desc}</p>
      ${ARROW_SVG}
    `;
    grid.appendChild(a);
  });

  if (typeof window.initScrollReveal === 'function') window.initScrollReveal();
}

document.addEventListener('DOMContentLoaded', () => {
  loadServicesGrid();

  // ── Hero search navigation ─────────────────────────────────────────────
  const heroInput    = document.querySelector('.hero-search__input');
  const heroBtn      = document.querySelector('.hero-search__btn');
  const autocomplete = document.getElementById('hero-autocomplete');

  function navigateToMarketplace(query) {
    const q = query || (heroInput ? heroInput.value.trim() : '');
    window.location.href = q
      ? `./services-marketplace.html?q=${encodeURIComponent(q)}`
      : './services-marketplace.html';
  }

  if (heroBtn)   heroBtn.addEventListener('click', () => navigateToMarketplace());
  if (heroInput) heroInput.addEventListener('keydown', e => { if (e.key === 'Enter') navigateToMarketplace(); });

  // ── Typewriter placeholder effect ─────────────────────────────────────
  if (heroInput) {
    const TYPEWRITER_PHRASES = [
      'Find a master plumber…',
      'Certified electrician?',
      'AC repair & services…',
      'Professional cleaning…',
      'Need a pro painter?',
      'Expert carpentry work…',
      'What service do you need?',
    ];

    let twPhraseIdx   = 0;
    let twCharIdx     = 0;
    let twDeleting    = false;
    let twTimer       = null;
    let twPaused      = false;  // paused while user focuses the input

    const TYPE_SPEED   = 55;   // ms per character while typing
    const DELETE_SPEED = 28;   // ms per character while deleting
    const PAUSE_AFTER  = 1800; // ms pause after fully typed
    const PAUSE_BEFORE = 380;  // ms pause before starting next phrase

    function twTick() {
      if (twPaused) return;  // user is interacting — freeze

      const phrase = TYPEWRITER_PHRASES[twPhraseIdx];

      if (!twDeleting) {
        // Typing forward
        twCharIdx++;
        heroInput.setAttribute('placeholder', phrase.slice(0, twCharIdx));

        if (twCharIdx === phrase.length) {
          // Fully typed — pause then start deleting
          twTimer = setTimeout(() => { twDeleting = true; twTick(); }, PAUSE_AFTER);
          return;
        }
      } else {
        // Deleting backward
        twCharIdx--;
        heroInput.setAttribute('placeholder', phrase.slice(0, twCharIdx));

        if (twCharIdx === 0) {
          // Fully erased — move to next phrase
          twDeleting  = false;
          twPhraseIdx = (twPhraseIdx + 1) % TYPEWRITER_PHRASES.length;
          twTimer = setTimeout(twTick, PAUSE_BEFORE);
          return;
        }
      }

      twTimer = setTimeout(twTick, twDeleting ? DELETE_SPEED : TYPE_SPEED);
    }

    // Pause animation while user types; restore on blur
    heroInput.addEventListener('focus', () => {
      twPaused = true;
      clearTimeout(twTimer);
      // Show a clean placeholder hint while focused
      heroInput.setAttribute('placeholder', 'Search services…');
    });

    heroInput.addEventListener('blur', () => {
      twPaused = false;
      // If the input is empty, restart the typewriter
      if (!heroInput.value.trim()) {
        clearTimeout(twTimer);
        twTimer = setTimeout(twTick, 600);
      }
    });

    // Kick off after a short delay so the splash loader finishes first
    twTimer = setTimeout(twTick, 1400);
  }

  // ── Autocomplete dropdown ─────────────────────────────────────────────
  let autocompleteServices = [];

  function renderAutocompleteItems(filterText) {
    if (!autocomplete) return;
    const filtered = filterText
      ? autocompleteServices.filter(s => s.toLowerCase().includes(filterText.toLowerCase()))
      : autocompleteServices;

    autocomplete.innerHTML = filtered.slice(0, 8).map(svc => {
      const cat  = svc.toLowerCase().replace(/[^a-z0-9]/g, '');
      const meta = Object.entries(CATEGORY_META).find(([k]) => svc.toLowerCase().includes(k.replace('-', '')))?.[1];
      const emoji = meta ? meta.emoji : '🔧';
      return `<button class="hero-autocomplete__item" role="option" data-service="${svc}">${emoji} ${svc}</button>`;
    }).join('');

    autocomplete.querySelectorAll('.hero-autocomplete__item').forEach(btn => {
      btn.addEventListener('mousedown', e => {
        e.preventDefault();
        const svc = btn.dataset.service;
        if (heroInput) heroInput.value = svc;
        hideAutocomplete();
        navigateToMarketplace(svc);
      });
    });

    autocomplete.hidden = filtered.length === 0;
  }

  function showAutocomplete(filterText) {
    if (!autocomplete || !autocompleteServices.length) return;
    renderAutocompleteItems(filterText);
  }

  function hideAutocomplete() {
    if (autocomplete) autocomplete.hidden = true;
  }

  // Seed autocomplete with category labels immediately; enrich with API titles if available
  autocompleteServices = HOME_CATEGORIES.map(c => c.label);

  getServices({ limit: 50 })
    .then(resp => {
      const apiTitles = ((resp && resp.services) ? resp.services : []).map(s => s.title);
      if (apiTitles.length) autocompleteServices = apiTitles;
    })
    .catch(() => {});

  if (heroInput && autocomplete) {
    heroInput.addEventListener('focus', () => showAutocomplete(heroInput.value));
    heroInput.addEventListener('input', () => showAutocomplete(heroInput.value));
    heroInput.addEventListener('keydown', e => { if (e.key === 'Escape') hideAutocomplete(); });

    document.addEventListener('click', e => {
      const searchWrap = heroInput.closest('.hero-search');
      if (searchWrap && !searchWrap.contains(e.target)) hideAutocomplete();
    });
  }

  // ── Elite Network carousel ────────────────────────────────────────────
  const eliteScroll = document.querySelector('#elite-scroll');
  const elitePrev   = document.querySelector('.elite-carousel__btn--prev');
  const eliteNext   = document.querySelector('.elite-carousel__btn--next');

  function eliteScrollStep() {
    if (!eliteScroll) return 360;
    const card = eliteScroll.querySelector('.elite-card');
    if (!card) return 360;
    const gapStr = getComputedStyle(eliteScroll).gap;
    const gap    = parseFloat(gapStr) || 24;
    return card.offsetWidth + gap;
  }

  function updateEliteCarouselButtons() {
    if (!eliteScroll || !elitePrev || !eliteNext) return;
    const el  = eliteScroll;
    const max = Math.max(0, el.scrollWidth - el.clientWidth);
    if (max <= 0) { elitePrev.disabled = true; eliteNext.disabled = true; return; }
    const sl  = el.scrollLeft;
    const rtl = getComputedStyle(el).direction === 'rtl';
    const tol = 6;
    let atStart, atEnd;
    if (rtl && sl <= 0) {
      atStart = sl >= -tol; atEnd = sl <= -max + tol;
    } else if (rtl && sl > 0) {
      atStart = sl <= tol; atEnd = sl >= max - tol;
    } else {
      atStart = sl <= tol; atEnd = sl >= max - tol;
    }
    elitePrev.disabled = atStart;
    eliteNext.disabled = atEnd;
  }

  function scrollElite(direction) {
    if (!eliteScroll) return;
    const step  = eliteScrollStep();
    const rtl   = getComputedStyle(eliteScroll).direction === 'rtl';
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

  // ── Section indicator scroll spy ───────────────────────────────────────
  const indicatorNav   = document.querySelector('.home-section-indicator');
  const indicatorLinks = Array.from(document.querySelectorAll('[data-home-indicator-link]'));
  const sectionMap     = indicatorLinks
    .map(link => {
      const id = link.getAttribute('href');
      if (!id || !id.startsWith('#')) return null;
      const section = document.querySelector(id);
      return section ? { link, section } : null;
    })
    .filter(Boolean);

  function updateIndicatorTheme(section) {
    if (!indicatorNav || !section) return;
    const bg = section.dataset.sectionBg;
    const isDarkTheme = document.documentElement.getAttribute('data-theme') === 'dark';
    const isOverDark = bg === 'dark' || (bg === 'adaptive' && isDarkTheme);
    indicatorNav.classList.toggle('is-over-dark', isOverDark);
    indicatorNav.classList.toggle('is-over-light', !isOverDark);
  }

  function setActiveIndicator(activeLink, activeSection) {
    indicatorLinks.forEach(link => {
      const isActive = link === activeLink;
      link.classList.toggle('is-active', isActive);
      if (isActive) link.setAttribute('aria-current', 'true');
      else           link.removeAttribute('aria-current');
    });
    if (activeSection) updateIndicatorTheme(activeSection);
  }

  // Also re-evaluate when theme is toggled
  if (indicatorNav) {
    const themeObserver = new MutationObserver(() => {
      const activeItem = sectionMap.find(item => item.link.classList.contains('is-active'));
      if (activeItem) updateIndicatorTheme(activeItem.section);
    });
    themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
  }

  if (sectionMap.length) {
    const observer = new IntersectionObserver(entries => {
      const visibleEntries = entries
        .filter(e => e.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio);
      if (!visibleEntries.length) return;
      const activeItem = sectionMap.find(item => item.section === visibleEntries[0].target);
      if (activeItem) setActiveIndicator(activeItem.link, activeItem.section);
    }, { root: null, threshold: [0.3, 0.5, 0.7], rootMargin: '-18% 0px -32% 0px' });

    sectionMap.forEach(item => observer.observe(item.section));
    indicatorLinks.forEach(link => link.addEventListener('click', (e) => {
      e.preventDefault();
      const id = link.getAttribute('href');
      const section = id && id.startsWith('#') ? document.querySelector(id) : null;
      if (section) section.scrollIntoView({ behavior: 'smooth' });
      const mapItem = sectionMap.find(item => item.link === link);
      setActiveIndicator(link, mapItem ? mapItem.section : null);
    }));
  }

  // ── Hero background parallax ──────────────────────────────────────────
  const heroBgImg   = document.querySelector('.home-hero__bg-img');
  const heroSection = document.querySelector('.home-hero');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  if (heroBgImg && heroSection && !reducedMotion) {
    window.addEventListener('scroll', () => {
      const scrolled = window.scrollY;
      const heroH    = heroSection.offsetHeight;
      if (scrolled < heroH) {
        const pct = scrolled / heroH;
        // Combine parallax with ken-burns — keep scale, shift Y gently
        heroBgImg.style.transform = `scale(1.06) translateY(${pct * 14}%) translate(-1%, 1%)`;
      }
    }, { passive: true });
  }


  // ── FOMO: Fake Live Booking Toasts ─────────────────────────────────────
  const bookingToast = document.getElementById('booking-toast');
  const toastTitle   = document.getElementById('toast-title');
  const toastSub     = document.getElementById('toast-sub');
  const toastClose   = document.getElementById('toast-close');

  if (bookingToast && toastTitle && toastSub) {
    const isArabic = (document.documentElement.getAttribute('lang') || '').toLowerCase().startsWith('ar');

    const FOMO_DATA_EN = [
      { name: 'Khaled',  city: 'Maadi',        service: 'Plumbing',      time: '2 min ago' },
      { name: 'Sara',    city: 'New Cairo',    service: 'AC Maintenance',time: '5 min ago' },
      { name: 'Mohamed', city: 'Heliopolis',   service: 'Electrical',    time: '1 min ago' },
      { name: 'Nour',    city: 'Zamalek',      service: 'Cleaning',      time: '8 min ago' },
      { name: 'Ahmed',   city: '6th October',  service: 'Painting',      time: '3 min ago' },
      { name: 'Laila',   city: 'Dokki',        service: 'Carpentry',     time: '10 min ago' }
    ];

    const FOMO_DATA_AR = [
      { name: 'خالد',   city: 'المعادي',        service: 'سباكة',         time: 'منذ دقيقتين' },
      { name: 'سارة',   city: 'القاهرة الجديدة', service: 'صيانة تكييف',     time: 'منذ 5 دقائق' },
      { name: 'محمد',   city: 'مصر الجديدة',    service: 'كهرباء',        time: 'منذ دقيقة' },
      { name: 'نور',    city: 'الزمالك',        service: 'تنظيف',         time: 'منذ 8 دقائق' },
      { name: 'أحمد',   city: '6 أكتوبر',       service: 'نقاشة',         time: 'منذ 3 دقائق' },
      { name: 'ليلى',   city: 'الدقي',         service: 'نجارة',         time: 'منذ 10 دقائق' }
    ];

    const FOMO_DATA = isArabic ? FOMO_DATA_AR : FOMO_DATA_EN;
    const titleTemplate = isArabic ? '{name} قام بالحجز للتو' : '{name} just booked';

    let fomoIndex = 0;
    let fomoTimer = null;
    
    function showFomo() {
      // Don't show if window is hidden (save resources)
      if (document.hidden) return;

      const data = FOMO_DATA[fomoIndex];
      toastTitle.textContent = titleTemplate.replace('{name}', data.name);
      toastSub.textContent   = `${data.service} · ${data.time}`;
      
      bookingToast.hidden = false;
      // Allow a frame for 'hidden' removal, then animate
      requestAnimationFrame(() => {
        bookingToast.classList.add('is-visible');
      });

      // Show for 3s
      fomoTimer = setTimeout(hideFomo, 3000);
      fomoIndex = (fomoIndex + 1) % FOMO_DATA.length;
    }

    function hideFomo() {
      bookingToast.classList.remove('is-visible');
      // Wait for CSS transition (500ms) before hitting 'hidden'
      setTimeout(() => {
        if (!bookingToast.classList.contains('is-visible')) {
          bookingToast.hidden = true;
        }
      }, 600);
    }

    if (toastClose) {
      toastClose.addEventListener('click', () => {
        clearTimeout(fomoTimer);
        hideFomo();
      });
    }

    // Initial delay 4s, then every 4s
    setTimeout(() => {
      showFomo();
      const scheduleNext = () => {
        const delay = 5000; // Fixed 4 second interval
        setTimeout(() => {
          showFomo();
          scheduleNext();
        }, delay);
      };
      scheduleNext();
    }, 4000);
  }
});

// .
