import { initShowcaseAtmosphere } from '../components/showcase-atmosphere.js';
import { forgotPassword } from '../api/auth.js';

initShowcaseAtmosphere();

function setError(msg) {
  const el = document.getElementById('forgot-error');
  if (!el) return;
  el.textContent = msg;
  el.hidden = !msg;
}

function setSuccess(msg) {
  const el = document.getElementById('forgot-success');
  if (!el) return;
  el.textContent = msg;
  el.hidden = !msg;
}

function setLoading(loading) {
  const btn = document.getElementById('forgot-submit');
  if (!btn) return;
  const spinner = btn.querySelector('.btn-login__spinner');
  btn.classList.toggle('btn-login--loading', loading);
  if (spinner) spinner.hidden = !loading;
}

function isValidEmail(v) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(v || '').trim());
}



const form = document.getElementById('forgot-form');
if (form) {
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');


    const email = form.querySelector('input[name="email"]')?.value?.trim() || '';

    if (!isValidEmail(email)) {
      return setError('Please enter a valid email address.');
    }

    setLoading(true);
    try {
      const res = await forgotPassword(email);
      setSuccess(res.message || 'If that email is registered you will receive a reset link shortly.');



      form.reset();
    } catch (err) {
      setError(err.message || 'Something went wrong. Please try again.');
    } finally {
      setLoading(false);
    }
  });
}
