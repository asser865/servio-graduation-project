/* ═══════════════════════════════════════════════════════════
   customer-dashboard.js
   ═══════════════════════════════════════════════════════════ */
import { showToast } from '../components/toast.js';
import { revealAll } from '../components/scroll-reveal.js';
import { getInitials } from '../utils/string.js';
import { getMe, updateMe, updateEmail, deleteMe, updatePassword } from '../api/users.js';
import { clearSession } from '../api/client.js';
import { uploadPublicFile } from '../api/uploads.js';
import { getMyBookings, cancelBooking } from '../api/bookings.js';
// No customer-facing review fetch endpoint exists on backend


const TAB_KEY = 'servio_activeTab_customer';

// Holds the uploaded avatar URL between file-select and form-save
let _pendingPhotoUrl = null;

function getSession() {
  try {
    return JSON.parse(sessionStorage.getItem('servio_session') || localStorage.getItem('servio_session') || 'null');
  } catch { return null; }
}

// ── Auth Guard ──────────────────────────────────────────
const session = getSession();
const isPreview = localStorage.getItem('servio_preview_mode') === 'true';

if (!session) {
  window.location.href = './login.html';
} else if (session.role === 'admin' && !isPreview) {
  window.location.href = './admin-dashboard.html';
} else if (session.role === 'technician') {
  window.location.href = './technician-dashboard.html';
}

function getAccount() {
  try {
    return JSON.parse(localStorage.getItem('servio_account') || 'null');
  } catch { return null; }
}

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function getErrorMessage(err, fallback) {
  return err?.data?.errors?.[0]?.message
    || err?.data?.message
    || err?.message
    || fallback;
}

/* ── Tab switching ──────────────────────────────────────── */
function initTabs() {
  const tabs = document.querySelectorAll('[data-tab]');
  const panels = document.querySelectorAll('[data-panel]');
  const mobileTabs = document.querySelector('[data-mobile-tabs]');

  // Build mobile tab strip
  if (mobileTabs) {
    tabs.forEach(tab => {
      const btn = document.createElement('button');
      btn.className = 'dash-mobile-tab';
      btn.type = 'button';
      btn.textContent = tab.textContent.trim();
      btn.dataset.mobileTab = tab.dataset.tab;
      mobileTabs.appendChild(btn);
    });
  }

  function showTab(id) {
    tabs.forEach(t => {
      const active = t.dataset.tab === id;
      t.classList.toggle('is-active', active);
      t.setAttribute('aria-selected', String(active));
    });
    document.querySelectorAll('.dash-mobile-tab').forEach(t => {
      t.classList.toggle('is-active', t.dataset.mobileTab === id);
    });
    panels.forEach(p => {
      const active = p.dataset.panel === id;
      p.classList.toggle('is-active', active);
      p.hidden = !active;
      if (active) revealAll(p);
    });
    sessionStorage.setItem(TAB_KEY, id);
  }

  tabs.forEach(tab => tab.addEventListener('click', () => showTab(tab.dataset.tab)));
  document.querySelectorAll('.dash-mobile-tab').forEach(btn => {
    btn.addEventListener('click', () => showTab(btn.dataset.mobileTab));
  });

  // data-tab-link buttons (Quick Actions → Bookings, Favourites, etc.)
  document.querySelectorAll('[data-tab-link]').forEach(btn => {
    btn.addEventListener('click', () => showTab(btn.dataset.tabLink));
  });

  // Cancel booking with contextual confirmation
  document.querySelectorAll('[data-cancel-booking]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const bookingId = btn.dataset.cancelBooking;
      const type = btn.dataset.cancelType || 'confirmed';
      const msg =
        type === 'pending'
          ? (typeof window.t === 'function' ? window.t('confirm_withdraw') : 'Withdraw this pending request? You can submit a new booking anytime.')
          : (typeof window.t === 'function' ? window.t('confirm_cancel') : 'Cancel this confirmed visit? You may need to book a new slot if you still need the service.');
      if (!window.confirm(msg)) return;
      try {
        if (bookingId) await cancelBooking(bookingId);
        const card = btn.closest('.dash-card, .booking-card');
        if (card) {
          card.style.transition = 'opacity 0.3s, transform 0.3s';
          card.style.opacity = '0';
          card.style.transform = 'translateX(8px)';
          setTimeout(() => {
            card.remove();
            if (typeof window.applyBookingFilter === 'function') window.applyBookingFilter();
          }, 300);
        }
        showToast(typeof window.t === 'function'
          ? (type === 'pending' ? window.t('toast_request_withdrawn') : window.t('toast_booking_cancelled'))
          : (type === 'pending' ? 'Request withdrawn.' : 'Booking cancelled.'), 'info');
      } catch (err) {
        showToast(err.message || 'Failed to cancel booking', 'error');
      }
    });
  });

  // Restore saved tab
  const saved = sessionStorage.getItem(TAB_KEY) || 'overview';
  showTab(saved);
}

/* ── Populate profile info ──────────────────────────────── */
function populateProfile() {
  const session = getSession();
  const account = getAccount();
  if (!session) {
    const currentPath = window.location.pathname;
    const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
    const redirectParam = encodeURIComponent('./' + currentPage + window.location.search);
    window.location.href = './login.html?redirect=' + redirectParam;
    return;
  }

  const name = session.name || 'User';
  const initials = getInitials(name);

  document.querySelectorAll('[data-dash-initials]').forEach(el => { el.textContent = initials; });
  const nameEl = document.querySelector('[data-dash-name]');
  const emailEl = document.querySelector('[data-dash-email]');
  const welcomeEl = document.querySelector('[data-dash-welcome]');
  if (nameEl) {
    nameEl.textContent = name;
    nameEl.removeAttribute('data-i18n'); // real name set — prevent lang.js from re-translating to "Loading…"
  }
  if (emailEl) {
    const email = session.email || '';
    emailEl.textContent = email || '—';
  }
  const settingsEmailInput = document.getElementById('settings-email');
  if (settingsEmailInput) settingsEmailInput.value = session.email || '';
  const firstName = name.split(' ')[0];
  document.querySelectorAll('[data-dash-firstname]').forEach(el => {
    el.textContent = firstName;
    el.removeAttribute('data-i18n'); // real name set — prevent lang.js from re-translating to placeholder
  });
  if (welcomeEl) {
    welcomeEl.textContent = typeof window.t === 'function' ? window.t('cust_welcome_sub_text') : 'Your overview';
    welcomeEl.removeAttribute('data-i18n');
  }

  // Pre-fill settings form from account data
  if (account) {
    document.querySelectorAll('[data-settings-field]').forEach(f => {
      if (account[f.dataset.settingsField] != null) {
        f.value = account[f.dataset.settingsField];
      }
    });
  }

  // Render avatar — photo takes priority over initials
  function renderAvatar(photoUrl) {
    const preview  = document.querySelector('[data-avatar-preview]');
    const topbar   = document.getElementById('topbar-avatar');
    const imgStyle = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';
    if (preview) {
      preview.innerHTML = photoUrl
        ? `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`
        : `<span data-dash-initials>${initials}</span>`;
    }
    if (topbar) {
      topbar.innerHTML = photoUrl
        ? `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`
        : initials[0] || 'U';
    }
  }

  // Show photo from session immediately (no flash)
  renderAvatar(session.profileImage || null);

  // Enrich profile from real API
  getMe().then(res => {
    const user = res;
    if (!user) return;
    const apiInitials = getInitials(user.name || '');
    document.querySelectorAll('[data-dash-initials]').forEach(el => { el.textContent = apiInitials; });

    // Update avatar with server photo if available
    if (user.profileImage) {
      renderAvatar(user.profileImage);
      // Keep session in sync
      const s = getSession();
      if (s && s.profileImage !== user.profileImage) {
        s.profileImage = user.profileImage;
        localStorage.setItem('servio_session', JSON.stringify(s));
      }
    }

    document.querySelectorAll('[data-dash-name], [data-cust-name], [data-dash-firstname]').forEach(el => {
      if (el.dataset.dashFirstname !== undefined) {
        el.textContent = (user.name || '').split(' ')[0] || '—';
      } else {
        el.textContent = user.name || '—';
      }
      el.removeAttribute('data-i18n');
    });
    const apiName = user.name || '';
    document.querySelectorAll('[data-dash-email], [data-cust-email]').forEach(el => {
      el.textContent = user.email || '—';
      el.removeAttribute('data-i18n');
    });

    // Pre-fill settings fields
    window.__servio_profile_email = user.email || '';
    try {
      const storedAccount = getAccount() || {};
      const syncedAccount = {
        ...storedAccount,
        name: apiName,
        fullName: apiName,
        email: user.email || '',
        phone: user.phone || '',
      };
      delete syncedAccount.city;
      localStorage.setItem('servio_account', JSON.stringify(syncedAccount));
    } catch (_) {}

    const fieldsMap = { name: apiName, fullName: apiName, email: user.email || '', phone: user.phone || '' };
    Object.entries(fieldsMap).forEach(([key, val]) => {
      const f = document.querySelector(`[data-settings-field="${key}"], input[name="${key}"]`);
      if (f) f.value = val;
    });
    const settingsEmail = document.getElementById('settings-email');
    if (settingsEmail) settingsEmail.value = user.email || '';

    if (user.address) {
      const fullAddr = [user.address.street, user.address.city, user.address.state, user.address.zipCode].filter(Boolean).join(', ');
      const addrHomeVal = document.getElementById('addr-home-value');
      if (addrHomeVal && fullAddr) {
        addrHomeVal.textContent = fullAddr;
        addrHomeVal.removeAttribute('data-i18n');
      }
      
      const addrProfEl = document.getElementById('profile-address');
      if(addrProfEl && fullAddr){
          addrProfEl.textContent = fullAddr;
      }
      
      // We will also store the true object into a global so the edit form can access it
      window.__servio_user_address = user.address;
    }

    // Update session in localStorage with fresh data
    try {
      const sess = JSON.parse(localStorage.getItem('servio_session') || '{}');
      localStorage.setItem('servio_session', JSON.stringify({ ...sess, name: apiName, email: user.email }));
    } catch (_) {}
    updateProfileCompleteness();
    if (typeof window.__servio_refreshProfileEditState === 'function') {
      window.__servio_refreshProfileEditState();
    }
  }).catch((err) => {
    console.error('Failed to load profile:', err);
    showToast(getErrorMessage(err, 'Failed to load the latest profile details.'), 'error');
  });
}

/* ── Live bookings & reviews data from API ──────────────── */
async function loadBookingsData() {
  try {
    const res = await getMyBookings();
    const bookings = res.bookings || [];

    // Update stats
    const active = bookings.filter(b => ['pending','accepted','in_progress'].includes(b.status));
    const completed = bookings.filter(b => b.status === 'completed');
    const tEl = document.querySelector('[data-stat="total-bookings"]');
    const aEl = document.querySelector('[data-stat="active-bookings"]');
    if (tEl) tEl.textContent = String(bookings.length);
    if (aEl) aEl.textContent = String(active.length);

    // Render bookings into the active-bookings panel
    const activeRoot = document.getElementById('activeBookingsRoot') || document.querySelector('[data-panel="bookings"] .dash-card-list, [data-panel="bookings"] .bookings-list');
    if (activeRoot && bookings.length) {
      const _t = typeof window.t === 'function' ? window.t : k => k;
      const STATUS_MAP = { pending:'Booked', accepted:'Confirmed', in_progress:'In Progress', completed:'Complete', cancelled:'Cancelled' };
      activeRoot.innerHTML = bookings.slice(0, 20).map(b => {
        const status = STATUS_MAP[b.status] || b.status || 'Booked';
        const date = b.scheduledDate ? new Date(b.scheduledDate).toLocaleDateString('en-US', {weekday:'short', month:'short', day:'numeric'}) : '—';
        const workerName = b.worker?.name || '—';
        const svcTitle = b.service?.title || b.serviceId || 'Service';
        return `<div class="booking-card" data-booking-card data-booking-status="${b.status}">
          <div class="booking-card__header">
            <span class="booking-card__service">${svcTitle}</span>
            <span class="booking-card__status booking-card__status--${b.status}">${status}</span>
          </div>
          <div class="booking-card__meta">
            <span>${date}</span>
            <span>${workerName}</span>
          </div>
          <div class="booking-card__actions">
            <a class="btn btn--sm" href="./booking-details.html?id=${b._id}">View Details</a>
          </div>
        </div>`;
      }).join('');
    }

    // No endpoint exists to fetch a customer's submitted reviews — clear the panel
    const reviewRoot = document.querySelector('[data-panel="reviews"] .dash-card-list, [data-panel="reviews"] .reviews-list');
    if (reviewRoot) {
      reviewRoot.innerHTML = '<p class="empty-state">No reviews yet.</p>';
    }
  } catch (_) {}
}

/* ── Stats ──────────────────────────────────────────────── */
async function populateStats() {
  try {
    const res = await getMyBookings({ limit: 100 });
    const bookings = res.bookings || [];

    const total     = bookings.length;
    const active    = bookings.filter(b => ['pending','accepted','in_progress'].includes(b.status)).length;
    const completed = bookings.filter(b => b.status === 'completed').length;
    const totalSpent = bookings
      .filter(b => b.status === 'completed' && b.totalPrice)
      .reduce((sum, b) => sum + (b.totalPrice || 0), 0);

    const goalTotal = 5;
    const pct = Math.min(Math.round((completed / goalTotal) * 100), 100);

    const tEl = document.querySelector('[data-stat="total-bookings"]');
    const aEl = document.querySelector('[data-stat="active-bookings"]');
    if (tEl) tEl.textContent = total;
    if (aEl) aEl.textContent = active;

    const spentEl = document.querySelector('[data-stat="total-spent"]');
    if (spentEl) spentEl.textContent = totalSpent + ' EGP';

    const ctxE = document.querySelector('.dash-stat-card__context[data-i18n-html]');
    if (ctxE) {
      ctxE.setAttribute('data-i18n-pct', String(pct));
      if (window.applyLanguage && window.__lang) window.applyLanguage(window.__lang);
    }
    const barFill = document.querySelector('[data-stat-goal-bar="total"]');
    if (barFill) barFill.style.width = pct + '%';
  } catch {
    // silently fallback — stats not critical
  }
}

/* ── Time-aware welcome text ────────────────────────────── */
function updateWelcomeText() {
  const timeLabel = document.querySelector('.dash-welcome__time-label');
  if (timeLabel) {
    const hour = new Date().getHours();
    const greetingKey = hour < 12 ? 'greeting_morning' : hour < 17 ? 'greeting_afternoon' : 'greeting_evening';
    timeLabel.textContent = typeof window.t === 'function' ? window.t(greetingKey) : (hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening');
  }
  const subEl = document.querySelector('.dash-welcome__sub');
  if (subEl) {
    const activeCount = parseInt(document.querySelector('[data-stat="active-bookings"]')?.textContent, 10) || 0;
    if (typeof window.t === 'function') {
      subEl.textContent =
        activeCount === 0
          ? window.t('cust_no_visits')
          : activeCount === 1
            ? window.t('cust_one_booking')
            : window.t('cust_n_bookings', { n: activeCount });
    } else {
      subEl.textContent =
        activeCount === 0
          ? 'No visits in progress — book when you\'re ready.'
          : activeCount === 1
            ? 'You have 1 booking in progress; details are under Bookings.'
            : `You have ${activeCount} bookings in progress — see the Bookings tab for status.`;
    }
  }
}

/* ── Notifications: mark all read ──────────────────────── */
function initNotifications() {
  const markAllBtn = document.getElementById('mark-all-read');
  if (!markAllBtn) return;
  markAllBtn.addEventListener('click', () => {
    document.querySelectorAll('.notif-card--unread').forEach(el => el.classList.remove('notif-card--unread'));
    document.querySelectorAll('.notif-card-v2.is-unread').forEach(el => el.classList.remove('is-unread'));
    document.querySelectorAll('.notif-card__dot:not(.notif-card__dot--read)').forEach(el => {
      el.classList.add('notif-card__dot--read');
    });
    showToast(typeof window.t === 'function' ? window.t('toast_notif_read') : 'All notifications marked as read.', 'success');
  });
}

/* ── Settings: photo upload ─────────────────────────────── */
function initSettingsForm() {
  const photoUploadInput = document.getElementById('photo-upload-input');
  const changePhotoBtn   = document.getElementById('btn-change-photo');
  const preview          = document.querySelector('[data-avatar-preview]');
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  const form             = document.querySelector('[data-settings-form]');
  const editBtn          = document.getElementById('btn-profile-edit');
  const cancelBtn        = document.getElementById('btn-profile-cancel');
  const editActions      = form?.querySelector('[data-profile-edit-actions]');
  const editableFields   = form ? Array.from(form.querySelectorAll('[data-settings-field]')) : [];
  const emailInput       = document.getElementById('settings-email');
  const submitBtn        = form?.querySelector('button[type="submit"]');

  let isProfileEditing = false;
  let profileSnapshot = {};

  function setError(input, message) {
    if (!input) return;
    input.classList.add('is-invalid');
    input.classList.remove('is-valid');
    const host = input.closest('.form-field') || input.parentElement;
    let err = host?.querySelector('.field-error');
    if (!err && host) {
      err = document.createElement('p');
      err.className = 'field-error';
      host.appendChild(err);
    }
    if (err) {
      err.textContent = message;
      err.classList.add('is-visible');
    }
  }

  function clearError(input) {
    if (!input) return;
    input.classList.remove('is-invalid');
    const host = input.closest('.form-field') || input.parentElement;
    const err = host?.querySelector('.field-error');
    if (err) err.classList.remove('is-visible');
  }

  function clearProfileErrors() {
    form?.querySelectorAll('.is-invalid, .is-valid').forEach(el => {
      el.classList.remove('is-invalid', 'is-valid');
    });
    form?.querySelectorAll('.field-error').forEach(el => el.classList.remove('is-visible'));
  }

  function snapshotProfileFields() {
    profileSnapshot = {};
    editableFields.forEach(field => {
      profileSnapshot[field.dataset.settingsField] = field.value;
    });
    profileSnapshot.photoUrl = _pendingPhotoUrl || getSession()?.profileImage || null;
  }

  function renderProfilePreview(photoUrl) {
    const currentSession = getSession() || {};
    const initials = getInitials(currentSession.name || profileSnapshot.fullName || 'User');
    const topbar = document.getElementById('topbar-avatar');
    const imgStyle = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';
    if (preview) {
      preview.innerHTML = photoUrl
        ? `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`
        : `<span data-dash-initials>${initials}</span>`;
    }
    if (topbar) {
      topbar.innerHTML = photoUrl
        ? `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`
        : initials[0] || 'U';
    }
  }

  function restoreProfileSnapshot() {
    editableFields.forEach(field => {
      const key = field.dataset.settingsField;
      if (profileSnapshot[key] !== undefined) field.value = profileSnapshot[key];
    });
    _pendingPhotoUrl = null;
    renderProfilePreview(profileSnapshot.photoUrl || getSession()?.profileImage || null);
    clearProfileErrors();
  }

  function setProfileEditMode(enabled, options = {}) {
    isProfileEditing = enabled;
    form?.classList.toggle('is-editing', enabled);
    if (enabled) {
      snapshotProfileFields();
    } else if (options.reset) {
      restoreProfileSnapshot();
    }

    editableFields.forEach(field => {
      field.readOnly = !enabled;
      field.setAttribute('aria-readonly', enabled ? 'false' : 'true');
    });

    if (changePhotoBtn) {
      changePhotoBtn.disabled = !enabled;
      changePhotoBtn.setAttribute('aria-disabled', String(!enabled));
    }
    if (editActions) editActions.hidden = !enabled;
    if (editBtn) {
      editBtn.setAttribute('aria-pressed', String(enabled));
      editBtn.disabled = enabled;
    }
  }

  window.__servio_refreshProfileEditState = () => {
    if (!isProfileEditing) {
      snapshotProfileFields();
      setProfileEditMode(false);
    }
  };

  editableFields.forEach(field => {
    field.addEventListener('input', () => {
      clearError(field);
    });
  });
  editBtn?.addEventListener('click', () => setProfileEditMode(true));
  cancelBtn?.addEventListener('click', () => {
    setProfileEditMode(false, { reset: true });
    showToast(_t('toast_profile_edit_cancelled') || 'Profile edits discarded.', 'info');
  });

  if (changePhotoBtn && photoUploadInput) {
    changePhotoBtn.addEventListener('click', () => {
      if (!isProfileEditing) return;
      photoUploadInput.click();
    });
  }

  if (photoUploadInput && preview) {
    photoUploadInput.addEventListener('change', async () => {
      if (!isProfileEditing) {
        photoUploadInput.value = '';
        return;
      }
      const file = photoUploadInput.files[0];
      if (!file) return;

      if (file.size > 2 * 1024 * 1024) {
        showToast(_t('toast_photo_error') || 'Image must be under 2 MB.', 'error');
        photoUploadInput.value = '';
        return;
      }

      // Show local preview immediately
      const reader = new FileReader();
      reader.onload = (evt) => {
        const imgStyle = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';
        preview.innerHTML = `<img src="${evt.target.result}" alt="Profile photo" style="${imgStyle}" />`;
        const topbar = document.getElementById('topbar-avatar');
        if (topbar) topbar.innerHTML = `<img src="${evt.target.result}" alt="Profile photo" style="${imgStyle}" />`;
      };
      reader.readAsDataURL(file);

      // Upload to server
      changePhotoBtn.disabled = true;
      changePhotoBtn.textContent = _t('toast_photo_uploading') || 'Uploading…';
      try {
        const result = await uploadPublicFile(file, 'avatar');
        _pendingPhotoUrl = result.url;
        showToast(_t('toast_photo_uploaded') || 'Photo uploaded.', 'success');
      } catch {
        showToast(_t('toast_photo_error') || 'Failed to upload photo.', 'error');
        _pendingPhotoUrl = null;
        renderProfilePreview(profileSnapshot.photoUrl || getSession()?.profileImage || null);
      } finally {
        changePhotoBtn.disabled = !isProfileEditing;
        changePhotoBtn.setAttribute('aria-disabled', String(!isProfileEditing));
        changePhotoBtn.innerHTML = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg><span data-i18n="cust_change_photo">${_t('cust_change_photo') || 'Change Photo'}</span>`;
      }
    });
  }

  if (!form) return;
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!isProfileEditing) {
      showToast(_t('toast_profile_locked') || 'Click Edit before changing profile details.', 'info');
      return;
    }

    clearProfileErrors();
    let reqOk = true;
    form.querySelectorAll('input[data-required]').forEach(input => {
      if (!input.value.trim()) {
        reqOk = false;
        setError(input, _t('toast_fill_required') || 'Please fill all required fields.');
      }
    });
    if (!reqOk) {
      showToast(_t('toast_fill_required') || 'Please fill all required fields.', 'info');
      return;
    }

    const fullName = document.getElementById('settings-fullname')?.value.trim() || '';
    const phone = document.getElementById('settings-phone')?.value.trim() || '';
    const phoneOk = /^[+]?[\d\s\-().]{7,20}$/.test(phone);

    if (!phoneOk) {
      const phoneInput = document.getElementById('settings-phone');
      setError(phoneInput, _t('err_invalid_phone') || 'Please enter a valid phone number.');
      phoneInput?.focus();
      return;
    }

    let savedProfile = false;
    try {
      if (submitBtn) submitBtn.disabled = true;
      const updatePayload = { name: fullName, phone };
      const currentSession = getSession();
      const photoUrl = _pendingPhotoUrl || currentSession?.profileImage || null;
      if (photoUrl) updatePayload.profileImage = photoUrl;

      const updatedUser = await updateMe(updatePayload);
      const savedName = updatedUser?.name || fullName;
      const savedEmail = updatedUser?.email || emailInput?.value || getSession()?.email || '';
      const savedPhone = updatedUser?.phone || phone;

      const account = {
        ...(getAccount() || {}),
        name: savedName,
        fullName: savedName,
        email: savedEmail,
        phone: savedPhone,
      };
      delete account.city;
      localStorage.setItem('servio_account', JSON.stringify(account));

      if (currentSession) {
        currentSession.name = savedName;
        currentSession.email = savedEmail;
        if (photoUrl) currentSession.profileImage = photoUrl;
        localStorage.setItem('servio_session', JSON.stringify(currentSession));
      }
      if (_pendingPhotoUrl) _pendingPhotoUrl = null;

      document.getElementById('settings-fullname').value = savedName;
      if (emailInput) emailInput.value = savedEmail;
      document.getElementById('settings-phone').value = savedPhone;
      window.__servio_profile_email = savedEmail;
      snapshotProfileFields();
      setProfileEditMode(false);
      showToast(_t('toast_settings_saved') || 'Your changes have been saved.', 'success');
      savedProfile = true;
    } catch (err) {
      const msg = getErrorMessage(err, 'Failed to save settings.');
      showToast(msg, 'error');
    } finally {
      if (submitBtn) submitBtn.disabled = false;
    }
    if (savedProfile) {
      populateProfile();
      updateWelcomeText();
    }
    updateProfileCompleteness();
  });
}

/* ── Fix 3: Delete account button ──────────────────────── */
function initEmailChangeModal() {
  const modal = document.getElementById('modal-change-email');
  const openBtn = document.getElementById('btn-change-email');
  const closeBtn = document.getElementById('btn-close-change-email');
  const cancelBtn = document.getElementById('btn-change-email-cancel');
  const form = document.getElementById('change-email-form');
  const newEmailInput = document.getElementById('change-email-new');
  const passwordInput = document.getElementById('change-email-password');
  const submitBtn = document.getElementById('btn-change-email-confirm');
  const profileEmail = document.getElementById('settings-email');
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  if (!modal || !openBtn || !form) return;

  function setError(input, message) {
    if (!input) return;
    input.classList.add('is-invalid');
    input.classList.remove('is-valid');
    const host = input.closest('.form-field') || input.parentElement;
    let err = host?.querySelector('.field-error');
    if (!err && host) {
      err = document.createElement('p');
      err.className = 'field-error';
      host.appendChild(err);
    }
    if (err) {
      err.textContent = message;
      err.classList.add('is-visible');
    }
  }

  function clearError(input) {
    if (!input) return;
    input.classList.remove('is-invalid', 'is-valid');
    const host = input.closest('.form-field') || input.parentElement;
    const err = host?.querySelector('.field-error');
    if (err) err.classList.remove('is-visible');
  }

  function clearForm() {
    [newEmailInput, passwordInput].forEach(clearError);
    if (newEmailInput) newEmailInput.value = '';
    if (passwordInput) passwordInput.value = '';
  }

  function openModal() {
    clearForm();
    if (newEmailInput) {
      newEmailInput.placeholder = profileEmail?.value || 'new@email.com';
    }
    modal.removeAttribute('hidden');
    document.body.style.overflow = 'hidden';
    newEmailInput?.focus();
  }

  function closeModal() {
    modal.setAttribute('hidden', '');
    document.body.style.overflow = '';
    clearForm();
  }

  openBtn.addEventListener('click', openModal);
  closeBtn?.addEventListener('click', closeModal);
  cancelBtn?.addEventListener('click', closeModal);
  modal.addEventListener('click', (event) => {
    if (event.target === modal) closeModal();
  });

  [newEmailInput, passwordInput].forEach(input => {
    input?.addEventListener('input', () => clearError(input));
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const newEmail = normalizeEmail(newEmailInput?.value);
    const currentPassword = passwordInput?.value || '';
    const currentEmail = normalizeEmail(profileEmail?.value || window.__servio_profile_email || getSession()?.email);

    let valid = true;
    if (!newEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newEmail)) {
      setError(newEmailInput, _t('err_invalid_email') || 'Please enter a valid email address.');
      valid = false;
    } else if (newEmail === currentEmail) {
      setError(newEmailInput, _t('err_email_same') || 'New email must be different from your current email.');
      valid = false;
    }
    if (!currentPassword) {
      setError(passwordInput, _t('toast_email_current_pw_required') || 'Enter your current password to change your email address.');
      valid = false;
    }
    if (!valid) return;

    try {
      if (submitBtn) submitBtn.disabled = true;
      const result = await updateEmail({ newEmail, currentPassword });
      if (profileEmail && result?.email) profileEmail.value = result.email;
      showToast(_t('toast_email_updated_relogin') || 'Email updated. Please log in again with your new email.', 'success');
      closeModal();
      clearSession();
      setTimeout(() => {
        window.location.href = './login.html';
      }, 1200);
    } catch (err) {
      const msg = getErrorMessage(err, 'Failed to update email.');
      if (err.status === 409) setError(newEmailInput, msg);
      else if (err.status === 401) setError(passwordInput, msg);
      else if (Array.isArray(err?.data?.errors)) {
        err.data.errors.forEach(error => {
          if (error.field === 'newEmail') setError(newEmailInput, error.message);
          if (error.field === 'currentPassword') setError(passwordInput, error.message);
        });
      }
      showToast(msg, 'error');
    } finally {
      if (submitBtn) submitBtn.disabled = false;
    }
  });
}

function initDeleteAccount() {
  const btn = document.getElementById('btn-delete-account');
  if (!btn) return;
  btn.addEventListener('click', () => {
    showToast(typeof window.t === 'function' ? window.t('toast_delete_demo') : 'Account deletion is not available in demo mode.', 'info');
  });
}

/* ── Fix 6: Password field show/hide toggle ─────────────── */
function initPasswordToggles() {
  document.querySelectorAll('.btn-toggle-password').forEach(btn => {
    btn.addEventListener('click', () => {
      const wrap = btn.closest('.input-password-wrap');
      const input = wrap?.querySelector('input');
      if (!input) return;
      const isPassword = input.type === 'password';
      input.type = isPassword ? 'text' : 'password';
      btn.querySelector('.eye-icon--open').style.display = isPassword ? 'none' : '';
      btn.querySelector('.eye-icon--closed').style.display = isPassword ? '' : 'none';
      const showLabel = typeof window.t === 'function' ? window.t('pw_show') : 'Show password';
      const hideLabel = typeof window.t === 'function' ? window.t('pw_hide') : 'Hide password';
      btn.setAttribute('aria-label', isPassword ? hideLabel : showLabel);
    });
  });
}

/* ── Fix 7: Required field indicators & inline validation ── */
function initSettingsValidation() {
  const form = document.querySelector('#tab-settings form, .settings-form, [data-settings-form]');
  if (!form) return;

  function setError(input, message) {
    input.classList.add('is-invalid');
    input.classList.remove('is-valid');
    let err = input.parentElement.querySelector('.field-error');
    if (!err) { err = document.createElement('p'); err.className = 'field-error'; input.parentElement.appendChild(err); }
    err.textContent = message;
    err.classList.add('is-visible');
  }

  function clearError(input) {
    input.classList.remove('is-invalid');
    let err = input.parentElement.querySelector('.field-error');
    if (err) err.classList.remove('is-visible');
  }

  function setValid(input) {
    input.classList.remove('is-invalid');
    input.classList.add('is-valid');
    let err = input.parentElement.querySelector('.field-error');
    if (err) err.classList.remove('is-visible');
  }

  // Clear on input
  form.querySelectorAll('input').forEach(input => {
    input.addEventListener('input', () => clearError(input));
  });

  /* Required fields on submit are handled in initSettingsForm (toast + return). */
}

/* ── Logout ─────────────────────────────────────────────── */
function initDashLogout() {
  const btn = document.querySelector('[data-dash-logout]');
  if (!btn) return;
  btn.addEventListener('click', () => {
    try {
      localStorage.removeItem('servio_session');
    } catch (_) { /* ignore */ }
    window.location.href = './login.html?redirect=' + encodeURIComponent(window.location.pathname + window.location.search);
  });
}

/* ── Booking filter & sort ─────────────────────────────── */
function applyBookingFilter() {
  const activeBtn = document.querySelector('[data-booking-filter].is-active');
  const filter = activeBtn?.dataset.bookingFilter || 'all';
  document.querySelectorAll('[data-booking-group]').forEach(group => {
    let any = false;
    group.querySelectorAll('[data-booking-card]').forEach(card => {
      const st = card.dataset.bookingStatus;
      const show = filter === 'all' || st === filter;
      card.hidden = !show;
      if (show) any = true;
    });
    group.hidden = !any;
    // Also toggle the section title preceding the group
    const title = group.previousElementSibling;
    if (title && title.classList.contains('dash-section-title')) {
      title.hidden = !any;
    }
  });
}

function sortBookingCards() {
  const select = document.querySelector('[data-booking-sort]');
  if (!select) return;
  const mode = select.value;
  const order = { active: 0, pending: 1, completed: 2 };
  document.querySelectorAll('[data-booking-group] .booking-group__cards').forEach(container => {
    const cards = Array.from(container.querySelectorAll('[data-booking-card]'));
    cards.sort((a, b) => {
      const da = new Date(a.dataset.bookingDate || 0).getTime();
      const db = new Date(b.dataset.bookingDate || 0).getTime();
      if (mode === 'date-asc') return da - db;
      if (mode === 'date-desc') return db - da;
      if (mode === 'status') return (order[a.dataset.bookingStatus] ?? 9) - (order[b.dataset.bookingStatus] ?? 9);
      return da - db;
    });
    cards.forEach(c => container.appendChild(c));
  });
}

function initBookingFilter() {
  const filterBtns = document.querySelectorAll('[data-booking-filter]');
  if (!filterBtns.length) return;
  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('is-active'));
      btn.classList.add('is-active');
      applyBookingFilter();
    });
  });
  const sortSel = document.querySelector('[data-booking-sort]');
  sortSel?.addEventListener('change', () => sortBookingCards());
  applyBookingFilter();
  window.applyBookingFilter = applyBookingFilter;
}

/* ── History: expand, date range, sort ─────────────────── */
/* ── History: Filters & Invoices ────────────────────────── */
function initHistoryPanel() {
  const filterRoot = document.getElementById('historyListRoot');
  const filters = document.querySelectorAll('[data-hist-filter]');
  const clearBtn = document.getElementById('clearHistFilters');

  function applyHistoryFilters() {
    if (!filterRoot) return;
    const cards = filterRoot.querySelectorAll('.history-card-v2');
    const vals = {};
    filters.forEach(f => { vals[f.dataset.histFilter] = f.value; });

    const now = Date.now();

    cards.forEach(card => {
      // Date-based timeframe logic
      let dateMatch = true;
      if (vals.date) {
        const cardTs = new Date(card.dataset.date || 0).getTime();
        const daysAgo = parseInt(vals.date, 10);
        dateMatch = cardTs >= (now - (daysAgo * 24 * 60 * 60 * 1000));
      }

      const match =
        (!vals.category || card.dataset.category === vals.category) &&
        (!vals.payment  || card.dataset.payment  === vals.payment)  &&
        (!vals.rating   || parseInt(card.dataset.rating || 0) >= parseInt(vals.rating)) &&
        dateMatch;

      card.classList.toggle('is-hidden', !match);
    });
  }

  filters.forEach(f => f.addEventListener('change', applyHistoryFilters));
  clearBtn?.addEventListener('click', () => {
    filters.forEach(f => { f.value = ''; });
    applyHistoryFilters();
  });

  // Localize history cards (Price, Currency, Payment Badge, Date)
  function localizeHistoryCards() {
    const _t = typeof window.t === 'function' ? window.t : (k) => k;
    const lang = localStorage.getItem('servio_lang') || 'en';

    document.querySelectorAll('.history-card-v2').forEach(card => {
      // 1. Payment Badge - map data-payment to i18n key
      const badge = card.querySelector('.history-v2__payment-badge');
      if (badge) {
        const payVal = card.dataset.payment; 
        const payKey = payVal === 'Credit Card' ? 'cust_pay_card' : (payVal === 'Cash' ? 'cust_pay_cash' : null);
        if (payKey) badge.textContent = _t(payKey);
      }

      // 2. Price/Currency - parse value and localize
      const priceEl = card.querySelector('.history-v2__price');
      if (priceEl) {
        const raw = priceEl.textContent.replace(/[^\d.,]/g, '').trim();
        if (lang === 'ar') {
           priceEl.textContent = `${raw} ${_t('currency_egp')}`;
        } else {
           priceEl.textContent = `${raw} EGP`;
        }
      }

      // 3. Date translation
      const dateEl = card.querySelector('.history-v2__provider .dot-sep + span');
      if (dateEl) {
        if (!dateEl.dataset.origText) dateEl.dataset.origText = dateEl.textContent;
        dateEl.textContent = translateDateTime(dateEl.dataset.origText);
      }
    });
  }

  localizeHistoryCards();
  document.addEventListener('langchange', localizeHistoryCards);

  // Invoice toggles (History & Bookings)
  document.querySelectorAll('[data-invoice-toggle]').forEach(btn => {
    btn.addEventListener('click', () => {
       const card = btn.closest('.history-card-v2, .booking-card');
       if (!card) return;
       const _t = typeof window.t === 'function' ? window.t : (k) => k;
       if (card.classList.contains('history-card-v2')) {
         const isExpanded = card.classList.toggle('is-expanded');
         btn.textContent = isExpanded ? _t('cust_hide_invoice') : _t('cust_view_invoice');
       } else {
         // For Booking Cards: toggle the .is-open class for smooth transition
         const panel = card.querySelector('.booking-card__invoice-panel');
         if (panel) {
           const isOpen = panel.classList.toggle('is-open');
           btn.textContent = isOpen ? _t('cust_hide_invoice') : _t('cust_view_invoice');
         }
       }
    });
  });
}

/* ── Favourites: filter, reorder, remove ───────────────── */
function initFavouritesPanel() {
  const grid = document.querySelector('[data-fav-list]');
  document.querySelectorAll('[data-fav-filter]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('[data-fav-filter]').forEach(b => b.classList.remove('is-active'));
      btn.classList.add('is-active');
      const cat = btn.dataset.favFilter;
      document.querySelectorAll('[data-fav-card]').forEach(card => {
        const c = card.dataset.favCategory || '';
        card.hidden = cat !== 'all' && c !== cat;
      });
    });
  });

  grid?.querySelectorAll('[data-fav-up]').forEach(btn => {
    btn.addEventListener('click', () => {
      const card = btn.closest('[data-fav-card]');
      const prev = card?.previousElementSibling;
      if (card && prev?.matches?.('[data-fav-card]')) grid.insertBefore(card, prev);
    });
  });
  grid?.querySelectorAll('[data-fav-down]').forEach(btn => {
    btn.addEventListener('click', () => {
      const card = btn.closest('[data-fav-card]');
      const next = card?.nextElementSibling;
      if (card && next?.matches?.('[data-fav-card]')) grid.insertBefore(next, card);
    });
  });

  grid?.querySelectorAll('[data-fav-remove]').forEach(btn => {
    btn.addEventListener('click', () => {
      const _t = typeof window.t === 'function' ? window.t : (k) => k;
      if (!confirm(_t('confirm_remove_fav'))) return;
      const card = btn.closest('[data-fav-card]');
      card?.remove();
      showToast(_t('toast_removed_fav'), 'info');
    });
  });
}

/* ── Notifications: quick actions & prefs ──────────────── */
function initNotificationActions() {
  const tabHandlers = {
    'view-bookings': 'bookings',
    'open-settings': 'settings',
  };
  document.querySelectorAll('[data-notif-action]').forEach(btn => {
    btn.addEventListener('click', () => {
      const action = btn.dataset.notifAction;
      const tab = tabHandlers[action];
      if (tab) {
        document.querySelector(`[data-tab="${tab}"]`)?.click();
        return;
      }
      const messages = {
        reschedule: 'Opening reschedule flow (demo)…',
        'cancel-booking': 'Cancel from the Bookings tab to confirm.',
        confirm: 'Slot confirmed (demo).',
        message: 'Messaging opens in a full release.',
      };
      showToast(messages[action] || 'Action recorded (demo).', 'info');
    });
  });

  document.querySelectorAll('[data-notif-pref]').forEach(cb => {
    cb.addEventListener('change', () => {
      showToast('Preference saved for this session (demo).', 'success');
    });
  });
}

/* ── Sidebar toggle (click to expand/collapse) ──────────── */
/* ── Init ───────────────────────────────────────────────── */
populateProfile();
loadBookingsData();
let _custPollInterval = null;
const startCustPolling = () => {
  if (_custPollInterval) clearInterval(_custPollInterval);
  _custPollInterval = setInterval(() => loadBookingsData(), 30000);
};
const stopCustPolling = () => { if (_custPollInterval) clearInterval(_custPollInterval); _custPollInterval = null; };
startCustPolling();
document.addEventListener('visibilitychange', () => { document.hidden ? stopCustPolling() : startCustPolling(); });
populateStats();
updateWelcomeText();

initTabs();
initBookingFilter();
initHistoryPanel();
initFavouritesPanel();
initNotificationActions();
initNotifications();
initSettingsForm();
initEmailChangeModal();
initDeleteAccount();
initPasswordToggles();
initSettingsValidation();
initSettingsTabs();
initSecurityForm();
initOtpField();
initPasswordStrength();
initSettingToggles();
initLanguageCards();
initThemeCards();
initAddressTab();
initAccountTab();
initDashLogout();

/* ── Settings horizontal tab switching ─────────────────── */
function initSettingsTabs() {
  const bar = document.getElementById('settings-tab-bar');
  if (!bar) return;
  bar.addEventListener('click', (e) => {
    const btn = e.target.closest('.stab-btn');
    if (!btn) return;
    const target = btn.dataset.stab;
    bar.querySelectorAll('.stab-btn').forEach(b => {
      b.classList.toggle('stab-btn--active', b === btn);
      b.setAttribute('aria-selected', b === btn ? 'true' : 'false');
    });
    document.querySelectorAll('.stab-pane').forEach(p => {
      const isTarget = p.id === 'stab-' + target;
      p.classList.toggle('stab-pane--active', isTarget);
      if (isTarget) p.removeAttribute('hidden');
      else p.setAttribute('hidden', '');
    });
    if (target === 'profile') updateProfileCompleteness();
  });
  // Run once on load so the bar shows the correct percentage immediately
  updateProfileCompleteness();
}

/* ── Security form — Change Password ─────────────────────── */
function initSecurityForm() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  // Eye-toggle for all password fields in this form
  document.querySelectorAll('#change-password-form .btn-toggle-password').forEach(btn => {
    btn.addEventListener('click', () => {
      const wrap = btn.closest('.input-password-wrap');
      const input = wrap?.querySelector('input');
      if (!input) return;
      const show = input.type === 'password';
      input.type = show ? 'text' : 'password';
      btn.querySelector('.eye-icon--show').style.display = show ? 'none' : '';
      btn.querySelector('.eye-icon--hide').style.display = show ? '' : 'none';
    });
  });

  // Strength segments + requirements checklist
  const newPwInput   = document.getElementById('cp-new');
  const strengthLabel = document.getElementById('cp-strength-label');
  const segs = [1,2,3,4].map(i => document.getElementById(`cp-seg-${i}`));
  const COLORS = ['#ef4444', '#f97316', '#eab308', '#22c55e'];
  const LABELS = ['Weak', 'Fair', 'Good', 'Strong'];

  const REQS = {
    'req-len':     v => v.length >= 8,
    'req-upper':   v => /[A-Z]/.test(v),
    'req-num':     v => /[0-9]/.test(v),
    'req-special': v => /[^A-Za-z0-9]/.test(v),
  };

  function updateStrength(val) {
    let score = 0;
    Object.entries(REQS).forEach(([id, test]) => {
      const met = test(val);
      if (met) score++;
      const el = document.getElementById(id);
      if (el) el.classList.toggle('met', met);
    });

    const color = val ? (COLORS[score - 1] || COLORS[0]) : 'var(--color-border)';
    segs.forEach((seg, i) => {
      if (!seg) return;
      const active = val && i < score;
      seg.classList.toggle('active', active);
      seg.style.setProperty('--pw-seg-color', color);
    });

    if (strengthLabel) {
      strengthLabel.textContent = val ? (LABELS[score - 1] || LABELS[0]) : 'Enter a password';
      strengthLabel.style.color = val ? color : '';
    }
  }

  if (newPwInput) {
    newPwInput.addEventListener('input', () => updateStrength(newPwInput.value));
  }

  const form      = document.getElementById('change-password-form');
  const errEl     = document.getElementById('cp-error');
  const submitBtn = document.getElementById('cp-submit');

  if (!form) return;

  form.addEventListener('reset', () => {
    // Reset strength UI on Clear button click
    setTimeout(() => updateStrength(''), 0);
  });

  form.addEventListener('submit', async e => {
    e.preventDefault();
    if (errEl) errEl.hidden = true;

    const currentPw = document.getElementById('cp-current')?.value?.trim() || '';
    const newPw     = document.getElementById('cp-new')?.value             || '';
    const confirmPw = document.getElementById('cp-confirm')?.value         || '';

    if (!currentPw || !newPw || !confirmPw) {
      if (errEl) { errEl.textContent = 'Please fill in all password fields.'; errEl.hidden = false; }
      return;
    }
    if (newPw.length < 8) {
      if (errEl) { errEl.textContent = 'New password must be at least 8 characters.'; errEl.hidden = false; }
      return;
    }
    if (newPw !== confirmPw) {
      if (errEl) { errEl.textContent = 'New passwords do not match.'; errEl.hidden = false; }
      return;
    }

    try {
      if (submitBtn) { submitBtn.disabled = true; submitBtn.textContent = 'Updating…'; }
      // Calls PATCH /users/me/password → { currentPassword, newPassword }
      await updatePassword({ currentPassword: currentPw, newPassword: newPw });
      showToast(_t('toast_password_changed') || 'Password updated successfully.', 'success');
      form.reset();
      updateStrength('');
    } catch (err) {
      const msg = err?.data?.message || err?.message || 'Failed to update password. Check your current password and try again.';
      if (errEl) { errEl.textContent = msg; errEl.hidden = false; }
    } finally {
      if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = 'Update Password'; }
    }
  });
}

/* ── OTP field visibility (show when phone changes in edit mode) ─ */
function initOtpField() {
  const phoneInput = document.getElementById('settings-phone');
  const otpWrap    = document.getElementById('otp-field-wrap');
  const sendOtpBtn = document.getElementById('btn-send-otp');
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  if (!phoneInput || !otpWrap) return;

  let originalPhone = phoneInput.value;

  // Show OTP field when the phone value changes during editing
  phoneInput.addEventListener('input', () => {
    const changed = phoneInput.value.trim() !== originalPhone.trim();
    otpWrap.hidden = !changed;
  });

  // Re-snapshot original when edit mode is activated
  document.getElementById('btn-profile-edit')?.addEventListener('click', () => {
    originalPhone = phoneInput.value;
    otpWrap.hidden = true;
    if (document.getElementById('settings-phone-otp')) {
      document.getElementById('settings-phone-otp').value = '';
    }
  });

  // Cancel restores original, hides OTP
  document.getElementById('btn-profile-cancel')?.addEventListener('click', () => {
    otpWrap.hidden = true;
    if (document.getElementById('settings-phone-otp')) {
      document.getElementById('settings-phone-otp').value = '';
    }
  });

  if (!sendOtpBtn) return;
  sendOtpBtn.addEventListener('click', () => {
    const phone = phoneInput.value.trim();
    if (!/^[+]?[\d\s\-().]{7,20}$/.test(phone)) {
      showToast('Please enter a valid phone number first.', 'error');
      return;
    }
    // Simulate sending OTP (wire to backend when endpoint is available)
    showToast(_t('toast_otp_sent') || `Verification code sent to ${phone}`, 'success');
    sendOtpBtn.disabled = true;
    let sec = 60;
    sendOtpBtn.textContent = `Resend in ${sec}s`;
    const interval = setInterval(() => {
      sec--;
      sendOtpBtn.textContent = sec > 0 ? `Resend in ${sec}s` : 'Send Code';
      if (sec <= 0) { clearInterval(interval); sendOtpBtn.disabled = false; }
    }, 1000);
  });
}

/* ── Password strength meter + live checklist ────────────── */
function initPasswordStrength() {
  // Handled inside initSecurityForm for the change-password form.
}

/* ── Profile completeness bar ────────────────────────────── */
function updateProfileCompleteness() {
  const account = getAccount ? getAccount() : null;
  const fields = ['fullName', 'email', 'phone'];
  const filled = fields.filter(f => account && account[f] && account[f].trim()).length;
  const avatar = document.querySelector('.settings-avatar-preview img');
  const total  = fields.length + 1; // +1 for photo
  const score  = Math.round(((filled + (avatar ? 1 : 0)) / total) * 100);
  const pct = document.getElementById('profile-complete-pct');
  const bar = document.getElementById('profile-complete-bar');
  const fill = document.getElementById('profile-complete-fill');
  if (pct) pct.textContent = score + '%';
  if (bar) bar.setAttribute('aria-valuenow', score);
  if (fill) fill.style.width = score + '%';
}

/* ── Settings toggles (notifications, 2FA) ──────────────── */
function initSettingToggles() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  const prefs = JSON.parse(localStorage.getItem('servio_notif_prefs') || '{}');

  document.querySelectorAll('.stab-toggle[data-pref]').forEach(btn => {
    const key = btn.dataset.pref;
    // Restore saved state (if we have it, otherwise keep HTML default)
    if (key in prefs) {
      const on = prefs[key];
      btn.setAttribute('aria-checked', on ? 'true' : 'false');
      btn.classList.toggle('stab-toggle--on', on);
    }
    btn.addEventListener('click', () => {
      const on = btn.getAttribute('aria-checked') !== 'true';
      btn.setAttribute('aria-checked', on ? 'true' : 'false');
      btn.classList.toggle('stab-toggle--on', on);
      prefs[key] = on;
      localStorage.setItem('servio_notif_prefs', JSON.stringify(prefs));
      showToast(_t('toast_notif_saved'), 'success');
    });
  });
}

/* ── Language cards ─────────────────────────────────────── */
function initLanguageCards() {
  const cards = document.getElementById('lang-cards');
  if (!cards) return;

  function syncCards() {
    const current = localStorage.getItem('servio_lang') || 'en';
    cards.querySelectorAll('.lang-card').forEach(c => {
      const active = c.dataset.lang === current;
      c.setAttribute('aria-checked', active ? 'true' : 'false');
    });
  }
  syncCards();

  cards.addEventListener('click', (e) => {
    const card = e.target.closest('.lang-card');
    if (!card) return;
    const lang = card.dataset.lang;
    // Trigger the existing lang.js switch
    const switcher = document.querySelector('[data-lang-switcher], [data-lang-switch]');
    if (switcher) {
      switcher.value = lang;
      switcher.dispatchEvent(new Event('change'));
    } else if (typeof window.setLang === 'function') {
      window.setLang(lang);
    } else {
      localStorage.setItem('servio_lang', lang);
      location.reload();
    }
    syncCards();
  });

  document.addEventListener('langchange', syncCards);
}

/* ── Theme cards ─────────────────────────────────────────── */
function initThemeCards() {
  const cards = document.getElementById('theme-cards');
  if (!cards) return;

  function syncCards() {
    const current = localStorage.getItem('servio_theme') || 'system';
    cards.querySelectorAll('.theme-card').forEach(c => {
      const active = c.dataset.themeChoice === current;
      c.setAttribute('aria-checked', active ? 'true' : 'false');
    });
  }
  syncCards();

  cards.addEventListener('click', (e) => {
    const card = e.target.closest('.theme-card');
    if (!card) return;
    const choice = card.dataset.themeChoice;
    localStorage.setItem('servio_theme', choice);

    let apply = choice;
    if (choice === 'system') {
      apply = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    document.documentElement.setAttribute('data-theme', apply);
    // Also try the existing dashboard toggle if present
    const toggle = document.querySelector('[data-theme-toggle]');
    if (toggle) toggle.checked = apply === 'dark';
    syncCards();
  });
}

/* ── Addresses tab ──────────────────────────────────────── */
function initAddressTab() {
  const formWrap   = document.getElementById('addr-form-wrap');
  const btnAdd     = document.getElementById('btn-addr-add');
  const btnCancel  = document.getElementById('btn-addr-cancel');
  const btnSave    = document.getElementById('btn-addr-save');
  const formTitle  = document.getElementById('addr-form-title');
  if (!formWrap) return;

  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  let currentAddrTarget = null;

  function openForm(target) {
    currentAddrTarget = target;
    formTitle.textContent = _t('cust_addr_edit_title');
    
    // We pre-fill from our window global
    const userAddr = window.__servio_user_address || {};
    
    document.getElementById('addr-input-street').value   = userAddr.street || '';
    document.getElementById('addr-input-district').value = userAddr.state || '';
    document.getElementById('addr-input-city').value     = userAddr.city || '';
    
    formWrap.removeAttribute('hidden');
    btnAdd.setAttribute('hidden', '');
    document.getElementById('addr-input-street').focus();
  }

  function closeForm() {
    formWrap.setAttribute('hidden', '');
    btnAdd.removeAttribute('hidden');
    currentAddrTarget = null;
  }

  // Edit buttons on each card
  document.querySelectorAll('.btn-addr-edit').forEach(btn => {
    btn.addEventListener('click', () => openForm(btn.dataset.addrTarget));
  });

  btnAdd.addEventListener('click', () => openForm('other-' + Date.now()));
  btnCancel.addEventListener('click', closeForm);

  btnSave.addEventListener('click', async () => {
    if (!currentAddrTarget) return;
    const street   = document.getElementById('addr-input-street').value.trim();
    const state    = document.getElementById('addr-input-district').value.trim();
    const city     = document.getElementById('addr-input-city').value.trim();
    if (!street) { document.getElementById('addr-input-street').focus(); return; }

    try {
      const address = { street, city, state, zipCode: window.__servio_user_address?.zipCode || '' };
      await updateMe({ address });
      window.__servio_user_address = address;
      
      const session = JSON.parse(localStorage.getItem('servio_session') || '{}');
      session.address = address;
      localStorage.setItem('servio_session', JSON.stringify(session));

      const full = [street, city, state].filter(Boolean).join(', ');
      const valueEl = document.getElementById('addr-home-value');
      if (valueEl) valueEl.textContent = full;
      
      const addrProfEl = document.getElementById('profile-address');
      if(addrProfEl) addrProfEl.textContent = full;

      closeForm();
      showToast(_t('toast_addr_saved') || 'Address saved successfully.', 'success');
    } catch (err) {
      console.error('Failed to save address:', err);
      showToast(err.response?.data?.message || err.message || 'Failed to save address', 'error');
    }
  });

  // Note: Values set dynamically by populateProfile
}

/* ── Account tab (export / deactivate / delete) ─────────── */
function initAccountTab() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  /* ── Export data ── */
  document.getElementById('btn-export-data')?.addEventListener('click', () => {
    showToast(_t('toast_export_demo'), 'info');
  });

  /* ── Deactivate modal ── */
  const modalDeactivate  = document.getElementById('modal-deactivate');
  const checkDeactivate  = document.getElementById('deactivate-confirm-check');
  const btnDeactivateOk  = document.getElementById('btn-deactivate-confirm');

  function openDeactivateModal() {
    if (!modalDeactivate) return;
    checkDeactivate.checked = false;
    btnDeactivateOk.disabled = true;
    modalDeactivate.removeAttribute('hidden');
    document.body.style.overflow = 'hidden';
    checkDeactivate.focus();
  }
  function closeDeactivateModal() {
    modalDeactivate?.setAttribute('hidden', '');
    document.body.style.overflow = '';
  }

  document.getElementById('btn-deactivate-account')?.addEventListener('click', openDeactivateModal);
  document.getElementById('btn-close-deactivate')?.addEventListener('click', closeDeactivateModal);
  document.getElementById('btn-deactivate-cancel')?.addEventListener('click', closeDeactivateModal);

  checkDeactivate?.addEventListener('change', () => {
    btnDeactivateOk.disabled = !checkDeactivate.checked;
  });

  btnDeactivateOk?.addEventListener('click', () => {
    closeDeactivateModal();
    showToast(_t('toast_deactivate_demo'), 'info');
  });

  /* ── Delete modal ── */
  const modalDelete   = document.getElementById('modal-delete');
  const inputDelete   = document.getElementById('delete-confirm-input');
  const btnDeleteOk   = document.getElementById('btn-delete-confirm');
  const CONFIRM_WORD  = 'DELETE';

  function openDeleteModal() {
    if (!modalDelete) return;
    inputDelete.value = '';
    inputDelete.classList.remove('is-valid');
    btnDeleteOk.disabled = true;
    modalDelete.removeAttribute('hidden');
    document.body.style.overflow = 'hidden';
    inputDelete.focus();
  }
  function closeDeleteModal() {
    modalDelete?.setAttribute('hidden', '');
    document.body.style.overflow = '';
  }

  // Override the existing btn-delete-account click (initDeleteAccount set a toast, we replace it)
  const btnDeleteAcct = document.getElementById('btn-delete-account');
  if (btnDeleteAcct) {
    // Clone to remove the old listener added by initDeleteAccount
    const fresh = btnDeleteAcct.cloneNode(true);
    btnDeleteAcct.parentNode.replaceChild(fresh, btnDeleteAcct);
    fresh.addEventListener('click', openDeleteModal);
  }

  document.getElementById('btn-close-delete')?.addEventListener('click', closeDeleteModal);
  document.getElementById('btn-delete-cancel')?.addEventListener('click', closeDeleteModal);

  inputDelete?.addEventListener('input', () => {
    const match = inputDelete.value === CONFIRM_WORD;
    inputDelete.classList.toggle('is-valid', match);
    btnDeleteOk.disabled = !match;
  });

  btnDeleteOk?.addEventListener('click', async () => {
    btnDeleteOk.disabled = true;
    try {
      await deleteMe();
      closeDeleteModal();
      showToast(_t('toast_delete_success') || 'Account deleted successfully.', 'success');
      setTimeout(() => {
        localStorage.removeItem('servio_token');
        localStorage.removeItem('servio_session');
        window.location.href = 'index.html';
      }, 1500);
    } catch (error) {
      btnDeleteOk.disabled = false;
      showToast(error.response?.data?.message || error.message || 'Failed to delete account.', 'error');
    }
  });

  /* ── Close on backdrop click ── */
  [modalDeactivate, modalDelete].forEach(modal => {
    modal?.addEventListener('click', (e) => {
      if (e.target === modal) {
        modal === modalDeactivate ? closeDeactivateModal() : closeDeleteModal();
      }
    });
  });

  /* ── Close on Escape ── */
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (modalDeactivate && !modalDeactivate.hidden) closeDeactivateModal();
    if (modalDelete     && !modalDelete.hidden)     closeDeleteModal();
  });
}

/* ── Date/Time Translation ────────────────────────────── */
function translateDateTime(str) {
  if (!str) return '';
  const lang = localStorage.getItem('servio_lang') || 'en';
  if (lang !== 'ar') return str;

  const monthsMap = {
    'Jan': 'يناير', 'Feb': 'فبراير', 'Mar': 'مارس', 'Apr': 'أبريل',
    'May': 'مايو', 'Jun': 'يونيو', 'Jul': 'يوليو', 'Aug': 'أغسطس',
    'Sep': 'سبتمبر', 'Oct': 'أكتوبر', 'Nov': 'نوفمبر', 'Dec': 'ديسمبر',
    'January': 'يناير', 'February': 'فبراير', 'March': 'مارس', 'April': 'أبريل',
    'June': 'يونيو', 'July': 'يوليو', 'August': 'أغسطس',
    'September': 'سبتمبر', 'October': 'أكتوبر', 'November': 'نوفمبر', 'December': 'ديسمبر',
    'Sun': 'الأحد', 'Mon': 'الاثنين', 'Tue': 'الثلاثاء', 'Wed': 'الأربعاء', 'Thu': 'الخميس', 'Fri': 'الجمعة', 'Sat': 'السبت'
  };

  const ampmMap = {
    'AM': 'صباحاً',
    'PM': 'مساءً'
  };

  let res = str;
  Object.keys(monthsMap).forEach(k => { res = res.replace(new RegExp('\\b' + k + '\\b', 'g'), monthsMap[k]); });
  Object.keys(ampmMap).forEach(k => { res = res.replace(new RegExp('\\b' + k + '\\b', 'g'), ampmMap[k]); });
  return res;
}

/* ── Live language switch ────────────────────────────────── */
function refreshDynamicText() {
  updateWelcomeText();
  const welcomeEl = document.querySelector('[data-dash-welcome]');
  if (welcomeEl) {
    welcomeEl.textContent = typeof window.t === 'function' ? window.t('cust_welcome_sub_text') : 'Your overview';
    welcomeEl.removeAttribute('data-i18n');
  }

  // Translate hours in schedule cards
  document.querySelectorAll('.dash-next-appt__hour, .dash-schedule-item__hour').forEach(el => {
    // Store original if not stored
    if (!el.dataset.origText) el.dataset.origText = el.textContent;
    el.textContent = translateDateTime(el.dataset.origText);
  });

  // Translate Job counts in Favourites
  document.querySelectorAll('.fav-card-v2__jobs-count').forEach(el => {
    if (!el.dataset.origText) el.dataset.origText = el.textContent;
    const countMatch = el.dataset.origText.match(/\d+/);
    if (countMatch && typeof window.t === 'function') {
      el.textContent = window.t('cust_fav_jobs_n', { n: countMatch[0] });
    }
  });
}

/* On every language switch (fired by lang.js after it calls applyLanguage) */
document.addEventListener('langchange', refreshDynamicText);

/* On initial load: lang.js fires langchange on DOMContentLoaded */
document.addEventListener('DOMContentLoaded', refreshDynamicText, { once: true });

/* ═══════════════════════════════════════════════
   PHASE 2 ADDITIONS
   ═══════════════════════════════════════════════ */

(function initPhase2Customer() {
  // ── Post Job modal ─────────────────────────
  document.getElementById('postJobBtn')?.addEventListener('click', () => {
    document.getElementById('postJobModal').hidden = false;
  });
  document.getElementById('closePostJobModal')?.addEventListener('click', () => {
    document.getElementById('postJobModal').hidden = true;
  });
  document.getElementById('cancelPostJob')?.addEventListener('click', () => {
    document.getElementById('postJobModal').hidden = true;
  });

  document.getElementById('postJobForm')?.addEventListener('submit', e => {
    e.preventDefault();
    const fd = new FormData(e.target);
    const job = {
      category: fd.get('category'), title: fd.get('title'),
      description: fd.get('description'), location: fd.get('location'),
      dateFrom: fd.get('dateFrom'), dateTo: fd.get('dateTo'),
      budgetMin: fd.get('budgetMin'), budgetMax: fd.get('budgetMax'),
      paymentPref: fd.get('paymentPref'),
      postedAt: new Date().toISOString(), status: 'open',
    };
    const posts = JSON.parse(localStorage.getItem('servio_job_posts') || '[]');
    posts.push(job);
    localStorage.setItem('servio_job_posts', JSON.stringify(posts));
    document.getElementById('postJobModal').hidden = true;
    e.target.reset();
    const _msg = typeof window.t === 'function' ? window.t('toast_job_posted') : 'Job posted successfully!';
    showToast?.(_msg, 'success') || alert(_msg);
  });

  // ── View Proposals — switch tab ────────────
  document.querySelectorAll('[data-view-proposals]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelector('[data-tab="proposals"]')?.click();
    });
  });

  // ── Close Job ─────────────────────────────
  document.querySelectorAll('[data-close-job]').forEach(btn => {
    btn.addEventListener('click', () => {
      const _t = typeof window.t === 'function' ? window.t : (k) => k;
      if (confirm(_t('confirm_close_job'))) {
        const card = btn.closest('.job-post-card');
        const openBadge = card?.querySelector('.jpc-badge--open');
        if (openBadge) {
          openBadge.textContent = _t('status_closed') || 'Closed';
          openBadge.className = 'jpc-badge jpc-badge--closed';
        }
        showToast?.(_t('toast_job_closed'), 'info');
      }
    });
  });

  // ── Accept Proposal — open payment modal ──
  let pendingProposal = null;
  document.querySelectorAll('[data-accept-proposal]').forEach(btn => {
    btn.addEventListener('click', () => {
      pendingProposal = { tech: btn.dataset.tech, price: parseFloat(btn.dataset.price) };
      document.getElementById('bookingSummaryBlock').hidden = true;
      document.getElementById('proceedPaymentBtn').hidden   = false;
      document.getElementById('paymentModal').hidden = false;
    });
  });
  document.getElementById('closePaymentModal')?.addEventListener('click', () => {
    document.getElementById('paymentModal').hidden = true;
  });

  document.getElementById('proceedPaymentBtn')?.addEventListener('click', () => {
    if (!pendingProposal) return;
    const _t = typeof window.t === 'function' ? window.t : (k) => k;
    const method = document.querySelector('[name="paymentMethod"]:checked')?.value || 'online';
    const labels = {
      online: _t('booking_online_payment'),
      cash: _t('booking_cash'),
    };
    document.getElementById('summaryTech').textContent    = `${_t('cust_lbl_technician')}: ${pendingProposal.tech}`;
    document.getElementById('summaryPrice').textContent   = `${_t('cust_lbl_amount')}: ${pendingProposal.price} EGP`;
    document.getElementById('summaryPayment').textContent = `${_t('cust_lbl_payment_method')}: ${labels[method]}`;
    document.getElementById('bookingSummaryBlock').hidden = false;
    document.getElementById('proceedPaymentBtn').hidden   = true;
  });

  document.getElementById('confirmBookingBtn')?.addEventListener('click', () => {
    const booking = {
      id: 'S-' + Date.now(),
      tech: pendingProposal?.tech || 'Technician',
      price: pendingProposal?.price || 0,
      payment: document.querySelector('[name="paymentMethod"]:checked')?.value || 'online',
      pin: null, status: 'Booked', timestamp: Date.now(),
    };
    localStorage.setItem('servio_active_booking', JSON.stringify(booking));
    const bookings = JSON.parse(localStorage.getItem('servio_bookings') || '[]');
    bookings.push(booking);
    localStorage.setItem('servio_bookings', JSON.stringify(bookings));
    window.location.href = './booking-confirmation.html';
  });

  // ── Decline proposal ──────────────────────
  document.querySelectorAll('[data-decline-proposal]').forEach(btn => {
    btn.addEventListener('click', () => {
      btn.closest('.proposal-card')?.remove();
      const _t = typeof window.t === 'function' ? window.t : (k) => k;
      showToast?.(_t('toast_proposal_declined') || 'Proposal declined', 'info');
    });
  });

  // ── Edit job post (stub) ───────────────────
  document.querySelectorAll('[data-i18n="cust_edit"]').forEach(btn => {
    btn.addEventListener('click', () => {
      const _t = typeof window.t === 'function' ? window.t : (k) => k;
      showToast(_t('toast_coming_soon'), 'info');
    });
  });

  // ── Dismiss notification ───────────────────
  document.querySelectorAll('[data-i18n="cust_dismiss"]').forEach(btn => {
    btn.addEventListener('click', () => {
      const _t = typeof window.t === 'function' ? window.t : (k) => k;
      btn.closest('.notif-card-v2')?.remove();
      showToast(_t('toast_notif_dismissed'), 'info');
    });
  });
})();

// .
