export function openPaymentConfirmModal({
  title,
  body,
  requireReason = false,
  reasonCodeOptions = [],
  confirmLabel = 'Confirm',
  onConfirm,
}) {
  const w = document.createElement('div');
  w.className = 'modal modal--center';
  w.innerHTML = `
    <div class="modal__panel">
      <button class="modal__close" aria-label="Close">&times;</button>
      <h2>${title}</h2>
      ${body ? `<p>${body}</p>` : ''}
      ${reasonCodeOptions.length ? `<label class="block"><span>Reason code</span><select id="confirmReasonCode">${reasonCodeOptions.map(opt => `<option value="${opt.value}">${opt.label}</option>`).join('')}</select></label>` : ''}
      ${requireReason ? '<label class="block"><span>Decision note</span><textarea id="confirmReason" minlength="5" required></textarea></label>' : ''}
      <p class="modal__error" data-error hidden></p>
      <div class="modal__actions">
        <button class="btn btn--ghost" data-cancel>Cancel</button>
        <button class="btn btn--primary" data-confirm>${confirmLabel}</button>
      </div>
    </div>`;

  document.body.appendChild(w);
  const close = () => w.remove();
  const showError = (message) => {
    const error = w.querySelector('[data-error]');
    if (!error) return;
    error.textContent = message;
    error.hidden = false;
  };

  w.querySelector('.modal__close').onclick = close;
  w.querySelector('[data-cancel]').onclick = close;
  w.querySelector('[data-confirm]').onclick = async () => {
    const reason = requireReason ? w.querySelector('#confirmReason').value.trim() : undefined;
    const reasonCode = w.querySelector('#confirmReasonCode')?.value;
    if (requireReason && (!reason || reason.length < 5)) {
      showError('Decision note must be at least 5 characters.');
      return;
    }

    const btn = w.querySelector('[data-confirm]');
    btn.disabled = true;
    btn.textContent = 'Working...';
    try {
      await onConfirm({ reason, reasonCode });
      close();
    } catch (e) {
      btn.disabled = false;
      btn.textContent = confirmLabel;
      showError(e.message || String(e));
    }
  };
}
