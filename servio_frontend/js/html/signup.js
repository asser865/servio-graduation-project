/* ═══════════════════════════════════════════════════════════
   Signup page logic — SERVIO multi-step onboarding
   ═══════════════════════════════════════════════════════════ */

import { initShowcaseAtmosphere } from '../components/showcase-atmosphere.js';
import { register } from '../api/auth.js';
import { uploadPublicFile } from '../api/uploads.js';

initShowcaseAtmosphere();

const SKILLS = ['plumbing', 'electrical', 'painting', 'flooring', 'carpentry', 'cleaning', 'hvac', 'other'];

const SKILLS_DISPLAY = {
  plumbing:   'Plumbing',
  electrical: 'Electrical',
  painting:   'Painting',
  flooring:   'Flooring',
  carpentry:  'Carpentry',
  cleaning:   'Cleaning',
  hvac:       'HVAC',
  other:      'Other',
};

const SKILLS_AR = {
  plumbing:   "السباكة",
  electrical: "الكهرباء",
  painting:   "الدهانات",
  flooring:   "الأرضيات",
  carpentry:  "النجارة",
  cleaning:   "التنظيف",
  hvac:       "التكييف والتدفئة",
  other:      "أخرى",
};

function qs(sel, root = document) {
  return root.querySelector(sel);
}

const DRAFT_KEY = 'servio_signup_draft';

function saveDraft(form, state) {
  if (!form || !state) return;
  const fields = {};
  // Capture all inputs (except passwords/files for security/size)
  const inputs = qsa('input:not([type="file"]):not([type="password"]), select, textarea', form);
  inputs.forEach(input => {
    if (input.name) {
      if (input.type === 'checkbox' || input.type === 'radio') {
        if (input.checked) fields[input.name] = input.value;
      } else {
        fields[input.name] = input.value;
      }
    }
  });

  const draft = {
    role: state.role,
    idx: state.idx,
    skills: Array.from(state.skills),
    fields
  };
  localStorage.setItem(DRAFT_KEY, JSON.stringify(draft));
}

function loadDraft(form, state) {
  const raw = localStorage.getItem(DRAFT_KEY);
  if (!raw) return;
  try {
    const draft = JSON.parse(raw);
    if (!draft) return;
    
    // 1. Restore core state
    state.role = draft.role || "";
    state.skills = new Set(draft.skills || []);
    if (state.role) {
      state.flow = computeFlow(state.role);
    }

    // IMPORTANT: If the draft was saved at a step that requires file uploads
    // (tech-verification) or a success screen (tech-review / customer-finish),
    // discard the entire draft and start fresh. Browsers always clear file inputs
    // on page load, so restoring to those steps causes silent validation failures
    // that trap the user. Starting fresh is the safest and clearest UX.
    const fileOrSuccessSteps = ['tech-verification', 'tech-review', 'customer-finish'];
    const restoredStep = state.flow[draft.idx || 0];
    if (restoredStep && fileOrSuccessSteps.includes(restoredStep)) {
      localStorage.removeItem(DRAFT_KEY);
      state.idx = 0;
      state.role = '';
      state.flow = computeFlow('customer');
      state.skills = new Set();
      return; // exit loadDraft — start fresh
    }

    state.idx = draft.idx || 0;

    // 2. Restore form fields
    if (draft.fields) {
      Object.entries(draft.fields).forEach(([name, value]) => {
        const inputs = qsa(`[name="${name}"]`, form);
        inputs.forEach(input => {
          if (input.type === 'checkbox' || input.type === 'radio') {
            input.checked = input.value === value;
          } else {
            input.value = value;
          }
          // Dispatch input event so UI listeners (e.g. enabling buttons) fire
          input.dispatchEvent(new Event('input', { bubbles: true }));
        });
      });
    }
  } catch (e) {
    console.warn("Failed to load signup draft", e);
  }
}

function clearDraft() {
  localStorage.removeItem(DRAFT_KEY);
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
  const redirectUrl = params.get("redirect");

  const authPages = ['login.html', 'signup.html'];
  const isRedirectToAuth = authPages.some(p => redirectUrl && redirectUrl.includes(p));

  // 1. If we have a valid non-auth redirect URL, go there
  if (redirectUrl && !isRedirectToAuth) {
    if (redirectUrl.startsWith('./') || redirectUrl.startsWith('/')) {
      window.location.href = redirectUrl;
      return;
    }
  }

  // 2. Otherwise go to role-specific dashboard
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
    btn.textContent = isAr ? (SKILLS_AR[skill] || skill) : (SKILLS_DISPLAY[skill] || skill);
    btn.addEventListener("click", () => {
      if (selected.has(skill)) selected.delete(skill);
      else selected.add(skill);
      renderSkills(form, selected, qs("#skills-search", form)?.value || "");
      form.dispatchEvent(new Event('input', { bubbles: true }));
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
    btn.addEventListener("click", () => {
      set(btn.dataset.availability);
      // Trigger save on interaction
      btn.dispatchEvent(new Event('input', { bubbles: true }));
    });
  });

  set(hidden?.value || "");
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
    card.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        setRole(card.dataset.role);
        saveDraft(form, state);
      }
    });

    card.addEventListener("click", () => {
      setRole(card.dataset.role);
      saveDraft(form, state);
    });
  });

  if (state.role) setRole(state.role);
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
    // OTP verification bypassed — SMS gateway not integrated yet
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

    const photoInput = qs('input[name="profilePhoto"]', form);
    if (!photoInput?.files?.length) {
      setError(form, 'doc-avatar',
        typeof window.t === 'function'
          ? window.t('signup_photo_required')
          : 'Profile photo is required.');
      const preview = qs('#signup-avatar-preview', form);
      if (preview) preview.classList.add('is-required');
      valid = false;
    } else {
      setError(form, 'doc-avatar', '');
    }

    const markCard = (name, isError) => {
      const card = qs(`[data-vdoc="${name}"]`, form);
      if (card) card.classList.toggle('is-error', isError);
    };

    const idFront = qs('input[name="idFront"]', form);
    const idBack  = qs('input[name="idBack"]', form);
    const selfie  = qs('input[name="idSelfie"]', form);
    const cv      = qs('input[name="cvFile"]', form);

    if (!idFront?.files?.length) {
      setError(form, "doc-idfront", "National ID front photo is required.");
      markCard("idFront", true);
      valid = false;
    } else {
      setError(form, "doc-idfront", "");
      markCard("idFront", false);
    }

    if (!idBack?.files?.length) {
      setError(form, "doc-idback", "National ID back photo is required.");
      markCard("idBack", true);
      valid = false;
    } else {
      setError(form, "doc-idback", "");
      markCard("idBack", false);
    }

    if (!selfie?.files?.length) {
      setError(form, "doc-selfie", "A selfie holding your ID is required.");
      markCard("idSelfie", true);
      valid = false;
    } else {
      setError(form, "doc-selfie", "");
      markCard("idSelfie", false);
    }

    if (cv?.files?.[0]) {
      const allowedCvTypes = [
        "application/pdf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      ];
      if (!allowedCvTypes.includes(cv.files[0].type)) {
        setError(form, "doc-cv", "CV must be a PDF, DOC, or DOCX file.");
        markCard("cvFile", true);
        valid = false;
      } else {
        setError(form, "doc-cv", "");
        markCard("cvFile", false);
      }
    } else {
      setError(form, "doc-cv", "");
      markCard("cvFile", false);
    }

    return valid;
  }

  return true;
}

/* ── Profile photo preview (signup) ───────────────────── */
function initProfilePhotoPreview(form) {
  const btn     = qs('#btn-signup-photo', form);
  const input   = qs('#signup-photo-input', form);
  const preview = qs('#signup-avatar-preview', form);
  const card    = qs('#signup-avatar-field', form);
  if (!btn || !input || !preview) return;

  btn.addEventListener('click', () => input.click());

  input.addEventListener('change', () => {
    const file = input.files[0];
    setError(form, 'doc-avatar', '');
    if (!file) return;

    if (file.size > 2 * 1024 * 1024) {
      setError(form, 'doc-avatar',
        typeof window.t === 'function'
          ? window.t('signup_photo_hint')
          : 'Image must be under 2 MB.');
      input.value = '';
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      preview.innerHTML = `<img src="${e.target.result}" alt="Profile photo" />`;
      preview.classList.add('has-photo');
      preview.classList.remove('is-required');
      card?.classList.add('has-photo');
      card?.classList.remove('is-required');
    };
    reader.readAsDataURL(file);
  });
}

/* ── Document upload cards ─────────────────────────────── */
function initDocUploadCards(form) {
  const IMAGE_KINDS = ['idFront', 'idBack', 'idSelfie', 'portfolio'];

  qsa('[data-vdoc-trigger]', form).forEach(btn => {
    const name  = btn.dataset.vdocTrigger;
    const input = qs(`input[name="${name}"]`, form);
    const card  = btn.closest('[data-vdoc]');
    const thumb = qs(`#vthumb-${name}`, form);
    if (!input || !card) return;

    btn.addEventListener('click', () => input.click());

    input.addEventListener('change', () => {
      const file = input.files[0];
      if (!file) return;

      card.classList.add('is-filled');
      card.classList.remove('is-error');

      // Show image thumbnail for photo uploads
      if (thumb && IMAGE_KINDS.includes(name) && file.type.startsWith('image/')) {
        const reader = new FileReader();
        reader.onload = (e) => {
          thumb.innerHTML = `<img src="${e.target.result}" alt="${name}" />`;
        };
        reader.readAsDataURL(file);
      }

      // Show filename for CV
      if (thumb && name === 'cvFile') {
        const short = file.name.length > 18 ? file.name.slice(0, 15) + '…' : file.name;
        const hint  = qs('.vdoc-card__hint', card);
        if (hint) hint.textContent = short;
      }

      // Portfolio: update hint with count
      if (name === 'portfolio') {
        const count = input.files.length;
        const hint  = qs('.vdoc-card__hint', card);
        if (hint) hint.textContent = `${count} photo${count !== 1 ? 's' : ''} selected`;
      }
    });
  });
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
    skills:           new Set(),
    signupOtpExpected: "",
  };

  loadDraft(form, state);

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

    saveDraft(form, state);

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

  const persistTechnicianAccount = async () => {
    const profilePhotoInput = qs('input[name="profilePhoto"]', form);
    const idFrontInput      = qs('input[name="idFront"]', form);
    const idBackInput       = qs('input[name="idBack"]', form);
    const idSelfieInput     = qs('input[name="idSelfie"]', form);
    const cvInput           = qs('input[name="cvFile"]', form);
    const portfolioInput    = qs('input[name="portfolio"]', form);

    const [avatarUpload, idFrontUpload, idBackUpload, idSelfieUpload, cvUpload, portfolioUploads] = await Promise.all([
      uploadPublicFile(profilePhotoInput?.files?.[0], 'avatar'),
      uploadPublicFile(idFrontInput?.files?.[0], 'idFront'),
      uploadPublicFile(idBackInput?.files?.[0], 'idBack'),
      uploadPublicFile(idSelfieInput?.files?.[0], 'idSelfie'),
      cvInput?.files?.[0] ? uploadPublicFile(cvInput.files[0], 'cv') : Promise.resolve(null),
      Promise.all(Array.from(portfolioInput?.files || []).slice(0, 5).map(file => uploadPublicFile(file, 'portfolio'))),
    ]);

    const payload = {
      name:             qs('input[name="fullName"]', form)?.value?.trim() || "",
      email:            qs('input[name="email"]', form)?.value?.trim() || "",
      phone:            qs('input[name="phone"]', form)?.value?.trim() || "",
      password:         qs('input[name="password"]', form)?.value || "",
      role:             "worker",
      skills:           Array.from(state.skills),
      locationLabel:    qs('input[name="serviceArea"]', form)?.value?.trim() || "",
      hourlyRate:       Number(qs('input[name="hourlyRate"]', form)?.value) || 0,
      bio:              qs('textarea[name="bio"]', form)?.value?.trim() || "",
      yearsExperience:  Number(qs('input[name="yearsExperience"]', form)?.value) || 0,
      availabilityType: qs('input[name="availability"]', form)?.value || "",
      profileImage:     avatarUpload?.url || "",
      idFrontUrl:       idFrontUpload?.url || "",
      idFrontName:      idFrontUpload?.name || "",
      idBackUrl:        idBackUpload?.url || "",
      idBackName:       idBackUpload?.name || "",
      idSelfieUrl:      idSelfieUpload?.url || "",
      idSelfieName:     idSelfieUpload?.name || "",
      cvUrl:            cvUpload?.url || "",
      cvName:           cvUpload?.name || "",
      portfolioFiles:   portfolioUploads.map(item => ({ url: item.url, name: item.name })),
    };

    return register(payload);
  };

  let _isSubmitting = false; // guard against double-submit

  const goNext = () => {
    if (_isSubmitting) return; // prevent double-click while async is running

    const currentKey = state.flow[state.idx];
    if (!validateCurrentStep(form, currentKey, state)) return;

    if (currentKey === "role") {
      state.flow = computeFlow(state.role);
    }

    const next = state.flow[state.idx + 1];
    if (!next) return;

    if (next === "tech-review") {
      // Find the submit button and show loading state
      const submitBtn = qs('[data-next]', form);
      if (submitBtn) {
        submitBtn.disabled = true;
        const btnSpan = submitBtn.querySelector('span');
        if (btnSpan) btnSpan.textContent = 'Submitting...';
      }
      _isSubmitting = true;

      persistTechnicianAccount()
        .then((data) => {
          try {
            localStorage.setItem('servio_account', JSON.stringify({
              role:                        'technician',
              status:                      data?.verificationStatus || 'pending',
              name:                        data?.name  || '',
              fullName:                    data?.name  || '',
              email:                       data?.email || '',
              phone:                       data?.phone || '',
              skills:                      data?.skills || [],
              specialty:                   (data?.skills || []).join(', '),
              hourlyRate:                  data?.hourlyRate || '',
              serviceArea:                 data?.locationLabel || '',
              verificationStatus:          data?.verificationStatus || 'pending',
              verificationRejectionReason: data?.verificationRejectionReason || '',
              uploadedDocs: {
                idFront:  { uploaded: !!(data?.idFrontUrl),  name: data?.idFrontName  || '', url: data?.idFrontUrl  || '' },
                idBack:   { uploaded: !!(data?.idBackUrl),   name: data?.idBackName   || '', url: data?.idBackUrl   || '' },
                idSelfie: { uploaded: !!(data?.idSelfieUrl), name: data?.idSelfieName || '', url: data?.idSelfieUrl || '' },
                cvFile:   { uploaded: !!(data?.cvUrl),       name: data?.cvName       || '', url: data?.cvUrl       || '' },
                portfolio: {
                  uploaded: !!(data?.portfolioFiles?.length),
                  count:    data?.portfolioFiles?.length || 0,
                  files:    data?.portfolioFiles || [],
                },
              },
            }));
            // Open the verification tab on the dashboard so the user
            // lands directly on the "Under Review" pending screen
            localStorage.setItem('servio_activeTab_technician', 'verification');
          } catch (_) {}

          clearDraft();
          // Go directly to dashboard — bypasses the in-form step which was
          // unreliable inside an async .then() chain, and avoids the
          // ?redirect= param in routeToDashboard sending them to the wrong page
          window.location.href = './technician-dashboard.html';
        })
        .catch((err) => {
          // Re-enable submit button on failure so user can retry
          const submitBtn = qs('[data-next]', form);
          if (submitBtn) {
            submitBtn.disabled = false;
            const btnSpan = submitBtn.querySelector('span');
            if (btnSpan) {
              btnSpan.textContent =
                (typeof window.t === 'function')
                  ? window.t('signup_submit_app')
                  : 'Submit application';
            }
          }
          _isSubmitting = false;

          // Show error on the page
          const errEl = qs('[data-error-for="tech-verification"]', form) || qs('[data-error-for="email"]', form);
          if (errEl) {
            const fieldErrors = err?.data?.errors;
            const detail = fieldErrors?.length
              ? fieldErrors.map(e => e.message).join(' ')
              : err.message || 'Registration failed. Please try again.';
            errEl.textContent = detail;
            errEl.hidden = false;
            // Scroll error into view
            errEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
          }
        });
      return;
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
  initProfilePhotoPreview(form);
  initDocUploadCards(form);
  initPortfolioPreview(form);
  renderSkills(form, state.skills, "");

  // Auto-save on any form input
  form.addEventListener('input', (e) => {
    // Avoid saving passwords if they happen to trigger input (mostly they shouldn't in our logic)
    if (e.target.type === 'password' || e.target.type === 'file') return;
    saveDraft(form, state);
  });

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
      if (finishCustomer.disabled) return;
      const currentKey = state.flow[state.idx];
      if (!validateCurrentStep(form, currentKey, state)) return;

      finishCustomer.disabled = true;
      const payload = {
        name: qs('input[name="fullName"]', form)?.value?.trim() || "",
        email: qs('input[name="email"]', form)?.value?.trim() || "",
        phone: qs('input[name="phone"]', form)?.value?.trim() || "",
        address: {
          street: qs('input[name="addressStreet"]', form)?.value?.trim() || "",
          city: qs('input[name="addressCity"]', form)?.value?.trim() || "",
          state: qs('input[name="addressState"]', form)?.value?.trim() || "",
          zipCode: qs('input[name="addressZip"]', form)?.value?.trim() || "",
        },
        password: qs('input[name="password"]', form)?.value || "",
        role: "customer",
      };

      register(payload)
        .then((data) => {
          // register() already calls saveSession(), but we'll ensure the mapped user is saved here too
          // data here is the user object returned by register()
          const mappedRole = mapRoleFromBackend(data.role || "user");
          
          localStorage.setItem('servio_session', JSON.stringify({
            id:    data._id || data.id,
            name:  data.name,
            email: data.email,
            role:  mappedRole,
            profileImage: data.profileImage || '',
          }));

          clearDraft();
          localStorage.removeItem('servio_account');
          routeToDashboard(mappedRole);
        })
        .catch((err) => {
          finishCustomer.disabled = false;
          const errEl = qs('[data-error-for="customer-finish"]', form) || qs('[data-error-for="email"]', form);
          if (errEl) { errEl.textContent = err.message || "Registration failed. Please try again."; errEl.hidden = false; }
        });
    });
  }

  // Technician "Back to Home" — go to dashboard so pending gate can show
  const gotIt = qs("[data-got-it]", form);
  if (gotIt) {
    gotIt.addEventListener('click', () => {
      window.location.href = './technician-dashboard.html';
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
  showStep(state.flow[state.idx] || state.flow[0]);
}

initSignup();


