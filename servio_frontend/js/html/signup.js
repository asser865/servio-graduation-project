/* ═══════════════════════════════════════════════════════════
   Signup page logic — SERVIO multi-step onboarding
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

const SKILLS = [
  "Plumbing",
  "Electrical",
  "HVAC",
  "Painting",
  "Carpentry",
  "Cleaning",
  "Roofing",
  "Flooring",
  "Appliance Repair",
  "Landscaping",
  "General Maintenance",
];

const SKILLS_AR = {
  "Plumbing":             "السباكة",
  "Electrical":           "الكهرباء",
  "HVAC":                 "التكييف والتدفئة",
  "Painting":             "الدهانات",
  "Carpentry":            "النجارة",
  "Cleaning":             "التنظيف",
  "Roofing":              "الأسقف",
  "Flooring":             "الأرضيات",
  "Appliance Repair":     "إصلاح الأجهزة",
  "Landscaping":          "تنسيق الحدائق",
  "General Maintenance":  "الصيانة العامة",
};

function qs(sel, root = document) {
  return root.querySelector(sel);
}

function qsa(sel, root = document) {
  return Array.from(root.querySelectorAll(sel));
}

function setHidden(el, hidden) {
  if (!el) return;
  el.hidden = Boolean(hidden);
}

function setError(form, key, message) {
  const el = qs(`[data-error-for="${key}"]`, form);
  if (!el) return;
  el.textContent = message || "";
  el.hidden = !message;
}

function isValidEmail(v) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(v || "").trim());
}

function isValidPhone(v) {
  const cleaned = String(v || "").replace(/[^\d+]/g, "");
  return cleaned.length >= 9;
}

function routeToDashboard(role) {
  const params = new URLSearchParams(window.location.search);
  const redirect = params.get("redirect");

  if (redirect) {
    if (redirect.startsWith('./') || redirect.startsWith('/') || !redirect.includes('://')) {
      window.location.href = redirect;
      return;
    }
  }

  const next = role === "technician" ? "./technician-dashboard.html" : "./customer-dashboard.html";
  window.location.href = next;
}

function initLoginRedirect() {
  const params = new URLSearchParams(window.location.search);
  const redirect = params.get("redirect");
  if (!redirect) return;

  const loginLink = document.querySelector('a[href*="login.html"]');
  if (loginLink) {
    const originalHref = loginLink.getAttribute('href');
    if (originalHref.includes('redirect=')) return;
    const separator = originalHref.includes('?') ? '&' : '?';
    loginLink.setAttribute('href', originalHref + separator + 'redirect=' + encodeURIComponent(redirect));
  }
}

function isStrongPassword(v) {
  const s = String(v || "");
  if (s.length < 8) return false;
  const hasLetter = /[A-Za-z]/.test(s);
  const hasNumber = /\d/.test(s);
  return hasLetter && hasNumber;
}

function saveAccount(payload) {
  localStorage.setItem("servio_account", JSON.stringify(payload));
}

/* ── Flow computation ──────────────────────────────────── */
function computeFlow(role) {
  if (role === "technician") {
    return [
      "role",
      "basic",
      "otp",
      "tech-skills",
      "tech-availability",
      "tech-pricing",
      "tech-verification",
      "tech-review",
    ];
  }
  return ["role", "basic", "otp", "customer-finish"];
}

/* ── Progress bar ──────────────────────────────────────── */
function updateProgress({ labelEl, hintEl, fillEl }, idx, total) {
  if (labelEl) {
    labelEl.textContent = (typeof window.t === 'function') 
      ? window.t('signup_step_label', { n: idx + 1 }) 
      : `Step ${idx + 1}`;
  }
  if (hintEl) {
    hintEl.textContent = (typeof window.t === 'function') 
      ? window.t('signup_step_of', { n: total }) 
      : `of ${total}`;
  }
  if (fillEl) {
    fillEl.style.width = `${Math.round(((idx + 1) / total) * 100)}%`;
  }
}

/* ── Skills chips ──────────────────────────────────────── */
function renderSkills(form, selected, filter) {
  const chipsWrap = qs("[data-skills-chips]", form);
  if (!chipsWrap) return;
  chipsWrap.innerHTML = "";
  const query = String(filter || "").trim().toLowerCase();
  const items = SKILLS.filter((s) => (query ? s.toLowerCase().includes(query) : true));

  const isAr = document.documentElement.getAttribute("dir") === "rtl";
  items.forEach((skill) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = `chip${selected.has(skill) ? " is-selected" : ""}`;
    btn.textContent = isAr ? (SKILLS_AR[skill] || skill) : skill;
    btn.addEventListener("click", () => {
      if (selected.has(skill)) selected.delete(skill);
      else selected.add(skill);
      renderSkills(form, selected, qs("#skills-search", form)?.value || "");
    });
    chipsWrap.appendChild(btn);
  });
}

/* ── Availability toggles ─────────────────────────────── */
function initAvailabilityToggles(form) {
  const wrap = qs("[data-availability-toggles]", form);
  if (!wrap) return;
  const hidden = qs('input[name="availability"]', form);
  const buttons = qsa("[data-availability]", wrap);

  const set = (val) => {
    buttons.forEach((b) => b.classList.toggle("is-selected", b.dataset.availability === val));
    if (hidden) hidden.value = val || "";
  };

  buttons.forEach((btn) => {
    btn.addEventListener("click", () => set(btn.dataset.availability));
  });

  set("");
}

/* ── Role card selection ──────────────────────────────── */
function initRoleCards(form, state) {
  const cards = qsa("[data-role-card]", form);
  const nextBtn = qs("[data-next]", form);

  const setRole = (role) => {
    state.role = role;
    cards.forEach((c) => {
      const isSelected = c.dataset.role === role;
      c.classList.toggle("is-selected", isSelected);
      c.setAttribute("aria-checked", String(isSelected));
    });
    setError(form, "role", "");
    
    // Enable the continue button
    if (nextBtn) {
      nextBtn.disabled = false;
    }

    // Update data-role which is then used by goNext to compute the flow
    state.role = role;
  };

  cards.forEach((card) => {
    card.addEventListener("click", () => setRole(card.dataset.role));
    card.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        setRole(card.dataset.role);
      }
    });
  });
}

/* ── Password toggles ─────────────────────────────────── */
function maskPhoneForOtp(phone) {
  const d = String(phone || "").replace(/\D/g, "");
  if (d.length < 4) return "your number";
  return `•••• ${d.slice(-4)}`;
}

function initSignupOtp(form, state) {
  const input = qs('input[name="signupOtp"]', form);
  const resend = qs("[data-otp-resend]", form);
  const tip = qs("[data-otp-resend-tip]", form);

  if (input) {
    input.addEventListener("input", () => {
      input.value = input.value.replace(/\D/g, "").slice(0, 6);
      setError(form, "otp", "");
    });
  }

  if (resend) {
    resend.addEventListener("click", () => {
      setError(form, "otp", "");
      if (tip) {
        tip.hidden = false;
        tip.textContent = "Code re-sent. Check your messages.";
      }
      if (input) input.value = "";
      input?.focus();
    });
  }
}

function refreshOtpStepUI(form, state) {
  if (!state.signupOtpExpected) {
    state.signupOtpExpected = "123456";
  }
  const dest = qs("[data-otp-destination]", form);
  const phone = qs('input[name="phone"]', form)?.value || "";
  if (dest) {
    dest.textContent = maskPhoneForOtp(phone);
  }
  const tip = qs("[data-otp-resend-tip]", form);
  if (tip) tip.hidden = true;
  const input = qs('input[name="signupOtp"]', form);
  if (input) {
    input.value = "";
    requestAnimationFrame(() => input.focus());
  }
}

function initPasswordToggles(form) {
  const toggles = qsa("[data-password-toggle]", form);

  toggles.forEach((btn) => {
    btn.addEventListener("click", () => {
      const wrap = btn.closest(".input-password-wrap");
      if (!wrap) return;
      const input = wrap.querySelector("input");
      if (!input) return;

      const isPassword = input.type === "password";
      input.type = isPassword ? "text" : "password";

      const showIcon = btn.querySelector(".password-toggle__show");
      const hideIcon = btn.querySelector(".password-toggle__hide");
      if (showIcon) showIcon.classList.toggle("u-display-none", isPassword);
      if (hideIcon) hideIcon.classList.toggle("u-display-none", !isPassword);

      btn.setAttribute("aria-label", isPassword ? "Hide password" : "Show password");
    });
  });
}

/* ── Reset / Clear buttons ────────────────────────────── */
function initResetButtons(form) {
  form.addEventListener('click', (e) => {
    const btn = e.target.closest('.input-reset');
    if (!btn) return;

    const wrap = btn.closest('.input-icon-wrap') || btn.closest('.field');
    if (!wrap) return;

    const input = wrap.querySelector('input');
    if (!input) return;

    input.value = '';
    input.focus();
    // Dispatch input event to trigger validation and UI updates
    input.dispatchEvent(new Event('input', { bubbles: true }));
  });
}

/* ── Step validation ──────────────────────────────────── */
function validateCurrentStep(form, stepKey, state) {
  setError(form, stepKey, "");

  if (stepKey === "role") {
    if (!state.role) {
      setError(form, "role", "Please select Customer or Technician to continue.");
      return false;
    }
    return true;
  }

  if (stepKey === "basic") {
    const fullName = qs('input[name="fullName"]', form)?.value?.trim() || "";
    const email = qs('input[name="email"]', form)?.value?.trim() || "";
    const phone = qs('input[name="phone"]', form)?.value?.trim() || "";
    const password = qs('input[name="password"]', form)?.value || "";

    if (fullName.length < 2) return setError(form, "basic", "Full name is required."), false;
    if (!isValidEmail(email)) return setError(form, "basic", "Enter a valid email address."), false;
    if (!isValidPhone(phone)) return setError(form, "basic", "Enter a valid phone number."), false;
    if (!isStrongPassword(password)) {
      setError(form, "basic", "Password must be 8+ characters and include letters and numbers.");
      return false;
    }
    return true;
  }

  if (stepKey === "otp") {
    if (!state.signupOtpExpected) {
      state.signupOtpExpected = "123456";
    }
    const raw =
      qs('input[name="signupOtp"]', form)?.value?.trim().replace(/\s/g, "") || "";
    if (!/^\d{6}$/.test(raw)) {
      setError(form, "otp", "Enter the 6-digit verification code.");
      return false;
    }
    if (raw !== state.signupOtpExpected) {
      setError(form, "otp", "That code doesn't match. Try again or resend.");
      return false;
    }
    setError(form, "otp", "");
    return true;
  }

  if (stepKey === "customer-finish") return true;

  if (stepKey === "tech-skills") {
    if (!state.skills.size) {
      setError(form, "tech-skills", "Select at least one skill to continue.");
      return false;
    }
    return true;
  }

  if (stepKey === "tech-availability") {
    const area = qs('input[name="serviceArea"]', form)?.value?.trim() || "";
    const availability = qs('input[name="availability"]', form)?.value || "";
    if (!area) return setError(form, "tech-availability", "Service area is required."), false;
    if (!availability) return setError(form, "tech-availability", "Select Weekdays, Weekends, or Both."), false;
    return true;
  }

  if (stepKey === "tech-pricing") {
    const rateVal = qs('input[name="hourlyRate"]', form)?.value ?? "";
    const rate = Number(rateVal);
    if (rateVal === "" || isNaN(rate) || rate < 50 || rate > 2000) {
      setError(form, "tech-pricing", "Enter a valid hourly rate between 50 and 2000 EGP.");
      return false;
    }
    setError(form, "tech-pricing", "");
    return true;
  }

  if (stepKey === "tech-verification") {
    let valid = true;

    const idFront = qs('input[name="idFront"]', form);
    const idBack = qs('input[name="idBack"]', form);
    const selfie = qs('input[name="idSelfie"]', form);

    if (!idFront?.files?.length) {
      setError(form, "doc-idfront", "National ID front photo is required.");
      valid = false;
    } else {
      setError(form, "doc-idfront", "");
    }

    if (!idBack?.files?.length) {
      setError(form, "doc-idback", "National ID back photo is required.");
      valid = false;
    } else {
      setError(form, "doc-idback", "");
    }

    if (!selfie?.files?.length) {
      setError(form, "doc-selfie", "A selfie holding your ID is required.");
      valid = false;
    } else {
      setError(form, "doc-selfie", "");
    }

    return valid;
  }

  return true;
}

/* ── Portfolio preview ─────────────────────────────────── */
function initPortfolioPreview(form) {
  const input     = qs('[data-portfolio-input]', form);
  const container = qs('[data-portfolio-thumbs]', form);
  if (!input || !container) return;

  input.addEventListener('change', () => {
    const files = Array.from(input.files || []).slice(0, 5);
    container.innerHTML = '';
    if (!files.length) { container.hidden = true; return; }
    container.hidden = false;
    files.forEach(file => {
      const img = document.createElement('img');
      img.className = 'portfolio-thumb';
      img.alt = file.name;
      const url = URL.createObjectURL(file);
      img.src = url;
      img.onload = () => URL.revokeObjectURL(url);
      container.appendChild(img);
    });
    // Enforce 5-file limit
    if (input.files.length > 5) {
      const dt = new DataTransfer();
      files.forEach(f => dt.items.add(f));
      input.files = dt.files;
    }
  });
}

/* ═══════════════════════════════════════════════════════════
   Main init
   ═══════════════════════════════════════════════════════════ */
export function initSignup() {
  initLoginRedirect();
  const form = qs("[data-signup-form]");
  if (!form) return;

  const progress = {
    labelEl: qs("[data-progress-label]"),
    hintEl: qs("[data-progress-hint]"),
    fillEl: qs("[data-progress-fill]"),
  };

  const state = {
    role: "",
    flow: computeFlow("customer"),
    idx: 0,
    skills: new Set(),
    /** Demo OTP — SMS not wired; shown in UI hint */
    signupOtpExpected: "",
  };

  const stepSections = qsa("[data-step]", form);

  let isInitialLoad = true;

  const showStep = (key) => {
    stepSections.forEach((s) => setHidden(s, s.dataset.step !== key));
    const i = state.flow.indexOf(key);
    state.idx = i >= 0 ? i : 0;
    
    // Hide progress bar on step 1 (role selection) and success screens
    const isStepOne = key === "role";
    const isSuccess = key === "tech-review" || key === "customer-finish";
    const progressContainer = qs("#signupProgress");
    if (progressContainer) progressContainer.hidden = isStepOne || isSuccess;

    if (!isSuccess && !isStepOne) {
      const total = state.role === "technician" ? state.flow.length : state.flow.length - 1;
      updateProgress(progress, state.idx, total);
    }

    if (key === "otp") {
      refreshOtpStepUI(form, state);
    }

    const showIndicator = state.role && !isStepOne && !isSuccess;
    updateRoleIndicator(state.role, showIndicator);

    // On step transitions (but not initial load) scroll form panel to top
    if (!isInitialLoad) {
      const panel = document.querySelector(".auth-form-panel--signup");
      if (panel) panel.scrollTo({ top: 0, behavior: "smooth" });
    }
    isInitialLoad = false;
  };

  const updateRoleIndicator = (role, visible) => {
    const el = qs("[data-role-indicator]");
    if (!el) return;
    
    setHidden(el, !visible);
    if (!visible) return;

    const iconEl = qs("[data-role-icon]", el);
    if (iconEl) {
      const isTech = role === "technician";
      iconEl.innerHTML = isTech
        ? `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg>`
        : `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>`;
    }

    const textEl = qs("[data-i18n-role-text]", el);
    if (textEl) {
      const key = role === "technician" ? "signup_role_indicator_tech" : "signup_role_indicator_customer";
      textEl.textContent = (typeof window.t === 'function') 
        ? window.t(key) 
        : (role === "technician" ? "Signup as Technician" : "Signup as Customer");
      // Add data-i18n attribute for the language switcher
      textEl.setAttribute("data-i18n", key);
    }
  };

  const persistTechnicianAccount = () => {
    const payload = {
      role: "technician",
      fullName: qs('input[name="fullName"]', form)?.value?.trim() || "",
      email: qs('input[name="email"]', form)?.value?.trim() || "",
      phone: qs('input[name="phone"]', form)?.value?.trim() || "",
      skills: Array.from(state.skills),
      serviceArea: qs('input[name="serviceArea"]', form)?.value?.trim() || "",
      availability: qs('input[name="availability"]', form)?.value || "",
      currency: qs('select[name="currency"]', form)?.value || "EGP",
      hourlyRate: qs('input[name="hourlyRate"]', form)?.value || "",
      status: "pending",
    };
    saveAccount(payload);
    localStorage.setItem(
      "servio_session",
      JSON.stringify({
        role: "technician",
        email: payload.email,
        name: payload.fullName,
      }),
    );
  };

  const goNext = () => {
    const currentKey = state.flow[state.idx];
    if (!validateCurrentStep(form, currentKey, state)) return;

    if (currentKey === "role") {
      state.flow = computeFlow(state.role);
    }

    const next = state.flow[state.idx + 1];
    if (!next) return;

    if (next === "tech-review") {
      persistTechnicianAccount();
    }

    showStep(next);
  };

  const goBack = () => {
    const prev = state.flow[state.idx - 1];
    if (prev) showStep(prev);
  };

  // Init interactive components
  initRoleCards(form, state);
  initAvailabilityToggles(form);
  initPasswordToggles(form);
  initResetButtons(form);
  initSignupOtp(form, state);
  initPortfolioPreview(form);
  renderSkills(form, state.skills, "");

  // Skills search filter
  const search = qs("#skills-search", form);
  if (search) {
    search.addEventListener("input", () => renderSkills(form, state.skills, search.value));
  }

  // Re-render skill chips when language changes
  document.addEventListener("langchange", () => {
    const currentKey = state.flow[state.idx];
    const isStepOne = currentKey === "role";
    const isSuccess = currentKey === "tech-review" || currentKey === "customer-finish";
    
    const progressContainer = qs("#signupProgress");
    if (progressContainer) progressContainer.hidden = isStepOne || isSuccess;

    const total = state.role === "technician" ? state.flow.length : state.flow.length - 1;
    updateRoleIndicator(state.role, state.role && !isStepOne && !isSuccess);
    if (!isStepOne && !isSuccess) {
      updateProgress(progress, state.idx, total);
    }
    renderSkills(form, state.skills, search?.value || "");
  });

  // Navigation buttons
  qsa("[data-next]", form).forEach((btn) => btn.addEventListener("click", goNext));
  qsa("[data-back]", form).forEach((btn) => btn.addEventListener("click", goBack));

  // Customer finish
  const finishCustomer = qs("[data-finish-customer]", form);
  if (finishCustomer) {
    finishCustomer.addEventListener("click", () => {
      const currentKey = state.flow[state.idx];
      if (!validateCurrentStep(form, currentKey, state)) return;

      const payload = {
        role: "customer",
        fullName: qs('input[name="fullName"]', form)?.value?.trim() || "",
        email: qs('input[name="email"]', form)?.value?.trim() || "",
        phone: qs('input[name="phone"]', form)?.value?.trim() || "",
        address: qs('input[name="address"]', form)?.value?.trim() || "",
      };
      saveAccount(payload);
      localStorage.setItem('servio_session', JSON.stringify({
        role: 'customer',
        email: payload.email,
        name: payload.fullName
      }));
      routeToDashboard("customer");
    });
  }

  // Technician "Back to Home" after submission
  const gotIt = qs("[data-got-it]", form);
  if (gotIt) {
    gotIt.addEventListener('click', () => {
      window.location.href = './index.html';
    });
  }

  // Enter key navigation
  form.addEventListener("keydown", (e) => {
    if (e.key !== "Enter") return;
    const active = document.activeElement;
    if (active && active.tagName === "TEXTAREA") return;
    const stepKey = state.flow[state.idx];
    if (stepKey === "tech-review" || stepKey === "customer-finish") return;
    e.preventDefault();
    goNext();
  });

  // Show initial step
  showStep(state.flow[0]);
}

initSignup();

// .
