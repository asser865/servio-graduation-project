const REFUND_REASON_OPTIONS = [
  { value: 'service_incomplete', label: 'Service incomplete' },
  { value: 'quality_issue', label: 'Quality issue' },
  { value: 'pricing_adjustment', label: 'Pricing adjustment' },
  { value: 'customer_goodwill', label: 'Customer goodwill' },
  { value: 'admin_policy', label: 'Admin policy' },
  { value: 'manual_adjustment', label: 'Manual adjustment' },
];

export function openPartialRefundModal({ payment, decisionDetail, onConfirm }) {
  const w = document.createElement('div');
  w.className = 'modal modal--center';
  const breakdown = decisionDetail?.paymentBreakdown || {};
  const fallbackRemaining = Number(payment.amount || 0) - Number(payment.refundedAmount || 0);
  const max = Number(breakdown.remainingRefundable ?? fallbackRemaining) || 0;
  const workerEarning = Number(breakdown.workerEarning ?? payment.workerEarning ?? payment.booking?.totalPrice ?? 0);
  const platformFee = Number(breakdown.platformFee ?? payment.platformFee ?? payment.booking?.platformFeeAmount ?? 0);

  w.innerHTML = `
    <div class="modal__panel">
      <button class="modal__close" aria-label="Close">&times;</button>
      <h2>Partial refund</h2>
      <p>Total ${fmt(payment.amount)} / Worker ${fmt(workerEarning)} / Platform ${fmt(platformFee)} / Remaining ${fmt(max)}</p>
      <label class="block">
        <span>Refund amount</span>
        <input id="prAmt" type="range" min="0" max="${max}" step="0.01" value="0">
        <input id="prAmtNum" type="number" min="0" max="${max}" step="0.01" value="0">
      </label>
      <label class="block">
        <span>Reason code</span>
        <select id="prReasonCode">${REFUND_REASON_OPTIONS.map(opt => `<option value="${opt.value}">${opt.label}</option>`).join('')}</select>
      </label>
      <fieldset>
        <legend>Deduct from</legend>
        <label><input type="radio" name="prFrom" value="tech" checked> Worker earnings</label>
        <label><input type="radio" name="prFrom" value="platform"> Platform fee</label>
        <label><input type="radio" name="prFrom" value="proportional"> Both proportional</label>
      </fieldset>
      <label class="block"><span>Decision note</span><textarea id="prReason" minlength="5"></textarea></label>
      <p class="modal__error" data-error hidden></p>
      <div class="modal__actions">
        <button class="btn btn--ghost" data-cancel>Cancel</button>
        <button class="btn btn--primary" data-confirm>Process refund</button>
      </div>
    </div>`;
  document.body.appendChild(w);

  const close = () => w.remove();
  const showError = (message) => {
    const error = w.querySelector('[data-error]');
    error.textContent = message;
    error.hidden = false;
  };
  const range = w.querySelector('#prAmt');
  const num = w.querySelector('#prAmtNum');
  range.oninput = () => { num.value = range.value; };
  num.oninput = () => { range.value = num.value; };
  w.querySelector('.modal__close').onclick = close;
  w.querySelector('[data-cancel]').onclick = close;
  w.querySelector('[data-confirm]').onclick = async () => {
    const refundAmount = parseFloat(num.value);
    const deductFrom = w.querySelector('input[name="prFrom"]:checked').value;
    const reasonCode = w.querySelector('#prReasonCode').value;
    const reason = w.querySelector('#prReason').value.trim();
    if (!(refundAmount > 0) || refundAmount > max) return showError('Enter a valid refund amount.');
    if (reason.length < 5) return showError('Decision note must be at least 5 characters.');
    const btn = w.querySelector('[data-confirm]');
    btn.disabled = true;
    btn.textContent = 'Working...';
    try {
      await onConfirm({ refundAmount, deductFrom, reasonCode, reason });
      close();
    } catch (e) {
      btn.disabled = false;
      btn.textContent = 'Process refund';
      showError(e.message || String(e));
    }
  };

  function fmt(n) {
    return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'EGP' }).format(n || 0);
  }
}
