/* Booking Confirmation JS — SERVIO */
import { showToast } from '../components/toast.js';

// ── Coming-soon stubs ─────────────────────────────────────────────────────────
document.getElementById('trackStatusBtn')?.addEventListener('click', () => {
  showToast('Coming soon', 'info');
});

const booking = JSON.parse(localStorage.getItem('servio_active_booking') || 'null');

// Populate PIN
const pinEl = document.getElementById('confirmationPin');
if (pinEl && booking?.pin) {
  pinEl.textContent = String(booking.pin).split('').join(' ');
} else if (pinEl) {
  pinEl.textContent = '4 8 2 1'; // fallback for direct page visits
}

// Populate payment summary
const paymentEl = document.getElementById('confirmationPaymentDetails');
if (paymentEl && booking) {
  const labelKey = booking.payment === 'cash' ? 'booking_cash_desc' : 'booking_online_desc';
  paymentEl.textContent = window.t(labelKey);
} else if (paymentEl) {
  paymentEl.textContent = window.t('booking_online_desc');
}

// ── Redirect to History ───────────────────────────────────────────────────────
document.getElementById('viewHistoryBtn')?.addEventListener('click', () => {
  localStorage.setItem('servio_activeTab_customer', 'history');
  window.location.href = './customer-dashboard.html';
});

// .
