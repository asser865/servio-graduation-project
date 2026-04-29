/* Booking Confirmation JS — SERVIO */
import { animate, stagger } from 'https://cdn.jsdelivr.net/npm/motion@12.38.0/+esm';
import { showToast } from '../components/toast.js';

// ── Coming-soon stubs ─────────────────────────────────────────────────────────
document.getElementById('trackStatusBtn')?.addEventListener('click', () => {
  showToast('Coming soon', 'info');
});

const booking = JSON.parse(localStorage.getItem('servio_active_booking') || 'null');

// Wire "View Details" button to real booking if available
const viewDetailsBtn = document.getElementById('viewDetailsBtn') || document.querySelector('[data-view-details]');
if (viewDetailsBtn && booking?._id) {
  viewDetailsBtn.href = `./booking-details.html?id=${booking._id}`;
}

// Populate booking reference elements
const refEls = document.querySelectorAll('[data-booking-ref]');
refEls.forEach(el => { el.textContent = 'Booking #' + (booking?.id || '—'); });
const refDescEls = document.querySelectorAll('[data-booking-ref-desc]');
refDescEls.forEach(el => {
  el.textContent = 'Your request has been sent. Reference: #' + (booking?.id || '—');
});

// Populate PIN
const pinEl = document.getElementById('confirmationPin');
if (pinEl && booking?.pin) {
  pinEl.textContent = String(booking.pin).split('').join(' ');
} else if (pinEl) {
  pinEl.textContent = 'PIN not available';
}

// Populate payment summary
const paymentEl = document.getElementById('confirmationPaymentDetails');
if (paymentEl && booking) {
  const labelKey = booking.payment === 'cash' ? 'booking_cash_desc' : 'booking_online_desc';
  paymentEl.textContent = (typeof window.t === 'function' ? window.t(labelKey) : labelKey);
} else if (paymentEl) {
  paymentEl.textContent = (typeof window.t === 'function' ? window.t('booking_online_desc') : 'booking_online_desc');
}

// ── Redirect to History ───────────────────────────────────────────────────────
document.getElementById('viewHistoryBtn')?.addEventListener('click', () => {
  localStorage.setItem('servio_activeTab_customer', 'history');
  window.location.href = './customer-dashboard.html';
});

// ── Copy booking reference ────────────────────────────────────────────────────
const refBtn = document.getElementById('refCopyBtn');
if (refBtn) {
  refBtn.addEventListener('click', async () => {
    const refText = '#' + (booking?.id || '—');
    try {
      await navigator.clipboard.writeText(refText);
    } catch {
      // fallback: do nothing
    }
    refBtn.classList.add('is-copied');
    animate(refBtn, { scale: [1, 1.08, 1] }, { duration: 0.25 });
    setTimeout(() => refBtn.classList.remove('is-copied'), 2000);
  });
}

// ── Cancel booking button ─────────────────────────────────────────────────────
document.getElementById('cancelBtn')?.addEventListener('click', () => {
  const confirmMsg = (typeof window.t === 'function' ? window.t('conf_cancel_confirm') : 'Are you sure you want to cancel this booking?');
  if (confirm(confirmMsg)) {
    // Would navigate to cancellation flow
    const successMsg = (typeof window.t === 'function' ? window.t('conf_cancel_success') : 'conf_cancel_success');
    alert(successMsg);
  }
});

// ── Entry animations ──────────────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', () => {
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (prefersReducedMotion) return;

  const icon    = document.getElementById('successIcon');
  const heading = document.querySelector('.confirmation-hero h1');
  const sub     = document.querySelector('.confirmation-hero__sub');
  const ref     = document.querySelector('.booking-ref');

  // 1. Success icon: scale in with spring-like bounce
  if (icon) {
    animate(icon,
      { scale: [0, 1.2, 0.9, 1.05, 1], opacity: [0, 1, 1, 1, 1] },
      { duration: 0.7, easing: 'ease-out' }
    );
  }

  // 2. Stagger heading, sub, ref badge
  animate([heading, sub, ref].filter(Boolean),
    { opacity: [0, 1], y: [16, 0] },
    { duration: 0.45, delay: stagger(0.1, { start: 0.35 }), easing: 'ease-out' }
  );

  // 3. Cards reveal
  const cards = document.querySelectorAll('.conf-card, .timeline, .conf-sidebar-card, .help-card');
  animate(cards,
    { opacity: [0, 1], y: [20, 0] },
    { duration: 0.5, delay: stagger(0.08, { start: 0.55 }), easing: 'ease-out' }
  );

  // 4. Timeline items stagger
  const timelineItems = document.querySelectorAll('.timeline-item');
  animate(timelineItems,
    { opacity: [0, 1], x: [-12, 0] },
    { duration: 0.4, delay: stagger(0.1, { start: 0.9 }), easing: 'ease-out' }
  );
});


