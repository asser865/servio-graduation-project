/* ═══════════════════════════════════════════════════════════
   Login page logic — SERVIO
   ═══════════════════════════════════════════════════════════ */

/* ── Showcase background atmosphere ────────────────────── */
function initShowcaseAtmosphere() {
  const showcase = document.querySelector('.auth-showcase');
  if (!showcase) return;

  // Extra blobs
  ['c', 'd'].forEach(id => {
    const blob = document.createElement('div');
    blob.className = `auth-blob-${id}`;
    blob.setAttribute('aria-hidden', 'true');
    showcase.appendChild(blob);
  });

  // Floating ember particles
  const emberDefs = [
    { x: '10%', dur: '9s',    delay: '0s',    drift: '16px'  },
    { x: '23%', dur: '13s',   delay: '1.6s',  drift: '-22px' },
    { x: '36%', dur: '10s',   delay: '3.2s',  drift: '26px'  },
    { x: '50%', dur: '15s',   delay: '0.8s',  drift: '-12px' },
    { x: '63%', dur: '11s',   delay: '4.8s',  drift: '20px'  },
    { x: '75%', dur: '8.5s',  delay: '2.2s',  drift: '-28px' },
    { x: '87%', dur: '14s',   delay: '5.4s',  drift: '14px'  },
    { x: '18%', dur: '12s',   delay: '6.5s',  drift: '-18px' },
    { x: '44%', dur: '9.5s',  delay: '7.2s',  drift: '24px'  },
    { x: '70%', dur: '11.5s', delay: '3.8s',  drift: '-15px' },
  ];
  emberDefs.forEach(({ x, dur, delay, drift }) => {
    const p = document.createElement('div');
    p.className = 'auth-particle';
    p.setAttribute('aria-hidden', 'true');
    p.style.setProperty('--x', x);
    p.style.setProperty('--dur', dur);
    p.style.setProperty('--delay', delay);
    p.style.setProperty('--drift', drift);
    showcase.appendChild(p);
  });

  // ── Canvas flow field ───────────────────────────────────
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  const canvas = showcase.querySelector('.auth-showcase__canvas');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  const N = 320;
  const COLS = 32, ROWS = 20;
  let W, H, t = 0, mouse = { x: -999, y: -999 };

  function fieldNoise(x, y, t) {
    return Math.sin(x * 0.8 + t * 0.6) * Math.cos(y * 0.9 - t * 0.4)
         + 0.5  * Math.sin(x * 1.5 - y * 1.1 + t * 0.9)
         + 0.25 * Math.cos(x * 2.3 + y * 1.8 + t * 0.5);
  }

  class FlowParticle {
    constructor() { this.reset(); }
    reset() {
      this.x     = Math.random() * W;
      this.y     = Math.random() * H;
      this.vx    = 0;
      this.vy    = 0;
      this.life  = Math.random() * 180 + 60;
      this.age   = 0;
      this.speed = Math.random() * 0.55 + 0.22;
      this.r     = Math.random() * 1.2 + 0.4;
      const f    = Math.random();
      this.col   = [210 + (185 - 210) * f | 0, 162 + (140 - 162) * f | 0, 80 + (55 - 80) * f | 0];
    }
    update() {
      const col   = Math.floor(this.x / W * COLS);
      const row   = Math.floor(this.y / H * ROWS);
      const angle = fieldNoise(col * 0.18, row * 0.18, t) * Math.PI * 2.2;
      const mdx   = this.x - mouse.x;
      const mdy   = this.y - mouse.y;
      const md    = Math.sqrt(mdx * mdx + mdy * mdy);
      const mf    = md < 100 ? (100 - md) / 100 * 2 : 0;
      this.vx    += Math.cos(angle) * 0.03 * this.speed + mdx / (md + 1) * mf * 0.2;
      this.vy    += Math.sin(angle) * 0.03 * this.speed + mdy / (md + 1) * mf * 0.2;
      this.vx    *= 0.92;
      this.vy    *= 0.92;
      this.x     += this.vx;
      this.y     += this.vy;
      this.age++;
      if (this.x < 0 || this.x > W || this.y < 0 || this.y > H || this.age > this.life) this.reset();
    }
    draw() {
      const alpha = Math.min(1, this.age / 20) * Math.min(1, (this.life - this.age) / 20) * 0.65;
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.r, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${this.col}, ${alpha})`;
      ctx.fill();
    }
  }

  let particles = [];

  function resize() {
    const rect = showcase.getBoundingClientRect();
    W = canvas.width  = rect.width;
    H = canvas.height = rect.height;
    particles = Array.from({ length: N }, () => new FlowParticle());
  }

  function loop() {
    ctx.fillStyle = 'rgba(16,8,6,0.18)';
    ctx.fillRect(0, 0, W, H);
    t += 0.0018;
    particles.forEach(p => { p.update(); p.draw(); });
    requestAnimationFrame(loop);
  }

  showcase.addEventListener('mousemove', e => {
    const r = canvas.getBoundingClientRect();
    mouse = { x: e.clientX - r.left, y: e.clientY - r.top };
  });
  showcase.addEventListener('mouseleave', () => { mouse = { x: -999, y: -999 }; });

  window.addEventListener('resize', resize);
  resize();
  loop();
}

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
