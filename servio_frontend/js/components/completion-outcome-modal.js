import { uploadPublicFile } from '../api/uploads.js';
import { showToast } from './toast.js';
import { animate } from 'https://cdn.jsdelivr.net/npm/motion@12.38.0/+esm';

let materialRowSeq = 0;

function createMaterialRowMarkup(rowId) {
  return `
    <div class="completion-material-row" data-material-row="${rowId}">
      <div class="completion-material-row__fields">
        <label class="completion-modal__field completion-material-row__name">
          <span>Material name</span>
          <input type="text" data-material-field="name" placeholder="PVC pipe" />
        </label>
        <label class="completion-modal__field completion-material-row__qty">
          <span>Qty</span>
          <input type="number" data-material-field="qty" min="1" step="1" value="1" />
        </label>
        <label class="completion-modal__field completion-material-row__price">
          <span>Unit price (EGP)</span>
          <input type="number" data-material-field="unitPrice" min="0" step="0.01" placeholder="0.00" />
        </label>
      </div>
      <div class="completion-material-row__fields">
        <label class="completion-modal__field completion-material-row__reason">
          <span>Reason (optional)</span>
          <input type="text" data-material-field="reason" placeholder="Why was this needed?" />
        </label>
        <label class="completion-modal__field completion-material-row__photo">
          <span>Photo (optional)</span>
          <input type="file" accept="image/*" data-material-field="photoInput" />
          <span class="completion-material-row__photo-status" data-material-field="photoStatus"></span>
        </label>
      </div>
      <button type="button" class="completion-material-row__remove" data-action="remove-material" aria-label="Remove material">×</button>
    </div>
  `;
}

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
          <button type="button" class="completion-outcome-btn completion-outcome-btn--declined" data-outcome="customer_declined_work">
            <span class="completion-outcome-btn__icon">🙅</span>
            <span class="completion-outcome-btn__label">Customer Declined the Work</span>
            <span class="completion-outcome-btn__sub">Tech arrived but customer declined the job</span>
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
            <label class="completion-modal__field"><span>Labor amount (EGP)</span><input type="number" data-field="laborAmount" min="0" step="0.01" placeholder="0.00" /></label>

            <div class="completion-materials" data-materials-list>
              <div class="completion-materials__header">
                <span>Materials used (optional)</span>
                <button type="button" class="btn btn--ghost btn--sm" data-action="add-material">+ Add material</button>
              </div>
              <div class="completion-materials__rows" data-material-rows></div>
            </div>

            <div class="completion-modal__subtotal" data-subtotal-row>
              <span>Subtotal</span>
              <span class="completion-modal__subtotal-value" data-subtotal-value>EGP 0.00</span>
            </div>

            <label class="completion-modal__field"><span>Notes (optional)</span><textarea data-field="workerNotes" rows="3" placeholder="What did you do?"></textarea></label>
          </div>

          <div class="completion-modal__refusal" data-fields-refused hidden>
            <label class="completion-modal__field"><span>Why did customer refuse payment? (required)</span><textarea data-field="refusalReason" rows="3" disabled></textarea></label>
            <p class="completion-modal__warning">⚠️ Customer will be asked to verify the refusal. False claims will result in account penalty.</p>
          </div>

          <div class="completion-modal__declined" data-fields-declined hidden>
            <label class="completion-modal__field"><span>Why did customer decline the work? (required)</span><textarea data-field="declineReason" rows="3" disabled></textarea></label>
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
    const declineReason = form.querySelector('[data-field="declineReason"]');
    const couldNotCompleteReason = form.querySelector('[data-field="couldNotCompleteReason"]');
    const laborAmountInput = form.querySelector('[data-field="laborAmount"]');
    const materialRowsContainer = form.querySelector('[data-material-rows]');
    const subtotalValueEl = form.querySelector('[data-subtotal-value]');
    let selectedOutcome = null;
    let subtotalDisplayed = 0;

    const syncConditionalFields = () => {
      const refusalSelected = selectedOutcome === 'customer_refused_payment';
      const declinedSelected = selectedOutcome === 'customer_declined_work';
      const incompleteSelected = selectedOutcome === 'could_not_complete';
      refusalReason.disabled = !refusalSelected;
      refusalReason.required = refusalSelected;
      declineReason.disabled = !declinedSelected;
      declineReason.required = declinedSelected;
      couldNotCompleteReason.disabled = !incompleteSelected;
      couldNotCompleteReason.required = incompleteSelected;
    };

    const formatEgp = (n) => `EGP ${n.toFixed(2)}`;

    const computeSubtotal = () => {
      const labor = parseFloat(laborAmountInput.value) || 0;
      let materialsTotal = 0;
      materialRowsContainer.querySelectorAll('[data-material-row]').forEach(row => {
        const qty = parseFloat(row.querySelector('[data-material-field="qty"]').value) || 0;
        const unitPrice = parseFloat(row.querySelector('[data-material-field="unitPrice"]').value) || 0;
        materialsTotal += qty * unitPrice;
      });
      return labor + materialsTotal;
    };

    const updateSubtotal = () => {
      const next = computeSubtotal();
      const from = subtotalDisplayed;
      animate(from, next, {
        duration: 0.35,
        easing: 'ease-out',
        onUpdate: (value) => {
          subtotalValueEl.textContent = formatEgp(value);
        },
      });
      subtotalDisplayed = next;
    };

    const addMaterialRow = () => {
      materialRowSeq += 1;
      const rowId = `m${materialRowSeq}`;
      materialRowsContainer.insertAdjacentHTML('beforeend', createMaterialRowMarkup(rowId));
      updateSubtotal();
    };

    // Event delegation for material row interactions (add/remove rows added dynamically).
    materialRowsContainer.addEventListener('click', (e) => {
      const removeBtn = e.target.closest('[data-action="remove-material"]');
      if (removeBtn) {
        removeBtn.closest('[data-material-row]')?.remove();
        updateSubtotal();
      }
    });

    materialRowsContainer.addEventListener('input', (e) => {
      if (e.target.matches('[data-material-field="qty"], [data-material-field="unitPrice"]')) {
        updateSubtotal();
      }
    });

    materialRowsContainer.addEventListener('change', async (e) => {
      const fileInput = e.target.closest('[data-material-field="photoInput"]');
      if (!fileInput) return;
      const row = fileInput.closest('[data-material-row]');
      const statusEl = row.querySelector('[data-material-field="photoStatus"]');
      const file = fileInput.files[0];
      if (!file) return;
      statusEl.textContent = 'Uploading...';
      try {
        const uploaded = await uploadPublicFile(file, 'completion');
        const url = uploaded?.url || uploaded;
        row.dataset.photoUrl = url;
        statusEl.textContent = 'Photo attached ✓';
      } catch (err) {
        row.dataset.photoUrl = '';
        statusEl.textContent = 'Upload failed';
        showToast(err?.message || 'Material photo upload failed.', 'error');
      }
    });

    laborAmountInput.addEventListener('input', updateSubtotal);

    form.querySelector('[data-action="add-material"]').addEventListener('click', addMaterialRow);

    overlay.querySelectorAll('.completion-outcome-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        selectedOutcome = btn.dataset.outcome;
        overlay.querySelector('.completion-modal__outcomes').hidden = true;
        form.hidden = false;
        overlay.querySelector('[data-photos-paid]').hidden = selectedOutcome !== 'customer_paid';
        overlay.querySelector('[data-fields-refused]').hidden = selectedOutcome !== 'customer_refused_payment';
        overlay.querySelector('[data-fields-declined]').hidden = selectedOutcome !== 'customer_declined_work';
        overlay.querySelector('[data-fields-incomplete]').hidden = selectedOutcome !== 'could_not_complete';
        if (selectedOutcome === 'customer_paid' && materialRowsContainer.children.length === 0) {
          addMaterialRow();
        }
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

          const materialRows = Array.from(materialRowsContainer.querySelectorAll('[data-material-row]'));
          const materials = materialRows
            .map(row => {
              const name = row.querySelector('[data-material-field="name"]').value.trim();
              const qty = Number(row.querySelector('[data-material-field="qty"]').value);
              const unitPrice = Number(row.querySelector('[data-material-field="unitPrice"]').value);
              const reason = row.querySelector('[data-material-field="reason"]').value.trim();
              const photo = row.dataset.photoUrl || '';
              return { name, qty, unitPrice, reason, photo };
            })
            .filter(m => m.name);

          for (const m of materials) {
            if (!m.name) throw new Error('Each material row needs a name.');
            if (!(m.qty >= 1)) throw new Error(`Quantity for "${m.name}" must be at least 1.`);
            if (!(m.unitPrice > 0)) throw new Error(`Unit price for "${m.name}" must be greater than 0.`);
          }
          if (materials.length > 50) {
            throw new Error('You can list up to 50 materials.');
          }

          const [beforeUploaded, afterUploaded] = await Promise.all([
            uploadPublicFile(beforeInput.files[0], 'completion'),
            uploadPublicFile(afterInput.files[0], 'completion'),
          ]);
          const beforeUrl = beforeUploaded?.url || beforeUploaded;
          const afterUrl = afterUploaded?.url || afterUploaded;
          payload.beforePhotos = [beforeUrl];
          payload.afterPhotos = [afterUrl];
          payload.laborAmount = Number(laborAmountInput.value) || 0;
          payload.materials = materials;
          payload.workerNotes = form.querySelector('[data-field="workerNotes"]').value;
        } else if (selectedOutcome === 'customer_refused_payment') {
          payload.refusalReason = form.querySelector('[data-field="refusalReason"]').value;
        } else if (selectedOutcome === 'customer_declined_work') {
          payload.declineReason = form.querySelector('[data-field="declineReason"]').value;
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
