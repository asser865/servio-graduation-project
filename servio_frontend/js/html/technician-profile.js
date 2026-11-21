/**
 * technician-profile.js
 * Dynamic profile population + entry animations + portfolio lightbox.
 */

import { animate, stagger } from 'https://cdn.jsdelivr.net/npm/motion@12.38.0/+esm';
import { getWorker } from '../api/users.js';
import { getWorkerReviews } from '../api/reviews.js';
import { createHeartToggle } from '../components/heart-toggle.js';
import { listMyFavoriteIds } from '../api/favorites.js';
import { renderBusyBadge } from '../components/busy-badge.js';

// ── Helpers ────────────────────────────────────────────────────────────────────

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

function buildListingHref(serviceKey, subserviceKey = '') {
  const params = new URLSearchParams();
  if (serviceKey) params.set('service', serviceKey);
  if (subserviceKey) params.set('subservice', subserviceKey);
  const query = params.toString();
  return `./technician-listing.html${query ? '?' + query : ''}`;
}

function buildBookingHref(techId, serviceKey, subserviceKey = '') {
  const params = new URLSearchParams({ worker: techId });
  if (serviceKey) params.set('service', serviceKey);
  if (subserviceKey) params.set('subservice', subserviceKey);
  return `./booking.html?${params.toString()}`;
}

function el(target) {
  return document.querySelector(`[data-profile-target="${target}"]`);
}

function setText(target, value) {
  const node = el(target);
  if (node) node.textContent = value;
}

const CLOCK_SVG = `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`;

function normalizeAreaList(items) {
  const values = Array.isArray(items) ? items : String(items || '').split(',');
  const seen = new Set();
  const result = [];
  values.forEach(item => {
    const area = String(item || '').trim();
    const key = area.toLowerCase();
    if (!area || seen.has(key)) return;
    seen.add(key);
    result.push(area);
  });
  return result;
}

function getCoverageAreas(worker) {
  if (Array.isArray(worker.coverageAreas) && worker.coverageAreas.length) {
    return normalizeAreaList(worker.coverageAreas);
  }
  return normalizeAreaList([worker.serviceArea, worker.locationLabel, worker.city].filter(Boolean).join(','));
}

// ── Credentials & Availability ─────────────────────────────────────────────────

function renderCredentials(worker) {
  const list = document.getElementById('credentials-list');
  if (!list) return;

  const CHECK_SVG = `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>`;
  const PENDING_SVG = `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#9ca3af" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`;

  if (!worker.isVerified) {
    list.innerHTML = `<li style="opacity:0.55">${PENDING_SVG}<span>Verification Pending</span></li>`;
    return;
  }

  const items = [
    'SERVIO Verified Professional',
    'Background Checked & ID Verified',
  ];

  const rating = worker.averageRating || 0;
  if      (rating >= 4.8) items.push('SERVIO Elite Tier');
  else if (rating >= 4.5) items.push('SERVIO Pro Tier');
  else                    items.push('SERVIO Standard Tier');

  if ((worker.completedJobs || 0) > 0) {
    items.push(`${worker.completedJobs}+ Verified Jobs Completed`);
  }

  list.innerHTML = items
    .map(text => `<li>${CHECK_SVG}<span>${escapeHtml(text)}</span></li>`)
    .join('');
}

function renderAvailability(worker) {
  const daysEl  = document.getElementById('avail-days');
  const hoursEl = document.getElementById('avail-hours');
  if (!daysEl) return;

  // Weekend-first order matches the existing HTML layout (Sat → Sun → Mon … Fri)
  const WEEK = [
    { key: 'saturday',  label: 'Sat' },
    { key: 'sunday',    label: 'Sun' },
    { key: 'monday',    label: 'Mon' },
    { key: 'tuesday',   label: 'Tue' },
    { key: 'wednesday', label: 'Wed' },
    { key: 'thursday',  label: 'Thu' },
    { key: 'friday',    label: 'Fri' },
  ];

  const schedule = worker.availability || [];

  if (!schedule.length) {
    daysEl.innerHTML = '<p style="font-size:0.85rem;color:#9ca3af;margin:0;">Schedule not yet published</p>';
    if (hoursEl) hoursEl.innerHTML = '';
    return;
  }

  daysEl.innerHTML = WEEK.map(({ key, label }) => {
    const slot = schedule.find(s => s.day === key);
    const cls  = slot ? 'avail-pill avail-pill--on' : 'avail-pill avail-pill--off';
    const tip  = slot ? ` title="${slot.from} – ${slot.to}"` : '';
    return `<span class="${cls}"${tip}>${label}</span>`;
  }).join('');

  if (hoursEl) {
    const fmt = t => {
      const [h, min] = t.split(':').map(Number);
      return `${h % 12 || 12}:${String(min).padStart(2, '0')} ${h >= 12 ? 'PM' : 'AM'}`;
    };
    const froms = schedule.map(s => s.from).sort();
    const tos   = schedule.map(s => s.to).sort().reverse();
    hoursEl.innerHTML = `
      <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
      <span>Typical hours: ${fmt(froms[0])} – ${fmt(tos[0])}</span>`;
  }
}

// ── Render ─────────────────────────────────────────────────────────────────────

function render(worker, lang) {
  const isAr = lang === 'ar';
  const name = escapeHtml(worker.name || 'Technician');
  const categories = (worker.categories || []).join(', ') || '—';
  const rating = worker.averageRating?.toFixed(1) || '0.0';
  const reviewCount = worker.totalReviews || 0;
  const avatarUrl = worker.profileImage || worker.avatar || worker.photo || 'https://ui-avatars.com/api/?name=' + encodeURIComponent(worker.name || 'T') + '&background=0d6efd&color=fff&size=256';
  const memberSince = worker.createdAt
    ? new Date(worker.createdAt).toLocaleDateString(isAr ? 'ar-EG' : 'en-US', { year: 'numeric', month: 'long' })
    : '—';

  document.title = `${name} | SERVIO`;

  const coverImg = el('cover-img');
  if (coverImg) { coverImg.src = worker.profileImage || avatarUrl; coverImg.alt = name; }

  const avatar = el('avatar');
  if (avatar) { avatar.src = avatarUrl; avatar.alt = name; avatar.onerror = () => { avatar.src = 'https://ui-avatars.com/api/?name=T&background=0d6efd&color=fff&size=256'; }; }

  setText('name', name);
  setText('title', categories.toUpperCase());
  setText('rating', rating);
  setText('location', worker.locationLabel || (isAr ? 'القاهرة' : 'Cairo'));
  setText('member-since', memberSince);
  setText('bio', worker.bio || '—');
  setText('flat-rate', (worker.hourlyRate || 0) + ' EGP');
  setText('booking-rate', worker.hourlyRate || '0');
  setText('years-exp', (worker.yearsExperience || 0));
  setText('response-time', '30M'); // Hardcoded as per reference image style
  setText('job-success', '97%');   // Hardcoded as per reference image style

  const reviewMeta = el('review-meta');
  if (reviewMeta) {
    reviewMeta.textContent = isAr ? `(${reviewCount} تقييم)` : `(${reviewCount} Reviews)`;
  }
  setText('rating-big', rating);
  const ratingCount = el('rating-count');
  if (ratingCount) {
    ratingCount.textContent = isAr ? `بناءً على ${reviewCount} تقييم` : `Based on ${reviewCount} reviews`;
  }

  renderCredentials(worker);
  renderAvailability(worker);

  const coverageAreas = el('coverage-areas');
  if (coverageAreas) {
    const areaTags = getCoverageAreas(worker);
    coverageAreas.innerHTML = areaTags.length
      ? `<p class="coverage-summary-profile">Covers ${areaTags.length} area${areaTags.length === 1 ? '' : 's'}</p>
         <div class="coverage-chip-list">${areaTags.map(a => `<span class="coverage-tag">${escapeHtml(a)}</span>`).join('')}</div>`
      : '<span class="coverage-tag" style="opacity:0.5">Not specified</span>';
  }

  const servicesGrid = el('services-grid');
  if (servicesGrid) {
    const populated = Array.isArray(worker.services) &&
      worker.services.length &&
      typeof worker.services[0] === 'object' &&
      worker.services[0] !== null;

    if (populated) {
      servicesGrid.innerHTML = worker.services.map(s => `
        <div class="service-card">
          <div class="service-card__body">
            <div class="service-card__name">${escapeHtml(s.title || s.category || '—')}</div>
            <div class="service-card__price">${s.basePrice ? `From ${s.basePrice} EGP` : '—'}</div>
          </div>
        </div>`).join('');
    } else {
      const fallback = worker.skills?.length ? worker.skills : worker.categories;
      servicesGrid.innerHTML = fallback?.length
        ? fallback.map(c => `
          <div class="service-card">
            <div class="service-card__body">
              <div class="service-card__name">${escapeHtml(c)}</div>
              <div class="service-card__price">—</div>
            </div>
          </div>`).join('')
        : '<p>—</p>';
    }
  }
}

// ── Render reviews ─────────────────────────────────────────────────────────────

function renderRatingBars(reviews) {
  const container = el('rating-bars');
  if (!container) return;

  const total = reviews.length;
  if (!total) {
    container.innerHTML = '';
    return;
  }

  const counts = [5, 4, 3, 2, 1].map(n => ({
    n,
    count: reviews.filter(r => Math.round(r.rating) === n).length,
  }));

  const max = Math.max(...counts.map(c => c.count), 1);

  container.innerHTML = counts.map(({ n, count }) => {
    const pct = Math.round((count / total) * 100);
    const barWidth = Math.round((count / max) * 100);
    const isLow = n <= 2;
    return `
      <div class="rating-bar-row">
        <span class="rating-bar-label">${n}</span>
        <div class="rating-bar-track">
          <div class="rating-bar-fill${isLow ? ' rating-bar-fill--low' : ''}" style="width:${barWidth}%"></div>
        </div>
        <span class="rating-bar-count">${count}</span>
      </div>`;
  }).join('');
}

function renderReviews(reviews, lang) {
  const isAr = lang === 'ar';
  const container = el('reviews-list');
  if (!container) return;

  if (!reviews || !reviews.length) {
    container.innerHTML = `<p style="padding:1rem;opacity:0.6">${isAr ? 'لا توجد تقييمات بعد.' : 'No reviews yet.'}</p>`;
    return;
  }

  container.innerHTML = reviews.map(r => {
    const reviewer = escapeHtml(r.user?.name || 'Customer');
    const initials  = reviewer.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
    const comment   = escapeHtml(r.comment || '');
    const date      = r.createdAt
      ? new Date(r.createdAt).toLocaleDateString(isAr ? 'ar-EG' : 'en-US', { year: 'numeric', month: 'long', day: 'numeric' })
      : '';
    const starCount = Math.round(r.rating || 0);
    const stars = Array.from({ length: 5 }, (_, i) =>
      i < starCount
        ? `<svg viewBox="0 0 24 24" width="14" height="14" fill="#F59E0B"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`
        : `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="#d1d5db" stroke-width="1.5"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`
    ).join('');

    return `
      <div class="review-card">
        <div class="review-card__header">
          <div class="review-card__initials" aria-hidden="true">${initials}</div>
          <div class="review-card__author-info">
            <div class="review-card__name">${reviewer}</div>
            <div class="review-card__date">${date}</div>
          </div>
          <div class="review-card__stars" aria-label="${starCount} out of 5 stars">${stars}</div>
        </div>
        ${comment ? `<p class="review-card__text">${comment}</p>` : ''}
      </div>`;
  }).join('');
}

// ── Animations ─────────────────────────────────────────────────────────────────

function runAnimations() {
  const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (prefersReduced) return;

  const cover  = document.querySelector('.profile-cover');
  const header = document.querySelector('.profile-header');
  const stats  = document.querySelector('.profile-stats');
  const layout = document.querySelector('.profile-layout');

  if (cover)  animate(cover,  { opacity: [0, 1] }, { duration: 0.5 });

  if (header) {
    const els = [
      header.querySelector('.profile-avatar-wrapper'),
      header.querySelector('.profile-name'),
      header.querySelector('.profile-title'),
      header.querySelector('.profile-meta'),
      header.querySelector('.profile-actions'),
    ].filter(Boolean);
    animate(els, { opacity: [0, 1], y: [20, 0] }, { delay: stagger(0.08), duration: 0.4, easing: 'ease-out' });
  }

  if (stats) {
    const blocks = stats.querySelectorAll('.stat-block');
    animate(blocks, { opacity: [0, 1], y: [16, 0] }, { delay: stagger(0.07, { start: 0.3 }), duration: 0.4, easing: 'ease-out' });
  }

  if (layout) {
    animate(layout, { opacity: [0, 1], y: [12, 0] }, { delay: 0.45, duration: 0.4, easing: 'ease-out' });
  }
}

// ── Animated stat counters ──────────────────────────────────────────────────────

function initCounters() {
  function animateCounter(el) {
    const raw    = el.textContent.trim();
    const num    = parseFloat(raw);
    if (isNaN(num)) return;
    const suffix = raw.replace(String(num), '');
    const start  = performance.now();
    const dur    = 900;
    function step(now) {
      const t    = Math.min((now - start) / dur, 1);
      const ease = 1 - Math.pow(1 - t, 3);
      const val  = num * ease;
      el.textContent = (Number.isInteger(num) ? Math.round(val) : val.toFixed(1)) + suffix;
      if (t < 1) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }

  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.querySelectorAll('.stat-block__value').forEach(animateCounter);
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.4 });

  const statsSection = document.querySelector('.profile-stats');
  if (statsSection) observer.observe(statsSection);
}

// ── Portfolio lightbox ──────────────────────────────────────────────────────────

function initLightbox() {
  const items = document.querySelectorAll('.portfolio-item');
  if (!items.length) return;

  const overlay = document.createElement('div');
  overlay.className = 'portfolio-lightbox';
  overlay.setAttribute('role', 'dialog');
  overlay.setAttribute('aria-modal', 'true');
  overlay.setAttribute('aria-label', 'Portfolio image');
  overlay.innerHTML = `
    <button class="portfolio-lightbox__close" aria-label="Close">
      <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2.5">
        <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
      </svg>
    </button>
    <img class="portfolio-lightbox__img" src="" alt="Portfolio image" />
  `;
  document.body.appendChild(overlay);

  const lbImg   = overlay.querySelector('.portfolio-lightbox__img');
  const closeBtn = overlay.querySelector('.portfolio-lightbox__close');

  function openLightbox(src, alt) {
    lbImg.src = src;
    lbImg.alt = alt || 'Portfolio image';
    overlay.classList.add('is-open');
    document.body.style.overflow = 'hidden';
    closeBtn.focus();
  }

  function closeLightbox() {
    overlay.classList.remove('is-open');
    document.body.style.overflow = '';
  }

  items.forEach(item => {
    item.setAttribute('role', 'button');
    item.setAttribute('tabindex', '0');
    item.addEventListener('click', () => {
      const img = item.querySelector('img');
      if (img) openLightbox(img.src, img.alt);
    });
    item.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); item.click(); }
    });
  });

  closeBtn.addEventListener('click', closeLightbox);
  overlay.addEventListener('click', e => { if (e.target === overlay) closeLightbox(); });
  document.addEventListener('keydown', e => { if (e.key === 'Escape') closeLightbox(); });
}

// ── Preview mode (tech viewing own profile) ────────────────────────────────────

function applyPreviewMode() {
  // Hide header, footer, and chrome — tech sees pure customer view
  [
    'header', '.site-header',
    'footer', '.site-footer',
    '.skip-link', '.scroll-progress',
  ].forEach(sel => {
    document.querySelectorAll(sel).forEach(el => { el.style.display = 'none'; });
  });

  // Banner at the top of main
  const main = document.querySelector('main');
  if (main) {
    const banner = document.createElement('div');
    banner.style.cssText = [
      'position:sticky',
      'top:0',
      'z-index:200',
      'display:flex',
      'align-items:center',
      'justify-content:space-between',
      'gap:1rem',
      'padding:0 1.5rem',
      'height:48px',
      'background:rgba(10,10,18,0.82)',
      'backdrop-filter:blur(12px)',
      '-webkit-backdrop-filter:blur(12px)',
      'border-bottom:1px solid rgba(255,255,255,0.08)',
      'font-size:0.8125rem',
    ].join(';');

    banner.innerHTML = `
      <div style="display:flex;align-items:center;gap:0.55rem;color:rgba(255,255,255,0.55);font-size:0.75rem;letter-spacing:0.04em;text-transform:uppercase;font-weight:500">
        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0;opacity:0.7"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
        Customer view
      </div>
      <div style="display:flex;align-items:center;gap:0.5rem;color:rgba(255,255,255,0.85);font-weight:500;font-size:0.8125rem;">
        <span style="width:7px;height:7px;border-radius:50%;background:#f59e0b;flex-shrink:0;box-shadow:0 0 6px #f59e0b99"></span>
        Preview Mode
      </div>
      <a href="./technician-dashboard.html" style="
        display:inline-flex;align-items:center;gap:0.4rem;
        color:rgba(255,255,255,0.9);text-decoration:none;
        font-size:0.8rem;font-weight:500;
        background:rgba(255,255,255,0.08);
        border:1px solid rgba(255,255,255,0.12);
        border-radius:999px;padding:0.3rem 0.9rem;
        transition:background 0.2s;
        white-space:nowrap;
      "
      onmouseover="this.style.background='rgba(255,255,255,0.15)'"
      onmouseout="this.style.background='rgba(255,255,255,0.08)'">
        <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
        Back to Dashboard
      </a>`;

    main.insertBefore(banner, main.firstChild);
  }

  // Hide header booking/message actions
  const profileActions = document.querySelector('.profile-actions');
  if (profileActions) profileActions.style.display = 'none';

  // Replace sticky booking card with a locked notice
  const bookingCard = document.querySelector('.booking-action-card');
  if (bookingCard) {
    bookingCard.innerHTML = `
      <div style="text-align:center;padding:1.5rem 1rem;opacity:0.7">
        <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" style="display:block;margin:0 auto 0.5rem"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
        <p style="margin:0;font-size:0.85rem;line-height:1.5">Booking and messaging are<br>locked in preview mode.</p>
      </div>`;
  }
}

// ── Init ───────────────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', async () => {
  const techId = getParam('id');
  const serviceKey = getParam('service') || '';
  const subserviceKey = getParam('subservice') || '';
  const isPreview = getParam('preview') === '1';

  if (!techId) {
    window.location.replace('./technician-listing.html');
    return;
  }

  const getLang = () => window.__lang || document.documentElement.lang || 'en';

  try {
    const [res, reviews] = await Promise.all([
      getWorker(techId),
      getWorkerReviews(techId).catch(() => []),
    ]);
    const worker = res?.worker || res?.data?.worker;

    if (!worker) {
      console.error('Worker not found in response:', res);
      window.location.replace(buildListingHref(serviceKey, subserviceKey));
      return;
    }

    render(worker, getLang());
    renderReviews(reviews, getLang());
    renderRatingBars(reviews);

    // Attach heart-toggle to the hero card — top-right corner
    try {
      const favIds = await listMyFavoriteIds().catch(() => new Set());
      const heart = createHeartToggle({
        workerId: String(worker._id),
        isFavorited: favIds.has(String(worker._id)),
      });
      heart.classList.add('tech-profile__heart');
      const heroCard = document.querySelector('.profile-hero-card');
      if (heroCard) heroCard.appendChild(heart);
    } catch (_) { /* heart optional */ }

    // Busy badge — insert after profile name element
    const busyBadge = renderBusyBadge(worker.busyState);
    if (busyBadge) {
      const nameEl = document.querySelector('[data-profile-target="name"]') ||
                     document.querySelector('.profile-name');
      if (nameEl) nameEl.insertAdjacentElement('afterend', busyBadge);
    }

    // Disable Book Now buttons if worker is currently busy
    if (worker.busyState?.isBusy) {
      const busyTitle = `Busy — try again in ~${worker.busyState.remainingMin ?? 'a few'} min`;
      [
        document.getElementById('bookNowBtn'),
        document.getElementById('bookServiceBtn'),
        el('book-btn'),
        document.querySelector('[data-book-btn]'),
        document.querySelector('.profile-cta__btn'),
      ].forEach(btn => {
        if (btn) {
          btn.setAttribute('disabled', 'true');
          btn.setAttribute('title', busyTitle);
        }
      });
    }

    document.addEventListener('langchange', e => {
      const lang = e.detail?.lang || getLang();
      render(worker, lang);
      renderReviews(reviews, lang);
      renderRatingBars(reviews);
    });

    if (isPreview) {
      applyPreviewMode();
    } else {
      // Wire all Book Now buttons
      const bookingHref = buildBookingHref(techId, serviceKey, subserviceKey);
      const bookNowBtn = document.getElementById('bookNowBtn');
      const bookServiceBtn = document.getElementById('bookServiceBtn');
      if (bookNowBtn) bookNowBtn.href = bookingHref;
      if (bookServiceBtn) bookServiceBtn.href = bookingHref;
      const bookBtn = el('book-btn') || document.querySelector('[data-book-btn]') || document.querySelector('.profile-cta__btn');
      if (bookBtn) bookBtn.href = bookingHref;
    }

    runAnimations();
    initCounters();
    initLightbox();

  } catch (err) {
    console.error('Failed to load worker profile:', err);
    const main = document.querySelector('main');
    if (main) main.innerHTML = '<p style="padding:3rem;text-align:center">Profile not found.</p>';
  }
});
