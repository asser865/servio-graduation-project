import { requestPayout } from '../api/payments.js';

function fmt(n) {
  return (Number(n) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

const METHODS = [
  { value: 'bank',          label: 'Bank transfer',  hint: 'IBAN required',  icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 21h18M5 21V10M19 21V10M3 10h18L12 3 3 10z"/><path d="M9 21v-6M15 21v-6"/></svg>' },
  { value: 'instapay',      label: 'InstaPay',       hint: 'Phone or handle', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2.5"/><path d="M11 18h2"/></svg>' },
  { value: 'vodafone_cash', label: 'Vodafone Cash',  hint: 'Wallet number',   icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/></svg>' },
  { value: 'orange_cash',   label: 'Orange Cash',    hint: 'Wallet number',   icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>' },
];

export function openPayoutRequestModal({ availableBalance, onSuccess, onError } = {}) {
  const balance = Number(availableBalance ?? 0);
  const minAmount = 50;
  const w = document.createElement('div');
  w.className = 'payout-modal';
  w.innerHTML = `
    <div class="payout-modal__panel" role="dialog" aria-labelledby="payoutModalTitle" aria-modal="true">
      <header class="payout-modal__header">
        <div>
          <h2 class="payout-modal__title" id="payoutModalTitle">Request payout</h2>
          <p class="payout-modal__subtitle">Withdraw your available wallet balance.</p>
        </div>
        <button class="payout-modal__close" type="button" aria-label="Close">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6 6 18M6 6l12 12"/></svg>
        </button>
      </header>

      <section class="payout-modal__balance">
        <span class="payout-modal__balance-label">Available to withdraw</span>
        <span class="payout-modal__balance-value">${fmt(balance)} <em>EGP</em></span>
      </section>

      <div class="payout-modal__body">
        <label class="payout-modal__field">
          <span class="payout-modal__label">Amount</span>
          <div class="payout-modal__amount-row">
            <div class="payout-modal__amount-input">
              <input id="poAmt" type="number" min="${minAmount}" max="${balance || 9999999}" step="0.01" placeholder="0.00" inputmode="decimal" />
              <span class="payout-modal__amount-suffix">EGP</span>
            </div>
            <button type="button" class="payout-modal__chip" data-quick>Max</button>
          </div>
          <span class="payout-modal__hint" id="poAmtHint">Minimum ${minAmount} EGP.</span>
        </label>

        <fieldset class="payout-modal__field payout-modal__field--methods">
          <legend class="payout-modal__label">Payout method</legend>
          <div class="payout-modal__methods">
            ${METHODS.map((m, i) => `
              <label class="payout-method" data-method="${m.value}">
                <input type="radio" name="poMethod" value="${m.value}" ${i === 0 ? 'checked' : ''} />
                <span class="payout-method__icon">${m.icon}</span>
                <span class="payout-method__body">
                  <span class="payout-method__label">${m.label}</span>
                  <span class="payout-method__hint">${m.hint}</span>
                </span>
                <span class="payout-method__check">
                  <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6 9 17l-5-5"/></svg>
                </span>
              </label>`).join('')}
          </div>
        </fieldset>

        <label class="payout-modal__field">
          <span class="payout-modal__label">Account details <em>required</em></span>
          <textarea id="poDetails" rows="2" placeholder="e.g. EG12 3456 7890 1234 5678 9012 34"></textarea>
        </label>

        <label class="payout-modal__field">
          <span class="payout-modal__label">Note <em>optional</em></span>
          <input id="poNote" type="text" maxlength="200" placeholder="Anything we should know?" />
        </label>
      </div>

      <footer class="payout-modal__footer">
        <span class="payout-modal__footnote">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/></svg>
          Processed within 3 business days.
        </span>
        <div class="payout-modal__actions">
          <button class="payout-modal__btn payout-modal__btn--ghost" type="button" data-cancel>Cancel</button>
          <button class="payout-modal__btn payout-modal__btn--primary" type="button" data-submit>Submit request</button>
        </div>
      </footer>
    </div>`;

  document.body.appendChild(w);
  document.body.style.overflow = 'hidden';
  const close = () => { w.remove(); document.body.style.overflow = ''; };
  w.querySelector('.payout-modal__close').onclick = close;
  w.querySelector('[data-cancel]').onclick = close;
  w.addEventListener('click', (e) => { if (e.target === w) close(); });
  document.addEventListener('keydown', function esc(ev) {
    if (ev.key === 'Escape') { close(); document.removeEventListener('keydown', esc); }
  });

  const amtEl = w.querySelector('#poAmt');
  const hintEl = w.querySelector('#poAmtHint');
  w.querySelector('[data-quick]').onclick = () => {
    amtEl.value = balance.toFixed(2);
    amtEl.dispatchEvent(new Event('input'));
  };
  amtEl.addEventListener('input', () => {
    const v = parseFloat(amtEl.value);
    if (Number.isFinite(v) && balance > 0 && v > balance) {
      hintEl.textContent = `Cannot exceed ${fmt(balance)} EGP available.`;
      hintEl.dataset.tone = 'bad';
    } else if (Number.isFinite(v) && v > 0 && v < minAmount) {
      hintEl.textContent = `Minimum ${minAmount} EGP.`;
      hintEl.dataset.tone = 'bad';
    } else {
      hintEl.textContent = `Minimum ${minAmount} EGP.`;
      hintEl.dataset.tone = '';
    }
  });

  w.querySelectorAll('.payout-method').forEach(card => {
    card.addEventListener('click', () => {
      w.querySelector(`input[value="${card.dataset.method}"]`).checked = true;
      w.querySelectorAll('.payout-method').forEach(c => c.classList.toggle('is-active', c === card));
    });
  });
  w.querySelector('.payout-method').classList.add('is-active');

  w.querySelector('[data-submit]').onclick = async () => {
    const amount = parseFloat(amtEl.value);
    const method = w.querySelector('input[name=poMethod]:checked').value;
    const details = w.querySelector('#poDetails').value.trim();
    const note = w.querySelector('#poNote').value.trim();
    if (!(amount >= minAmount)) { hintEl.textContent = `Minimum ${minAmount} EGP.`; hintEl.dataset.tone = 'bad'; amtEl.focus(); return; }
    if (balance > 0 && amount > balance) { hintEl.textContent = `Cannot exceed ${fmt(balance)} EGP available.`; hintEl.dataset.tone = 'bad'; amtEl.focus(); return; }
    if (!details) { w.querySelector('#poDetails').focus(); return; }
    const btn = w.querySelector('[data-submit]');
    btn.disabled = true; btn.textContent = 'Submitting…';
    try {
      await requestPayout({ amount, method, details: { raw: details, note } });
      close();
      onSuccess?.();
    } catch (e) {
      btn.disabled = false; btn.textContent = 'Submit request';
      (onError || alert)(e.message || e);
    }
  };
}
