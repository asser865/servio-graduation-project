import { initNavbar } from "./components/navbar.js";
import { initAuthHeader } from "./components/auth-header.js";
import { initNotifBell } from "./components/notif-bell.js";
import { initNotifWatcher } from './components/notif-watcher.js';
import { initChatWidget } from "./components/chat-widget.js";
import { initScrollReveal } from "./components/scroll-reveal.js";
import { initScrollEffects } from "./components/scroll-effects.js";
import { initSplashLoader } from "./components/splash-loader.js";
import { initThemeToggle } from "./components/theme-toggle.js";
import { initFooterAnimation } from "./components/footer-animation.js";
import { initPreviewMode } from "./components/preview-mode.js";
import { initBackToTop } from "./components/back-to-top.js";

// ── Role Boundary Enforcement ──────────────────────────────
(function enforceRoleBoundaries() {
  let session;
  try {
    session = JSON.parse(localStorage.getItem('servio_session') || 'null');
  } catch {
    localStorage.removeItem('servio_session');
    localStorage.removeItem('servio_token');
    return;
  }
  if (!session) {
    localStorage.removeItem('servio_token');
    return;
  }

  // Allow Admins to bypass guards if they explicitly requested Preview Mode
  if (session.role === 'admin' && localStorage.getItem('servio_preview_mode') === 'true') return;

  const path = window.location.pathname.toLowerCase();
  
  const isAdminPage = path.includes('admin-dashboard');
  const isTechPage  = path.includes('technician-dashboard');
  const isCustPage  = path.includes('customer-dashboard');
  const isAuthPage  = path.includes('login.html') || path.includes('signup.html')
                   || path.includes('forgot-password.html') || path.includes('reset-password.html');

  // Technician previewing their own public profile (read-only)
  const isTechProfilePreview = path.includes('technician-profile')
    && new URLSearchParams(window.location.search).get('preview') === '1';

  if (isAuthPage) return;

  // 1. Admin: Strictly isolated to Admin Dashboard
  if (session.role === 'admin' && !isAdminPage) {
    window.location.href = './admin-dashboard.html';
    return;
  }

  // 2. Technician: Strictly isolated to Technician Dashboard
  //    Exception: allowed to view their own public profile with preview=1
  if (session.role === 'technician' && !isTechPage && !isTechProfilePreview) {
    window.location.href = './technician-dashboard.html';
    return;
  }

  // 3. Customer: Restricted from Admin/Technician screens
  if (session.role === 'customer' && (isAdminPage || isTechPage)) {
    window.location.href = './customer-dashboard.html';
    return;
  }
})();

initPreviewMode();
initThemeToggle();
initSplashLoader();
const isAuthPage = document.body.classList.contains('auth-page');

if (!isAuthPage) {
  initNavbar();
  initAuthHeader();
  initNotifBell();
  initNotifWatcher();
  initChatWidget();
  initScrollReveal();
  initScrollEffects();
  initFooterAnimation();
  initBackToTop();
}

// .
