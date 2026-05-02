/* ═══════════════════════════════════════════════════════════
   Login page logic — SERVIO
   ═══════════════════════════════════════════════════════════ */

import { initShowcaseAtmosphere } from '../components/showcase-atmosphere.js';
import { login } from '../api/auth.js';

initShowcaseAtmosphere();

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
    if (!isAuthPage && (redirect.startsWith('./') || redirect.startsWith('/'))) {
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

    if (!isValidEmail(email)) {
      setLoading(false);
      return setError(errorEl, "Enter a valid email address.");
    }
    if (password.length < 8) {
      setLoading(false);
      return setError(errorEl, "Password must be at least 8 characters.");
    }

    if (rememberCheckbox && rememberCheckbox.checked) {
      localStorage.setItem("servio_remember_email", email);
    } else {
      localStorage.removeItem("servio_remember_email");
    }

    login(email, password)
      .then((user) => {
        if (user.role === 'technician' && user.verificationStatus === 'pending') {
          localStorage.setItem('servio_account', JSON.stringify({ verificationStatus: 'pending' }));
        } else {
          localStorage.removeItem('servio_account');
        }
        routeToDashboard(user.role);
      })
      .catch((err) => {
        setLoading(false);
        setError(errorEl, err.message || "Invalid email or password.");
      });
  });
}

initLogin();


