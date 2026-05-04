/* Admin Preview Mode Banner — SERVIO
 * Injected globally on every public page when servio_preview_mode === 'true'.
 * Excluded from dashboard, auth, and post-booking pages.
 */

const BANNER_HEIGHT = 48; // px

const EXCLUDED_SEGMENTS = [
  'dashboard',
  'login',
  'signup',
  'messages',
  'booking-history',
  'booking-confirmation',
];

function isExcludedPage() {
  const path = window.location.pathname;
  return EXCLUDED_SEGMENTS.some((seg) => path.includes(seg));
}

function getAdminDashboardHref() {
  // Works whether current page is at root or inside /html/
  return window.location.pathname.includes('/html/')
    ? './admin-dashboard.html'
    : './html/admin-dashboard.html';
}

function injectStyles() {
  const style = document.createElement('style');
  style.textContent = `
    #admin-preview-banner {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      width: 100%;
      height: ${BANNER_HEIGHT}px;
      background: #1a1f27;
      color: #fff;
      z-index: 99999;
      display: flex;
      align-items: center;
      box-shadow: 0 2px 8px rgba(0,0,0,0.35);
      font-family: Inter, system-ui, sans-serif;
      font-size: 0.85rem;
    }
    .preview-banner__inner {
      width: 100%;
      max-width: 100%;
      padding: 0 1.25rem;
      display: flex;
      align-items: center;
      gap: 0.6rem;
    }
    .preview-banner__icon {
      display: flex;
      align-items: center;
      flex-shrink: 0;
      color: #9A8C73;
    }
    .preview-banner__text {
      flex: 1;
      font-weight: 500;
      letter-spacing: 0.01em;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .preview-banner__exit {
      flex-shrink: 0;
      background: transparent;
      border: 1.5px solid rgba(255,255,255,0.35);
      color: #fff;
      border-radius: 8px;
      padding: 5px 14px;
      font-size: 0.8rem;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.15s, border-color 0.15s;
      font-family: inherit;
      letter-spacing: 0.01em;
    }
    .preview-banner__exit:hover {
      background: rgba(255,255,255,0.1);
      border-color: rgba(255,255,255,0.6);
    }
  `;
  document.head.appendChild(style);
}

function injectBanner() {
  const banner = document.createElement('div');
  banner.id = 'admin-preview-banner';
  banner.setAttribute('role', 'status');
  banner.setAttribute('aria-label', 'Admin Preview Mode active');
  banner.innerHTML = `
    <div class="preview-banner__inner">
      <span class="preview-banner__icon" aria-hidden="true">
        <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
          <circle cx="12" cy="12" r="3"/>
        </svg>
      </span>
      <span class="preview-banner__text">Admin Preview Mode &mdash; You are viewing the site as a customer</span>
      <button class="preview-banner__exit" id="exitPreviewBtn" type="button">Exit Preview</button>
    </div>
  `;

  document.body.insertBefore(banner, document.body.firstChild);

  // Push page content and fixed header below the banner
  document.body.style.paddingTop = `${BANNER_HEIGHT}px`;
  
  const header = document.querySelector('[data-site-header]') || document.querySelector('.site-header');
  if (header) {
    header.style.top = `${BANNER_HEIGHT}px`;
  }

  document.getElementById('exitPreviewBtn').addEventListener('click', () => {
    localStorage.removeItem('servio_preview_mode');
    window.location.href = getAdminDashboardHref();
  });
}

export function initPreviewMode() {
  if (localStorage.getItem('servio_preview_mode') !== 'true') return;
  if (isExcludedPage()) return;

  injectStyles();

  if (document.body) {
    injectBanner();
  } else {
    document.addEventListener('DOMContentLoaded', injectBanner);
  }
}

// .
