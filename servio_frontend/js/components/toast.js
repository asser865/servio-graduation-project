// Reusable toast notification — import showToast from this module

const ICONS = {
  success: '✓',
  error: '✕',
  info: 'ℹ',
};

const AUTO_DISMISS_MS = 3000;

/**
 * Lazily creates (or retrieves) the shared toast container appended to <body>.
 * @returns {HTMLElement}
 */
function getContainer() {
  let container = document.getElementById('toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    document.body.appendChild(container);
  }
  return container;
}

/**
 * Slides a toast out and removes it from the DOM once the transition ends.
 * @param {HTMLElement} toast
 */
function dismiss(toast) {
  // Guard: already dismissing
  if (toast.dataset.dismissing === 'true') return;
  toast.dataset.dismissing = 'true';

  toast.classList.remove('toast--visible');

  toast.addEventListener('transitionend', () => {
    toast.remove();
  }, { once: true });
}

/**
 * Show a toast notification.
 * @param {string} message - The message to display.
 * @param {'success'|'error'|'info'} [type='success'] - Visual variant.
 */
export function showToast(message, type = 'success') {
  const safeType = ['success', 'error', 'info'].includes(type) ? type : 'success';
  const icon = ICONS[safeType];

  const container = getContainer();

  // Build toast element
  const toast = document.createElement('div');
  toast.className = `toast toast--${safeType}`;
  toast.innerHTML = `
    <span class="toast__icon" aria-hidden="true">${icon}</span>
    <span class="toast__message">${message}</span>
    <button class="toast__close" aria-label="Dismiss">&times;</button>
  `;

  container.appendChild(toast);

  // Trigger CSS transition — rAF ensures the browser has painted the initial
  // state (transform: translateX(110%)) before we apply the visible class.
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      toast.classList.add('toast--visible');
    });
  });

  // Auto-dismiss
  const timerId = setTimeout(() => dismiss(toast), AUTO_DISMISS_MS);

  // Close button — immediate dismiss
  toast.querySelector('.toast__close').addEventListener('click', () => {
    clearTimeout(timerId);
    dismiss(toast);
  });
}

// .
