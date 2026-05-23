export function openPartialRefundModal({ payment, onConfirm }) {
  const w = document.createElement('div');
  w.className = 'modal modal--center';
  const max = payment.amount;
  const techEarn = (payment.booking?.basePrice ?? payment.booking?.totalPrice ?? max) - (payment.booking?.platformFeeAmount || 0);
  w.innerHTML = `
    <div class="modal__panel">
      <button class="modal__close" aria-label="Close">&times;</button>
      <h2>Partial Refund</h2>
      <p>Total: ${fmt(payment.amount)} · Tech: ${fmt(techEarn)} · Fee: ${fmt(payment.booking?.platformFeeAmount || 0)}</p>
      <label class="block">
        <span>Refund amount</span>
        <input id="prAmt" type="range" min="0" max="${max}" step="0.01" value="0">
        <input id="prAmtNum" type="number" min="0" max="${max}" step="0.01" value="0">
      </label>
      <fieldset>
        <legend>Deduct from</legend>
        <label><input type="radio" name="prFrom" value="tech" checked> Tech earnings</label>
        <label><input type="radio" name="prFrom" value="platform"> Platform fee</label>
        <label><input type="radio" name="prFrom" value="proportional"> Both (proportional)</label>
      </fieldset>
      <label class="block"><span>Reason</span><textarea id="prReason" minlength="5"></textarea></label>
      <div class="modal__actions">
        <button class="btn btn--ghost" data-cancel>Cancel</button>
        <button class="btn btn--primary" data-confirm>Process refund</button>
      </div>
    </div>`;
  document.body.appendChild(w);
  const close = () => w.remove();
  const range = w.querySelector('#prAmt');
  const num = w.querySelector('#prAmtNum');
  range.oninput = () => { num.value = range.value; };
  num.oninput = () => { range.value = num.value; };
  w.querySelector('.modal__close').onclick = close;
  w.querySelector('[data-cancel]').onclick = close;
  w.querySelector('[data-confirm]').onclick = async () => {
    const refundAmount = parseFloat(num.value);
    const deductFrom = w.querySelector('input[name="prFrom"]:checked').value;
    const reason = w.querySelector('#prReason').value.trim();
    if (!(refundAmount > 0) || refundAmount > max) return alert('Invalid amount');
    if (reason.length < 5) return alert('Reason 5+ chars');
    const btn = w.querySelector('[data-confirm]');
    btn.disabled = true;
    btn.textContent = 'Working…';
    try {
      await onConfirm({ refundAmount, deductFrom, reason });
      close();
    } catch (e) {
      btn.disabled = false;
      btn.textContent = 'Process refund';
      alert(e.message || e);
    }
  };

  function fmt(n) {
    return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'EGP' }).format(n || 0);
  }
}
