import { adminVerifySettlement, adminRejectSettlement } from '../api/payments.js';
import { alertDialog } from './confirm-dialog.js';

export function openSettlementVerifyModal({ settlementId, onSuccess, onError } = {}) {
  const notify = (m) => alertDialog({ title: 'Action failed', body: String(m?.message || m), tone: 'danger' });
  const w = document.createElement('div');
  w.className = 'modal modal--center';
  w.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.5);display:flex;align-items:center;justify-content:center;z-index:9999;';
  w.innerHTML = `
    <div class="modal__panel" style="background:#fff;padding:24px;border-radius:12px;max-width:480px;width:90%;position:relative;">
      <button class="modal__close" type="button" style="position:absolute;top:12px;right:12px;border:none;background:none;font-size:24px;cursor:pointer;">×</button>
      <h2>Verify Settlement</h2>
      <p>Verify or reject this manual settlement submission.</p>
      <div class="modal__actions" style="display:flex;gap:8px;margin:16px 0;">
        <button class="btn-premium btn-premium--primary" data-act="verify" type="button">Verify</button>
        <button class="btn-premium btn-premium--danger" data-act="reject" type="button">Reject…</button>
        <button class="btn-premium btn-premium--ghost" data-cancel type="button">Cancel</button>
      </div>
      <label id="rejectReasonWrap" hidden style="display:block;margin:12px 0;">Reason
        <textarea id="rejReason" minlength="5" style="width:100%;padding:8px;border:1px solid #e5e7eb;border-radius:6px;margin-top:4px;min-height:60px;"></textarea>
      </label>
      <div class="modal__actions" id="confirmRow" hidden style="display:flex;gap:8px;justify-content:flex-end;">
        <button class="btn-premium btn-premium--danger" data-act="confirm-reject" type="button">Confirm reject</button>
      </div>
    </div>`;
  document.body.appendChild(w);
  const close = () => w.remove();
  w.querySelector('.modal__close').onclick = close;
  w.querySelector('[data-cancel]').onclick = close;
  w.addEventListener('click', (e) => { if (e.target === w) close(); });

  w.querySelector('[data-act="verify"]').onclick = async () => {
    try { await adminVerifySettlement(settlementId); close(); onSuccess?.(); }
    catch (e) { (onError || notify)(e.message || e); }
  };
  w.querySelector('[data-act="reject"]').onclick = () => {
    w.querySelector('#rejectReasonWrap').hidden = false;
    w.querySelector('#confirmRow').hidden = false;
  };
  w.querySelector('[data-act="confirm-reject"]').onclick = async () => {
    const reason = w.querySelector('#rejReason').value.trim();
    if (reason.length < 5) return alertDialog({ title: 'Reason too short', body: 'Enter at least 5 characters explaining the rejection.', tone: 'warning' });
    try { await adminRejectSettlement(settlementId, { reason }); close(); onSuccess?.(); }
    catch (e) { (onError || notify)(e.message || e); }
  };
}
