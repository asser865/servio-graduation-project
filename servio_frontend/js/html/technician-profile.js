/**
 * technician-profile.js
 * Dynamic profile population + entry animations + portfolio lightbox.
 */

import { animate, stagger } from 'https://cdn.jsdelivr.net/npm/motion@12.38.0/+esm';
import { getWorker } from '../api/users.js';

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

function el(target) {
  return document.querySelector(`[data-profile-target="${target}"]`);
}

function setText(target, value) {
  const node = el(target);
  if (node) node.textContent = value;
}

const CLOCK_SVG = `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`;

// ── Render ─────────────────────────────────────────────────────────────────────

function render(worker, lang) {
  const isAr = lang === 'ar';
  const name = escapeHtml(worker.name || 'Technician');
  const categories = (worker.categories || []).join(', ') || '—';
  const rating = worker.averageRating?.toFixed(1) || '0.0';
  const reviewCount = worker.totalReviews || 0;
  const avatarUrl = worker.profileImage || 'https://ui-avatars.com/api/?name=' + encodeURIComponent(worker.name || 'T') + '&background=0d6efd&color=fff&size=256';
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

  // Availability Pills Logic
  const availType = worker.availabilityType || 'both'; // Default to both if not set
  const pills = document.querySelectorAll('.avail-pill');
  pills.forEach(pill => {
    const dayKey = pill.getAttribute('data-i18n') || '';
    pill.classList.remove('avail-pill--on', 'avail-pill--off');
    
    // Simple logic: Fri is usually 'off' unless 'both' or specific days
    if (dayKey === 'prof_day_fri') {
      pill.classList.add(availType === 'both' ? 'avail-pill--on' : 'avail-pill--off');
    } else {
      // Sat-Thu are 'on' for weekdays or both, 'off' for weekends (approximate)
      if (availType === 'weekdays' || availType === 'both') {
        pill.classList.add('avail-pill--on');
      } else {
        pill.classList.add('avail-pill--off');
      }
    }
  });

  const coverageAreas = el('coverage-areas');
  if (coverageAreas) {
    coverageAreas.innerHTML = (worker.categories || ['general'])
      .map(c => `<span class="coverage-tag">${escapeHtml(c)}</span>`)
      .join('');
  }

  const servicesGrid = el('services-grid');
  if (servicesGrid) {
    // Show worker skills as service cards
    const displayList = worker.skills && worker.skills.length ? worker.skills : worker.categories;
    servicesGrid.innerHTML = displayList.length
      ? displayList.map(c => `
        <div class="service-card">
          <div class="service-card__body">
            <div class="service-card__name">${escapeHtml(c)}</div>
            <div class="service-card__price">—</div>
          </div>
        </div>`).join('')
      : '<p>—</p>';
  }
}

// ── Render reviews ─────────────────────────────────────────────────────────────

function renderReviews(reviews, lang) {
  const isAr = lang === 'ar';
  const container = el('reviews-list');
  if (!container) return;

  if (!reviews || !reviews.length) {
    container.innerHTML = `<p style="padding:1rem">${isAr ? 'لا توجد تقييمات بعد.' : 'No reviews yet.'}</p>`;
    return;
  }

  container.innerHTML = reviews.map(r => {
    const reviewer = escapeHtml(r.user?.name || 'Customer');
    const comment = escapeHtml(r.comment || '');
    const stars = '★'.repeat(Math.round(r.rating || 0)) + '☆'.repeat(5 - Math.round(r.rating || 0));
    const date = r.createdAt ? new Date(r.createdAt).toLocaleDateString(isAr ? 'ar-EG' : 'en-US') : '';
    return `
      <div class="review-card">
        <div class="review-card__header">
          <span class="review-card__name">${reviewer}</span>
          <span class="review-card__stars">${stars}</span>
          <span class="review-card__date">${date}</span>
        </div>
        <p class="review-card__body">${comment}</p>
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

// ── Init ───────────────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', async () => {
  const techId = getParam('id');
  const serviceKey = getParam('service') || '';

  if (!techId) {
    window.location.replace('./technician-listing.html');
    return;
  }

  const getLang = () => window.__lang || document.documentElement.lang || 'en';

  try {
    const res = await getWorker(techId);
    // api client already unwraps { success, data } → res IS the data object directly
    const worker = res?.worker || res?.data?.worker;
    const reviews = res?.reviews || res?.data?.reviews || [];

    if (!worker) {
      console.error('Worker not found in response:', res);
      window.location.replace('./technician-listing.html' + (serviceKey ? `?service=${serviceKey}` : ''));
      return;
    }

    render(worker, getLang());
    renderReviews(reviews, getLang());

    document.addEventListener('langchange', e => {
      const lang = e.detail?.lang || getLang();
      render(worker, lang);
      renderReviews(reviews, lang);
    });

    // Book Now button — link to booking page
    const bookBtn = el('book-btn') || document.querySelector('[data-book-btn]') || document.querySelector('.profile-cta__btn');
    if (bookBtn) {
      bookBtn.href = `./booking.html?worker=${techId}&service=${serviceKey}`;
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
