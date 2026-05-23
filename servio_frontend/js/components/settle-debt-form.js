import { getMyDebtsV2, settleMyDebt } from '../api/payments.js';
import { uploadImage } from '../utils/upload-image.js';

function fmt(n) {
  try { return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'EGP' }).format(Number(n) || 0); }
  catch (_) { return `${Number(n || 0).toFixed(2)} EGP`; }
}

const SEND_TO = {
  instapay:       'Send to: servio@instapay',
  vodafone_cash:  'Send to: 01000000000',
  bank_transfer:  'Bank: NBE — IBAN EG000000000000000000000',
  cash_to_office: 'Office: Servio HQ, 12 St., Cairo (Sun-Thu 10-17)',
};

export async function openSettleDebtModal({ onSuccess, onError } = {}) {
  let summary, walletBalance = 0;
  try {
    const my = await getMyDebtsV2();
    summary = my?.data?.summary || {};
    walletBalance = Number(summary.walletBalance || 0);
  } catch (e) {
    (onError || alert)('Failed to load debts: ' + (e.message || e));
    return;
  }
  const totalOwed = Number(summary.totalOutstanding || 0);
  if (totalOwed <= 0) { (onError || alert)('No outstanding debt'); return; }

  const w = document.createElement('div');
  w.className = 'modal modal--center';
  w.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.5);display:flex;align-items:center;justify-content:center;z-index:9999;';
  w.innerHTML = `
    <div class="modal__panel" style="background:#fff;padding:24px;border-radius:12px;max-width:500px;width:90%;max-height:90vh;overflow:auto;">
      <button class="modal__close" type="button" style="position:absolute;top:12px;right:12px;border:none;background:none;font-size:24px;cursor:pointer;">×</button>
      <h2>Settle Debt</h2>
      <p>Amount owed: <strong>${fmt(totalOwed)}</strong></p>
      <label style="display:block;margin:12px 0;">Pay amount
        <div class="row" style="display:flex;gap:8px;margin-top:4px;">
          <input type="number" id="payAmt" min="0.01" max="${totalOwed}" step="0.01" value="${totalOwed.toFixed(2)}" required style="flex:1;padding:8px;border:1px solid #e5e7eb;border-radius:6px;">
          <button type="button" data-quick="${totalOwed}" class="btn-premium btn-premium--sm">Full</button>
          <button type="button" data-quick="${(totalOwed/2).toFixed(2)}" class="btn-premium btn-premium--sm">Half</button>
        </div>
      </label>
      <fieldset style="border:1px solid #e5e7eb;padding:12px;border-radius:8px;margin:12px 0;">
        <legend>Method</legend>
        <label style="display:block;padding:4px 0;"><input type="radio" name="m" value="wallet_balance"> Wallet (${fmt(walletBalance)})</label>
        <label style="display:block;padding:4px 0;"><input type="radio" name="m" value="instapay"> Instapay</label>
        <label style="display:block;padding:4px 0;"><input type="radio" name="m" value="vodafone_cash"> Vodafone Cash</label>
        <label style="display:block;padding:4px 0;"><input type="radio" name="m" value="bank_transfer"> Bank transfer</label>
        <label style="display:block;padding:4px 0;"><input type="radio" name="m" value="cash_to_office"> Cash at office</label>
      </fieldset>
      <div id="manualFields" hidden>
        <label style="display:block;margin:8px 0;">Transaction reference<input type="text" id="ref" minlength="3" style="width:100%;padding:8px;border:1px solid #e5e7eb;border-radius:6px;margin-top:4px;"></label>
        <label style="display:block;margin:8px 0;">Receipt photo<input type="file" id="proof" accept="image/jpeg,image/png,image/webp" style="margin-top:4px;"></label>
        <p class="note" id="sendToNote" style="background:#fef3c7;padding:8px;border-radius:6px;color:#92400e;font-size:0.875rem;"></p>
      </div>
      <div class="modal__actions" style="display:flex;gap:8px;justify-content:flex-end;margin-top:16px;">
        <button class="btn-premium btn-premium--ghost" data-cancel type="button">Cancel</button>
        <button class="btn-premium btn-premium--primary" data-submit type="button">Submit settlement</button>
      </div>
      <p class="note" style="font-size:0.75rem;color:#6b7280;margin-top:8px;">Manual methods need admin verification (usually &lt;24h).</p>
    </div>`;
  document.body.appendChild(w);
  const close = () => w.remove();
  w.querySelector('.modal__close').onclick = close;
  w.querySelector('[data-cancel]').onclick = close;
  w.addEventListener('click', (e) => { if (e.target === w) close(); });

  w.querySelectorAll('[data-quick]').forEach(b => {
    b.onclick = () => { w.querySelector('#payAmt').value = b.dataset.quick; };
  });

  w.querySelectorAll('input[name=m]').forEach(r => {
    r.onchange = () => {
      const isWallet = r.value === 'wallet_balance';
      w.querySelector('#manualFields').hidden = isWallet;
      w.querySelector('#sendToNote').textContent = SEND_TO[r.value] || '';
    };
  });

  w.querySelector('[data-submit]').onclick = async () => {
    const amount = parseFloat(w.querySelector('#payAmt').value);
    const method = w.querySelector('input[name=m]:checked')?.value;
    if (!method) return alert('Pick a method');
    if (!(amount > 0 && amount <= totalOwed)) return alert('Invalid amount');
    const payload = { amount, method };
    if (method !== 'wallet_balance') {
      const ref = w.querySelector('#ref').value.trim();
      if (ref.length < 3) return alert('Reference required (3+ chars)');
      payload.reference = ref;
      const proofFile = w.querySelector('#proof').files[0];
      if (proofFile) {
        try {
          const u = await uploadImage(proofFile, 'settlement-proofs');
          payload.proofUrl = u.url || u;
        } catch (e) {
          return alert('Upload failed: ' + (e.message || e));
        }
      }
    }
    const btn = w.querySelector('[data-submit]');
    btn.disabled = true; btn.textContent = 'Submitting…';
    try {
      await settleMyDebt(payload);
      close();
      onSuccess?.();
    } catch (e) {
      btn.disabled = false; btn.textContent = 'Submit settlement';
      (onError || alert)(e.message || e);
    }
  };
}
