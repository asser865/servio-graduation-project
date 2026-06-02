import { uploadPublicFile } from '../api/uploads.js';
import { showToast } from './toast.js';

const ISSUE_REASONS = [
  ['work_not_done', 'Work was not done'],
  ['work_damaged_property', 'Work damaged my property'],
  ['overcharged', 'I was overcharged'],
  ['tech_unprofessional', 'Technician was unprofessional'],
  ['incomplete', 'Job was incomplete'],
  ['tech_did_not_arrive', 'Technician did not arrive'],
  ['other', 'Other'],
];

export default function openCustomerFeedbackModal({ bookingId, onSubmit }) {
  return new Promise((resolve) => {
    const overlay = document.createElement('div');
    overlay.className = 'customer-feedback-modal__overlay';
    overlay.innerHTML = `
      <div class="customer-feedback-modal" role="dialog" aria-labelledby="customerFeedbackTitle">
        <header class="customer-feedback-modal__header">
          <h2 id="customerFeedbackTitle">Service Feedback</h2>
          <button type="button" class="customer-feedback-modal__close" aria-label="Close">×</button>
        </header>

        <div class="customer-feedback-modal__choices" data-choices>
          <button type="button" class="cf-choice-btn cf-choice-btn--confirm" data-choice="confirmed">
            <span class="cf-choice-btn__icon">✅</span>
            <span class="cf-choice-btn__label">Confirm Job</span>
            <span class="cf-choice-btn__sub">Everything is good — release payment</span>
          </button>
          <button type="button" class="cf-choice-btn cf-choice-btn--report" data-choice="reported_issue">
            <span class="cf-choice-btn__icon">⚠️</span>
            <span class="cf-choice-btn__label">Report Issue</span>
            <span class="cf-choice-btn__sub">Something went wrong with this job</span>
          </button>
        </div>

        <form class="customer-feedback-modal__form" data-form hidden>
          <div class="customer-feedback-modal__field" data-fields-confirm hidden>
            <span>Rate the service (optional)</span>
            <div class="cf-stars" data-stars role="radiogroup" aria-label="Rating">
              ${[1, 2, 3, 4, 5].map((n) => `<span class="cf-star" data-star="${n}" role="radio" aria-checked="false" tabindex="0">★</span>`).join('')}
            </div>
            <label class="customer-feedback-modal__field">
              <span>Notes (optional)</span>
              <textarea data-field="confirmNotes" rows="3" placeholder="Anything you'd like to share about the service"></textarea>
            </label>
          </div>

          <div class="customer-feedback-modal__field" data-fields-report hidden>
            <label class="customer-feedback-modal__field">
              <span>What went wrong? (required)</span>
              <select data-field="issueReason" disabled>
                <option value="">Select a reason...</option>
                ${ISSUE_REASONS.map(([v, l]) => `<option value="${v}">${l}</option>`).join('')}
              </select>
            </label>
            <label class="customer-feedback-modal__field">
              <span>Describe the issue (required)</span>
              <textarea data-field="reportNotes" rows="4" disabled placeholder="Provide details about what happened"></textarea>
            </label>
            <label class="customer-feedback-modal__field">
              <span>Evidence photos (at least 1 required)</span>
              <input type="file" accept="image/*" multiple data-photo-input />
            </label>
            <div class="cf-photo-list" data-photo-list hidden></div>
            <p class="customer-feedback-modal__warning">⚠️ The technician will be asked to respond. False reports may result in account penalty.</p>
          </div>

          <footer class="customer-feedback-modal__actions">
            <button type="button" class="btn btn--ghost" data-action="back">Back</button>
            <button type="submit" class="btn btn--primary" data-action="submit">Submit</button>
          </footer>
        </form>
      </div>
    `;
    document.body.appendChild(overlay);

    const close = () => { overlay.remove(); resolve(); };
    overlay.querySelector('.customer-feedback-modal__close').addEventListener('click', close);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });

    const form = overlay.querySelector('[data-form]');
    const choicesWrap = overlay.querySelector('[data-choices]');
    const fieldsConfirm = overlay.querySelector('[data-fields-confirm]');
    const fieldsReport = overlay.querySelector('[data-fields-report]');
    const photoInput = overlay.querySelector('[data-photo-input]');
    const photoList = overlay.querySelector('[data-photo-list]');
    const issueReason = overlay.querySelector('[data-field="issueReason"]');
    const reportNotes = overlay.querySelector('[data-field="reportNotes"]');
    let selectedAction = null;
    let selectedRating = 0;

    const syncConditionalFields = () => {
      const reportSelected = selectedAction === 'reported_issue';
      issueReason.disabled = !reportSelected;
      issueReason.required = reportSelected;
      reportNotes.disabled = !reportSelected;
      reportNotes.required = reportSelected;
      photoInput.disabled = !reportSelected;
    };
    syncConditionalFields();

    // Star rating
    const stars = overlay.querySelectorAll('.cf-star');
    const setRating = (n) => {
      selectedRating = n;
      stars.forEach((star) => {
        const val = Number(star.dataset.star);
        const active = val <= n;
        star.classList.toggle('is-active', active);
        star.setAttribute('aria-checked', active ? 'true' : 'false');
      });
    };
    stars.forEach((star) => {
      star.addEventListener('click', () => setRating(Number(star.dataset.star)));
      star.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          setRating(Number(star.dataset.star));
        }
      });
    });

    // Photo preview — build via DOM (file names are user-controlled, avoid innerHTML XSS)
    photoInput.addEventListener('change', () => {
      const files = [...(photoInput.files || [])];
      photoList.hidden = files.length === 0;
      photoList.replaceChildren();
      files.forEach((f) => {
        const item = document.createElement('span');
        item.className = 'cf-photo-item';
        const name = document.createElement('span');
        name.textContent = f.name;
        const size = document.createElement('small');
        size.textContent = `${Math.ceil(f.size / 1024)} KB`;
        item.append(name, size);
        photoList.appendChild(item);
      });
    });

    // Choice -> form
    overlay.querySelectorAll('.cf-choice-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        selectedAction = btn.dataset.choice;
        choicesWrap.hidden = true;
        form.hidden = false;
        fieldsConfirm.hidden = selectedAction !== 'confirmed';
        fieldsReport.hidden = selectedAction !== 'reported_issue';
        syncConditionalFields();
      });
    });

    overlay.querySelector('[data-action="back"]').addEventListener('click', () => {
      form.hidden = true;
      choicesWrap.hidden = false;
      selectedAction = null;
      syncConditionalFields();
    });

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const submitBtn = form.querySelector('[data-action="submit"]');
      submitBtn.disabled = true;
      submitBtn.textContent = 'Submitting...';

      try {
        const payload = { action: selectedAction };

        if (selectedAction === 'confirmed') {
          if (selectedRating > 0) payload.rating = selectedRating;
          const notes = form.querySelector('[data-field="confirmNotes"]').value.trim();
          if (notes) payload.notes = notes;
        } else if (selectedAction === 'reported_issue') {
          const issueReason = form.querySelector('[data-field="issueReason"]').value;
          const notes = form.querySelector('[data-field="reportNotes"]').value.trim();
          const files = [...(photoInput.files || [])];

          if (!issueReason) throw new Error('Please select a reason.');
          if (!notes) throw new Error('Please describe the issue.');
          if (files.length === 0) throw new Error('At least one evidence photo is required.');

          submitBtn.textContent = 'Uploading...';
          const evidenceImages = [];
          for (const file of files) {
            const uploaded = await uploadPublicFile(file, 'customer-feedback');
            const url = uploaded?.url || uploaded;
            if (url) evidenceImages.push(url);
          }
          if (evidenceImages.length === 0) throw new Error('Photo upload failed. Try again.');

          payload.issueReason = issueReason;
          payload.notes = notes;
          payload.evidenceImages = evidenceImages;
          submitBtn.textContent = 'Submitting...';
        }

        await onSubmit(payload);
        showToast('Feedback submitted.', 'success');
        close();
      } catch (err) {
        showToast(err?.data?.message || err?.message || 'Submission failed.', 'error');
        submitBtn.disabled = false;
        submitBtn.textContent = 'Submit';
      }
    });
  });
}
