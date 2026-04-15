/* ═══════════════════════════════════════════════════════════
   auth-header.js — Sitewide logged-in header state
   Reads servio_session; injects avatar + dropdown if logged in.
   ═══════════════════════════════════════════════════════════ */
import { getInitials } from '../utils/string.js';

function getSession() {
  try {
    return JSON.parse(localStorage.getItem('servio_session') || 'null');
  } catch {
    return null;
  }
}

function getDashboardHref(role) {
  if (role === 'technician') return './technician-dashboard.html';
  if (role === 'admin')      return './admin-dashboard.html';
  return './customer-dashboard.html';
}

/**
 * Find all Login links and append ?redirect=<currentUrl> 
 * so the user comes back here after logging in.
 */
function initLoginRedirects() {
  const currentPath = window.location.pathname;
  const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
  
  // Exclude auth pages from redirect pool to avoid circular flows
  if (currentPage.includes('login.html') || currentPage.includes('signup.html')) return;

  const encodedRedirect = encodeURIComponent('./' + currentPage + window.location.search);

  // Targets any link pointing to login.html
  document.querySelectorAll('a[href*="login.html"]').forEach(link => {
    const originalHref = link.getAttribute('href');
    if (originalHref.includes('redirect=')) return; // Avoid double appending
    
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

  // Hide existing Login / Sign Up buttons
  headerRight.querySelectorAll('.btn[href*="login"], .btn[href*="signup"]').forEach(el => {
    el.style.display = 'none';
  });

  // Build avatar dropdown
  const initials = getInitials(session.name);
  const dashHref = getDashboardHref(session.role);

  const wrapper = document.createElement('div');
  wrapper.className = 'header-avatar';
  wrapper.setAttribute('data-header-avatar', '');
  wrapper.innerHTML = `
    <button class="header-avatar__btn" type="button"
      aria-haspopup="true" aria-expanded="false"
      aria-label="Account menu for ${session.name || 'user'}">
      <span class="header-avatar__initials" aria-hidden="true">${initials}</span>
    </button>
    <div class="header-avatar__dropdown" hidden role="menu">
      <a class="header-avatar__item" href="${dashHref}" role="menuitem" data-i18n="nav_dashboard">${window.t('nav_dashboard')}</a>
      <button class="header-avatar__item header-avatar__item--logout"
        type="button" role="menuitem" data-logout data-i18n="nav_logout">${window.t('nav_logout')}</button>
    </div>
  `;

  headerRight.appendChild(wrapper);

  // Toggle dropdown
  const btn = wrapper.querySelector('.header-avatar__btn');
  const dropdown = wrapper.querySelector('.header-avatar__dropdown');

  btn.addEventListener('click', () => {
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

  // Logout
  wrapper.querySelector('[data-logout]').addEventListener('click', () => {
    localStorage.removeItem('servio_session');
    // Home lives in pages/ (same folder as other site pages), not project root
    window.location.href = './index.html';
  });
}

// .
