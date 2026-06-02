import { uploadPublicFile } from '../api/uploads.js';
import { showToast } from './toast.js';

export function openCompletionOutcomeModal({ bookingId, onSubmit }) {
  return new Promise((resolve) => {
    const overlay = document.createElement('div');
    overlay.className = 'completion-modal__overlay';
    overlay.innerHTML = `
      <div class="completion-modal" role="dialog" aria-labelledby="completionModalTitle">
        <header class="completion-modal__header">
          <h2 id="completionModalTitle">Job Outcome</h2>
          <button type="button" class="completion-modal__close" aria-label="Close">×</button>
        </header>

        <div class="completion-modal__outcomes">
          <button type="button" class="completion-outcome-btn completion-outcome-btn--paid" data-outcome="customer_paid">
            <span class="completion-outcome-btn__icon">✅</span>
            <span class="completion-outcome-btn__label">Customer Paid</span>
            <span class="completion-outcome-btn__sub">Job done, payment received</span>
          </button>
          <button type="button" class="completion-outcome-btn completion-outcome-btn--refused" data-outcome="customer_refused_payment">
            <span class="completion-outcome-btn__icon">⚠️</span>
            <span class="completion-outcome-btn__label">Customer Refused Payment</span>
            <span class="completion-outcome-btn__sub">Job done but customer wouldn't pay</span>
          </button>
          <button type="button" class="completion-outcome-btn completion-outcome-btn--incomplete" data-outcome="could_not_complete">
            <span class="completion-outcome-btn__icon">🚫</span>
            <span class="completion-outcome-btn__label">Couldn't Complete Job</span>
            <span class="completion-outcome-btn__sub">Unable to finish (parts missing, customer not home, etc)</span>
          </button>
        </div>

        <form class="completion-modal__form" data-form hidden>
          <div class="completion-modal__photos" data-photos-paid hidden>
            <label class="completion-modal__field"><span>Before photo</span><input type="file" accept="image/*" data-photo-input="before" /></label>
            <label class="completion-modal__field"><span>After photo</span><input type="file" accept="image/*" data-photo-input="after" /></label>
            <label class="completion-modal__field"><span>Materials used (optional)</span><input type="text" data-field="materialsUsed" placeholder="PVC pipe, sealant, ..." /></label>
            <label class="completion-modal__field"><span>Notes (optional)</span><textarea data-field="workerNotes" rows="3" placeholder="What did you do?"></textarea></label>
          </div>

          <div class="completion-modal__refusal" data-fields-refused hidden>
            <label class="completion-modal__field"><span>Why did customer refuse payment? (required)</span><textarea data-field="refusalReason" rows="3" disabled></textarea></label>
            <p class="completion-modal__warning">⚠️ Customer will be asked to verify the refusal. False claims will result in account penalty.</p>
          </div>

          <div class="completion-modal__incomplete" data-fields-incomplete hidden>
            <label class="completion-modal__field"><span>Why couldn't you complete the job? (required)</span><textarea data-field="couldNotCompleteReason" rows="3" disabled></textarea></label>
          </div>

          <footer class="completion-modal__actions">
            <button type="button" class="btn btn--ghost" data-action="back">Back</button>
            <button type="submit" class="btn btn--primary" data-action="submit">Submit</button>
          </footer>
        </form>
      </div>
    `;
    document.body.appendChild(overlay);

    const close = () => { overlay.remove(); resolve(); };
    overlay.querySelector('.completion-modal__close').addEventListener('click', close);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });

    const form = overlay.querySelector('[data-form]');
    const refusalReason = form.querySelector('[data-field="refusalReason"]');
    const couldNotCompleteReason = form.querySelector('[data-field="couldNotCompleteReason"]');
    let selectedOutcome = null;

    const syncConditionalFields = () => {
      const refusalSelected = selectedOutcome === 'customer_refused_payment';
      const incompleteSelected = selectedOutcome === 'could_not_complete';
      refusalReason.disabled = !refusalSelected;
      refusalReason.required = refusalSelected;
      couldNotCompleteReason.disabled = !incompleteSelected;
      couldNotCompleteReason.required = incompleteSelected;
    };

    overlay.querySelectorAll('.completion-outcome-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        selectedOutcome = btn.dataset.outcome;
        overlay.querySelector('.completion-modal__outcomes').hidden = true;
        form.hidden = false;
        overlay.querySelector('[data-photos-paid]').hidden = selectedOutcome !== 'customer_paid';
        overlay.querySelector('[data-fields-refused]').hidden = selectedOutcome !== 'customer_refused_payment';
        overlay.querySelector('[data-fields-incomplete]').hidden = selectedOutcome !== 'could_not_complete';
        syncConditionalFields();
      });
    });

    overlay.querySelector('[data-action="back"]').addEventListener('click', () => {
      form.hidden = true;
      overlay.querySelector('.completion-modal__outcomes').hidden = false;
      selectedOutcome = null;
      syncConditionalFields();
    });

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const submitBtn = form.querySelector('[data-action="submit"]');
      submitBtn.disabled = true;
      submitBtn.textContent = 'Uploading...';

      try {
        const payload = { outcome: selectedOutcome };

        if (selectedOutcome === 'customer_paid') {
          const beforeInput = form.querySelector('[data-photo-input="before"]');
          const afterInput = form.querySelector('[data-photo-input="after"]');
          if (!beforeInput.files[0] || !afterInput.files[0]) {
            throw new Error('Both before and after photos required.');
          }
          const [beforeUploaded, afterUploaded] = await Promise.all([
            uploadPublicFile(beforeInput.files[0], 'completion'),
            uploadPublicFile(afterInput.files[0], 'completion'),
          ]);
          const beforeUrl = beforeUploaded?.url || beforeUploaded;
          const afterUrl = afterUploaded?.url || afterUploaded;
          payload.beforePhotos = [beforeUrl];
          payload.afterPhotos = [afterUrl];
          payload.materialsUsed = form.querySelector('[data-field="materialsUsed"]').value;
          payload.workerNotes = form.querySelector('[data-field="workerNotes"]').value;
        } else if (selectedOutcome === 'customer_refused_payment') {
          payload.refusalReason = form.querySelector('[data-field="refusalReason"]').value;
        } else if (selectedOutcome === 'could_not_complete') {
          payload.couldNotCompleteReason = form.querySelector('[data-field="couldNotCompleteReason"]').value;
        }

        await onSubmit(payload);
        showToast('Outcome submitted.', 'success');
        close();
      } catch (err) {
        showToast(err?.message || 'Submission failed.', 'error');
        submitBtn.disabled = false;
        submitBtn.textContent = 'Submit';
      }
    });
  });
}
