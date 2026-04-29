import { initShowcaseAtmosphere } from '../components/showcase-atmosphere.js';
import { resetPassword } from '../api/auth.js';

initShowcaseAtmosphere();

const token = new URLSearchParams(window.location.search).get('token');

// Show invalid-token UI if no token in URL
if (!token) {
  document.getElementById('reset-form').hidden    = true;
  document.getElementById('reset-invalid').hidden = false;
}

function setError(msg) {
  const el = document.getElementById('reset-error');
  if (!el) return;
  el.textContent = msg;
  el.hidden = !msg;
}

function setLoading(loading) {
  const btn = document.getElementById('reset-submit');
  if (!btn) return;
  const spinner = btn.querySelector('.btn-login__spinner');
  btn.classList.toggle('btn-login--loading', loading);
  if (spinner) spinner.hidden = !loading;
}

function initPasswordToggles() {
  document.querySelectorAll('[data-password-toggle]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const wrap  = btn.closest('.input-password-wrap');
      const input = wrap?.querySelector('input');
      if (!input) return;
      const isPassword = input.type === 'password';
      input.type = isPassword ? 'text' : 'password';
      btn.querySelector('.password-toggle__show')?.classList.toggle('u-display-none', isPassword);
      btn.querySelector('.password-toggle__hide')?.classList.toggle('u-display-none', !isPassword);
      btn.setAttribute('aria-label', isPassword ? 'Hide password' : 'Show password');
    });
  });
}
initPasswordToggles();

function routeToDashboard(role) {
  const routes = { admin: './admin-dashboard.html', technician: './technician-dashboard.html' };
  window.location.href = routes[role] || './customer-dashboard.html';
}

const form = document.getElementById('reset-form');
if (form && token) {
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    setError('');

    const password = form.querySelector('input[name="password"]')?.value || '';
    const confirm  = form.querySelector('input[name="confirm"]')?.value  || '';

    if (password.length < 8) {
      return setError('Password must be at least 8 characters.');
    }
    if (!/\d/.test(password)) {
      return setError('Password must contain at least one number.');
    }
    if (password !== confirm) {
      return setError('Passwords do not match.');
    }

    setLoading(true);
    try {
      const res = await resetPassword(token, password);

      // Save session so the user is logged in immediately after reset
      if (res.data?.token && res.data?.user) {
        const { saveSession, mapRoleFromBackend } = await import('../api/client.js');
        const user = { ...res.data.user, role: mapRoleFromBackend(res.data.user.role) };
        saveSession(res.data.token, user);
        routeToDashboard(user.role);
      } else {
        window.location.href = './login.html';
      }
    } catch (err) {
      setLoading(false);
      if (err.status === 400) {
        // Show invalid-token UI for expired/used tokens
        form.hidden = true;
        document.getElementById('reset-invalid').hidden = false;
      } else {
        setError(err.message || 'Something went wrong. Please try again.');
      }
    }
  });
}
