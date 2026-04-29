document.addEventListener('DOMContentLoaded', () => {
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
  const SERVICES = ['Plumbing', 'Electrical', 'AC Maintenance', 'Professional Cleaning', 'Painting', 'Carpentry'];

  function showAutocomplete(filterText) {
    if (!autocomplete) return;
    const items = autocomplete.querySelectorAll('.hero-autocomplete__item');
    items.forEach((item, i) => {
      const svc   = SERVICES[i] || '';
      const match = !filterText || svc.toLowerCase().includes(filterText.toLowerCase());
      item.style.display = match ? '' : 'none';
    });
    autocomplete.hidden = false;
  }

  function hideAutocomplete() {
    if (autocomplete) autocomplete.hidden = true;
  }

  if (heroInput && autocomplete) {
    heroInput.addEventListener('focus', () => showAutocomplete(heroInput.value));
    heroInput.addEventListener('input', () => showAutocomplete(heroInput.value));
    heroInput.addEventListener('keydown', e => { if (e.key === 'Escape') hideAutocomplete(); });

    autocomplete.querySelectorAll('.hero-autocomplete__item').forEach(btn => {
      btn.addEventListener('mousedown', e => {
        e.preventDefault();
        const svc = btn.dataset.service;
        if (heroInput) heroInput.value = svc;
        hideAutocomplete();
        navigateToMarketplace(svc);
      });
    });

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
