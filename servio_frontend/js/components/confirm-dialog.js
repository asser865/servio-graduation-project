import { escapeHtml } from '../utils/string.js';

// Promise-based, professional replacements for window.confirm / window.prompt.
// Fully self-contained: injects its own scoped styles (driven by the global
// design tokens in base/variables.css) so it looks right on any page, including
// the admin dashboard, without depending on page-specific modal CSS.

const STYLE_ID = 'cd-dialog-styles';

function ensureStyles() {
  if (document.getElementById(STYLE_ID)) return;
  const style = document.createElement('style');
  style.id = STYLE_ID;
  style.textContent = `
    .cd-overlay {
      position: fixed; inset: 0; z-index: 10000;
      display: flex; align-items: center; justify-content: center;
      padding: 20px;
      background: rgba(20, 23, 28, 0.55);
      backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px);
      animation: cd-fade 0.18s ease;
    }
    .cd-panel {
      width: 100%; max-width: 440px;
      background: var(--color-surface-raised, #fff);
      color: var(--color-text, #222831);
      border: 1px solid var(--color-border, #ddd);
      border-radius: var(--radius-lg, 18px);
      box-shadow: var(--shadow-md, 0 14px 36px rgba(0,0,0,0.2));
      padding: 28px 26px 22px;
      position: relative;
      font-family: var(--font-primary, 'Inter', sans-serif);
      animation: cd-pop 0.2s cubic-bezier(0.16, 1, 0.3, 1);
    }
    .cd-icon {
      width: 46px; height: 46px; border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
      margin-bottom: 16px; font-size: 22px; line-height: 1;
    }
    .cd-icon--primary { background: var(--color-info-bg, rgba(41,128,185,0.12)); color: var(--color-info, #2980b9); }
    .cd-icon--danger  { background: var(--color-danger-bg, rgba(192,57,43,0.12)); color: var(--color-danger, #c0392b); }
    .cd-icon--success { background: var(--color-success-bg, rgba(39,174,96,0.12)); color: var(--color-success, #27ae60); }
    .cd-icon--warning { background: var(--color-warning-bg, rgba(230,126,34,0.12)); color: var(--color-warning, #e67e22); }
    .cd-icon--info    { background: var(--color-info-bg, rgba(41,128,185,0.12)); color: var(--color-info, #2980b9); }
    .cd-title {
      margin: 0 0 8px; font-size: 1.18rem; font-weight: 650;
      font-family: var(--font-heading, 'Poppins', sans-serif);
      color: var(--color-text, #222831);
    }
    .cd-text {
      margin: 0 0 6px; font-size: 0.94rem; line-height: 1.55;
      color: var(--color-text-light, #6B6560);
    }
    .cd-field { display: block; margin-top: 16px; }
    .cd-field > span {
      display: block; margin-bottom: 6px; font-size: 0.82rem;
      font-weight: 600; color: var(--color-text-light, #6B6560);
    }
    .cd-field textarea, .cd-field input {
      width: 100%; box-sizing: border-box;
      padding: 10px 12px; font: inherit; font-size: 0.92rem;
      color: var(--color-text, #222831);
      background: var(--color-surface, #fff);
      border: 1px solid var(--color-border, #ddd);
      border-radius: var(--radius-sm, 10px);
      resize: vertical;
      transition: border-color 0.15s ease, box-shadow 0.15s ease;
    }
    .cd-field textarea:focus, .cd-field input:focus {
      outline: none;
      border-color: var(--color-accent, #9A8C73);
      box-shadow: 0 0 0 3px var(--color-info-bg, rgba(41,128,185,0.12));
    }
    .cd-error { margin: 10px 0 0; font-size: 0.84rem; color: var(--color-danger, #c0392b); }
    .cd-actions {
      display: flex; justify-content: flex-end; gap: 10px; margin-top: 22px;
    }
    .cd-btn {
      padding: 9px 18px; font: inherit; font-size: 0.9rem; font-weight: 600;
      border-radius: var(--radius-sm, 10px); border: 1px solid transparent;
      cursor: pointer; transition: transform 0.08s ease, filter 0.15s ease, background 0.15s ease;
    }
    .cd-btn:active { transform: translateY(1px); }
    .cd-btn:disabled { opacity: 0.6; cursor: default; }
    .cd-btn--ghost {
      background: transparent; color: var(--color-text-light, #6B6560);
      border-color: var(--color-border, #ddd);
    }
    .cd-btn--ghost:hover { background: var(--color-surface-alt, #f5f5f5); }
    .cd-btn--primary { background: var(--color-primary, #222831); color: var(--color-surface, #fff); }
    .cd-btn--primary:hover { filter: brightness(1.12); }
    .cd-btn--danger { background: var(--color-danger, #c0392b); color: #fff; }
    .cd-btn--danger:hover { filter: brightness(1.08); }
    .cd-close {
      position: absolute; top: 14px; right: 14px;
      width: 30px; height: 30px; border: none; background: transparent;
      font-size: 22px; line-height: 1; cursor: pointer; border-radius: 50%;
      color: var(--color-text-light, #888); transition: background 0.15s ease;
    }
    .cd-close:hover { background: var(--color-surface-alt, #f0f0f0); }
    [data-theme="dark"] .cd-overlay { background: rgba(0, 0, 0, 0.6); }
    @keyframes cd-fade { from { opacity: 0; } to { opacity: 1; } }
    @keyframes cd-pop { from { opacity: 0; transform: translateY(12px) scale(0.97); } to { opacity: 1; transform: none; } }
    @media (prefers-reduced-motion: reduce) {
      .cd-overlay, .cd-panel { animation: none; }
    }
  `;
  document.head.appendChild(style);
}

function mount(html) {
  ensureStyles();
  const w = document.createElement('div');
  w.className = 'cd-overlay';
  w.innerHTML = html;
  document.body.appendChild(w);
  return w;
}

function paragraphs(body) {
  return String(body)
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean)
    .map(line => `<p class="cd-text">${escapeHtml(line)}</p>`)
    .join('');
}

/**
 * Professional confirmation dialog. Resolves true (confirmed) / false (cancelled).
 * @param {object} opts
 * @param {string} opts.title
 * @param {string} [opts.body]            Newlines become separate paragraphs.
 * @param {string} [opts.confirmLabel='Confirm']
 * @param {string} [opts.cancelLabel='Cancel']
 * @param {'primary'|'danger'} [opts.tone='primary']
 */
export function confirmDialog({
  title,
  body = '',
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  tone = 'primary',
} = {}) {
  return new Promise((resolve) => {
    const icon = tone === 'danger' ? '&#9888;' : '&#63;';
    const w = mount(`
      <div class="cd-panel" role="alertdialog" aria-modal="true" aria-label="${escapeHtml(title)}">
        <button class="cd-close" aria-label="Close" data-cancel>&times;</button>
        <div class="cd-icon cd-icon--${tone === 'danger' ? 'danger' : 'primary'}">${icon}</div>
        <h2 class="cd-title">${escapeHtml(title)}</h2>
        ${paragraphs(body)}
        <div class="cd-actions">
          <button class="cd-btn cd-btn--ghost" data-cancel>${escapeHtml(cancelLabel)}</button>
          <button class="cd-btn cd-btn--${tone === 'danger' ? 'danger' : 'primary'}" data-confirm>${escapeHtml(confirmLabel)}</button>
        </div>
      </div>`);

    const done = (value) => {
      document.removeEventListener('keydown', onKey);
      w.remove();
      resolve(value);
    };
    const onKey = (e) => {
      if (e.key === 'Escape') done(false);
      if (e.key === 'Enter') done(true);
    };

    w.querySelectorAll('[data-cancel]').forEach(el => { el.onclick = () => done(false); });
    w.querySelector('[data-confirm]').onclick = () => done(true);
    w.addEventListener('click', e => { if (e.target === w) done(false); });
    document.addEventListener('keydown', onKey);
    w.querySelector('[data-confirm]').focus();
  });
}

/**
 * Professional prompt dialog. Resolves to the entered string, or null if cancelled.
 * @param {object} opts
 * @param {string} opts.title
 * @param {string} [opts.body]
 * @param {string} [opts.label]
 * @param {string} [opts.placeholder]
 * @param {string} [opts.value='']
 * @param {string} [opts.confirmLabel='Submit']
 * @param {string} [opts.cancelLabel='Cancel']
 * @param {boolean} [opts.required=true]
 * @param {boolean} [opts.multiline=true]
 * @param {'primary'|'danger'} [opts.tone='primary']
 */
export function promptDialog({
  title,
  body = '',
  label = '',
  placeholder = '',
  value = '',
  confirmLabel = 'Submit',
  cancelLabel = 'Cancel',
  required = true,
  multiline = true,
  tone = 'primary',
} = {}) {
  return new Promise((resolve) => {
    const field = multiline
      ? `<textarea rows="3" data-input placeholder="${escapeHtml(placeholder)}">${escapeHtml(value)}</textarea>`
      : `<input type="text" data-input placeholder="${escapeHtml(placeholder)}" value="${escapeHtml(value)}">`;

    const w = mount(`
      <div class="cd-panel" role="dialog" aria-modal="true" aria-label="${escapeHtml(title)}">
        <button class="cd-close" aria-label="Close" data-cancel>&times;</button>
        <div class="cd-icon cd-icon--${tone === 'danger' ? 'danger' : 'primary'}">${tone === 'danger' ? '&#9888;' : '&#9998;'}</div>
        <h2 class="cd-title">${escapeHtml(title)}</h2>
        ${body ? `<p class="cd-text">${escapeHtml(body)}</p>` : ''}
        <label class="cd-field">
          ${label ? `<span>${escapeHtml(label)}</span>` : ''}
          ${field}
        </label>
        <p class="cd-error" data-error hidden></p>
        <div class="cd-actions">
          <button class="cd-btn cd-btn--ghost" data-cancel>${escapeHtml(cancelLabel)}</button>
          <button class="cd-btn cd-btn--${tone === 'danger' ? 'danger' : 'primary'}" data-confirm>${escapeHtml(confirmLabel)}</button>
        </div>
      </div>`);

    const input = w.querySelector('[data-input]');
    const error = w.querySelector('[data-error]');
    const done = (val) => {
      document.removeEventListener('keydown', onKey);
      w.remove();
      resolve(val);
    };
    const submit = () => {
      const val = input.value.trim();
      if (required && !val) {
        error.textContent = 'This field is required.';
        error.hidden = false;
        input.focus();
        return;
      }
      done(val);
    };
    const onKey = (e) => {
      if (e.key === 'Escape') done(null);
      if (e.key === 'Enter' && (!multiline || e.ctrlKey || e.metaKey)) submit();
    };

    w.querySelectorAll('[data-cancel]').forEach(el => { el.onclick = () => done(null); });
    w.querySelector('[data-confirm]').onclick = submit;
    w.addEventListener('click', e => { if (e.target === w) done(null); });
    document.addEventListener('keydown', onKey);
    input.focus();
  });
}

const ALERT_ICONS = {
  primary: '&#8505;',  // ℹ
  info: '&#8505;',
  success: '&#10003;', // ✓
  warning: '&#9888;',  // ⚠
  danger: '&#9888;',
};

/**
 * Professional notice dialog (replaces window.alert). Resolves when dismissed.
 * @param {object} opts
 * @param {string} opts.title
 * @param {string} [opts.body]            Newlines become separate paragraphs.
 * @param {string} [opts.confirmLabel='OK']
 * @param {'primary'|'success'|'warning'|'danger'|'info'} [opts.tone='info']
 */
export function alertDialog({
  title,
  body = '',
  confirmLabel = 'OK',
  tone = 'info',
} = {}) {
  return new Promise((resolve) => {
    const variant = ALERT_ICONS[tone] ? tone : 'info';
    const w = mount(`
      <div class="cd-panel" role="alertdialog" aria-modal="true" aria-label="${escapeHtml(title)}">
        <button class="cd-close" aria-label="Close" data-confirm>&times;</button>
        <div class="cd-icon cd-icon--${variant}">${ALERT_ICONS[variant]}</div>
        <h2 class="cd-title">${escapeHtml(title)}</h2>
        ${paragraphs(body)}
        <div class="cd-actions">
          <button class="cd-btn cd-btn--${variant === 'danger' ? 'danger' : 'primary'}" data-confirm>${escapeHtml(confirmLabel)}</button>
        </div>
      </div>`);

    const done = () => {
      document.removeEventListener('keydown', onKey);
      w.remove();
      resolve();
    };
    const onKey = (e) => {
      if (e.key === 'Escape' || e.key === 'Enter') done();
    };

    w.querySelectorAll('[data-confirm]').forEach(el => { el.onclick = done; });
    w.addEventListener('click', e => { if (e.target === w) done(); });
    document.addEventListener('keydown', onKey);
    w.querySelector('.cd-btn').focus();
  });
}
