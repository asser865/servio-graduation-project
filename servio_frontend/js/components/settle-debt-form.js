/* ═══════════════════════════════════════════════════════════════════════
   settle-debt-form.js — Premium settle-debt modal
   Theme-aware (light/dark), keyboard-navigable, polished UX.
   ═══════════════════════════════════════════════════════════════════════ */
import { getMyDebtsV2, settleMyDebt } from '../api/payments.js';
import { uploadImage } from '../utils/upload-image.js';

const STYLE_ID = 'settle-debt-modal-styles';

function fmt(n) {
  const v = Number(n) || 0;
  return v.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

const METHODS = [
  {
    id: 'wallet_balance',
    label: 'Wallet balance',
    desc: 'Instant — settles immediately from your wallet.',
    instant: true,
    icon: '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="6" width="20" height="14" rx="2.5"/><path d="M2 10h20M18 15h.01"/></svg>',
  },
  {
    id: 'instapay',
    label: 'InstaPay',
    desc: 'Send to: servio@instapay',
    instant: false,
    icon: '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2.5"/><path d="M11 18h2"/></svg>',
  },
  {
    id: 'vodafone_cash',
    label: 'Vodafone Cash',
    desc: 'Send to: 01000000000',
    instant: false,
    icon: '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/></svg>',
  },
  {
    id: 'bank_transfer',
    label: 'Bank transfer',
    desc: 'NBE — IBAN EG000000000000000000000',
    instant: false,
    icon: '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 21h18M5 21V10M19 21V10M3 10h18L12 3 3 10z"/></svg>',
  },
  {
    id: 'cash_to_office',
    label: 'Cash at office',
    desc: 'Servio HQ, 12 St., Cairo — Sun–Thu 10:00–17:00',
    instant: false,
    icon: '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 22h18M5 22V10l7-5 7 5v12M9 14h6M9 18h6"/></svg>',
  },
];

function injectStyles() {
  if (document.getElementById(STYLE_ID)) return;
  const css = `
.settle-modal { position: fixed; inset: 0; z-index: 10000; display: flex; align-items: center; justify-content: center;
  background: rgba(7, 10, 18, .62); backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px);
  animation: settleFade .18s ease-out; padding: 16px; }
@keyframes settleFade { from { opacity: 0; } to { opacity: 1; } }
@keyframes settleRise { from { opacity: 0; transform: translateY(14px) scale(.985); } to { opacity: 1; transform: none; } }
.settle-modal__panel { position: relative; width: 100%; max-width: 540px; max-height: 92vh; overflow: hidden;
  background: #fff; color: #15212e;
  border: 1px solid rgba(15,23,42,.08); border-radius: 22px;
  box-shadow: 0 28px 80px -20px rgba(0,0,0,.45), 0 8px 24px -8px rgba(0,0,0,.25);
  display: flex; flex-direction: column; animation: settleRise .26s cubic-bezier(.2,.7,.25,1); }
[data-theme="dark"] .settle-modal__panel { background: #161b27; color: #f1ecdf;
  border-color: rgba(255,255,255,.06); box-shadow: 0 28px 90px -10px rgba(0,0,0,.7); }
.settle-modal__head { display: flex; align-items: flex-start; gap: 14px; padding: 22px 24px 18px;
  border-bottom: 1px solid rgba(15,23,42,.07);
  background: linear-gradient(180deg, rgba(217,119,6,.06), transparent 70%); }
[data-theme="dark"] .settle-modal__head { border-bottom-color: rgba(255,255,255,.05);
  background: linear-gradient(180deg, rgba(253,230,138,.05), transparent 70%); }
.settle-modal__icon { width: 42px; height: 42px; border-radius: 12px; flex: 0 0 auto; display: grid; place-items: center;
  background: linear-gradient(135deg, #f59e0b, #d97706); color: #fff;
  box-shadow: 0 8px 20px -8px rgba(217,119,6,.55); }
.settle-modal__title-block { flex: 1; min-width: 0; }
.settle-modal__title { margin: 0 0 4px; font-family: var(--font-heading, Poppins, sans-serif);
  font-size: 1.15rem; font-weight: 700; letter-spacing: -.01em; line-height: 1.2; }
.settle-modal__sub { margin: 0; font-size: .82rem; color: #64748b; line-height: 1.45; }
[data-theme="dark"] .settle-modal__sub { color: rgba(241,236,223,.62); }
.settle-modal__close { position: absolute; top: 14px; right: 14px; width: 32px; height: 32px; border-radius: 10px;
  display: grid; place-items: center; background: transparent; border: 1px solid transparent; cursor: pointer;
  color: #64748b; font-size: 18px; line-height: 1; transition: background .15s, border-color .15s; z-index: 2; }
.settle-modal__close:hover { background: rgba(0,0,0,.05); border-color: rgba(0,0,0,.06); }
[data-theme="dark"] .settle-modal__close { color: rgba(241,236,223,.7); }
[data-theme="dark"] .settle-modal__close:hover { background: rgba(255,255,255,.06); border-color: rgba(255,255,255,.08); }
.settle-modal__body { padding: 20px 24px 8px; overflow-y: auto; }
.settle-modal__owed { display: flex; align-items: baseline; justify-content: space-between; gap: 12px;
  padding: 14px 16px; margin-bottom: 16px; border-radius: 14px;
  background: linear-gradient(135deg, rgba(217,119,6,.08), rgba(245,158,11,.04));
  border: 1px solid rgba(217,119,6,.18); }
[data-theme="dark"] .settle-modal__owed { background: linear-gradient(135deg, rgba(253,230,138,.07), rgba(217,119,6,.03));
  border-color: rgba(253,230,138,.16); }
.settle-modal__owed-label { font-size: .68rem; font-weight: 700; letter-spacing: .14em; text-transform: uppercase;
  color: #b45309; }
[data-theme="dark"] .settle-modal__owed-label { color: #fde68a; }
.settle-modal__owed-amt { font-family: var(--font-heading, Poppins, sans-serif); font-size: 1.5rem; font-weight: 800;
  letter-spacing: -.02em; color: #b45309; font-variant-numeric: tabular-nums; }
[data-theme="dark"] .settle-modal__owed-amt { color: #fde68a; }
.settle-modal__owed-amt em { font-size: .56em; font-style: normal; font-weight: 700; opacity: .7; margin-left: 5px; letter-spacing: .14em; }
.settle-modal__field { margin: 0 0 14px; }
.settle-modal__field-label { display: block; font-size: .72rem; font-weight: 700; letter-spacing: .1em;
  text-transform: uppercase; color: #64748b; margin-bottom: 6px; }
[data-theme="dark"] .settle-modal__field-label { color: rgba(241,236,223,.62); }
.settle-modal__amount-row { display: flex; gap: 8px; }
.settle-modal__amount-input { flex: 1; min-width: 0; padding: 11px 14px; font-size: 1rem; font-weight: 700;
  border-radius: 10px; border: 1px solid rgba(15,23,42,.12);
  background: #fafbfc; color: inherit; font-variant-numeric: tabular-nums; transition: border-color .15s, box-shadow .15s; }
.settle-modal__amount-input:focus { outline: none; border-color: #d97706; box-shadow: 0 0 0 3px rgba(217,119,6,.18); }
[data-theme="dark"] .settle-modal__amount-input { background: #0f1420; border-color: rgba(255,255,255,.08); }
[data-theme="dark"] .settle-modal__amount-input:focus { border-color: #fbbf24; box-shadow: 0 0 0 3px rgba(251,191,36,.2); }
.settle-modal__quick { padding: 0 12px; font-size: .78rem; font-weight: 700; border-radius: 10px;
  border: 1px solid rgba(15,23,42,.12); background: #fafbfc;
  color: #15212e; cursor: pointer; transition: background .15s, border-color .15s; }
.settle-modal__quick:hover { background: rgba(217,119,6,.08); border-color: rgba(217,119,6,.3); color: #b45309; }
[data-theme="dark"] .settle-modal__quick { background: #0f1420; border-color: rgba(255,255,255,.08); color: #f1ecdf; }
[data-theme="dark"] .settle-modal__quick:hover { background: rgba(253,230,138,.08); border-color: rgba(253,230,138,.25); color: #fde68a; }
.settle-modal__methods { display: grid; gap: 8px; }
.settle-modal__method { position: relative; display: flex; align-items: center; gap: 12px;
  padding: 12px 14px; border-radius: 12px; cursor: pointer;
  border: 1.5px solid rgba(15,23,42,.1);
  background: #fafbfc; transition: border-color .15s, background .15s, transform .1s; }
.settle-modal__method:hover { border-color: rgba(217,119,6,.4); background: rgba(217,119,6,.04); }
.settle-modal__method input { position: absolute; opacity: 0; pointer-events: none; }
.settle-modal__method.is-active { border-color: #d97706; background: rgba(217,119,6,.07);
  box-shadow: 0 0 0 3px rgba(217,119,6,.1); }
[data-theme="dark"] .settle-modal__method { background: #0f1420; border-color: rgba(255,255,255,.07); }
[data-theme="dark"] .settle-modal__method:hover { background: rgba(253,230,138,.04); border-color: rgba(253,230,138,.3); }
[data-theme="dark"] .settle-modal__method.is-active { background: rgba(253,230,138,.06); border-color: #fbbf24;
  box-shadow: 0 0 0 3px rgba(251,191,36,.1); }
.settle-modal__method-icon { width: 36px; height: 36px; border-radius: 10px; display: grid; place-items: center;
  background: rgba(217,119,6,.1); color: #b45309; flex: 0 0 auto; }
[data-theme="dark"] .settle-modal__method-icon { background: rgba(253,230,138,.1); color: #fde68a; }
.settle-modal__method-text { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.settle-modal__method-name { font-size: .92rem; font-weight: 700; line-height: 1.2; }
.settle-modal__method-desc { font-size: .73rem; color: #64748b; line-height: 1.35; }
[data-theme="dark"] .settle-modal__method-desc { color: rgba(241,236,223,.55); }
.settle-modal__method-badge { font-size: .62rem; font-weight: 800; letter-spacing: .08em; text-transform: uppercase;
  padding: 3px 8px; border-radius: 999px; flex: 0 0 auto; }
.settle-modal__method-badge--instant { background: #16a34a; color: #fff; }
.settle-modal__method-badge--manual { background: rgba(0,0,0,.05); color: #64748b; }
[data-theme="dark"] .settle-modal__method-badge--manual { background: rgba(255,255,255,.06); color: rgba(241,236,223,.6); }
.settle-modal__manual { margin-top: 14px; padding: 14px; border-radius: 12px;
  background: rgba(0,0,0,.025); border: 1px dashed rgba(15,23,42,.12); }
[data-theme="dark"] .settle-modal__manual { background: rgba(255,255,255,.025); border-color: rgba(255,255,255,.08); }
.settle-modal__manual-note { margin: 0 0 12px; padding: 10px 12px; border-radius: 9px;
  background: rgba(217,119,6,.1); color: #92400e; font-size: .78rem; line-height: 1.4; font-weight: 600; }
[data-theme="dark"] .settle-modal__manual-note { background: rgba(253,230,138,.08); color: #fde68a; }
.settle-modal__input, .settle-modal__file { width: 100%; padding: 10px 12px; font-size: .9rem;
  border-radius: 9px; border: 1px solid rgba(15,23,42,.12);
  background: #fff; color: inherit; transition: border-color .15s, box-shadow .15s; }
.settle-modal__input:focus, .settle-modal__file:focus { outline: none; border-color: #d97706;
  box-shadow: 0 0 0 3px rgba(217,119,6,.15); }
[data-theme="dark"] .settle-modal__input, [data-theme="dark"] .settle-modal__file { background: #0a0f1a; border-color: rgba(255,255,255,.08); }
.settle-modal__error { margin: 8px 0 0; padding: 10px 12px; border-radius: 9px; font-size: .82rem; font-weight: 600;
  background: rgba(220,38,38,.1); color: #b91c1c; border: 1px solid rgba(220,38,38,.2); display: none; }
.settle-modal__error.is-visible { display: block; }
[data-theme="dark"] .settle-modal__error { background: rgba(248,113,113,.1); color: #fca5a5; border-color: rgba(248,113,113,.2); }
.settle-modal__foot { display: flex; gap: 10px; padding: 16px 24px 22px;
  border-top: 1px solid rgba(15,23,42,.07); }
[data-theme="dark"] .settle-modal__foot { border-top-color: rgba(255,255,255,.05); }
.settle-modal__btn { flex: 1; padding: 12px 20px; font-size: .95rem; font-weight: 700; border-radius: 11px;
  cursor: pointer; border: 1px solid transparent; transition: background .15s, transform .08s, box-shadow .15s;
  font-family: inherit; display: inline-flex; align-items: center; justify-content: center; gap: 8px; }
.settle-modal__btn:active { transform: translateY(1px); }
.settle-modal__btn--ghost { background: transparent; border-color: rgba(15,23,42,.14); color: inherit; }
.settle-modal__btn--ghost:hover { background: rgba(0,0,0,.04); }
[data-theme="dark"] .settle-modal__btn--ghost { border-color: rgba(255,255,255,.1); }
[data-theme="dark"] .settle-modal__btn--ghost:hover { background: rgba(255,255,255,.05); }
.settle-modal__btn--primary { background: linear-gradient(135deg, #f59e0b, #d97706); color: #fff;
  box-shadow: 0 6px 20px -6px rgba(217,119,6,.6); }
.settle-modal__btn--primary:hover { box-shadow: 0 10px 28px -8px rgba(217,119,6,.7); }
.settle-modal__btn--primary[disabled] { opacity: .6; cursor: not-allowed; box-shadow: none; }
.settle-modal__hint { padding: 0 24px 16px; margin: 0; font-size: .72rem; color: #64748b; text-align: center; line-height: 1.45; }
[data-theme="dark"] .settle-modal__hint { color: rgba(241,236,223,.5); }
.settle-modal__spinner { display: inline-block; width: 14px; height: 14px; border: 2px solid currentColor; border-right-color: transparent;
  border-radius: 50%; animation: settleSpin .7s linear infinite; vertical-align: middle; }
@keyframes settleSpin { to { transform: rotate(360deg); } }
@media (max-width: 540px) {
  .settle-modal__head { padding: 18px 18px 14px; }
  .settle-modal__body { padding: 16px 18px 6px; }
  .settle-modal__foot { padding: 14px 18px 18px; flex-direction: column-reverse; }
  .settle-modal__hint { padding: 0 18px 14px; }
}
`;
  const s = document.createElement('style');
  s.id = STYLE_ID;
  s.textContent = css;
  document.head.appendChild(s);
}

function showLoadingModal() {
  const w = document.createElement('div');
  w.className = 'settle-modal';
  w.innerHTML = `<div class="settle-modal__panel" style="max-width:380px;padding:32px;text-align:center;">
    <div class="settle-modal__spinner" style="margin:0 auto 14px;width:28px;height:28px;border-width:3px;color:#d97706;"></div>
    <p style="margin:0;font-size:.9rem;color:#64748b;">Loading your debt details…</p>
  </div>`;
  document.body.appendChild(w);
  return w;
}

export async function openSettleDebtModal({ onSuccess, onError } = {}) {
  injectStyles();

  if (document.querySelector('.settle-modal[data-settle-active]')) return;

  const loading = showLoadingModal();

  let summary = {};
  let walletBalance = 0;
  try {
    const my = await getMyDebtsV2();
    summary = my?.data?.summary || my?.summary || {};
    walletBalance = Number(summary.walletBalance) || 0;
  } catch (e) {
    loading.remove();
    const msg = "Couldn't load your debt details: " + (e?.message || e);
    if (onError) onError(msg); else alert(msg);
    return;
  }
  loading.remove();

  const totalOwed = Number(summary.totalOutstanding) || 0;
  if (totalOwed <= 0) {
    const msg = "No outstanding platform fees to settle. You're all clear.";
    if (onError) onError(msg); else alert(msg);
    return;
  }

  const w = document.createElement('div');
  w.className = 'settle-modal';
  w.setAttribute('data-settle-active', 'true');
  w.setAttribute('role', 'dialog');
  w.setAttribute('aria-modal', 'true');
  w.setAttribute('aria-labelledby', 'settleModalTitle');
  w.innerHTML = `
    <div class="settle-modal__panel">
      <button class="settle-modal__close" type="button" aria-label="Close">
        <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M18 6 6 18M6 6l12 12"/></svg>
      </button>
      <header class="settle-modal__head">
        <div class="settle-modal__icon" aria-hidden="true">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
        </div>
        <div class="settle-modal__title-block">
          <h2 class="settle-modal__title" id="settleModalTitle">Settle platform fees</h2>
          <p class="settle-modal__sub">Pay your outstanding cash-job commission so you can keep accepting big jobs.</p>
        </div>
      </header>
      <div class="settle-modal__body">
        <div class="settle-modal__owed">
          <span class="settle-modal__owed-label">Amount owed</span>
          <span class="settle-modal__owed-amt">${fmt(totalOwed)}<em>EGP</em></span>
        </div>

        <div class="settle-modal__field">
          <label for="settlePayAmt" class="settle-modal__field-label">How much to pay</label>
          <div class="settle-modal__amount-row">
            <input id="settlePayAmt" class="settle-modal__amount-input" type="number" min="0.01" max="${totalOwed}" step="0.01" value="${totalOwed.toFixed(2)}" inputmode="decimal" required>
            <button type="button" class="settle-modal__quick" data-quick="${totalOwed.toFixed(2)}">Full</button>
            <button type="button" class="settle-modal__quick" data-quick="${(totalOwed/2).toFixed(2)}">Half</button>
          </div>
        </div>

        <div class="settle-modal__field">
          <span class="settle-modal__field-label">Payment method</span>
          <div class="settle-modal__methods" role="radiogroup" aria-label="Payment method">
            ${METHODS.map(m => `
              <label class="settle-modal__method" data-method="${m.id}">
                <input type="radio" name="settleMethod" value="${m.id}">
                <span class="settle-modal__method-icon" aria-hidden="true">${m.icon}</span>
                <span class="settle-modal__method-text">
                  <span class="settle-modal__method-name">${m.label}${m.id === 'wallet_balance' ? ` <span style="font-weight:600;opacity:.65;font-size:.82em;">(${fmt(walletBalance)} EGP available)</span>` : ''}</span>
                  <span class="settle-modal__method-desc">${m.desc}</span>
                </span>
                <span class="settle-modal__method-badge ${m.instant ? 'settle-modal__method-badge--instant' : 'settle-modal__method-badge--manual'}">${m.instant ? 'Instant' : 'Manual'}</span>
              </label>
            `).join('')}
          </div>
        </div>

        <div class="settle-modal__manual" id="settleManualFields" hidden>
          <p class="settle-modal__manual-note" id="settleSendToNote"></p>
          <div class="settle-modal__field">
            <label for="settleRef" class="settle-modal__field-label">Transaction reference</label>
            <input id="settleRef" class="settle-modal__input" type="text" minlength="3" placeholder="Reference / receipt number">
          </div>
          <div class="settle-modal__field" style="margin-bottom:0;">
            <label for="settleProof" class="settle-modal__field-label">Receipt photo (optional)</label>
            <input id="settleProof" class="settle-modal__file" type="file" accept="image/jpeg,image/png,image/webp">
          </div>
        </div>

        <div class="settle-modal__error" id="settleErr"></div>
      </div>
      <footer class="settle-modal__foot">
        <button type="button" class="settle-modal__btn settle-modal__btn--ghost" data-cancel>Cancel</button>
        <button type="button" class="settle-modal__btn settle-modal__btn--primary" data-submit>
          <span data-submit-label>Submit settlement</span>
        </button>
      </footer>
      <p class="settle-modal__hint">Manual methods are verified by admin (usually under 24 hours).</p>
    </div>`;
  document.body.appendChild(w);

  const $ = sel => w.querySelector(sel);
  const close = () => { w.remove(); document.removeEventListener('keydown', onKey); };
  const onKey = (e) => { if (e.key === 'Escape') close(); };
  document.addEventListener('keydown', onKey);

  $('.settle-modal__close').onclick = close;
  $('[data-cancel]').onclick = close;
  w.addEventListener('click', (e) => { if (e.target === w) close(); });

  setTimeout(() => $('#settlePayAmt')?.focus(), 50);

  w.querySelectorAll('[data-quick]').forEach(b => {
    b.onclick = () => { $('#settlePayAmt').value = b.dataset.quick; };
  });

  const errEl = $('#settleErr');
  const showErr = (msg) => { errEl.textContent = msg; errEl.classList.add('is-visible'); };
  const clearErr = () => { errEl.textContent = ''; errEl.classList.remove('is-visible'); };

  w.querySelectorAll('.settle-modal__method').forEach(card => {
    card.onclick = (e) => {
      if (e.target.tagName === 'INPUT') return;
      w.querySelectorAll('.settle-modal__method').forEach(c => c.classList.remove('is-active'));
      card.classList.add('is-active');
      const radio = card.querySelector('input');
      radio.checked = true;
      const m = METHODS.find(x => x.id === card.dataset.method);
      const isWallet = m.id === 'wallet_balance';
      $('#settleManualFields').hidden = isWallet;
      if (!isWallet) $('#settleSendToNote').textContent = m.desc;
      clearErr();
    };
  });

  $('[data-submit]').onclick = async () => {
    clearErr();
    const amount = parseFloat($('#settlePayAmt').value);
    const method = w.querySelector('input[name=settleMethod]:checked')?.value;
    if (!method) return showErr('Please pick a payment method.');
    if (!(amount > 0)) return showErr('Enter a valid amount.');
    if (amount > totalOwed + 0.001) return showErr(`Amount cannot exceed ${fmt(totalOwed)} EGP.`);

    if (method === 'wallet_balance' && amount > walletBalance + 0.001) {
      return showErr(`Wallet balance (${fmt(walletBalance)} EGP) is too low for this amount.`);
    }

    const payload = { amount, method };
    if (method !== 'wallet_balance') {
      const ref = $('#settleRef').value.trim();
      if (ref.length < 3) return showErr('Reference is required (3 characters minimum).');
      payload.reference = ref;
      const proofFile = $('#settleProof').files[0];
      if (proofFile) {
        try {
          const u = await uploadImage(proofFile, 'settlement-proofs');
          payload.proofUrl = u.url || u;
        } catch (e) {
          return showErr('Receipt upload failed: ' + (e?.message || e));
        }
      }
    }

    const btn = $('[data-submit]');
    const label = $('[data-submit-label]');
    btn.disabled = true;
    label.innerHTML = '<span class="settle-modal__spinner"></span> Submitting…';
    try {
      await settleMyDebt(payload);
      close();
      onSuccess?.();
    } catch (e) {
      btn.disabled = false;
      label.textContent = 'Submit settlement';
      showErr(e?.message || String(e) || 'Submission failed.');
    }
  };
}
