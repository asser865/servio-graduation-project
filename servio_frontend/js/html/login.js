/* ═══════════════════════════════════════════════════════════
   Login page logic — SERVIO
   ═══════════════════════════════════════════════════════════ */

import { initShowcaseAtmosphere } from '../components/showcase-atmosphere.js';

initShowcaseAtmosphere();

function getStoredAccount() {
  try {
    const raw = localStorage.getItem("servio_account");
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function setError(el, message) {
  if (!el) return;
  el.textContent = message;
  el.hidden = !message;
}

function isValidEmail(v) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(v || "").trim());
}

function initSignupRedirect() {
  const params = new URLSearchParams(window.location.search);
  const redirect = params.get("redirect");
  if (!redirect) return;

  const signupLink = document.querySelector('a[href*="signup.html"]');
  if (signupLink) {
    const originalHref = signupLink.getAttribute('href');
    if (originalHref.includes('redirect=')) return;
    const separator = originalHref.includes('?') ? '&' : '?';
    signupLink.setAttribute('href', originalHref + separator + 'redirect=' + encodeURIComponent(redirect));
  }
}

function routeToDashboard(role) {
  // Admins and Technicians are strictly isolated to their dashboards
  if (role === "admin") {
    window.location.href = "./admin-dashboard.html";
    return;
  }
  if (role === "technician") {
    window.location.href = "./technician-dashboard.html";
    return;
  }

  const params = new URLSearchParams(window.location.search);
  const redirect = params.get("redirect");

  if (redirect) {
    // Prevent redirecting back to signup or login pages after successful login
    const isAuthPage = redirect.includes('signup.html') || redirect.includes('login.html');
    
    // Basic validation to prevent (ensure it's local)
    if (!isAuthPage && (redirect.startsWith('./') || redirect.startsWith('/') || !redirect.includes('://'))) {
      window.location.href = decodeURIComponent(redirect);
      return;
    }
  }

  window.location.href = "./customer-dashboard.html";
}

/* ── Password show/hide toggle ─────────────────────────── */
function initPasswordToggles(root) {
  const toggles = root.querySelectorAll("[data-password-toggle]");

  toggles.forEach((btn) => {
    btn.addEventListener("click", () => {
      const wrap = btn.closest(".input-password-wrap");
      if (!wrap) return;
      const input = wrap.querySelector("input");
      if (!input) return;

      const isPassword = input.type === "password";
      input.type = isPassword ? "text" : "password";

      // Swap icons
      const showIcon = btn.querySelector(".password-toggle__show");
      const hideIcon = btn.querySelector(".password-toggle__hide");
      if (showIcon) showIcon.classList.toggle("u-display-none", isPassword);
      if (hideIcon) hideIcon.classList.toggle("u-display-none", !isPassword);

      btn.setAttribute("aria-label", isPassword ? "Hide password" : "Show password");
    });
  });
}

/* ── Remember me ───────────────────────────────────────── */
function initRememberMe() {
  const emailInput = document.querySelector("#login-email");
  const checkbox = document.querySelector("#remember-me");

  if (!emailInput || !checkbox) return;

  // Restore remembered email
  const remembered = localStorage.getItem("servio_remember_email");
  if (remembered) {
    emailInput.value = remembered;
    checkbox.checked = true;
  }

  // Save or clear on change
  checkbox.addEventListener("change", () => {
    if (!checkbox.checked) {
      localStorage.removeItem("servio_remember_email");
    }
  });

  return checkbox;
}

/* ── Main init ─────────────────────────────────────────── */
export function initLogin() {
  initSignupRedirect();
  const form = document.querySelector("[data-login-form]");
  if (!form) return;

  const errorEl = document.querySelector("[data-login-error]");

  // Init features
  initPasswordToggles(form);
  const rememberCheckbox = initRememberMe();

  // Helper for loading state
  function setLoading(loading) {
    const btn = form.querySelector("#login-submit");
    if (!btn) return;
    const spinner = btn.querySelector(".btn-login__spinner");
    
    if (loading) {
      btn.classList.add("btn-login--loading");
      if (spinner) spinner.hidden = false;
    } else {
      btn.classList.remove("btn-login--loading");
      if (spinner) spinner.hidden = true;
    }
  }

  // Form submit
  form.addEventListener("submit", (e) => {
    e.preventDefault();
    setError(errorEl, "");
    setLoading(true);

    const email = form.querySelector('input[name="email"]')?.value?.trim() || "";
    const password = form.querySelector('input[name="password"]')?.value || "";

    // Wrap the rest of the logic in a timeout to show the animation
    setTimeout(() => {
    // Hardcoded demo account shortcuts
    if (email === 'admin@servio.eg' && password === 'admin123') {
      localStorage.setItem('servio_session', JSON.stringify({ role: 'admin', email: 'admin@servio.eg', name: 'Admin' }));
      routeToDashboard('admin');
      return;
    }
    if (email === 'ahmed@test.com' && password === 'test1234') {
      localStorage.setItem('servio_session', JSON.stringify({ role: 'customer', email: 'ahmed@test.com', name: 'Ahmed Yasser' }));
      routeToDashboard('customer');
      return;
    }
    if (email === 'khaled@test.com' && password === 'test1234') {
      localStorage.setItem('servio_session', JSON.stringify({ role: 'technician', email: 'khaled@test.com', name: 'Khaled Mohamed' }));
      routeToDashboard('technician');
      return;
    }

    if (!isValidEmail(email)) {
      setLoading(false);
      return setError(errorEl, "Enter a valid email address.");
    }
    if (password.length < 8) {
      setLoading(false);
      return setError(errorEl, "Password must be at least 8 characters.");
    }

    // Remember email if checkbox is checked
    if (rememberCheckbox && rememberCheckbox.checked) {
      localStorage.setItem("servio_remember_email", email);
    } else {
      localStorage.removeItem("servio_remember_email");
    }

    // Detect role from stored account
    const acct = getStoredAccount();
    const role =
      acct && acct.email && acct.role && acct.email.toLowerCase() === email.toLowerCase()
        ? acct.role
        : "customer";

    // Block pending technicians from logging in
    if (role === 'technician' && acct?.status === 'pending') {
      setLoading(false);
      setError(errorEl, 'Your account is pending approval. Our team will notify you within 24 hours. Need help? Contact support@servio.eg');
      return;
    }

    const name = acct?.fullName || acct?.email || '';
    localStorage.setItem('servio_session', JSON.stringify({ role, email, name }));
    routeToDashboard(role);
    }, 1200); // 1.2s delay to show off the pretty animation
  });
}

initLogin();

// .
