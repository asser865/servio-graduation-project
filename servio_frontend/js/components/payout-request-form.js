import { requestPayout } from '../api/payments.js';

function fmt(n) {
  try { return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'EGP' }).format(Number(n) || 0); }
  catch (_) { return `${Number(n || 0).toFixed(2)} EGP`; }
}

export function openPayoutRequestModal({ availableBalance, onSuccess, onError } = {}) {
  const balance = Number(availableBalance ?? 0);
  const w = document.createElement('div');
  w.className = 'modal modal--center';
  w.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.5);display:flex;align-items:center;justify-content:center;z-index:9999;';
  w.innerHTML = `
    <div class="modal__panel" style="background:#fff;padding:24px;border-radius:12px;max-width:500px;width:90%;max-height:90vh;overflow:auto;position:relative;">
      <button class="modal__close" type="button" style="position:absolute;top:12px;right:12px;border:none;background:none;font-size:24px;cursor:pointer;">×</button>
      <h2>Request Payout</h2>
      <p>Available: <strong>${fmt(balance)}</strong></p>
      <label style="display:block;margin:12px 0;">Amount
        <div class="row" style="display:flex;gap:8px;margin-top:4px;">
          <input type="number" id="poAmt" min="50" max="${balance || 9999999}" step="0.01" required style="flex:1;padding:8px;border:1px solid #e5e7eb;border-radius:6px;">
          <button type="button" data-quick class="btn-premium btn-premium--sm">All</button>
        </div>
      </label>
      <fieldset style="border:1px solid #e5e7eb;padding:12px;border-radius:8px;margin:12px 0;">
        <legend>Method</legend>
        <label style="display:block;padding:4px 0;"><input type="radio" name="m" value="bank" checked> Bank transfer</label>
        <label style="display:block;padding:4px 0;"><input type="radio" name="m" value="instapay"> Instapay</label>
        <label style="display:block;padding:4px 0;"><input type="radio" name="m" value="vodafone_cash"> Vodafone Cash</label>
        <label style="display:block;padding:4px 0;"><input type="radio" name="m" value="orange_cash"> Orange Cash</label>
      </fieldset>
      <label style="display:block;margin:8px 0;">Details<textarea id="poDetails" placeholder="IBAN / phone / account ref" style="width:100%;padding:8px;border:1px solid #e5e7eb;border-radius:6px;margin-top:4px;min-height:60px;"></textarea></label>
      <label style="display:block;margin:8px 0;">Note (optional)<input id="poNote" type="text" maxlength="200" style="width:100%;padding:8px;border:1px solid #e5e7eb;border-radius:6px;margin-top:4px;"></label>
      <div class="modal__actions" style="display:flex;gap:8px;justify-content:flex-end;margin-top:16px;">
        <button class="btn-premium btn-premium--ghost" data-cancel type="button">Cancel</button>
        <button class="btn-premium btn-premium--primary" data-submit type="button">Submit Request</button>
      </div>
      <p class="note" style="font-size:0.75rem;color:#6b7280;margin-top:8px;">Processed within 3 business days.</p>
    </div>`;
  document.body.appendChild(w);
  const close = () => w.remove();
  w.querySelector('.modal__close').onclick = close;
  w.querySelector('[data-cancel]').onclick = close;
  w.addEventListener('click', (e) => { if (e.target === w) close(); });
  w.querySelector('[data-quick]').onclick = () => { w.querySelector('#poAmt').value = balance; };

  w.querySelector('[data-submit]').onclick = async () => {
    const amount = parseFloat(w.querySelector('#poAmt').value);
    const method = w.querySelector('input[name=m]:checked').value;
    const details = w.querySelector('#poDetails').value.trim();
    const note = w.querySelector('#poNote').value.trim();
    if (!(amount >= 50)) return alert('Min 50');
    if (balance > 0 && amount > balance) return alert('Amount exceeds balance');
    if (!details) return alert('Details required');
    const btn = w.querySelector('[data-submit]');
    btn.disabled = true; btn.textContent = 'Submitting…';
    try {
      await requestPayout({ amount, method, details: { raw: details, note } });
      close();
      onSuccess?.();
    } catch (e) {
      btn.disabled = false; btn.textContent = 'Submit Request';
      (onError || alert)(e.message || e);
    }
  };
}
