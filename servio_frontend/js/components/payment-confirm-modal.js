export function openPaymentConfirmModal({ title, body, requireReason = false, onConfirm }) {
  const w = document.createElement('div');
  w.className = 'modal modal--center';
  w.innerHTML = `
    <div class="modal__panel">
      <button class="modal__close" aria-label="Close">&times;</button>
      <h2>${title}</h2>
      ${body ? `<p>${body}</p>` : ''}
      ${requireReason ? '<label class="block"><span>Reason</span><textarea id="confirmReason" minlength="5" required></textarea></label>' : ''}
      <div class="modal__actions">
        <button class="btn btn--ghost" data-cancel>Cancel</button>
        <button class="btn btn--primary" data-confirm>Confirm</button>
      </div>
    </div>`;
  document.body.appendChild(w);
  const close = () => w.remove();
  w.querySelector('.modal__close').onclick = close;
  w.querySelector('[data-cancel]').onclick = close;
  w.querySelector('[data-confirm]').onclick = async () => {
    const reason = requireReason ? w.querySelector('#confirmReason').value.trim() : undefined;
    if (requireReason && (!reason || reason.length < 5)) return alert('Reason 5+ chars');
    const btn = w.querySelector('[data-confirm]');
    btn.disabled = true;
    btn.textContent = 'Working…';
    try {
      await onConfirm(reason);
      close();
    } catch (e) {
      btn.disabled = false;
      btn.textContent = 'Confirm';
      alert(e.message || e);
    }
  };
}
