import { adminApprovePayout, adminMarkPayoutPaid, adminRejectPayout } from '../api/payments.js';
import { alertDialog } from './confirm-dialog.js';

export function openPayoutDecisionModal({ payoutId, currentStatus, onSuccess, onError } = {}) {
  const notify = (m) => alertDialog({ title: 'Action failed', body: String(m?.message || m), tone: 'danger' });
  const w = document.createElement('div');
  w.className = 'modal modal--center';
  w.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.5);display:flex;align-items:center;justify-content:center;z-index:9999;';
  w.innerHTML = `
    <div class="modal__panel" style="background:#fff;padding:24px;border-radius:12px;max-width:480px;width:90%;position:relative;">
      <button class="modal__close" type="button" style="position:absolute;top:12px;right:12px;border:none;background:none;font-size:24px;cursor:pointer;">×</button>
      <h2>Payout decision</h2>
      <p>Current status: <strong>${currentStatus || '—'}</strong></p>
      <div class="modal__actions" style="display:flex;gap:8px;flex-wrap:wrap;margin:16px 0;">
        <button class="btn-premium btn-premium--primary" data-act="approve" type="button">Approve</button>
        <button class="btn-premium btn-premium--success" data-act="mark_paid" type="button">Mark Paid…</button>
        <button class="btn-premium btn-premium--danger" data-act="reject" type="button">Reject…</button>
        <button class="btn-premium btn-premium--ghost" data-cancel type="button">Cancel</button>
      </div>
      <label id="txnWrap" hidden style="display:block;margin:8px 0;">Transaction reference<input type="text" id="txn" minlength="3" style="width:100%;padding:8px;border:1px solid #e5e7eb;border-radius:6px;margin-top:4px;"></label>
      <label id="noteWrap" hidden style="display:block;margin:8px 0;">Note<input type="text" id="note" style="width:100%;padding:8px;border:1px solid #e5e7eb;border-radius:6px;margin-top:4px;"></label>
      <label id="reasonWrap" hidden style="display:block;margin:8px 0;">Reason<textarea id="reason" minlength="5" style="width:100%;padding:8px;border:1px solid #e5e7eb;border-radius:6px;margin-top:4px;min-height:60px;"></textarea></label>
      <div class="modal__actions" id="confirmRow" hidden style="display:flex;gap:8px;justify-content:flex-end;">
        <button class="btn-premium btn-premium--primary" data-act="confirm" type="button">Confirm</button>
      </div>
    </div>`;
  document.body.appendChild(w);
  const close = () => w.remove();
  let chosen = null;
  w.querySelector('.modal__close').onclick = close;
  w.querySelector('[data-cancel]').onclick = close;
  w.addEventListener('click', (e) => { if (e.target === w) close(); });

  ['approve', 'mark_paid', 'reject'].forEach(a => {
    w.querySelector(`[data-act="${a}"]`).onclick = () => {
      chosen = a;
      w.querySelector('#txnWrap').hidden = (a !== 'mark_paid');
      w.querySelector('#noteWrap').hidden = (a !== 'approve');
      w.querySelector('#reasonWrap').hidden = (a !== 'reject');
      w.querySelector('#confirmRow').hidden = false;
    };
  });

  w.querySelector('[data-act="confirm"]').onclick = async () => {
    try {
      if (chosen === 'approve') {
        await adminApprovePayout(payoutId, { note: w.querySelector('#note').value.trim() });
      } else if (chosen === 'mark_paid') {
        const transactionRef = w.querySelector('#txn').value.trim();
        if (transactionRef.length < 3) return alertDialog({ title: 'Reference required', body: 'Enter a transaction reference of at least 3 characters.', tone: 'warning' });
        await adminMarkPayoutPaid(payoutId, { transactionRef });
      } else if (chosen === 'reject') {
        const reason = w.querySelector('#reason').value.trim();
        if (reason.length < 5) return alertDialog({ title: 'Reason too short', body: 'Enter at least 5 characters explaining the rejection.', tone: 'warning' });
        await adminRejectPayout(payoutId, { reason });
      } else {
        return alertDialog({ title: 'No action selected', body: 'Pick an action before confirming.', tone: 'warning' });
      }
      close();
      onSuccess?.();
    } catch (e) {
      (onError || notify)(e.message || e);
    }
  };
}
