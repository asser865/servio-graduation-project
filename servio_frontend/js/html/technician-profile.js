/**
 * technician-profile.js
 * Dynamic profile population + entry animations + portfolio lightbox.
 */

import { animate, stagger } from 'https://cdn.jsdelivr.net/npm/motion@12.38.0/+esm';
import { TECHNICIANS } from '../data/technicians-data.js';
import { SERVICES } from '../data/services-data.js';

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

function render(tech, techId, serviceKey, lang) {
  const isAr = lang === 'ar';

  // Title
  const name = isAr ? tech.nameAr : tech.name;
  const title = isAr ? tech.titleAr : tech.title;
  document.title = `${name} – ${title} | SERVIO`;

  // Images
  const coverImg = el('cover-img');
  if (coverImg) { coverImg.src = tech.cover; coverImg.alt = name; }
  const avatar = el('avatar');
  if (avatar) { avatar.src = tech.avatar; avatar.alt = name; }

  // Name & title
  setText('name', name);
  setText('title', title);

  // Meta
  setText('location', `${tech.distance} mi. (${isAr ? tech.areaAr : tech.area})`);
  setText('rating', String(tech.rating));
  const reviewMeta = el('review-meta');
  if (reviewMeta) {
    reviewMeta.textContent = isAr
      ? `(${tech.reviewCount} تقييم)`
      : `(${tech.reviewCount} Reviews)`;
  }

  // Stats
  setText('flat-rate', isAr ? tech.flatRateAr : tech.flatRate);
  setText('years-exp', String(tech.yearsExp));
  setText('response-time', tech.responseTime);
  setText('job-success', tech.jobSuccess);

  // Bio
  setText('bio', isAr ? tech.bioAr : tech.bioEn);

  // Member since
  setText('member-since', isAr ? tech.memberSinceAr : tech.memberSince);

  // Services grid
  const servicesGrid = el('services-grid');
  if (servicesGrid) {
    servicesGrid.innerHTML = tech.services.map(svc => {
      const svcName     = escapeHtml(isAr ? svc.nameAr     : svc.nameEn);
      const svcPrice    = escapeHtml(isAr ? svc.priceAr    : svc.priceEn);
      const svcDuration = escapeHtml(isAr ? svc.durationAr : svc.durationEn);
      return `
      <div class="service-card${svc.emergency ? ' service-card--emergency' : ''}">
        <div class="service-card__icon-wrap">
          <svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="1.8">
            ${svc.emergency
              ? '<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>'
              : '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>'}
          </svg>
        </div>
        <div class="service-card__body">
          <div class="service-card__name">
            ${svcName}
            ${svc.emergency ? '<span class="emergency-badge">24/7</span>' : ''}
          </div>
          <div class="service-card__price">${svcPrice}</div>
          <div class="service-card__duration">
            ${CLOCK_SVG}
            <span>${svcDuration}</span>
          </div>
        </div>
      </div>`;
    }).join('');
  }

  // Coverage areas
  const coverageAreas = el('coverage-areas');
  if (coverageAreas) {
    const areaStr = isAr ? tech.areaAr : tech.area;
    coverageAreas.innerHTML = areaStr
      .split(', ')
      .map(a => `<span class="coverage-tag">${escapeHtml(a)}</span>`)
      .join('');
  }

  // Reviews overview numbers
  setText('rating-big', String(tech.rating));
  const ratingCount = el('rating-count');
  if (ratingCount) {
    ratingCount.textContent = isAr
      ? `بناءً على ${tech.reviewCount} تقييم`
      : `Based on ${tech.reviewCount} reviews`;
  }

  // Booking rate
  setText('booking-rate', String(tech.price));
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

document.addEventListener('DOMContentLoaded', () => {
  const techId    = getParam('id');
  const serviceKey = getParam('service');
  const tech      = techId && TECHNICIANS[techId];

  if (!tech) {
    const fallback = serviceKey
      ? `./technician-listing.html?service=${serviceKey}`
      : './technician-listing.html';
    window.location.replace(fallback);
    return;
  }

  const getLang = () => window.__lang || document.documentElement.lang || 'en';

  render(tech, techId, serviceKey, getLang());
  runAnimations();
  initCounters();
  initLightbox();

  document.addEventListener('langchange', e => {
    render(tech, techId, serviceKey, e.detail?.lang || getLang());
  });
});
