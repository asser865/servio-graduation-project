import { openDispute } from '../api/disputes.js';

export function openDisputeModal({ bookingId, onSuccess, onError }) {
  const wrap = document.createElement('div');
  wrap.className = 'modal modal--center';
  wrap.innerHTML = `
    <div class="modal__panel">
      <button class="modal__close" aria-label="Close">&times;</button>
      <h2 data-i18n="dispute.title">Report an issue</h2>
      <fieldset>
        <legend data-i18n="dispute.reason">Reason</legend>
        <label><input type="radio" name="reason" value="work_not_done" required> Work not done</label>
        <label><input type="radio" name="reason" value="quality"> Quality issue</label>
        <label><input type="radio" name="reason" value="price_mismatch"> Price mismatch</label>
        <label><input type="radio" name="reason" value="damage"> Damage caused</label>
        <label><input type="radio" name="reason" value="other"> Other</label>
      </fieldset>
      <label class="block">
        <span data-i18n="dispute.details">Details (min 20 chars)</span>
        <textarea id="disputeDetails" minlength="20" maxlength="2000" required></textarea>
      </label>
      <label class="block">
        <span data-i18n="dispute.photos">Photos (optional, max 4)</span>
        <input type="file" id="disputePhotos" multiple accept="image/png,image/jpeg,image/webp">
      </label>
      <div class="modal__actions">
        <button class="btn btn--ghost" data-action="cancel">Cancel</button>
        <button class="btn btn--danger" data-action="submit">Submit dispute</button>
      </div>
    </div>`;
  document.body.appendChild(wrap);
  const close = () => wrap.remove();
  wrap.querySelector('.modal__close').onclick = close;
  wrap.querySelector('[data-action="cancel"]').onclick = close;
  wrap.querySelector('[data-action="submit"]').onclick = async () => {
    const reason = wrap.querySelector('input[name="reason"]:checked')?.value;
    const details = wrap.querySelector('#disputeDetails').value.trim();
    if (!reason || details.length < 20) return alert('Pick a reason and add 20+ chars');
    const btn = wrap.querySelector('[data-action="submit"]');
    btn.disabled = true;
    btn.textContent = 'Submitting…';
    try {
      const result = await openDispute(bookingId, { reasonCategory: reason, details, photos: [] });
      close();
      onSuccess?.(result);
    } catch (err) {
      btn.disabled = false;
      btn.textContent = 'Submit dispute';
      onError?.(err);
    }
  };
}
