// servio_frontend/js/components/card-picker-modal.js
import { animate } from 'https://cdn.jsdelivr.net/npm/motion@12.38.0/+esm';
import { getSavedCards, addSavedCard } from '../api/savedCards.js';

const CARD_ICONS = {
  visa:       '<svg viewBox="0 0 48 16" width="38" height="13" fill="none" aria-hidden="true"><text x="0" y="13" font-size="13" font-weight="800" fill="#1a1f71" font-family="Arial">VISA</text></svg>',
  mastercard: '<svg viewBox="0 0 32 20" width="32" height="20" aria-hidden="true"><circle cx="12" cy="10" r="10" fill="#eb001b"/><circle cx="20" cy="10" r="10" fill="#f79e1b" fill-opacity="0.85"/></svg>',
  amex:       '<svg viewBox="0 0 48 16" width="38" height="13" fill="none" aria-hidden="true"><text x="0" y="13" font-size="11" font-weight="700" fill="#2e77bc" font-family="Arial">AMEX</text></svg>',
  other:      '<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>',
};

let _selectedCardId = null;
let _onConfirm = null;
let _returnFocusEl = null;

function detectCardType(num) {
  const first = num.replace(/\D/g, '')[0];
  if (first === '4') return 'visa';
  if (first === '5') return 'mastercard';
  if (first === '3') return 'amex';
  return 'other';
}

function buildCardItem(card) {
  const icon = CARD_ICONS[card.cardType] || CARD_ICONS.other;
  const isSelected = card._id === _selectedCardId;
  const item = document.createElement('div');
  item.dataset.cardId = card._id;
  item.style.cssText = `
    display:flex;align-items:center;gap:12px;padding:12px 14px;
    border-radius:10px;cursor:pointer;transition:border-color .2s,background .2s,box-shadow .2s;
    border:2px solid ${isSelected ? '#f5a623' : 'var(--color-border)'};
    background:${isSelected ? 'rgba(245,166,35,.10)' : 'var(--color-surface-alt)'};
    box-shadow:${isSelected ? '0 4px 14px rgba(245,166,35,.18)' : 'var(--shadow-sm)'};
  `;
  item.innerHTML = `
    <span style="flex-shrink:0">${icon}</span>
    <div style="flex:1;min-width:0">
      <div style="font-weight:600;font-size:14px;color:var(--color-text)">•••• •••• •••• ${card.last4}</div>
      <div style="font-size:12px;color:var(--color-text-light);margin-top:2px">
        ${card.label ? card.label + ' · ' : ''}Exp ${card.expiry}
      </div>
    </div>
    ${card.isDefault ? '<span style="font-size:11px;background:rgba(245,166,35,.15);color:#b8791a;border:1px solid rgba(245,166,35,.4);border-radius:4px;padding:2px 7px;flex-shrink:0;font-weight:600">Default</span>' : ''}
    <div style="width:18px;height:18px;border-radius:50%;border:2px solid ${isSelected ? '#f5a623' : 'var(--color-text-light)'};background:${isSelected ? '#f5a623' : 'transparent'};flex-shrink:0;display:flex;align-items:center;justify-content:center;">
      ${isSelected ? '<svg viewBox="0 0 10 8" width="10" height="8" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="1,4 4,7 9,1"/></svg>' : ''}
    </div>
  `;
  item.addEventListener('click', () => selectCard(card._id));
  return item;
}

function selectCard(id) {
  _selectedCardId = id;
  renderCardList(_lastCards);
  const confirmBtn = document.getElementById('cpConfirmBtn');
  if (confirmBtn) confirmBtn.disabled = false;
}

let _lastCards = [];

function renderCardList(cards) {
  _lastCards = cards;
  const list = document.getElementById('cpCardList');
  const addNewBtn = document.getElementById('cpAddNewBtn');
  const limitMsg = document.getElementById('cpLimitMsg');
  const confirmBtn = document.getElementById('cpConfirmBtn');
  if (!list) return;

  list.innerHTML = '';
  if (!cards.length) {
    list.innerHTML = '<div class="pay-modal__empty">No saved cards yet. Add one to continue with card payment.</div>';
  } else {
    cards.forEach(card => list.appendChild(buildCardItem(card)));
  }

  const atLimit = cards.length >= 3;
  if (addNewBtn) addNewBtn.style.display = atLimit ? 'none' : '';
  if (limitMsg)  limitMsg.style.display  = atLimit ? 'block' : 'none';
  if (confirmBtn) confirmBtn.disabled = !_selectedCardId;
}

function showView(viewId) {
  ['cpListView', 'cpAddView', 'cpProcessing', 'cpSuccess'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.hidden = id !== viewId;
  });
}

function resetAddForm() {
  ['cpCardHolder', 'cpCardNumber', 'cpExpiry', 'cpCVV', 'cpLabel'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.value = '';
  });
  const err = document.getElementById('cpAddErrorMsg');
  if (err) { err.style.display = 'none'; err.textContent = ''; }
}

function validateAddForm() {
  const name = document.getElementById('cpCardHolder')?.value.trim() || '';
  const num  = (document.getElementById('cpCardNumber')?.value || '').replace(/\s/g, '');
  const exp  = document.getElementById('cpExpiry')?.value.trim() || '';
  const cvv  = document.getElementById('cpCVV')?.value.trim() || '';
  if (!name)                                     return 'Cardholder name is required.';
  if (num.length !== 16 || !/^\d+$/.test(num))  return 'Please enter a valid 16-digit card number.';
  if (!/^\d{2}\s*\/\s*\d{2}$/.test(exp))        return 'Please enter a valid expiry (MM / YY).';
  if (cvv.length < 3 || !/^\d+$/.test(cvv))     return 'Please enter a valid CVV.';
  return null;
}

export function openCardPickerModal(totalAmount, onConfirmCallback) {
  _onConfirm = onConfirmCallback;
  _selectedCardId = null;
  _returnFocusEl = document.activeElement instanceof HTMLElement ? document.activeElement : null;

  const overlay = document.getElementById('cardPickerOverlay');
  const modal   = document.getElementById('cardPickerModal');
  const amount  = document.getElementById('cpAmount');
  if (!overlay || !modal) return;

  if (amount) amount.textContent = `Total: ${totalAmount} EGP`;

  overlay.hidden = false;
  modal.setAttribute('tabindex', '-1');
  document.body.style.overflow = 'hidden';

  if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    animate(overlay, { opacity: [0, 1] }, { duration: 0.25 });
    animate(modal, { opacity: [0, 1], y: [30, 0], scale: [0.95, 1] }, { duration: 0.35, easing: [0.22, 1, 0.36, 1] });
  }

  showView('cpListView');
  resetAddForm();
  setTimeout(() => modal.focus(), 0);

  getSavedCards()
    .then(res => {
      const cards = res.data || res || [];
      if (cards.length === 0) {
        showView('cpAddView');
        document.getElementById('cpCardHolder')?.focus();
      } else {
        const def = cards.find(c => c.isDefault) || cards[0];
        _selectedCardId = def._id;
        renderCardList(cards);
        showView('cpListView');
      }
    })
    .catch(() => {
      showView('cpAddView');
      document.getElementById('cpCardHolder')?.focus();
    });
}

export function closeCardPickerModal() {
  const overlay = document.getElementById('cardPickerOverlay');
  if (!overlay) return;
  if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    animate(overlay, { opacity: [1, 0] }, { duration: 0.2 }).then(() => {
      overlay.hidden = true;
      document.body.style.overflow = '';
      _returnFocusEl?.focus?.();
    });
  } else {
    overlay.hidden = true;
    document.body.style.overflow = '';
    _returnFocusEl?.focus?.();
  }
}

// ── Event wiring (runs once on module load) ─────────────────────────────────

document.getElementById('cpClose')?.addEventListener('click', closeCardPickerModal);

document.getElementById('cardPickerOverlay')?.addEventListener('click', (e) => {
  if (e.target === e.currentTarget) closeCardPickerModal();
});

document.addEventListener('keydown', (e) => {
  const overlay = document.getElementById('cardPickerOverlay');
  if (e.key === 'Escape' && overlay && !overlay.hidden) closeCardPickerModal();
});

document.getElementById('cpAddNewBtn')?.addEventListener('click', () => {
  showView('cpAddView');
  resetAddForm();
  document.getElementById('cpCardHolder')?.focus();
});

document.getElementById('cpBackBtn')?.addEventListener('click', () => {
  showView('cpListView');
});

// Card number formatting
document.getElementById('cpCardNumber')?.addEventListener('input', (e) => {
  const raw = e.target.value.replace(/\D/g, '').slice(0, 16);
  e.target.value = raw.replace(/(.{4})/g, '$1 ').trim();
});

document.getElementById('cpExpiry')?.addEventListener('input', (e) => {
  const raw = e.target.value.replace(/\D/g, '').slice(0, 4);
  e.target.value = raw.length > 2 ? raw.slice(0, 2) + ' / ' + raw.slice(2) : raw;
});

document.getElementById('cpSaveNewBtn')?.addEventListener('click', async () => {
  const error = validateAddForm();
  const errEl = document.getElementById('cpAddErrorMsg');
  if (error) {
    if (errEl) { errEl.textContent = error; errEl.style.display = 'block'; }
    return;
  }
  if (errEl) errEl.style.display = 'none';

  const rawNum   = (document.getElementById('cpCardNumber')?.value || '').replace(/\s/g, '');
  const last4    = rawNum.slice(-4);
  const cardType = detectCardType(rawNum);
  const expiry   = (document.getElementById('cpExpiry')?.value || '').replace(/\s/g, '');
  const label    = document.getElementById('cpLabel')?.value.trim() || '';

  const btn = document.getElementById('cpSaveNewBtn');
  if (btn) { btn.disabled = true; btn.textContent = 'Saving...'; }

  try {
    const res  = await addSavedCard({ last4, cardType, expiry, label });
    const card = res.data || res;
    _selectedCardId = card._id;

    // Refresh list then show it
    const listRes = await getSavedCards();
    const cards   = listRes.data || listRes || [];
    renderCardList(cards);
    showView('cpListView');
  } catch (err) {
    const msg = err?.data?.message || err?.message || 'Failed to save card.';
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = 'Save & Use This Card'; }
  }
});

document.getElementById('cpConfirmBtn')?.addEventListener('click', () => {
  if (!_selectedCardId) return;
  const card = _lastCards.find(c => c._id === _selectedCardId);
  if (!card) return;
  showView('cpProcessing');
  setTimeout(async () => {
    try {
      if (typeof _onConfirm === 'function') {
        await _onConfirm({
          savedCardId: card._id,
          last4: card.last4,
          cardType: card.cardType,
          expiry: card.expiry,
          label: card.label || '',
        });
      }
      showView('cpSuccess');
      if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        const s = document.getElementById('cpSuccess');
        if (s) animate(s, { opacity: [0, 1], scale: [0.9, 1] }, { duration: 0.4 });
      }
    } catch (err) {
      const errEl = document.getElementById('cpAddErrorMsg');
      const msg = err?.data?.message || err?.message || 'Booking failed. Please try again.';
      showView('cpListView');
      if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
    }
  }, 1800);
});

document.getElementById('cpContinueBtn')?.addEventListener('click', closeCardPickerModal);
