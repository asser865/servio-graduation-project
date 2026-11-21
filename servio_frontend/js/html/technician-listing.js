/**
 * technician-listing.js
 * Dynamic header + technician cards, plus search, filter, sort.
 */

import { initScrollReveal } from '../components/scroll-reveal.js';
import { SERVICES, getSubserviceForKey, getSubserviceLabel } from '../data/services-data.js';
import { getWorkers } from '../api/users.js';
import { subscribeNotify }  from '../api/notify.js';
import { getSession }       from '../api/client.js';
import { createHeartToggle } from '../components/heart-toggle.js';
import { listMyFavoriteIds } from '../api/favorites.js';
import { alertDialog } from '../components/confirm-dialog.js';
import { renderBusyBadge } from '../components/busy-badge.js';

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

// Last-resort display name for a subservice slug that isn't in the hardcoded
// `included` list (e.g. a backend service title): "pipe-repair" → "Pipe Repair".
function humanizeSlug(slug) {
  return String(slug || '')
    .split('-')
    .filter(Boolean)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

function buildProfileHref(id, serviceKey, subserviceKey = '') {
  const params = new URLSearchParams({ id, service: serviceKey });
  if (subserviceKey) params.set('subservice', subserviceKey);
  return `./technician-profile.html?${params.toString()}`;
}

const BADGE_VERIFIED_SVG = `<span class="badge-verified" title="Verified Professional"><svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M9 12.5l2 2 4-4m-3-9l2.39 4.84L20 7.27l-3.64 3.55.86 5.01L12 13.27l-4.22 2.22.86-5.01L5 6.73l5.61-.43L12 2z"/></svg> Verified</span>`;
const LOC_SVG = `<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>`;

function buildStars(rating) {
  const full = Math.floor(rating);
  const half = rating - full >= 0.5;
  const empty = 5 - full - (half ? 1 : 0);
  let stars = '';
  for (let i = 0; i < full; i++)  stars += `<svg viewBox="0 0 24 24" width="13" height="13" fill="currentColor" class="star star--full"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`;
  if (half)                        stars += `<svg viewBox="0 0 24 24" width="13" height="13" fill="currentColor" class="star star--half"><defs><linearGradient id="hg"><stop offset="50%" stop-color="currentColor"/><stop offset="50%" stop-color="transparent"/></linearGradient></defs><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" fill="url(#hg)" stroke="currentColor" stroke-width="1"/></svg>`;
  for (let i = 0; i < empty; i++) stars += `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="1.5" class="star star--empty"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`;
  return stars;
}

// ── Render hero ───────────────────────────────────────────────────────────────

function renderHero(svc, serviceKey, subserviceKey, lang) {
  const t = svc[lang] || svc.en;
  const isAr = lang === 'ar';
  const serviceName = isAr ? svc.ar.title : svc.en.title;
  const subservice = getSubserviceForKey(serviceKey, subserviceKey);
  const subserviceName = getSubserviceLabel(serviceKey, subserviceKey, lang)
    || (subserviceKey ? humanizeSlug(subserviceKey) : '');
  const pageName = subserviceName || serviceName;
  const subserviceDesc = subservice ? (subservice[lang] || subservice.en)?.desc : '';

  document.title = `${pageName} | SERVIO`;

  const heroImg = document.querySelector('[data-listing-target="hero-img"]');
  if (heroImg) { heroImg.src = svc.heroImage; heroImg.alt = pageName; }

  const breadcrumb = document.querySelector('[data-listing-target="breadcrumb-current"]');
  if (breadcrumb) breadcrumb.textContent = subserviceName ? `${serviceName} / ${subserviceName}` : serviceName;

  const title = document.querySelector('[data-listing-target="title"]');
  if (title) title.textContent = pageName;

  const lead = document.querySelector('[data-listing-target="lead"]');
  if (lead) lead.textContent = subserviceDesc || t.lead;
}

// ── Build card HTML ───────────────────────────────────────────────────────────

function buildCardFromAPI(worker, serviceKey, subserviceKey, lang, delay) {
  const isAr = lang === 'ar';
  const id = worker._id;
  const name = escapeHtml(worker.name || 'Technician');
  const ratingNum = parseFloat(worker.averageRating) || 0;
  const rating = ratingNum.toFixed(1);
  const reviewCount = worker.totalReviews || 0;
  const price = worker.hourlyRate || 0;
  const avatar = worker.profileImage || worker.avatar || worker.photo || 'https://ui-avatars.com/api/?name=' + encodeURIComponent(worker.name || 'T') + '&background=6366f1&color=fff&size=128';
  const profileHref = buildProfileHref(id, serviceKey, subserviceKey);

  // Labels
  const viewLabel      = isAr ? 'عرض الملف الشخصي' : 'View Profile';
  const startingLabel  = isAr ? 'ابتداءً من' : 'STARTING';
  const currencyLabel  = isAr ? 'جنيه' : 'EGP';
  const priceUnit      = isAr ? '/ساعة' : '/hr';
  const ratingLabel    = isAr ? `${rating} تقييم` : `${rating} Avg`;

  const isAvail    = worker.isAvailable === true;
  const availLabel = isAvail
    ? (isAr ? 'متاح الآن' : 'AVAILABLE NOW')
    : (isAr ? 'غير متاح' : 'OFFLINE');

  // Build a short bio from categories if no bio exists
  const bio = worker.bio || worker.about || '';
  const descText = bio
    ? escapeHtml(bio)
    : (worker.categories?.length
        ? escapeHtml(`Specialist in ${worker.categories.slice(0, 2).join(' & ')}.`)
        : '');

  return `
    <article class="tech-card" data-reveal data-reveal-delay="${delay}"
             data-avail="${availLabel.toLowerCase()}"
             data-price="${price}"
             data-tech-id="${id}">
      <div class="tech-card__top">
        <img class="tech-card__avatar" src="${avatar}" alt="${name}"
             onerror="this.src='https://ui-avatars.com/api/?name=T&background=6366f1&color=fff&size=128'">
        <div class="tech-card__info">
          <h3 class="tech-card__name">
            ${name}
            ${worker.isVerified ? BADGE_VERIFIED_SVG : ''}
          </h3>
          <div class="tech-card__trust">
            <span class="tech-card__rating">${ratingLabel}</span>
            <span class="tech-card__reviews">(${reviewCount})</span>
          </div>
        </div>
      </div>

      ${descText ? `<p class="tech-card__desc">${descText}</p>` : ''}

      <div class="tech-card__footer">
        <div class="tech-card__price-blurb">
          <span class="tech-card__price-label">${startingLabel}</span>
          <div class="tech-card__price">${price} ${currencyLabel}<span>${priceUnit}</span></div>
        </div>
        <div>
          <div class="tech-card__availability">${availLabel}</div>
          <div class="tech-card__actions">
            <a class="tech-card__action" href="${profileHref}">${viewLabel}</a>
          </div>
        </div>
      </div>
    </article>`;
}

// ── Notify Me ─────────────────────────────────────────────────────────────────

function initNotifyMe(serviceKey) {
  const btn     = document.getElementById('notify-me-btn');
  const confirm = document.getElementById('notify-me-confirm');
  if (!btn) return;

  btn.addEventListener('click', async () => {
    const session = getSession();
    if (!session?.email) {
      window.location.href = `./login.html?redirect=${encodeURIComponent(window.location.href)}`;
      return;
    }

    btn.disabled    = true;
    btn.textContent = 'Subscribing…';

    try {
      await subscribeNotify(serviceKey);
      btn.style.display = 'none';
      if (confirm) confirm.style.display = 'block';
    } catch (err) {
      btn.disabled    = false;
      btn.textContent = 'Notify Me';
      const alreadySubscribed = err?.message?.toLowerCase().includes('already');
      if (confirm && alreadySubscribed) {
        btn.style.display   = 'none';
        confirm.style.display = 'block';
      } else {
        alertDialog({ title: 'Subscription failed', body: 'Could not subscribe. Please try again.', tone: 'danger' });
      }
    }
  });
}

// ── Render cards ──────────────────────────────────────────────────────────────

async function renderCards(serviceKey, subserviceKey, lang) {
  const techGrid      = document.getElementById('tech-grid');
  if (!techGrid) return;

  const pagination    = document.querySelector('.pagination');
  const resultsHeader = document.querySelector('.results-header');

  if (pagination)    pagination.style.display    = 'none';
  if (resultsHeader) resultsHeader.style.display = 'none';

  techGrid.innerHTML = `
    <div style="padding:3rem;text-align:center;display:flex;flex-direction:column;
                align-items:center;gap:1rem;">
      <div style="width:48px;height:48px;border:4px solid #E3D5CA;border-top-color:#3C2415;
                  border-radius:50%;animation:listing-spin 0.8s linear infinite;"></div>
      <p style="color:#6B6560;font-size:0.95rem;margin:0;">Finding available technicians…</p>
    </div>`;

  let workers = [];
  try {
    const res = await getWorkers({ category: serviceKey });
    workers = res?.workers || res?.data?.workers || [];
  } catch (err) {
    console.error('getWorkers error:', err);
    techGrid.innerHTML = `
      <div style="padding:3rem;text-align:center;display:flex;flex-direction:column;
                  align-items:center;gap:0.75rem;">
        <div style="font-size:2rem;">⚠️</div>
        <p style="color:#6B6560;font-size:0.95rem;margin:0;">Could not load technicians. Please try again.</p>
      </div>`;
    return;
  }

  if (!workers.length) {
    techGrid.innerHTML = '';
    const noOnlineState    = document.getElementById('no-online-state');
    const filterEmptyState = document.getElementById('empty-state');
    if (noOnlineState)    noOnlineState.style.display    = 'flex';
    if (filterEmptyState) filterEmptyState.style.display = 'none';
    const resultCount = document.getElementById('result-count');
    if (resultCount) resultCount.textContent = '0';
    return;
  }

  const noOnlineState = document.getElementById('no-online-state');
  if (noOnlineState) noOnlineState.style.display = 'none';
  if (pagination)    pagination.style.display    = 'none';
  if (resultsHeader) resultsHeader.style.display = '';

  _cachedWorkers = workers;
  techGrid.innerHTML = workers.map((worker, i) => buildCardFromAPI(worker, serviceKey, subserviceKey, lang, i * 50)).join('');

  // Attach heart-toggle and busy badge — wrapped so a failure never hides cards
  try {
    const favIds = window.__favIds || (window.__favIds = await listMyFavoriteIds().catch(() => new Set()));
    techGrid.querySelectorAll('.tech-card').forEach((card, idx) => {
      const workerId = card.getAttribute('data-tech-id');
      try {
        const heart = createHeartToggle({
          workerId,
          isFavorited: favIds.has(workerId),
          onChange: (now) => now ? favIds.add(workerId) : favIds.delete(workerId),
        });
        heart.classList.add('tech-card__heart');
        card.querySelector('.tech-card__top')?.appendChild(heart);
      } catch (_) { /* heart optional */ }

      const worker = workers[idx];
      if (worker) {
        try {
          const badge = renderBusyBadge(worker.busyState);
          if (badge) {
            const metaTarget = card.querySelector('.tech-card__trust') || card.querySelector('.tech-card__top');
            metaTarget?.appendChild(badge);
          }
          if (worker.busyState?.isBusy) {
            const bookBtn = card.querySelector('[data-action="book-now"]') ||
                            card.querySelector('.btn-book') ||
                            card.querySelector('.book-btn');
            if (bookBtn) {
              bookBtn.setAttribute('disabled', 'true');
              bookBtn.setAttribute('title',
                `Busy — try again in ~${worker.busyState.remainingMin ?? 'a few'} min`);
            }
          }
        } catch (_) { /* badge optional */ }
      }
    });
  } catch (_) { /* decorations optional — cards already visible */ }

  techGrid.querySelectorAll('.tech-card').forEach(card => {
    card.style.cursor = 'pointer';
    card.addEventListener('click', e => {
      if (e.target.closest('a')) return;
      const id = card.getAttribute('data-tech-id');
      window.location.href = buildProfileHref(id, serviceKey, subserviceKey);
    });
  });

  initScrollReveal();

  const resultCount = document.getElementById('result-count');
  if (resultCount) resultCount.textContent = workers.length;
}

// ── Filter / sort (existing logic, preserved) ──────────────────────────────────

document.addEventListener('DOMContentLoaded', async () => {
  const serviceKey = getParam('service');
  const subserviceKey = getParam('subservice') || '';
  const svc = serviceKey && SERVICES[serviceKey];

  if (!svc) {
    window.location.replace('./services-marketplace.html');
    return;
  }

  const getLang = () => window.__lang || document.documentElement.lang || 'en';

  renderHero(svc, serviceKey, subserviceKey, getLang());
  await renderCards(serviceKey, subserviceKey, getLang());
  initNotifyMe(serviceKey);

  document.addEventListener('langchange', async e => {
    const lang = e.detail?.lang || getLang();
    renderHero(svc, serviceKey, subserviceKey, lang);
    if (_cachedWorkers.length) {
      const techGrid = document.getElementById('tech-grid');
      if (techGrid) {
        techGrid.innerHTML = _cachedWorkers.map((w, i) => buildCardFromAPI(w, serviceKey, subserviceKey, lang, i * 50)).join('');
        techGrid.querySelectorAll('.tech-card').forEach(card => {
          card.style.cursor = 'pointer';
          card.addEventListener('click', ev => {
            if (ev.target.closest('a')) return;
            window.location.href = buildProfileHref(card.getAttribute('data-tech-id'), serviceKey, subserviceKey);
          });
        });
        initScrollReveal();
      }
    } else {
      await renderCards(serviceKey, subserviceKey, lang);
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
      if (state.filter === 'top-rated')            matchesFilter = rating >= 4.8;
      else if (state.filter === 'available-today') matchesFilter = avail.includes('available');
      else if (state.filter === 'verified')        matchesFilter = isVerified(card);

      const matchesDistance = state.distance === 'any' || dist <= parseInt(state.distance);
      const matchesPrice    = price >= state.priceMin && price <= state.priceMax;

      let matchesAvail = true;
      if (state.advancedApplied) {
        if (state.availToday && state.availWeek) {
          matchesAvail = avail.includes('available') || avail.includes('week') || avail.includes('tomorrow');
        } else if (state.availToday) {
          matchesAvail = avail.includes('available');
        } else if (state.availWeek) {
          matchesAvail = avail.includes('available') || avail.includes('week') || avail.includes('tomorrow');
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
    if (emptyState) {
      const noOnlineEl = document.getElementById('no-online-state');
      const noOnlineVisible = noOnlineEl && noOnlineEl.style.display !== 'none';
      emptyState.style.display = (!noOnlineVisible && visible.length === 0) ? 'block' : 'none';
    }

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
