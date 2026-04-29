/**
 * technician-listing.js
 * Dynamic header + technician cards, plus search, filter, sort.
 */

import { initScrollReveal } from '../components/scroll-reveal.js';
import { SERVICES } from '../data/services-data.js';
import { getWorkers } from '../api/users.js';

// Module-level cache so langchange re-renders without re-fetching
let _cachedWorkers = [];

// ── Helpers ───────────────────────────────────────────────────────────────────

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function getParam(key) {
  return new URLSearchParams(window.location.search).get(key);
}

const BADGE_VERIFIED_SVG = `<span class="badge-verified"><svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg></span>`;
const LOC_SVG = `<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>`;

// ── Render hero ───────────────────────────────────────────────────────────────

function renderHero(svc, serviceKey, lang) {
  const t = svc[lang] || svc.en;
  const isAr = lang === 'ar';
  const serviceName = isAr ? svc.ar.title : svc.en.title;

  document.title = `${serviceName} | SERVIO`;

  const heroImg = document.querySelector('[data-listing-target="hero-img"]');
  if (heroImg) { heroImg.src = svc.heroImage; heroImg.alt = serviceName; }

  const breadcrumb = document.querySelector('[data-listing-target="breadcrumb-current"]');
  if (breadcrumb) breadcrumb.textContent = serviceName;

  const title = document.querySelector('[data-listing-target="title"]');
  if (title) title.textContent = serviceName;

  const lead = document.querySelector('[data-listing-target="lead"]');
  if (lead) lead.textContent = t.lead;
}

// ── Build card HTML ───────────────────────────────────────────────────────────

function buildCardFromAPI(worker, serviceKey, lang, delay) {
  const isAr = lang === 'ar';
  const id = worker._id;
  const name = escapeHtml(worker.name || 'Technician');
  const rating = worker.averageRating?.toFixed(1) || '0.0';
  const reviewCount = worker.totalReviews || 0;
  const ratingLabel = isAr ? `${rating} تقييم` : `${rating} Avg`;
  const avatar = worker.profileImage || 'https://ui-avatars.com/api/?name=' + encodeURIComponent(worker.name || 'T') + '&background=0d6efd&color=fff&size=128';
  const profileHref = `./technician-profile.html?id=${id}&service=${serviceKey}`;
  const viewLabel = isAr ? 'عرض الملف الشخصي' : 'View Profile';
  const availLabel = worker.availability?.length
    ? (isAr ? 'متاح' : 'Available')
    : (isAr ? 'حدد الوقت' : 'By Appointment');

  const categories = (worker.categories || [])
    .map(c => `<span class="tech-card__category-tag">${escapeHtml(c)}</span>`)
    .join('');

  return `
    <article class="tech-card" data-reveal data-reveal-delay="${delay}" data-avail="${availLabel.toLowerCase()}" data-tech-id="${id}">
      <div class="tech-card__top">
        <img class="tech-card__avatar" src="${avatar}" alt="${name}" onerror="this.src='https://ui-avatars.com/api/?name=T&background=0d6efd&color=fff&size=128'">
        <div class="tech-card__info">
          <h3 class="tech-card__name">
            ${name}
            ${worker.isVerified ? BADGE_VERIFIED_SVG : ''}
          </h3>
          <div class="tech-card__trust">
            <span class="tech-card__rating">${ratingLabel}</span>
            <span>(${reviewCount})</span>
          </div>
          <div class="tech-card__categories">${categories}</div>
        </div>
      </div>
      <div class="tech-card__footer">
        <div>
          <div class="tech-card__availability">${availLabel}</div>
          <a class="tech-card__action" href="${profileHref}">${viewLabel}</a>
        </div>
      </div>
    </article>`;
}

// ── Render cards ──────────────────────────────────────────────────────────────

async function renderCards(serviceKey, lang) {
  const techGrid = document.getElementById('tech-grid');
  if (!techGrid) return;

  techGrid.innerHTML = '<p style="padding:2rem;text-align:center">Loading...</p>';

  let workers = [];
  try {
    const res = await getWorkers({ category: serviceKey });
    // api client already unwraps { success, data } → res IS the data object directly
    workers = res?.workers || res?.data?.workers || [];
  } catch (err) {
    console.error('getWorkers error:', err);
    techGrid.innerHTML = '<p style="padding:2rem;text-align:center">Could not load technicians. Please try again.</p>';
    return;
  }

  if (!workers.length) {
    techGrid.innerHTML = '<p style="padding:2rem;text-align:center">No technicians available for this service yet.</p>';
    const resultCount = document.getElementById('result-count');
    if (resultCount) resultCount.textContent = '0';
    return;
  }

  _cachedWorkers = workers;
  techGrid.innerHTML = workers.map((worker, i) => buildCardFromAPI(worker, serviceKey, lang, i * 50)).join('');

  techGrid.querySelectorAll('.tech-card').forEach(card => {
    card.style.cursor = 'pointer';
    card.addEventListener('click', e => {
      if (e.target.closest('a')) return;
      const id = card.getAttribute('data-tech-id');
      window.location.href = `./technician-profile.html?id=${id}&service=${serviceKey}`;
    });
  });

  initScrollReveal();

  const resultCount = document.getElementById('result-count');
  if (resultCount) resultCount.textContent = workers.length;
}

// ── Filter / sort (existing logic, preserved) ──────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
  const serviceKey = getParam('service');
  const svc = serviceKey && SERVICES[serviceKey];

  if (!svc) {
    window.location.replace('./services-marketplace.html');
    return;
  }

  const getLang = () => window.__lang || document.documentElement.lang || 'en';

  renderHero(svc, serviceKey, getLang());
  renderCards(serviceKey, getLang());

  document.addEventListener('langchange', async e => {
    const lang = e.detail?.lang || getLang();
    renderHero(svc, serviceKey, lang);
    if (_cachedWorkers.length) {
      const techGrid = document.getElementById('tech-grid');
      if (techGrid) {
        techGrid.innerHTML = _cachedWorkers.map((w, i) => buildCardFromAPI(w, serviceKey, lang, i * 50)).join('');
        techGrid.querySelectorAll('.tech-card').forEach(card => {
          card.style.cursor = 'pointer';
          card.addEventListener('click', ev => {
            if (ev.target.closest('a')) return;
            window.location.href = `./technician-profile.html?id=${card.getAttribute('data-tech-id')}&service=${serviceKey}`;
          });
        });
        initScrollReveal();
      }
    } else {
      await renderCards(serviceKey, lang);
    }
    applyFilters();
  });

  // ── DOM refs ────────────────────────────────────────────────────────────────
  const searchInput    = document.getElementById('tech-search');
  const searchClear    = document.getElementById('techSearchClear');
  const filterBtns     = document.querySelectorAll('.filter-pill[data-filter]');
  const distanceFilter = document.getElementById('distance-filter');
  const sortSelect     = document.getElementById('sort-select');
  const advancedToggle = document.getElementById('advancedToggle');
  const advancedPanel  = document.getElementById('advancedPanel');
  const filterBadge    = document.getElementById('filterBadge');
  const priceMin       = document.getElementById('priceMin');
  const priceMax       = document.getElementById('priceMax');
  const availToday     = document.getElementById('availToday');
  const availWeek      = document.getElementById('availWeek');
  const applyAdvanced  = document.getElementById('applyAdvanced');
  const clearAdvanced  = document.getElementById('clearAdvanced');
  const resultCount    = document.getElementById('result-count');
  const emptyState     = document.getElementById('empty-state');
  const emptyStateBtn  = document.querySelector('.empty-state button');
  const techGrid       = document.getElementById('tech-grid');

  // ── State ───────────────────────────────────────────────────────────────────
  let state = {
    query:           '',
    filter:          'all',
    distance:        'any',
    sort:            'featured',
    priceMin:        0,
    priceMax:        500,
    availToday:      false,
    availWeek:       false,
    advancedApplied: false,
  };

  // ── Helpers ─────────────────────────────────────────────────────────────────
  function getCards() {
    return Array.from(document.querySelectorAll('.tech-card'));
  }

  function getRating(card) {
    const ratingEl = card.querySelector('.tech-card__rating');
    return ratingEl ? parseFloat(ratingEl.textContent) || 0 : 0;
  }

  function getPrice(card) {
    return parseInt(card.getAttribute('data-price')) || 0;
  }

  function getAvailability(card) {
    // Use data-avail attribute so filtering works in both languages
    return (card.getAttribute('data-avail') || '').toLowerCase();
  }

  function isVerified(card) {
    return card.querySelector('.badge-verified') !== null;
  }

  // ── Animate count ────────────────────────────────────────────────────────────
  function animateCount(el, to) {
    const from = parseInt(el.textContent) || 0;
    if (from === to) return;
    const dur = 300;
    const start = performance.now();
    function tick(now) {
      const p = Math.min((now - start) / dur, 1);
      el.textContent = Math.round(from + (to - from) * p);
      if (p < 1) requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }

  // ── Filter + sort ────────────────────────────────────────────────────────────
  function applyFilters() {
    const cards = getCards();

    const visible = [];
    const hidden  = [];

    cards.forEach(card => {
      const name   = (card.querySelector('.tech-card__name')?.textContent || '').toLowerCase();
      const desc   = (card.querySelector('.tech-card__desc')?.textContent || '').toLowerCase();
      const avail  = getAvailability(card);
      const rating = getRating(card);
      const price  = getPrice(card);
      const dist   = parseInt(card.getAttribute('data-distance')) || 0;

      const matchesSearch = !state.query || name.includes(state.query) || desc.includes(state.query);

      let matchesFilter = true;
      if (state.filter === 'top-rated')         matchesFilter = rating >= 4.8;
      else if (state.filter === 'available-today') matchesFilter = avail.includes('today');
      else if (state.filter === 'verified')     matchesFilter = isVerified(card);

      const matchesDistance = state.distance === 'any' || dist <= parseInt(state.distance);
      const matchesPrice    = price >= state.priceMin && price <= state.priceMax;

      let matchesAvail = true;
      if (state.advancedApplied) {
        if (state.availToday && state.availWeek) {
          matchesAvail = avail.includes('today') || avail.includes('week') || avail.includes('tomorrow');
        } else if (state.availToday) {
          matchesAvail = avail.includes('today');
        } else if (state.availWeek) {
          matchesAvail = avail.includes('week') || avail.includes('today') || avail.includes('tomorrow');
        }
      }

      const passes = matchesSearch && matchesFilter && matchesDistance && matchesPrice && matchesAvail;
      (passes ? visible : hidden).push(card);
    });

    visible.sort((a, b) => {
      if (state.sort === 'highest-rated') return getRating(b) - getRating(a);
      if (state.sort === 'price-low')     return getPrice(a) - getPrice(b);
      if (state.sort === 'price-high')    return getPrice(b) - getPrice(a);
      return 0;
    });

    hidden.forEach(card => { card.style.display = 'none'; });
    visible.forEach(card => { card.style.display = 'flex'; techGrid.appendChild(card); });

    if (resultCount) animateCount(resultCount, visible.length);
    if (emptyState)  emptyState.style.display = visible.length === 0 ? 'block' : 'none';

    updateFilterBadge();
  }

  // ── Filter badge ──────────────────────────────────────────────────────────────
  function updateFilterBadge() {
    let count = 0;
    if (state.distance !== 'any') count++;
    if (state.advancedApplied) {
      if (state.priceMin > 0 || state.priceMax < 500) count++;
      if (state.availToday || state.availWeek) count++;
    }
    if (filterBadge) {
      filterBadge.textContent = count;
      filterBadge.hidden = count === 0;
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────────
  if (searchInput) {
    searchInput.addEventListener('input', e => {
      state.query = e.target.value.toLowerCase().trim();
      if (searchClear) searchClear.hidden = !state.query;
      applyFilters();
    });
  }
  if (searchClear) {
    searchClear.addEventListener('click', () => {
      if (searchInput) { searchInput.value = ''; searchInput.focus(); }
      state.query = '';
      searchClear.hidden = true;
      applyFilters();
    });
  }

  // ── Filter pills ──────────────────────────────────────────────────────────────
  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('filter-pill--active'));
      btn.classList.add('filter-pill--active');
      state.filter = btn.getAttribute('data-filter');
      applyFilters();
    });
  });

  // ── Distance ──────────────────────────────────────────────────────────────────
  if (distanceFilter) {
    distanceFilter.addEventListener('change', () => {
      state.distance = distanceFilter.value;
      applyFilters();
    });
  }

  // ── Sort ──────────────────────────────────────────────────────────────────────
  if (sortSelect) {
    sortSelect.addEventListener('change', () => {
      state.sort = sortSelect.value;
      applyFilters();
    });
  }

  // ── Advanced panel ────────────────────────────────────────────────────────────
  if (advancedToggle && advancedPanel) {
    advancedToggle.addEventListener('click', () => {
      const isOpen = advancedPanel.classList.toggle('is-open');
      advancedToggle.setAttribute('aria-expanded', String(isOpen));
      advancedPanel.setAttribute('aria-hidden', String(!isOpen));
    });
  }

  if (applyAdvanced) {
    applyAdvanced.addEventListener('click', () => {
      state.priceMin = parseInt(priceMin?.value) || 0;
      state.priceMax = parseInt(priceMax?.value) || 500;
      state.availToday = availToday?.checked || false;
      state.availWeek  = availWeek?.checked  || false;
      state.advancedApplied = true;
      advancedPanel.classList.remove('is-open');
      advancedToggle?.setAttribute('aria-expanded', 'false');
      advancedPanel.setAttribute('aria-hidden', 'true');
      applyFilters();
    });
  }

  function resetAdvanced() {
    if (priceMin)   priceMin.value    = '0';
    if (priceMax)   priceMax.value    = '500';
    if (availToday) availToday.checked = false;
    if (availWeek)  availWeek.checked  = false;
    state.priceMin = 0;
    state.priceMax = 500;
    state.availToday = false;
    state.availWeek  = false;
    state.advancedApplied = false;
    applyFilters();
  }

  if (clearAdvanced) clearAdvanced.addEventListener('click', resetAdvanced);

  if (emptyStateBtn) {
    emptyStateBtn.addEventListener('click', () => {
      if (searchInput)   searchInput.value = '';
      if (searchClear)   searchClear.hidden = true;
      if (distanceFilter) distanceFilter.value = 'any';
      if (sortSelect)    sortSelect.value = 'featured';
      filterBtns.forEach(b => b.classList.remove('filter-pill--active'));
      document.querySelector('.filter-pill[data-filter="all"]')?.classList.add('filter-pill--active');
      state.query    = '';
      state.filter   = 'all';
      state.distance = 'any';
      state.sort     = 'featured';
      resetAdvanced();
    });
  }

  // ── Initial filter run ────────────────────────────────────────────────────────
  applyFilters();
});
