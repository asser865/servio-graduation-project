/* Booking Confirmation JS — SERVIO */
import { animate, stagger } from 'https://cdn.jsdelivr.net/npm/motion@12.38.0/+esm';
import { showToast } from '../components/toast.js';
import { cancelBooking } from '../api/bookings.js';

const booking = JSON.parse(localStorage.getItem('servio_active_booking') || 'null');
const tech    = booking?.technician || {};

// ── Helpers ───────────────────────────────────────────────────────────────────
function setText(id, text) {
  const el = document.getElementById(id);
  if (el) el.textContent = text;
}

// ── Populate all dynamic fields ───────────────────────────────────────────────
// Runs inside DOMContentLoaded so it executes AFTER the i18n system (lang.js
// registers its DOMContentLoaded handler as a regular sync script, which runs
// before module-script DOMContentLoaded handlers).
function populate() {
  if (!booking) {
    setText('conf-hero-sub',
      'Your service request has been submitted. We will notify you once confirmed.');
    setText('confirmationPaymentDetails', '—');
    setText('confirmationPin', 'PIN not available');
    return;
  }

  // Hero subtitle
  const techName = tech.name || booking.workerName || '';
  setText('conf-hero-sub', techName
    ? `Your request has been sent to ${techName}. They will confirm within 30 minutes.`
    : 'Your service request has been submitted. We will notify you once confirmed.');

  // Technician card
  const avatar = document.getElementById('conf-tech-avatar');
  if (avatar) {
    const src = booking.workerAvatar || booking.workerPhoto;
    if (src) { avatar.src = src; avatar.alt = techName || 'Technician'; }
  }
  setText('conf-tech-name', techName || '—');

  const roleEl = document.getElementById('conf-tech-role');
  if (roleEl) {
    const specialty = tech.specialty || '—';
    const loc       = booking.workerLocation || '';
    roleEl.textContent = loc ? `${specialty} · ${loc}` : specialty;
  }

  const ratingEl = document.getElementById('conf-tech-rating');
  if (ratingEl) {
    const rating  = tech.rating != null ? tech.rating : '—';
    const reviews = booking.workerReviewCount;
    ratingEl.textContent = reviews ? `${rating} · ${reviews} reviews` : `${rating}`;
  }

  // Service details
  setText('conf-service-value', booking.service || booking.serviceType || booking.category || '—');
  setText('conf-date-value',    booking.date    || booking.scheduledDate || '—');
  setText('conf-time-value',    booking.time    || booking.scheduledTime || '—');
  setText('conf-address-value', booking.address || '—');

  // Payment rows
  setText('conf-payment-method-value', booking.paymentMethod || booking.payment || '—');

  const rate = booking.rate != null ? Number(booking.rate) : null;
  if (rate != null && rate > 0) {
    const fee   = rate * 0.05;
    setText('conf-base-rate-value',    `${rate.toFixed(2)} EGP`);
    setText('conf-platform-fee-value', `${fee.toFixed(2)} EGP`);
    setText('conf-total-value',        `${(rate + fee).toFixed(2)} EGP+`);
  } else {
    const rateRow = document.getElementById('conf-base-rate-row');
    const feeRow  = document.getElementById('conf-platform-fee-row');
    if (rateRow) rateRow.hidden = true;
    if (feeRow)  feeRow.hidden  = true;
    setText('conf-total-value', '—');
  }

  // Payment summary card (no data-i18n on this element anymore)
  const payEl = document.getElementById('confirmationPaymentDetails');
  if (payEl) {
    if (booking.payment === 'cash') {
      payEl.textContent = 'You will pay cash to the technician upon arrival. No upfront payment required.';
    } else if (booking.payment === 'online') {
      payEl.textContent = 'Payment will be processed online. You will receive a receipt via email.';
    } else {
      payEl.textContent = booking.paymentMethod || '—';
    }
  }

  // Booking reference badge (no data-i18n on this element)
  document.querySelectorAll('[data-booking-ref]').forEach(el => {
    el.textContent = 'Booking #' + (booking.id || booking._id || '—');
  });

  // PIN
  const pinEl = document.getElementById('confirmationPin');
  if (pinEl) {
    pinEl.textContent = booking.pin
      ? String(booking.pin).split('').join(' ')
      : 'PIN not available';
  }

  // Sidebar message button and view-details link
  setText('conf-msg-tech-name', techName ? `Message ${techName}` : 'Message Technician');

  const viewDetailsBtn = document.getElementById('viewDetailsBtn');
  if (viewDetailsBtn && booking._id && /^[a-f0-9]{24}$/i.test(booking._id)) {
    viewDetailsBtn.href = `./booking-details.html?id=${booking._id}`;
  }
}

// ── Event wiring (can happen before DOMContentLoaded) ────────────────────────
document.getElementById('viewHistoryBtn')?.addEventListener('click', () => {
  localStorage.setItem('servio_activeTab_customer', 'history');
  window.location.href = './customer-dashboard.html';
});

const refBtn = document.getElementById('refCopyBtn');
if (refBtn) {
  refBtn.addEventListener('click', async () => {
    const refText = '#' + (booking?.id || booking?._id || '—');
    try { await navigator.clipboard.writeText(refText); } catch { /* fallback */ }
    refBtn.classList.add('is-copied');
    animate(refBtn, { scale: [1, 1.08, 1] }, { duration: 0.25 });
    setTimeout(() => refBtn.classList.remove('is-copied'), 2000);
  });
}

document.getElementById('cancelBtn')?.addEventListener('click', async () => {
  const msg = typeof window.t === 'function'
    ? window.t('conf_cancel_confirm')
    : 'Are you sure you want to cancel this booking?';
  if (!confirm(msg)) return;

  if (booking?._id && /^[a-f0-9]{24}$/i.test(booking._id)) {
    try {
      await cancelBooking(booking._id);
      localStorage.removeItem('servio_active_booking');
      showToast('Booking cancelled', 'success');
      setTimeout(() => { window.location.href = './customer-dashboard.html'; }, 1500);
    } catch {
      showToast('Could not cancel booking. Please try again.', 'error');
    }
  } else {
    localStorage.removeItem('servio_active_booking');
    showToast('Booking cancelled', 'success');
    setTimeout(() => { window.location.href = './customer-dashboard.html'; }, 1500);
  }
});

// ── DOMContentLoaded: populate data + run animations ─────────────────────────
// populate() must be here, not at module top-level, so it fires AFTER lang.js
// applies i18n translations (lang.js registers its boot on DOMContentLoaded as
// a regular sync script, whose handler executes before our module's handler).
window.addEventListener('DOMContentLoaded', () => {
  populate();

  // Also re-populate on language switch so i18n doesn't clobber dynamic values
  window.addEventListener('langchange', populate);

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  const icon    = document.getElementById('successIcon');
  const heading = document.querySelector('.confirmation-hero h1');
  const sub     = document.querySelector('.confirmation-hero__sub');
  const ref     = document.querySelector('.booking-ref');

  if (icon) {
    animate(icon,
      { scale: [0, 1.2, 0.9, 1.05, 1], opacity: [0, 1, 1, 1, 1] },
      { duration: 0.7, easing: 'ease-out' }
    );
  }

  animate([heading, sub, ref].filter(Boolean),
    { opacity: [0, 1], y: [16, 0] },
    { duration: 0.45, delay: stagger(0.1, { start: 0.35 }), easing: 'ease-out' }
  );

  const cards = document.querySelectorAll(
    '.conf-card, .timeline, .conf-sidebar-card, .help-card, .confirmation-pin-card, .confirmation-payment-card'
  );
  animate(cards,
    { opacity: [0, 1], y: [20, 0] },
    { duration: 0.5, delay: stagger(0.08, { start: 0.55 }), easing: 'ease-out' }
  );

  animate(document.querySelectorAll('.timeline-item'),
    { opacity: [0, 1], x: [-12, 0] },
    { duration: 0.4, delay: stagger(0.1, { start: 0.9 }), easing: 'ease-out' }
  );
});
