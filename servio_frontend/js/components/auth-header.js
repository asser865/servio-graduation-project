/* ═══════════════════════════════════════════════════════════
   auth-header.js — Sitewide logged-in header state
   Reads servio_session; injects avatar + dropdown if logged in.
   ═══════════════════════════════════════════════════════════ */
import { getInitials } from '../utils/string.js';

function getSession() {
  try {
    return JSON.parse(
      sessionStorage.getItem('servio_session') ||
      localStorage.getItem('servio_session') ||
      'null'
    );
  } catch {
    return null;
  }
}

function getDashboardHref(role) {
  if (role === 'technician') return './technician-dashboard.html';
  if (role === 'admin')      return './admin-dashboard.html';
  return './customer-dashboard.html';
}

function initLoginRedirects() {
  const currentPath = window.location.pathname;
  const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
  if (currentPage.includes('login.html') || currentPage.includes('signup.html')) return;
  const encodedRedirect = encodeURIComponent('./' + currentPage + window.location.search);
  document.querySelectorAll('a[href*="login.html"]').forEach(link => {
    const originalHref = link.getAttribute('href');
    if (originalHref.includes('redirect=')) return;
    const separator = originalHref.includes('?') ? '&' : '?';
    link.setAttribute('href', originalHref + separator + 'redirect=' + encodedRedirect);
  });
}

export function initAuthHeader() {
  initLoginRedirects();
  const session = getSession();
  if (!session) return;

  const headerRight = document.querySelector('.header__right');
  if (!headerRight) return;

  // Hide Login / Sign Up buttons
  headerRight.querySelectorAll('.btn[href*="login"], .btn[href*="signup"]').forEach(el => {
    el.style.display = 'none';
  });

  const initials   = getInitials(session.name);
  const dashHref   = getDashboardHref(session.role);
  const safeName   = (session.name  || 'User').replace(/[<>"'&]/g, '');
  const safeEmail  = (session.email || '').replace(/[<>"'&]/g, '');
  const photoUrl   = session.profileImage || null;
  const imgStyle   = 'width:100%;height:100%;object-fit:cover;border-radius:50%;display:block;';

  // Role display
  const roleLabels = { admin: 'Administrator', technician: 'Technician', customer: 'Customer' };
  const roleLabel  = roleLabels[session.role] || 'Member';
  const roleMod    = session.role || 'customer';

  // Button content — photo or initials
  const btnInner = photoUrl
    ? `<img src="${photoUrl}" alt="${safeName}" style="${imgStyle}" />`
    : `<span class="header-avatar__initials" aria-hidden="true">${initials}</span>`;

  // Info-card photo/initials (larger)
  const cardPhoto = photoUrl
    ? `<img src="${photoUrl}" alt="${safeName}" style="${imgStyle}" />`
    : `<span class="header-avatar__card-initials">${initials}</span>`;

  const wrapper = document.createElement('div');
  wrapper.className = 'header-avatar';
  wrapper.setAttribute('data-header-avatar', '');
  wrapper.innerHTML = `
    <!-- Avatar Button -->
    <button class="header-avatar__btn" id="topbar-avatar" type="button"
      aria-haspopup="true" aria-expanded="false"
      aria-label="Account menu for ${safeName}">
      ${btnInner}
    </button>

    <!-- Dropdown -->
    <div class="header-avatar__dropdown" hidden role="menu" aria-label="Account menu">

      <!-- ── Account info card ── -->
      <div class="header-avatar__card">
        <div class="header-avatar__card-photo">${cardPhoto}</div>
        <div class="header-avatar__card-body">
          <p class="header-avatar__card-name">${safeName}</p>
          <p class="header-avatar__card-email" title="${safeEmail}">${safeEmail || '—'}</p>
          <span class="header-avatar__card-badge header-avatar__card-badge--${roleMod}">${roleLabel}</span>
        </div>
      </div>

      <div class="header-avatar__sep" role="separator"></div>

      <!-- ── My Dashboard ── -->
      <a class="header-avatar__item" href="${dashHref}" role="menuitem">
        <span class="header-avatar__item-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none"
               stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="3" width="7" height="7" rx="1"/>
            <rect x="14" y="3" width="7" height="7" rx="1"/>
            <rect x="3" y="14" width="7" height="7" rx="1"/>
            <rect x="14" y="14" width="7" height="7" rx="1"/>
          </svg>
        </span>
        <span class="header-avatar__item-label" data-i18n="nav_dashboard">My Dashboard</span>
        <span class="header-avatar__item-arrow" aria-hidden="true">
          <svg viewBox="0 0 24 24" width="12" height="12" fill="none"
               stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="9 18 15 12 9 6"/>
          </svg>
        </span>
      </a>

      <!-- ── Logout ── -->
      <button class="header-avatar__item header-avatar__item--logout"
        type="button" role="menuitem" data-logout>
        <span class="header-avatar__item-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none"
               stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
            <polyline points="16 17 21 12 16 7"/>
            <line x1="21" y1="12" x2="9" y2="12"/>
          </svg>
        </span>
        <span class="header-avatar__item-label" data-i18n="nav_logout">Logout</span>
      </button>
    </div>
  `;

  headerRight.appendChild(wrapper);

  const btn      = wrapper.querySelector('.header-avatar__btn');
  const dropdown = wrapper.querySelector('.header-avatar__dropdown');

  // Toggle
  btn.addEventListener('click', (e) => {
    e.stopPropagation();
    const isOpen = !dropdown.hidden;
    dropdown.hidden = isOpen;
    btn.setAttribute('aria-expanded', String(!isOpen));
  });

  // Close on outside click
  document.addEventListener('click', (e) => {
    if (!wrapper.contains(e.target)) {
      dropdown.hidden = true;
      btn.setAttribute('aria-expanded', 'false');
    }
  });

  // Close on Escape
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !dropdown.hidden) {
      dropdown.hidden = true;
      btn.setAttribute('aria-expanded', 'false');
      btn.focus();
    }
  });

  // Logout
  wrapper.querySelector('[data-logout]').addEventListener('click', () => {
    localStorage.removeItem('servio_session');
    localStorage.removeItem('servio_token');
    sessionStorage.removeItem('servio_session');
    window.location.href = './index.html';
  });
}

// .
