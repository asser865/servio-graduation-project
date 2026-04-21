/* ─────────────────────────────────────────────────────────────────────────
   HOME — CINEMATIC LUXURY INTERACTIONS
   Kinetic title, 3D tilt, magnetic buttons, cursor spotlight, hero stagger.
   Loads after home.js. Pure progressive enhancement — no breakage if
   any element is absent.
   ──────────────────────────────────────────────────────────────────────── */

(function () {
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const ready = (fn) =>
    document.readyState === 'loading'
      ? document.addEventListener('DOMContentLoaded', fn, { once: true })
      : fn();

  ready(init);

  function init() {
    // Markup-time work — safe to run immediately
    splitHeroTitle();
    annotateEditorialHeaders();
    injectCtaOrnaments();
    revealEditorialHeadersOnScroll();
    flagCountedMetrics();

    // Interactions and timed animations wait for the splash loader to exit
    whenSplashDone(() => {
      cycleKineticWord();
      initEliteTilt();
      initMagneticButtons();
      initCtaSpotlight();
    });
  }

  /* Wait for body to lose .is-loading (splash loader exit). If it's already
     gone or no splash exists, fire immediately. */
  function whenSplashDone(cb) {
    let fired = false;
    const fire = () => { if (!fired) { fired = true; cb(); } };

    if (!document.body.classList.contains('is-loading')) {
      fire();
      return;
    }
    const obs = new MutationObserver(() => {
      if (!document.body.classList.contains('is-loading')) {
        obs.disconnect();
        fire();
      }
    });
    obs.observe(document.body, { attributes: true, attributeFilter: ['class'] });
    // Safety net — fire after 6s no matter what
    setTimeout(() => { obs.disconnect(); fire(); }, 6000);
  }

  /* ───── 1. Split hero title last line into staggered words
     The static parts already animate via CSS keyframes; we just wrap each
     non-dynamic span's text in <span class="luxe-word">word</span> so each
     gets a per-word stagger.
  ─────────────────────────────────────────────────────────────────────── */
  function splitHeroTitle() {
    const title = document.querySelector('.hero-editorial__title');
    if (!title) return;

    let wordIndex = 1;
    const directChildren = Array.from(title.childNodes);

    directChildren.forEach((node) => {
      if (node.nodeType !== 1) return;
      // Don't touch the dynamic span — it has its own animation
      if (node.classList && node.classList.contains('hero-editorial__dynamic')) return;
      if (node.tagName === 'BR') return;

      const text = node.textContent.trim();
      if (!text) return;

      const words = text.split(/\s+/);
      const wrapped = words
        .map((w) => {
          const cls = `luxe-word luxe-word--${Math.min(wordIndex, 4)}`;
          wordIndex++;
          return `<span class="${cls}">${escapeHtml(w)}</span>`;
        })
        .join(' ');

      // Preserve i18n attribute by setting innerHTML on the same node
      node.innerHTML = wrapped;
    });
  }

  /* ───── 2. Kinetic dynamic word — cycle every 2.6s
     Uses the existing .hero-editorial__dynamic span. Switches to Arabic
     vocabulary if html[lang=ar].
  ─────────────────────────────────────────────────────────────────────── */
  function cycleKineticWord() {
    const node = document.querySelector('.hero-editorial__dynamic');
    if (!node || reducedMotion) return;

    const isArabic = (document.documentElement.getAttribute('lang') || '').toLowerCase().startsWith('ar');
    const wordsEn = ['Home Services', 'Plumbing.', 'Electrical.', 'Cleaning.', 'Carpentry.', 'AC Repair.'];
    const wordsAr = ['خدمات منزلية', 'سباكة.', 'كهرباء.', 'تنظيف.', 'نجارة.', 'صيانة تكييف.'];
    const words = isArabic ? wordsAr : wordsEn;

    let i = 0;
    const swap = () => {
      i = (i + 1) % words.length;
      // Phase 1 — exit transition
      node.classList.add('is-leaving');

      setTimeout(() => {
        // Phase 2 — snap to entering state without transition
        node.style.transition = 'none';
        node.textContent = words[i];
        node.classList.remove('is-leaving');
        node.classList.add('is-entering');
        // Force reflow so the snapped state takes effect
        void node.offsetWidth;

        // Phase 3 — restore transition, drop modifier, animate back to natural
        requestAnimationFrame(() => {
          node.style.transition = '';
          node.classList.remove('is-entering');
        });
      }, 380);
    };

    // Initial pause to let hero choreography settle
    setTimeout(() => {
      swap();
      setInterval(swap, 2800);
    }, 2400);
  }

  /* ───── 3. 3D mouse tilt on Elite cards + cursor sheen
  ─────────────────────────────────────────────────────────────────────── */
  function initEliteTilt() {
    if (reducedMotion) return;

    const cards = document.querySelectorAll('.elite-card');
    if (!cards.length) return;

    const MAX_DEG = 7;

    cards.forEach((card) => {
      // Inject sheen overlay once
      if (!card.querySelector('.luxe-sheen')) {
        const sheen = document.createElement('span');
        sheen.className = 'luxe-sheen';
        card.prepend(sheen);
      }

      let rafId = 0;
      const onMove = (e) => {
        const r = card.getBoundingClientRect();
        const px = (e.clientX - r.left) / r.width;     // 0..1
        const py = (e.clientY - r.top) / r.height;
        const ry = (px - 0.5) * MAX_DEG * 2;            // tilt around Y by X
        const rx = -(py - 0.5) * MAX_DEG * 2;           // tilt around X by Y

        if (rafId) cancelAnimationFrame(rafId);
        rafId = requestAnimationFrame(() => {
          card.style.setProperty('--luxe-rx', rx.toFixed(2) + 'deg');
          card.style.setProperty('--luxe-ry', ry.toFixed(2) + 'deg');
          card.style.setProperty('--luxe-mx', (px * 100).toFixed(1) + '%');
          card.style.setProperty('--luxe-my', (py * 100).toFixed(1) + '%');
          card.classList.add('is-luxe-tilted');
        });
      };

      const onLeave = () => {
        if (rafId) cancelAnimationFrame(rafId);
        card.style.setProperty('--luxe-rx', '0deg');
        card.style.setProperty('--luxe-ry', '0deg');
        card.classList.remove('is-luxe-tilted');
      };

      card.addEventListener('mousemove', onMove);
      card.addEventListener('mouseleave', onLeave);
    });
  }

  /* ───── 4. Magnetic buttons — gentle pull toward cursor
  ─────────────────────────────────────────────────────────────────────── */
  function initMagneticButtons() {
    if (reducedMotion) return;

    const targets = document.querySelectorAll('.luxe-magnetic');
    targets.forEach((el) => {
      const STRENGTH = parseFloat(el.dataset.luxeMagnetic) || 0.35;
      const MAX = 14;

      const onMove = (e) => {
        const r = el.getBoundingClientRect();
        const cx = r.left + r.width / 2;
        const cy = r.top + r.height / 2;
        const dx = (e.clientX - cx) * STRENGTH;
        const dy = (e.clientY - cy) * STRENGTH;
        const x = Math.max(-MAX, Math.min(MAX, dx));
        const y = Math.max(-MAX, Math.min(MAX, dy));
        el.style.setProperty('--luxe-mag-x', x.toFixed(2) + 'px');
        el.style.setProperty('--luxe-mag-y', y.toFixed(2) + 'px');
        el.classList.add('is-luxe-magnetized');
      };

      const onLeave = () => {
        el.style.setProperty('--luxe-mag-x', '0px');
        el.style.setProperty('--luxe-mag-y', '0px');
        el.classList.remove('is-luxe-magnetized');
      };

      el.addEventListener('mousemove', onMove);
      el.addEventListener('mouseleave', onLeave);
    });
  }

  /* ───── 5. CTA cursor spotlight — radial gradient follows pointer
  ─────────────────────────────────────────────────────────────────────── */
  function initCtaSpotlight() {
    const panel = document.querySelector('.home-cta__panel');
    if (!panel || reducedMotion) return;

    let rafId = 0;
    panel.addEventListener('mousemove', (e) => {
      if (rafId) cancelAnimationFrame(rafId);
      rafId = requestAnimationFrame(() => {
        const r = panel.getBoundingClientRect();
        const x = ((e.clientX - r.left) / r.width) * 100;
        const y = ((e.clientY - r.top) / r.height) * 100;
        panel.style.setProperty('--luxe-spot-x', x.toFixed(1) + '%');
        panel.style.setProperty('--luxe-spot-y', y.toFixed(1) + '%');
      });
    });
  }

  /* ───── 6. Annotate editorial headers with data-luxe-num + eyebrow
  ─────────────────────────────────────────────────────────────────────── */
  function annotateEditorialHeaders() {
    const config = [
      { selector: '.section--services .editorial-header',  num: '01', en: 'CURATED DISCIPLINES',  ar: 'مجالات مختارة' },
      { selector: '.tech-network .editorial-header',       num: '02', en: 'THE ELITE NETWORK',     ar: 'الشبكة النخبوية' },
      { selector: '.testimonials .editorial-header',       num: '03', en: 'CLIENT VOICES',         ar: 'آراء العملاء' },
      { selector: '.how-it-works .editorial-header',       num: '04', en: 'THE PROCESS',           ar: 'العملية' },
      { selector: '.metrics .editorial-header, .metrics .metrics-copy', num: '05', en: 'BY THE NUMBERS', ar: 'بالأرقام' },
    ];

    const isArabic = (document.documentElement.getAttribute('lang') || '').toLowerCase().startsWith('ar');

    config.forEach(({ selector, num, en, ar }) => {
      document.querySelectorAll(selector).forEach((el) => {
        if (!el.hasAttribute('data-luxe-num')) {
          el.setAttribute('data-luxe-num', num);
          el.setAttribute('data-luxe-eyebrow', isArabic ? ar : en);
        }
      });
    });
  }

  /* ───── 7. Inject CTA ornament layers (frame + spotlight)
  ─────────────────────────────────────────────────────────────────────── */
  function injectCtaOrnaments() {
    const panel = document.querySelector('.home-cta__panel');
    if (!panel) return;

    if (!panel.querySelector('.luxe-spotlight')) {
      const spot = document.createElement('span');
      spot.className = 'luxe-spotlight';
      panel.prepend(spot);
    }
    if (!panel.querySelector('.luxe-frame')) {
      const frame = document.createElement('span');
      frame.className = 'luxe-frame';
      panel.prepend(frame);
    }
  }

  /* ───── 8. Reveal editorial headers + apply luxe in-class on intersection
     Existing scroll-reveal toggles `is-visible`. We piggy-back; for headers
     that DON'T already have data-reveal, we add our own observer.
  ─────────────────────────────────────────────────────────────────────── */
  function revealEditorialHeadersOnScroll() {
    if (!('IntersectionObserver' in window)) return;

    const headers = document.querySelectorAll('.editorial-header, .metrics-copy');
    if (!headers.length) return;

    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-luxe-in');
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.25 }
    );

    headers.forEach((h) => io.observe(h));
  }

  /* ───── 9. After counter completes, mark metric-card so underline draws
     The existing scroll-effects.js animates count-to but doesn't dispatch
     an event. We approximate by listening for IntersectionObserver here.
  ─────────────────────────────────────────────────────────────────────── */
  function flagCountedMetrics() {
    if (!('IntersectionObserver' in window)) return;
    const cards = document.querySelectorAll('.metric-card');
    if (!cards.length) return;

    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            // Counter takes ~900ms; add the class slightly after to draw line
            setTimeout(() => entry.target.classList.add('is-luxe-counted'), 950);
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.45 }
    );
    cards.forEach((c) => io.observe(c));
  }

  /* ───── helpers
  ─────────────────────────────────────────────────────────────────────── */
  function escapeHtml(s) {
    return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
})();

/* . */
