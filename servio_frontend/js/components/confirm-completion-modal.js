import { confirmBooking } from '../api/payments.js';

export function openConfirmCompletionModal({ bookingId, rating, comment, tags, onSuccess, onError }) {
  const wrap = document.createElement('div');
  wrap.className = 'modal modal--center';
  wrap.innerHTML = `
    <div class="modal__panel">
      <button class="modal__close" aria-label="Close">&times;</button>
      <h2 data-i18n="escrow.confirmModalTitle">Confirm completion</h2>
      <p data-i18n="escrow.confirmModalBody">By confirming, the booking moves to admin review and payment will be released after approval.</p>
      <div class="modal__actions">
        <button class="btn btn--ghost" data-action="cancel">Cancel</button>
        <button class="btn btn--primary" data-action="submit">Confirm</button>
      </div>
    </div>`;
  document.body.appendChild(wrap);
  const close = () => wrap.remove();
  wrap.querySelector('.modal__close').onclick = close;
  wrap.querySelector('[data-action="cancel"]').onclick = close;
  wrap.querySelector('[data-action="submit"]').onclick = async () => {
    const btn = wrap.querySelector('[data-action="submit"]');
    btn.disabled = true;
    btn.textContent = 'Submitting…';
    try {
      const result = await confirmBooking(bookingId, { rating, comment, tags });
      close();
      onSuccess?.(result);
    } catch (err) {
      btn.disabled = false;
      btn.textContent = 'Confirm';
      onError?.(err);
    }
  };
}
