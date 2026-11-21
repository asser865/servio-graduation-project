import { initScrollReveal } from '../components/scroll-reveal.js';
import { SERVICES, slugifyServiceLabel } from '../data/services-data.js';
import { getServices } from '../api/services.js';

// ── Helpers ────────────────────────────────────────────────────────────────

function getParam(key) {
  return new URLSearchParams(window.location.search).get(key);
}

function el(target) {
  return document.querySelector(`[data-svc-target="${target}"]`);
}

function listingHref(serviceKey, subserviceKey = '') {
  const params = new URLSearchParams({ service: serviceKey });
  if (subserviceKey) params.set('subservice', subserviceKey);
  return `./technician-listing.html?${params.toString()}`;
}

function stars(n) {
  return '★'.repeat(n) + '☆'.repeat(5 - n);
}

// "Can't find your issue?" escape hatch appended to the sub-service grid. serviceKey is
// the only dynamic value and is URL-encoded into the href; all visible text is static.
function describeCard(serviceKey, delayIndex = 0, isAr = false) {
  const title = isAr ? 'لم تجد مشكلتك؟' : "Can't find your issue?";
  const desc  = isAr
    ? 'صِف المشكلة بكلماتك وسنطابقك مع الخدمة والفني المناسب.'
    : 'Describe it in your own words — we’ll match the right service and technician.';
  const href = `./smart-match.html?service=${encodeURIComponent(serviceKey)}`;
  return `
      <a class="svc-card svc-card--describe" href="${href}" data-reveal data-reveal-delay="${delayIndex * 100}">
        <div class="svc-card__icon">✦</div>
        <h3 class="svc-card__title">${title}</h3>
        <p class="svc-card__desc">${desc}</p>
      </a>`;
}

// ── Render ─────────────────────────────────────────────────────────────────

function render(svc, serviceKey, lang) {
  const t = svc[lang] || svc.en;
  const isAr = lang === 'ar';

  // Document title
  document.title = `${t.title} | SERVIO`;

  // Hero
  const heroImg = el('hero-img');
  if (heroImg) { heroImg.src = svc.heroImage; heroImg.alt = t.title; }
  setText('title', t.title);
  setText('lead', t.lead);
  setText('price-badge', t.priceBadge);
  const findBtn = el('find-btn');
  if (findBtn) {
    findBtn.textContent = t.findBtn;
    findBtn.href = listingHref(serviceKey);
  }

  // Included grid — data shape: { icon, en: { title, desc }, ar: { title, desc } }
  const grid = el('included-grid');
  if (grid) {
    const cards = svc.included.map((item, i) => {
      const lang2 = isAr ? item.ar : item.en;
      const subserviceKey = slugifyServiceLabel(item.en?.title || lang2.title);
      return `
      <a class="svc-card" href="${listingHref(serviceKey, subserviceKey)}" data-reveal data-reveal-delay="${i * 100}">
        <div class="svc-card__icon">${item.icon}</div>
        <h3 class="svc-card__title">${lang2.title}</h3>
        <p class="svc-card__desc">${lang2.desc}</p>
      </a>`;
    }).join('');
    // Escape hatch: a customer who doesn't see their exact issue describes it in their
    // own words on Smart Match, which matches a service + technician instead of dead-ending.
    grid.innerHTML = cards + describeCard(serviceKey, svc.included.length, isAr);
  }

  // Pricing grid — data shape: { featured?, en: { tier, price, jobs }, ar: { tier, price, jobs } }
  const pricingGrid = el('pricing-grid');
  if (pricingGrid) {
    pricingGrid.innerHTML = svc.pricing.map((tier, i) => {
      const lang2 = isAr ? tier.ar : tier.en;
      return `
      <div class="svc-pricing__card${tier.featured ? ' svc-pricing__card--featured' : ''}" data-reveal data-reveal-delay="${i * 100}">
        ${tier.featured ? `<span class="svc-pricing__badge" data-i18n="svc_tier2_badge">Most Common</span>` : ''}
        <p class="svc-pricing__tier">${lang2.tier}</p>
        <p class="svc-pricing__price">${lang2.price}</p>
        <p class="svc-pricing__jobs">${lang2.jobs}</p>
      </div>`;
    }).join('');
  }

  // FAQ list — data shape: { en: { q, a }, ar: { q, a } }
  const faqList = el('faq-list');
  if (faqList) {
    faqList.innerHTML = svc.faqs.map(faq => {
      const lang2 = isAr ? faq.ar : faq.en;
      return `
      <div class="svc-faq__item">
        <button class="svc-faq__question" type="button" aria-expanded="false">
          <span>${lang2.q}</span>
          <span class="svc-faq__icon" aria-hidden="true">+</span>
        </button>
        <div class="svc-faq__answer" role="region">
          <p>${lang2.a}</p>
        </div>
      </div>`;
    }).join('');
    initFaqAccordion(faqList);
  }

  // Reviews grid — data shape: { initials, stars, en: { name, quote }, ar: { name, quote } }
  const reviewsGrid = el('reviews-grid');
  if (reviewsGrid) {
    reviewsGrid.innerHTML = svc.reviews.map((rev, i) => {
      const lang2 = isAr ? rev.ar : rev.en;
      return `
      <div class="svc-review-card" data-reveal data-reveal-delay="${i * 100}">
        <div class="svc-review-card__header">
          <div class="svc-review-card__avatar" aria-hidden="true">${rev.initials}</div>
          <div>
            <div class="svc-review-card__name">${lang2.name}</div>
            <div class="svc-review-card__stars" aria-label="${rev.stars} out of 5 stars">${stars(rev.stars)}</div>
          </div>
        </div>
        <p class="svc-review-card__quote">${lang2.quote}</p>
        <span class="svc-review-card__tag">${t.title}</span>
      </div>`;
    }).join('');
  }

  // CTA
  setText('cta-title', t.ctaTitle);
  setText('cta-sub', t.ctaSub);
  const ctaBtn = el('cta-btn');
  if (ctaBtn) {
    ctaBtn.textContent = t.ctaBtn;
    ctaBtn.href = listingHref(serviceKey);
  }
}

function setText(target, value) {
  const node = el(target);
  if (node) node.textContent = value;
}

// ── FAQ Accordion ──────────────────────────────────────────────────────────

function initFaqAccordion(container) {
  const items = container.querySelectorAll('.svc-faq__item');
  items.forEach(item => {
    const btn = item.querySelector('.svc-faq__question');
    btn.addEventListener('click', () => {
      const isOpen = item.classList.contains('is-open');
      items.forEach(i => {
        i.classList.remove('is-open');
        i.querySelector('.svc-faq__question').setAttribute('aria-expanded', 'false');
      });
      if (!isOpen) {
        item.classList.add('is-open');
        btn.setAttribute('aria-expanded', 'true');
      }
    });
  });
}

// ── Init ───────────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
  const serviceKey = getParam('service');
  const svc = serviceKey && SERVICES[serviceKey];

  if (!svc) {
    window.location.replace('./services-marketplace.html');
    return;
  }

  const getLang = () => window.__lang || document.documentElement.lang || 'en';

  render(svc, serviceKey, getLang());
  initScrollReveal();

  // Enrich with real API ratings
  getServices({ category: serviceKey, limit: 1 })
    .then(res => {
      const apiSvc = res?.services?.[0];
      if (!apiSvc) return;
      const ratingEl = el('average-rating') || document.querySelector('[data-svc-target="average-rating"]');
      if (ratingEl && apiSvc.averageRating) ratingEl.textContent = apiSvc.averageRating.toFixed(1);
      const reviewCountEl = el('review-count') || document.querySelector('[data-svc-target="review-count"]');
      if (reviewCountEl && apiSvc.totalReviews) reviewCountEl.textContent = apiSvc.totalReviews;
    })
    .catch(() => {}); // Silent fail — static rating from data file stays

  document.addEventListener('langchange', e => {
    render(svc, serviceKey, e.detail?.lang || getLang());
  });
});
