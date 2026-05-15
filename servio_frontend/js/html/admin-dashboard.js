/* ───────────────────────────────────────────────
   Admin Dashboard — SERVIO
   ─────────────────────────────────────────────── */

import { showToast } from '../components/toast.js';
import { getAllUsers, deleteUser, updateUserStatus, updatePassword, reviewWorker, approveWorkerCategory } from '../api/users.js';
import { getServices, createService, updateService, deleteService as apiDeleteService } from '../api/services.js';
import { getAllBookings } from '../api/bookings.js';
import { getAuditLogs, deleteAuditLog, getAdminSettings, updateAdminSettings, getAnalytics } from '../api/admin.js';
import {
  getPendingApprovals,
  adminApprovePayment,
  adminRejectCash,
  adminRefund,
  getCashDebts,
  markCashDebtPaid,
} from '../api/payments.js';

// Auth guard
const session = JSON.parse(localStorage.getItem('servio_session') || 'null');
if (!session) {
  const currentPath = window.location.pathname;
  const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
  const redirectParam = encodeURIComponent('./' + currentPage + window.location.search);
  window.location.href = './login.html?redirect=' + redirectParam;
  throw new Error('Unauthenticated — redirecting to login');
}
if (session.role !== 'admin') {
  window.location.href = './index.html';
  throw new Error('Role redirect — not admin');
}

// ── Helper: locale-aware date ──────────────────
function _adminDateStr() {
  const locale = (typeof window.__lang !== 'undefined' && window.__lang === 'ar') ? 'ar-EG' : 'en-US';
  return new Date().toLocaleDateString(locale, { day: 'numeric', month: 'short', year: 'numeric' });
}

function _updateOverviewDate() {
  const el = document.getElementById('overviewDate');
  if (el) el.textContent = _adminDateStr();
}

// Module-level bridges so loadAdminData() (defined outside initAdminDashboard) can call modal helpers
let _openProfileModal, _openTechProfileModal;
let _currentRejectWorkerId = '';

function getVerificationStatus(user) {
  return user?.verificationStatus || (user?.isVerified ? 'approved' : 'pending');
}

function getTechStatusLabel(user) {
  if (!user?.isActive) return 'Suspended';
  const status = getVerificationStatus(user);
  if (status === 'approved') return 'Verified';
  if (status === 'rejected') return 'Rejected';
  return 'Pending';
}

function getTechStatusBadgeClass(user) {
  const label = getTechStatusLabel(user);
  if (label === 'Verified') return 'bk-badge--completed';
  if (label === 'Rejected') return 'bk-badge--disputed';
  if (label === 'Suspended') return 'bk-badge--cancelled';
  return 'bk-badge--active';
}

function formatAdminDate(value) {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '—' : date.toLocaleString();
}

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

async function downloadRemoteFile(url, filename) {
  if (!url) return;
  try {
    const response = await fetch(url, { mode: 'cors' });
    if (!response.ok) throw new Error('Download failed.');
    const blob = await response.blob();
    const objectUrl = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = objectUrl;
    link.download = filename || 'download';
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(objectUrl);
  } catch (_) {
    // Fallback for cross-origin URLs that block blob fetch
    const link = document.createElement('a');
    link.href = url;
    link.download = filename || 'download';
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
    document.body.appendChild(link);
    link.click();
    link.remove();
  }
}

function buildTechProfileData(user) {
  return {
    id: user._id,
    name: user.name || '—',
    email: user.email || '—',
    skills: (user.skills || []).join(', ') || (user.categories || []).join(', ') || 'General',
    area: user.locationLabel || '—',
    phone: user.phone || '—',
    rate: user.hourlyRate ? `${user.hourlyRate} EGP/hr` : '—',
    rating: user.averageRating ?? '—',
    jobs: user.completedJobs ?? '—',
    joined: formatAdminDate(user.createdAt),
    experience: user.yearsExperience ? `${user.yearsExperience} yrs` : '—',
    bio: user.bio || '',
    status: getTechStatusLabel(user),
    submittedAt: formatAdminDate(user.verificationSubmittedAt || user.createdAt),
    reviewedBy: user.verificationReviewedBy || '—',
    reviewedAt: formatAdminDate(user.verificationReviewedAt),
    rejectionReason: user.verificationRejectionReason || '',
    idFrontUrl: user.idFrontUrl || '',
    idFrontName: user.idFrontName || '',
    idBackUrl: user.idBackUrl || '',
    idBackName: user.idBackName || '',
    idSelfieUrl: user.idSelfieUrl || '',
    idSelfieName: user.idSelfieName || '',
    cvUrl: user.cvUrl || '',
    cvName: user.cvName || '',
    portfolioFiles: Array.isArray(user.portfolioFiles) ? user.portfolioFiles : [],
  };
}

function initAdminDashboard() {
  // ── Tab switching ──────────────────────────
  const navBtns = document.querySelectorAll('.admin-nav__btn');
  const panels  = document.querySelectorAll('.admin-panel');

  const headerTitle = document.getElementById('admin-header-title');
  function switchTab(tabName, save = true) {
    navBtns.forEach(b => b.classList.toggle('is-active', b.dataset.tab === tabName));
    panels.forEach(p => p.classList.toggle('is-active', p.dataset.panel === tabName));
    // Sync topbar title with active tab label
    const activeBtn = document.querySelector(`.admin-nav__btn[data-tab="${tabName}"]`);
    if (headerTitle && activeBtn) {
      const labelEl = activeBtn.querySelector('span[data-i18n]');
      if (labelEl) {
        headerTitle.textContent = labelEl.textContent;
        headerTitle.setAttribute('data-i18n', labelEl.getAttribute('data-i18n'));
      }
    }
    // Persist tab state
    if (save) {
      sessionStorage.setItem('servio_admin_active_tab', tabName);
    }
  }

  // Restore active tab from sessionStorage or default to overview
  const savedTab = sessionStorage.getItem('servio_admin_active_tab');
  if (savedTab) {
    switchTab(savedTab, false);
  } else {
    switchTab('overview', false);
  }

  navBtns.forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });

  // ── Quick action buttons (data-goto-tab) ──
  document.querySelectorAll('[data-goto-tab]').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.gotoTab));
  });

  // ── Users: combined search + status filter ─
  function _updateUserCount() {
    const countEl = document.getElementById('userCount');
    if (!countEl) return;
    const visible = document.querySelectorAll('.user-row:not(.is-hidden)').length;
    const total   = document.querySelectorAll('.user-row').length;
    
    const t = (typeof window.t === 'function') ? window.t : (k) => k;
    
    if (visible === total) {
      countEl.textContent = t('admin_users_count').replace('{n}', total);
    } else {
      countEl.textContent = t('admin_pagination_users').replace('{v}', visible).replace('{n}', total);
    }
  }

  function _applyUserFilters() {
    const q         = (document.getElementById('userSearch')?.value || '').toLowerCase();
    const status    = document.getElementById('userStatusFilter')?.value || '';
    const dateRange = document.getElementById('userDateFilter')?.value || 'all';
    const sortBy    = document.getElementById('userSortSelect')?.value || 'newest';
    const now       = new Date(); // To calculate relative months

    const tbody = document.querySelector('.admin-table tbody');
    if (!tbody) return;

    const rows = Array.from(tbody.querySelectorAll('.user-row'));

    rows.forEach(row => {
      const name      = row.querySelector('.user-name')?.textContent.toLowerCase()  || '';
      const email     = row.querySelector('.user-email')?.textContent.toLowerCase() || '';
      const rowStatus = row.dataset.status || '';
      
      const matchQ      = q === '' || name.includes(q) || email.includes(q);
      const matchStatus = status === '' || rowStatus === status;
      let matchDate     = true;

      if (dateRange !== 'all') {
        const dateCell = row.querySelectorAll('td')[2]?.textContent; 
        if (dateCell) {
          const rowDate = new Date(dateCell);
          // Simple month diff calculation
          const diffMonths = (now.getFullYear() - rowDate.getFullYear()) * 12 + (now.getMonth() - rowDate.getMonth());
          if (dateRange === 'this_month') matchDate = diffMonths <= 0;
          if (dateRange === 'last_3_months') matchDate = diffMonths <= 3;
        }
      }

      row.classList.toggle('is-hidden', !matchQ || !matchStatus || !matchDate);
    });

    // Execute sorting
    rows.sort((a, b) => {
      if (sortBy === 'newest') {
        const dateA = new Date(a.querySelectorAll('td')[2]?.textContent || 0).getTime();
        const dateB = new Date(b.querySelectorAll('td')[2]?.textContent || 0).getTime();
        return dateB - dateA;
      }
      if (sortBy === 'bookings') {
        const countA = parseInt(a.querySelectorAll('td')[3]?.textContent || 0, 10);
        const countB = parseInt(b.querySelectorAll('td')[3]?.textContent || 0, 10);
        return countB - countA;
      }
      if (sortBy === 'name') {
        const nameA = a.querySelector('.user-name')?.textContent || '';
        const nameB = b.querySelector('.user-name')?.textContent || '';
        return nameA.localeCompare(nameB);
      }
      return 0;
    });

    // Re-append rows to enforce the sort order in the DOM
    rows.forEach(row => tbody.appendChild(row));

    _updateUserCount();
  }

  document.getElementById('userSearch')?.addEventListener('input', _applyUserFilters);
  document.querySelectorAll('.admin-filter-select').forEach(select => {
    select.addEventListener('change', _applyUserFilters);
  });
  _updateUserCount();

  // ── Profile-modal helpers ─────────────────
  function openProfileModal(id) {
    const el = document.getElementById(id);
    if (!el) return;
    el.removeAttribute('hidden');
    el.style.display = 'flex';
  }
  function closeProfileModal(id) {
    const el = document.getElementById(id);
    if (!el) return;
    el.style.display = 'none';
  }
  document.querySelectorAll('[data-modal-close]').forEach(btn => {
    btn.addEventListener('click', () => closeProfileModal(btn.dataset.modalClose));
  });
  document.querySelectorAll('.admin-modal-backdrop').forEach(backdrop => {
    backdrop.addEventListener('click', e => {
      if (e.target === backdrop) closeProfileModal(backdrop.id);
    });
  });
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
      document.querySelectorAll('.admin-modal-backdrop:not([hidden])').forEach(m => closeProfileModal(m.id));
    }
  });

  // ── Users: View modal ─────────────────────
  document.querySelectorAll('[data-action="view"]').forEach(btn => {
    btn.addEventListener('click', () => {
      const row = btn.closest('tr');
      if (!row) return;
      const cells = row.querySelectorAll('td');
      const id        = cells[0]?.textContent?.trim() || '—';
      const name      = cells[1]?.textContent?.trim() || '—';
      const email     = cells[2]?.textContent?.trim() || '—';
      const joinDate  = cells[3]?.textContent?.trim() || '—';
      const bookings  = cells[4]?.textContent?.trim() || '—';
      const statusBadge = cells[5]?.querySelector('.status-badge');
      const statusText  = statusBadge?.textContent?.trim() || '—';
      const isActive  = row.dataset.status === 'active';

      const initials = name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
      document.getElementById('userModalAvatar').textContent = initials;
      document.getElementById('userModalName').textContent   = name;
      document.getElementById('userModalEmail').textContent  = email;
      document.getElementById('userModalId').textContent     = id;
      document.getElementById('userModalJoinDate').textContent = joinDate;
      document.getElementById('userModalBookings').textContent = bookings;
      document.getElementById('userModalStatus').textContent = statusText;

      const badge = document.getElementById('userModalStatusBadge');
      badge.textContent = statusText;
      badge.className = isActive
        ? 'bk-badge bk-badge--completed'
        : 'bk-badge bk-badge--pending';

      openProfileModal('userViewModal');
    });
  });


  // ── Technicians: approve / reject helpers ─



  // ── Technicians: Table Filters & Actions ───────────────
  const techSearch = document.getElementById('techSearch');
  const techStatusFilter = document.getElementById('techStatusFilter');
  const techsTableBody = document.querySelector('#allTechsTable tbody');

  function _applyTechFilters() {
    if (!techsTableBody) return;
    const q = (techSearch?.value || '').toLowerCase();
    const status = techStatusFilter?.value || 'All';
    let visibleCount = 0;
    
    document.querySelectorAll('#allTechsTable tbody tr').forEach(row => {
      const name = row.querySelector('.t-name')?.textContent.toLowerCase() || '';
      const specialty = row.querySelector('.t-specialty')?.textContent.toLowerCase() || '';
      // table doesn't have email column in mock, just name and specialty
      const rowStatus = row.dataset.status || '';

      const matchQ = q === '' || name.includes(q) || specialty.includes(q);
      const matchStatus = status === 'All' || rowStatus === status;

      row.classList.toggle('is-hidden', !matchQ || !matchStatus);
      if (matchQ && matchStatus) {
        visibleCount++;
        row.style.display = '';
      } else {
        row.style.display = 'none';
      }
    });

    const infoEl = document.getElementById('techPaginationInfo');
    const total = document.querySelectorAll('#allTechsTable tbody tr').length;
    if (infoEl) {
      const t = (typeof window.t === 'function') ? window.t : (k) => k;
      infoEl.textContent = t('admin_pagination_techs')
        .replace('{v}', visibleCount)
        .replace('{n}', total);
    }
  }

  techSearch?.addEventListener('input', _applyTechFilters);
  techStatusFilter?.addEventListener('change', _applyTechFilters);
  _applyTechFilters(); // run on init to set correct count

  document.getElementById('exportTechsBtn')?.addEventListener('click', () => {
    showToast(typeof window.t === 'function' ? window.t('toast_tech_exported') : 'Technician data exported', 'success');
  });

  // ── Technicians: Profile modal ────────────
  function renderModalDocument({ thumbId, downloadId, url, label, fileName, isImage = true }) {
    const thumbEl = document.getElementById(thumbId);
    const downloadBtn = document.getElementById(downloadId);
    if (!thumbEl || !downloadBtn) return;

    thumbEl.innerHTML = '';
    thumbEl.classList.remove('apm-doc-card__thumb--ok');
    thumbEl.classList.toggle('apm-doc-card__thumb--file', !isImage);
    thumbEl.onclick = null;
    downloadBtn.disabled = !url;

    if (!url) {
      const span = document.createElement('span');
      span.className = 'apm-doc-card__missing';
      span.textContent = 'Not submitted';
      thumbEl.appendChild(span);
      downloadBtn.onclick = null;
      return;
    }

    if (isImage) {
      const img = document.createElement('img');
      img.alt = label;
      img.style.cssText = 'width:100%;height:100%;object-fit:cover;display:block;';

      img.onerror = () => {
        // Image URL is inaccessible — show a fallback with an open-in-new-tab link
        thumbEl.innerHTML = '';
        thumbEl.classList.remove('apm-doc-card__thumb--ok');
        thumbEl.style.cssText = 'display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;padding:12px;cursor:default;';
        thumbEl.onclick = null;

        const iconWrap = document.createElement('div');
        iconWrap.innerHTML = `<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#aaa" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>`;

        const msg = document.createElement('span');
        msg.textContent = 'Preview unavailable';
        msg.style.cssText = 'font-size:10px;color:#aaa;text-align:center;';

        const link = document.createElement('a');
        link.href = url;
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
        link.textContent = 'Open file ↗';
        link.style.cssText = 'font-size:10px;color:#9A8C73;text-decoration:underline;';
        link.onclick = e => e.stopPropagation();

        thumbEl.appendChild(iconWrap);
        thumbEl.appendChild(msg);
        thumbEl.appendChild(link);
      };

      img.src = url;
      thumbEl.appendChild(img);
      thumbEl.classList.add('apm-doc-card__thumb--ok');
      thumbEl.onclick = () => _openDocLightbox(url, label);
    } else {
      const fileInfo = document.createElement('div');
      fileInfo.className = 'apm-doc-card__file';
      fileInfo.innerHTML = `<strong>${escapeHtml(fileName || label)}</strong><span>Ready to download</span>`;
      thumbEl.appendChild(fileInfo);
    }

    downloadBtn.onclick = async () => {
      try {
        await downloadRemoteFile(url, fileName || label);
      } catch (err) {
        showToast(err.message || 'Download failed.', 'error');
      }
    };
  }

  function renderPortfolioItems(items) {
    const wrap = document.getElementById('techModalPortfolioWrap');
    const viewer = document.getElementById('techModalPortfolioViewer');
    if (!wrap || !viewer) return;

    const files = Array.isArray(items) ? items.filter((item) => item?.url) : [];
    viewer.innerHTML = '';
    wrap.hidden = files.length === 0;
    if (!files.length) return;

    files.forEach((file, index) => {
      const card = document.createElement('div');
      card.className = 'apm-doc-card';
      card.innerHTML = `
        <div class="apm-doc-card__thumb apm-doc-card__thumb--ok"></div>
        <div class="apm-doc-card__footer">
          <div class="apm-doc-card__label">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
            Portfolio ${index + 1}
          </div>
          <button type="button" class="apm-doc-card__btn">Download</button>
        </div>
      `;
      const thumb = card.querySelector('.apm-doc-card__thumb');
      const button = card.querySelector('.apm-doc-card__btn');
      const img = document.createElement('img');
      img.alt = file.name || `Portfolio ${index + 1}`;
      img.style.cssText = 'width:100%;height:100%;object-fit:cover;display:block;';
      img.onerror = () => {
        thumb.innerHTML = '';
        thumb.classList.remove('apm-doc-card__thumb--ok');
        thumb.style.cssText = 'display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;padding:12px;cursor:default;';
        thumb.onclick = null;
        thumb.innerHTML = `<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#aaa" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg><span style="font-size:10px;color:#aaa;text-align:center;">Preview unavailable</span><a href="${file.url}" target="_blank" rel="noopener noreferrer" style="font-size:10px;color:#9A8C73;text-decoration:underline;" onclick="event.stopPropagation()">Open file ↗</a>`;
      };
      img.src = file.url;
      thumb.appendChild(img);
      thumb.onclick = () => _openDocLightbox(file.url, file.name || `Portfolio ${index + 1}`);
      button.onclick = async () => {
        try {
          await downloadRemoteFile(file.url, file.name || `portfolio-${index + 1}.jpg`);
        } catch (err) {
          showToast(err.message || 'Download failed.', 'error');
        }
      };
      viewer.appendChild(card);
    });
  }

  function openTechProfileModal(data) {
    const initials = (data.name || 'TN').split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
    document.getElementById('techModalAvatar').textContent = initials;
    document.getElementById('techModalName').textContent = data.name || '—';
    document.getElementById('techModalEmail').textContent = data.email || '—';
    document.getElementById('techModalSkills').textContent = data.skills || '—';
    document.getElementById('techModalArea').textContent = data.area || '—';
    document.getElementById('techModalPhone').textContent = data.phone || '—';
    document.getElementById('techModalRate').textContent = data.rate || '—';
    document.getElementById('techModalRating').textContent = data.rating || '—';
    document.getElementById('techModalJobs').textContent = data.jobs || '—';
    document.getElementById('techModalJoined').textContent = data.joined || '—';
    document.getElementById('techModalExp').textContent = data.experience || '—';
    document.getElementById('techModalSubmittedAt').textContent = data.submittedAt || '—';
    document.getElementById('techModalReviewedBy').textContent = data.reviewedBy || '—';
    document.getElementById('techModalReviewedAt').textContent = data.reviewedAt || '—';

    const bioWrap = document.getElementById('techModalBioWrap');
    const bioEl = document.getElementById('techModalBio');
    if (data.bio) {
      bioEl.textContent = data.bio;
      bioWrap.style.display = 'block';
    } else {
      bioWrap.style.display = 'none';
    }

    const badge = document.getElementById('techModalStatusBadge');
    badge.textContent = data.status || '—';
    const statusClass = data.status === 'Verified' ? 'bk-badge--completed'
      : data.status === 'Pending' ? 'bk-badge--active'
      : data.status === 'Rejected' ? 'bk-badge--disputed'
      : 'bk-badge--pending';
    badge.className = 'bk-badge ' + statusClass;

    const rejectWrap = document.getElementById('techModalRejectWrap');
    const rejectEl = document.getElementById('techModalRejectReason');
    const hasRejectReason = !!data.rejectionReason;
    if (rejectWrap) rejectWrap.hidden = !hasRejectReason;
    if (rejectEl) rejectEl.textContent = data.rejectionReason || '—';

    renderModalDocument({
      thumbId: 'docThumbFront',
      downloadId: 'docDownloadFront',
      url: data.idFrontUrl,
      label: 'National ID (Front)',
      fileName: data.idFrontName,
      isImage: true,
    });
    renderModalDocument({
      thumbId: 'docThumbBack',
      downloadId: 'docDownloadBack',
      url: data.idBackUrl,
      label: 'National ID (Back)',
      fileName: data.idBackName,
      isImage: true,
    });
    renderModalDocument({
      thumbId: 'docThumbSelfie',
      downloadId: 'docDownloadSelfie',
      url: data.idSelfieUrl,
      label: 'ID Selfie',
      fileName: data.idSelfieName,
      isImage: true,
    });
    renderModalDocument({
      thumbId: 'docThumbCv',
      downloadId: 'docDownloadCv',
      url: data.cvUrl,
      label: 'CV / Resume',
      fileName: data.cvName,
      isImage: false,
    });
    renderPortfolioItems(data.portfolioFiles);

    openProfileModal('techProfileModal');
  }

  // Lightbox helpers
  function _openDocLightbox(url, label) {
    const lb    = document.getElementById('docLightbox');
    const img   = document.getElementById('docLightboxImg');
    const lbl   = document.getElementById('docLightboxLabel');
    if (!lb || !img) return;
    img.src = url;
    if (lbl) lbl.textContent = label || '';
    lb.hidden = false;
  }
  function _closeDocLightbox() {
    const lb = document.getElementById('docLightbox');
    if (lb) { lb.hidden = true; document.getElementById('docLightboxImg').src = ''; }
  }
  document.getElementById('docLightboxClose')?.addEventListener('click', _closeDocLightbox);
  document.getElementById('docLightboxBackdrop')?.addEventListener('click', _closeDocLightbox);
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') _closeDocLightbox(); });



  document.querySelectorAll('.view-tech-link').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const row = btn.closest('tr');
      if (!row) return;
      const cells = row.querySelectorAll('td');
      openTechProfileModal({
        name:    cells[1]?.textContent?.trim() || '—',
        email:   '—',
        skills:  cells[2]?.textContent?.trim() || '—',
        area:    cells[3]?.textContent?.trim() || '—',
        phone:   '—',
        rate:    '—',
        rating:  cells[4]?.textContent?.trim() || '—',
        jobs:    cells[5]?.textContent?.trim() || '—',
        status:  row.dataset.status || '—',
        isPendingDynamic: false,
      });
    });
  });

  // ── Bookings: status filter & search ──────
  const bookingSearch = document.getElementById('bookingSearch');
  const bookingStatusFilter = document.getElementById('bookingStatusFilter');
  const bookingPills = document.querySelectorAll('#bookingPills .booking-pill');

  function _applyBookingFilters() {
    const q = (bookingSearch?.value || '').toLowerCase();
    const status = bookingStatusFilter?.value || '';

    // Sync pills
    bookingPills.forEach(pill => {
      const isMatch = pill.dataset.val === status;
      pill.classList.toggle('badge--active', isMatch);
      pill.classList.toggle('is-active', isMatch);
      if (isMatch) {
        pill.style.background = 'var(--color-accent)';
        pill.style.color = '#fff';
        pill.style.borderColor = 'transparent';
      } else {
        pill.style.background = 'var(--color-surface)';
        pill.style.color = 'var(--color-text)';
        pill.style.borderColor = 'var(--color-border)';
      }
    });

    // Filter rows
    document.querySelectorAll('.booking-row').forEach(row => {
      const id = row.querySelector('.bk-id')?.textContent.toLowerCase() || '';
      const cust = row.querySelector('.bk-cust')?.textContent.toLowerCase() || '';
      const tech = row.querySelector('.bk-tech')?.textContent.toLowerCase() || '';
      const rowStatus = row.dataset.status || '';

      const matchQ = q === '' || id.includes(q) || cust.includes(q) || tech.includes(q);
      const matchStatus = status === '' || rowStatus === status;

      row.classList.toggle('is-hidden', !matchQ || !matchStatus);
      row.style.display = (matchQ && matchStatus) ? '' : 'none';
    });

    const infoEl = document.getElementById('bookingPaginationInfo');
    const visibleCount = document.querySelectorAll('.booking-row:not(.is-hidden)').length;
    const total = document.querySelectorAll('.booking-row').length;
    if (infoEl) {
      const t = (typeof window.t === 'function') ? window.t : (k) => k;
      infoEl.textContent = t('admin_pagination_bookings')
        .replace('{v}', visibleCount)
        .replace('{n}', total);
    }
  }

  bookingSearch?.addEventListener('input', _applyBookingFilters);
  bookingStatusFilter?.addEventListener('change', _applyBookingFilters);

  bookingPills.forEach(pill => {
    pill.addEventListener('click', () => {
      if (bookingStatusFilter) {
        bookingStatusFilter.value = pill.dataset.val;
        _applyBookingFilters();
      }
    });
  });

  // ── Bookings: Actions ──────────────────────
  document.getElementById('exportBookingsBtn')?.addEventListener('click', () => {
    showToast(typeof window.t === 'function' ? window.t('toast_booking_exported') : 'Booking data exported', 'success');
  });

  document.querySelectorAll('[data-action="view-booking"]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.id;
      showToast(typeof window.t === 'function' ? window.t('toast_view_booking') : `Viewing booking S-${id} — feature coming soon`, 'info');
    });
  });


  // ── Disputes: more info ───────────────────
  document.querySelectorAll('[data-action="more-info"]').forEach(btn => {
    btn.addEventListener('click', () => showToast(typeof window.t === 'function' ? window.t('toast_info_request_sent') : 'Information request sent', 'info'));
  });

  // ── Settlements: Redesigned Actions & Filters ───────
  const settlementSearch = document.getElementById('settlementSearch');
  const settlementStatusFilter = document.getElementById('settlementStatusFilter');
  const settlementSort = document.getElementById('settlementSort');
  const settlementsTableBody = document.querySelector('[data-panel="settlements"] tbody');

  function _applySettlementFilters() {
    if (!settlementsTableBody) return;
    const q = (settlementSearch?.value || '').toLowerCase();
    const status = settlementStatusFilter?.value || '';
    
    document.querySelectorAll('[data-panel="settlements"] .settlement-row').forEach(row => {
      const name = row.querySelector('div > div:first-child')?.textContent.toLowerCase() || '';
      const id = row.querySelector('div > div:last-child')?.textContent.toLowerCase() || '';
      
      const matchQ = q === '' || name.includes(q) || id.includes(q);
      // For mock purposes, we check if the row's innerHTML contains the status value
      // This is a simple way to handle the status filters in a static mock.
      const matchStatus = status === '' || row.dataset.status === status;

      row.style.display = (matchQ && matchStatus) ? '' : 'none';
    });
  }

  settlementSearch?.addEventListener('input', _applySettlementFilters);
  settlementStatusFilter?.addEventListener('change', _applySettlementFilters);
  settlementSort?.addEventListener('change', () => {
    showToast(typeof window.t === 'function' ? window.t('toast_feature_soon') : 'Sorting feature coming soon', 'info');
  });

  // Action: Record Payment
  document.querySelectorAll('[data-action="record-payment"]').forEach(btn => {
    btn.addEventListener('click', () => {
      const row = btn.closest('tr');
      const badge = row.querySelector('.bk-badge');
      const amountCell = row.querySelectorAll('td')[2]?.querySelector('.settlement-amount');
      
      if (badge) {
        badge.className = 'bk-badge bk-badge--settled';
        badge.textContent = typeof window.t === 'function' ? window.t('status_settled') : 'Settled';
        badge.setAttribute('data-i18n', 'status_settled');
      }
      if (amountCell) {
        const t = (typeof window.t === 'function') ? window.t : (k) => k;
        amountCell.innerHTML = `0 <span data-i18n="admin_currency">${t('admin_currency')}</span>`;
        amountCell.style.color = 'var(--color-text-muted)';
      }
      
      btn.style.opacity = '0.5';
      btn.style.pointerEvents = 'none';
      showToast(typeof window.t === 'function' ? window.t('toast_marked_paid') : 'Payment recorded successfully', 'success');
    });
  });

  // Action: Send Reminder
  document.querySelectorAll('[data-action="send-reminder"]').forEach(btn => {
    btn.addEventListener('click', () => {
      showToast(typeof window.t === 'function' ? window.t('toast_reminder_sent') : 'Reminder sent to technician', 'info');
    });
  });

  // Action: View Ledger
  document.querySelectorAll('[data-action="view-ledger"]').forEach(btn => {
    btn.addEventListener('click', () => {
      showToast(typeof window.t === 'function' ? window.t('toast_feature_soon') : 'Ledger view coming soon', 'info');
    });
  });

  // ── Services Management ────────────────────
  async function renderServicesList() {
    const list = document.getElementById('servicesList');
    if (!list) return;

    try {
      const response = await getServices();
      const apiServices = response.services || [];
      
      list.innerHTML = '';
      if (apiServices.length === 0) {
        list.innerHTML = '<tr><td colspan="5" style="text-align:center; padding:2rem; color:var(--color-text-muted);">No services found in database. Add your first service to get started.</td></tr>';
        _updateServiceKPIs([]);
        return;
      }

      apiServices.forEach(svc => {
        const tr = document.createElement('tr');
        tr.className = 'booking-row service-row'; 
        tr.dataset.category = svc.category;
        tr.dataset.status = svc.isActive !== false ? 'Active' : 'Inactive';

        const nameKey = 'svc_' + (svc.title || '').toLowerCase().replace(/ /g, '_');
        const catKey = 'skill_' + svc.category.toLowerCase();

        const priceText = svc.basePrice !== undefined 
          ? `${svc.basePrice} <span data-i18n="admin_currency">${typeof window.t === 'function' ? window.t('admin_currency') : 'EGP'}</span>${svc.priceUnit === 'per_hour' ? ' /hr' : (svc.priceUnit === 'per_sqm' ? ' /sqm' : '')}`
          : '—';

        tr.innerHTML = `
          <td style="font-weight:600;" data-i18n="${nameKey}">${svc.title}</td>
          <td>
            <span class="bk-badge" style="background:rgba(154,140,115,0.1); color:var(--color-accent);" data-i18n="${catKey}">
              ${svc.category}
            </span>
          </td>
          <td class="bk-amount center-align" style="font-family: monospace;">
            ${priceText}
          </td>
          <td style="text-align:center;">
            <span class="bk-badge ${svc.isActive === false ? 'bk-badge--cancelled' : 'bk-badge--completed'} status-badge" data-i18n="status_${svc.isActive !== false ? 'active' : 'inactive'}">${svc.isActive !== false ? 'Active' : 'Inactive'}</span>
          </td>
          <td>
            <div class="table-actions" style="justify-content:center;">
              <button class="bk-action-btn bk-action-btn--xs" data-id="${svc._id}" data-action="edit-service" title="Edit">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 113 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
              </button>
              <button class="bk-action-btn bk-action-btn--xs bk-action-btn--delete" data-id="${svc._id}" data-action="delete-service" title="Delete">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/></svg>
              </button>
            </div>
          </td>
        `;
        list.appendChild(tr);
      });

      // Re-attach listeners with Mongo _id
      list.querySelectorAll('[data-action="edit-service"]').forEach(btn => {
        btn.addEventListener('click', () => editService(btn.dataset.id, apiServices));
      });
      list.querySelectorAll('[data-action="delete-service"]').forEach(btn => {
        btn.addEventListener('click', () => deleteService(btn.dataset.id));
      });

      _updateServiceKPIs(apiServices);
      _applyServiceFilters();

      // Update pagination footer with actual count
      const svcInfoEl = document.getElementById('servicePaginationInfo');
      if (svcInfoEl) {
        const t = (typeof window.t === 'function') ? window.t : (k) => k;
        svcInfoEl.setAttribute('data-i18n-v', apiServices.length);
        svcInfoEl.setAttribute('data-i18n-n', apiServices.length);
        svcInfoEl.textContent = t('admin_pagination_services').replace('{v}', apiServices.length).replace('{n}', apiServices.length);
      }
      
      if (typeof window.translatePage === 'function') window.translatePage();
      
    } catch (err) {
      console.error('Failed to fetch services:', err);
      showToast('Error loading services list', 'error');
    }
  }

  function _updateServiceKPIs(services = []) {
    const totalEl = document.getElementById('totalServicesCount');
    const categoriesEl = document.getElementById('activeCategoriesCount');
    const topCatEl = document.getElementById('topServiceCategory');
    if (totalEl) totalEl.textContent = services.length;
    if (categoriesEl) {
      const cats = new Set(services.map(s => s.category));
      categoriesEl.textContent = cats.size;
    }
    if (topCatEl && services.length > 0) {
      const counts = services.reduce((acc, s) => {
        acc[s.category] = (acc[s.category] || 0) + 1;
        return acc;
      }, {});
      const topCat = Object.keys(counts).reduce((a, b) => counts[a] > counts[b] ? a : b);
      topCatEl.textContent = topCat;
      topCatEl.dataset.i18n = 'skill_' + topCat.toLowerCase();
      // Force individual translation for the dynamic KPI
      if (typeof window.translatePage === 'function') window.translatePage();
    }
  }

  function _applyServiceFilters() {
    const q = (document.getElementById('serviceSearch')?.value || '').toLowerCase();
    const cat = document.getElementById('serviceCategoryFilter')?.value || 'All';

    document.querySelectorAll('.service-row').forEach(row => {
      const name = row.querySelector('.table-cell--bold')?.textContent.toLowerCase() || '';
      const rowCat = row.dataset.category;
      
      const matchQ = q === '' || name.includes(q);
      const matchCat = cat === 'All' || rowCat === cat;

      row.classList.toggle('is-hidden', !matchQ || !matchCat);
      row.style.display = (matchQ && matchCat) ? '' : 'none';
    });

    const infoEl = document.getElementById('servicePaginationInfo');
    const visibleCount = document.querySelectorAll('.service-row:not(.is-hidden)').length;
    const total = document.querySelectorAll('.service-row').length;
    if (infoEl) {
      const t = (typeof window.t === 'function') ? window.t : (k) => k;
      infoEl.textContent = t('admin_pagination_services')
        .replace('{v}', visibleCount)
        .replace('{n}', total);
    }
  }

  // Modal logic
  const serviceModal = document.getElementById('serviceModal');
  const serviceForm = document.getElementById('serviceForm');

  async function openModal(id = null, serviceList = []) {
    const title = document.getElementById('serviceModalTitle');
    const saveBtnText = document.getElementById('saveServiceBtn');
    
    if (id) {
      const svc = serviceList.find(s => s._id === id);
      if (!svc) return;

      title.textContent = typeof window.t === 'function' ? window.t('admin_modal_edit_service_title') : 'Edit Service';
      title.setAttribute('data-i18n', 'admin_modal_edit_service_title');
      document.getElementById('serviceId').value = svc._id;
      document.getElementById('serviceName').value = svc.title || '';
      document.getElementById('serviceDesc').value = svc.description || svc.desc || '';
      document.getElementById('serviceCategory').value = svc.category || '';
      document.getElementById('priceUnit').value = svc.priceUnit || 'per_hour';
      document.getElementById('basePrice').value = svc.basePrice || '';
      saveBtnText.textContent = typeof window.t === 'function' ? window.t('admin_btn_save_changes') : 'Save Changes';
      saveBtnText.setAttribute('data-i18n', 'admin_btn_save_changes');
    } else {
      title.textContent = typeof window.t === 'function' ? window.t('admin_modal_add_service_title') : 'Add New Service';
      title.setAttribute('data-i18n', 'admin_modal_add_service_title');
      serviceForm.reset();
      document.getElementById('serviceId').value = '';
      saveBtnText.textContent = typeof window.t === 'function' ? window.t('admin_btn_add_service') : 'Add Service';
      saveBtnText.setAttribute('data-i18n', 'admin_btn_add_service');
    }
    
    serviceModal.hidden = false;
    if (typeof window.translatePage === 'function') window.translatePage();
  }

  function closeModal() {
    serviceModal.hidden = true;
  }

  document.getElementById('openAddServiceModal')?.addEventListener('click', () => openModal());
  document.getElementById('closeServiceModal')?.addEventListener('click', closeModal);
  document.getElementById('cancelServiceBtn')?.addEventListener('click', closeModal);
  document.getElementById('serviceSearch')?.addEventListener('input', _applyServiceFilters);
  document.getElementById('serviceCategoryFilter')?.addEventListener('change', _applyServiceFilters);

  serviceForm?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = document.getElementById('serviceId').value;
    const data = { 
      title: document.getElementById('serviceName').value.trim(), 
      description: document.getElementById('serviceDesc').value.trim(), 
      category: document.getElementById('serviceCategory').value.toLowerCase(), 
      basePrice: parseInt(document.getElementById('basePrice').value) || 0,
      priceUnit: document.getElementById('priceUnit').value
    };

    try {
      if (id) {
        await updateService(id, data);
        showToast('Service updated', 'success');
      } else {
        await createService(data);
        showToast('New service added', 'success');
      }
      
      closeModal();
      renderServicesList();
    } catch (err) {
      console.error('Failed to save service:', err);
      showToast('Error saving service data', 'error');
    }
  });

  function editService(id, serviceList) {
    openModal(id, serviceList);
  }

  async function deleteService(id) {
    if (confirm('Are you sure you want to delete this service?')) {
      try {
        await apiDeleteService(id);
        renderServicesList();
        showToast('Service deleted', 'error');
      } catch (err) {
        console.error('Failed to delete service:', err);
        showToast('Error deleting service', 'error');
      }
    }
  }

  // Init services
  renderServicesList();


  // ──────────────────────────────────────────────────────────
  //  SETTINGS — STAB TAB SWITCHING
  // ──────────────────────────────────────────────────────────
  function initSettingsStabs() {
    const bar   = document.getElementById('adminSettingsTabBar');
    if (!bar) return;
    const btns  = bar.querySelectorAll('.stab-btn');
    const panes = document.querySelectorAll('[id^="admin-stab-"]');

    btns.forEach(btn => {
      btn.addEventListener('click', () => {
        const target = btn.dataset.stab;
        btns.forEach(b => {
          b.classList.toggle('stab-btn--active', b.dataset.stab === target);
          b.setAttribute('aria-selected', b.dataset.stab === target ? 'true' : 'false');
        });
        panes.forEach(p => {
          const match = p.id === `admin-stab-${target}`;
          p.classList.toggle('stab-pane--active', match);
          if (match) p.removeAttribute('hidden'); else p.setAttribute('hidden', '');
        });
      });
    });
  }
  initSettingsStabs();

  // ──────────────────────────────────────────────────────────
  //  SETTINGS — TOGGLE SWITCH HANDLER
  // ──────────────────────────────────────────────────────────
  document.querySelectorAll('.stab-toggle').forEach(btn => {
    btn.addEventListener('click', () => {
      const on = btn.getAttribute('aria-checked') !== 'true';
      btn.setAttribute('aria-checked', on ? 'true' : 'false');
      btn.classList.toggle('stab-toggle--on', on);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  SETTINGS — LOAD / SAVE (localStorage)
  // ──────────────────────────────────────────────────────────
  const _T = k => (typeof window.t === 'function' ? window.t(k) : k);

  function _setToggle(id, value) {
    const el = document.getElementById(id);
    if (!el) return;
    const on = !!value;
    el.setAttribute('aria-checked', on ? 'true' : 'false');
    el.classList.toggle('stab-toggle--on', on);
  }

  function _getToggle(id) {
    const el = document.getElementById(id);
    return el ? el.getAttribute('aria-checked') === 'true' : false;
  }

  function _applySettings(saved) {
    if (!saved) return;
    if (saved.commissionRate    != null) document.getElementById('commissionRate').value    = saved.commissionRate;
    if (saved.maxCashLiability  != null) document.getElementById('maxCashLiability').value  = saved.maxCashLiability;
    if (saved.autoReleaseWindow != null) document.getElementById('autoReleaseWindow').value = saved.autoReleaseWindow;
    if (saved.minDepositPct     != null) document.getElementById('minDepositPct').value     = saved.minDepositPct;
    if (saved.minBookingAmount  != null) document.getElementById('minBookingAmount').value  = saved.minBookingAmount;
    if (saved.cashPaymentsEnabled != null) _setToggle('toggleCashPayments', saved.cashPaymentsEnabled);
    if (saved.reqNationalId   != null) _setToggle('toggleReqNationalId', saved.reqNationalId);
    if (saved.reqTradeLicense != null) _setToggle('toggleReqTradeLicense', saved.reqTradeLicense);
    if (saved.autoSuspendDisputes != null) document.getElementById('autoSuspendDisputes').value = saved.autoSuspendDisputes;
    if (saved.minRatingFlag   != null) document.getElementById('minRatingFlag').value   = saved.minRatingFlag;
    if (saved.maxCashJobsDay  != null) document.getElementById('maxCashJobsDay').value  = saved.maxCashJobsDay;
    if (saved.notifNewUser       != null) _setToggle('notifNewUser', saved.notifNewUser);
    if (saved.notifNewTech       != null) _setToggle('notifNewTech', saved.notifNewTech);
    if (saved.notifNewDispute    != null) _setToggle('notifNewDispute', saved.notifNewDispute);
    if (saved.notifOverduePayment!= null) _setToggle('notifOverduePayment', saved.notifOverduePayment);
    if (saved.notifDailySummary  != null) _setToggle('notifDailySummary', saved.notifDailySummary);
    if (saved.adminAlertEmail    != null && document.getElementById('adminAlertEmail'))
      document.getElementById('adminAlertEmail').value = saved.adminAlertEmail;
    if (saved.twoFAEnabled    != null) _setToggle('toggle2FA', saved.twoFAEnabled);
    if (saved.sessionTimeout  != null) document.getElementById('sessionTimeout').value = saved.sessionTimeout;
    if (saved.maintenanceMode != null) _setToggle('toggleMaintenance', saved.maintenanceMode);
    if (saved.platformName    != null) document.getElementById('platformName').value    = saved.platformName;
    if (saved.supportEmail    != null) document.getElementById('supportEmail').value    = saved.supportEmail;
    if (saved.maxUploadSize   != null) document.getElementById('maxUploadSize').value   = saved.maxUploadSize;
    if (saved.flagAiMatch     != null) _setToggle('flagAiMatch',     saved.flagAiMatch);
    if (saved.flagCashPayments!= null) _setToggle('flagCashPayments',saved.flagCashPayments);
    if (saved.flagTechSignup  != null) _setToggle('flagTechSignup',  saved.flagTechSignup);
    if (saved.flagReviews     != null) _setToggle('flagReviews',     saved.flagReviews);
    const warnEl = document.getElementById('settingCashDebtWarningThreshold');
    const blockEl = document.getElementById('settingCashDebtBlockThreshold');
    const autoEl  = document.getElementById('settingCashDebtAutoBlockEnabled');
    if (warnEl)  warnEl.value   = saved.cashDebtWarningThreshold ?? 1000;
    if (blockEl) blockEl.value  = saved.cashDebtBlockThreshold ?? 5000;
    if (autoEl)  autoEl.checked = saved.cashDebtAutoBlockEnabled !== false;
  }

  // Load settings from API, fall back to localStorage
  getAdminSettings().then(data => _applySettings(data)).catch(() => {
    const saved = JSON.parse(localStorage.getItem('servio_admin_config') || 'null');
    _applySettings(saved);
  });

  async function _saveConfig(patch) {
    try {
      await updateAdminSettings(patch);
    } catch {
      const current = JSON.parse(localStorage.getItem('servio_admin_config') || '{}');
      localStorage.setItem('servio_admin_config', JSON.stringify({ ...current, ...patch }));
    }
  }

  // Platform form
  document.getElementById('adminSettingsForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const warn  = Number(document.getElementById('settingCashDebtWarningThreshold')?.value);
    const block = Number(document.getElementById('settingCashDebtBlockThreshold')?.value);
    if (warn > 0 && block > 0 && block <= warn) {
      showToast(window.t?.('admin_debt_block_gt_warning') || 'Block threshold must be greater than warning threshold.', 'error');
      return;
    }
    await _saveConfig({
      commissionRate:       document.getElementById('commissionRate')?.value,
      maxCashLiability:     document.getElementById('maxCashLiability')?.value,
      autoReleaseWindow:    document.getElementById('autoReleaseWindow')?.value,
      minDepositPct:        document.getElementById('minDepositPct')?.value,
      minBookingAmount:     document.getElementById('minBookingAmount')?.value,
      cashPaymentsEnabled:  _getToggle('toggleCashPayments'),
      cashDebtWarningThreshold: Number(document.getElementById('settingCashDebtWarningThreshold')?.value || 1000),
      cashDebtBlockThreshold:   Number(document.getElementById('settingCashDebtBlockThreshold')?.value || 5000),
      cashDebtAutoBlockEnabled: document.getElementById('settingCashDebtAutoBlockEnabled')?.checked !== false,
    });
    showToast(_T('toast_admin_settings_saved'), 'success');
  });

  // Moderation form
  document.getElementById('adminModerationForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    await _saveConfig({
      reqNationalId:        _getToggle('toggleReqNationalId'),
      reqTradeLicense:      _getToggle('toggleReqTradeLicense'),
      autoSuspendDisputes:  document.getElementById('autoSuspendDisputes')?.value,
      minRatingFlag:        document.getElementById('minRatingFlag')?.value,
      maxCashJobsDay:       document.getElementById('maxCashJobsDay')?.value,
    });
    showToast(_T('toast_admin_settings_saved'), 'success');
  });

  // Notifications form
  document.getElementById('adminNotifForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    await _saveConfig({
      notifNewUser:         _getToggle('notifNewUser'),
      notifNewTech:         _getToggle('notifNewTech'),
      notifNewDispute:      _getToggle('notifNewDispute'),
      notifOverduePayment:  _getToggle('notifOverduePayment'),
      notifDailySummary:    _getToggle('notifDailySummary'),
      adminAlertEmail:      document.getElementById('adminAlertEmail')?.value,
    });
    showToast(_T('toast_admin_settings_saved'), 'success');
  });

  // System form
  document.getElementById('adminSystemForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const isMaint = _getToggle('toggleMaintenance');
    await _saveConfig({
      maintenanceMode:  isMaint,
      platformName:     document.getElementById('platformName')?.value,
      supportEmail:     document.getElementById('supportEmail')?.value,
      maxUploadSize:    document.getElementById('maxUploadSize')?.value,
      flagAiMatch:      _getToggle('flagAiMatch'),
      flagCashPayments: _getToggle('flagCashPayments'),
      flagTechSignup:   _getToggle('flagTechSignup'),
      flagReviews:      _getToggle('flagReviews'),
    });
    showToast(isMaint ? _T('toast_maintenance_on') : _T('toast_admin_settings_saved'), isMaint ? 'warn' : 'success');
  });

  // ──────────────────────────────────────────────────────────
  //  SETTINGS — PASSWORD STRENGTH METER
  // ──────────────────────────────────────────────────────────
  const newPwdInput     = document.getElementById('newPwd');
  const pwStrengthFill  = document.getElementById('adminPwStrengthFill');
  const pwStrengthLabel = document.getElementById('adminPwStrengthLabel');

  function _pwStrength(pw) {
    let score = 0;
    if (pw.length >= 8)  score++;
    if (pw.length >= 12) score++;
    if (/[A-Z]/.test(pw)) score++;
    if (/[0-9]/.test(pw)) score++;
    if (/[^A-Za-z0-9]/.test(pw)) score++;
    return score;
  }

  newPwdInput?.addEventListener('input', () => {
    const score = _pwStrength(newPwdInput.value);
    const pct   = Math.min(100, score * 20) + '%';
    const colors = ['#ef4444','#f97316','#eab308','#22c55e','#10b981'];
    const labels = [
      _T('pw_strength_very_weak') || 'Very Weak',
      _T('pw_strength_weak')      || 'Weak',
      _T('pw_strength_fair')      || 'Fair',
      _T('pw_strength_strong')    || 'Strong',
      _T('pw_strength_very_strong')|| 'Very Strong',
    ];
    if (pwStrengthFill) {
      pwStrengthFill.style.width = pct;
      pwStrengthFill.style.background = colors[Math.max(0, score - 1)] || colors[0];
    }
    if (pwStrengthLabel) {
      pwStrengthLabel.textContent = newPwdInput.value ? (labels[Math.max(0, score - 1)] || labels[0]) : '';
    }
  });

  document.getElementById('adminPwdForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const currentPw = document.getElementById('currentPwd')?.value;
    const newPw  = document.getElementById('newPwd')?.value;
    const confPw = document.getElementById('confirmPwd')?.value;
    const errEl  = document.getElementById('adminPwdError');
    if (newPw !== confPw) {
      if (errEl) { errEl.textContent = 'Passwords do not match'; errEl.hidden = false; }
      return;
    }
    if (errEl) errEl.hidden = true;
    try {
      await updatePassword({ currentPassword: currentPw, newPassword: newPw });
      showToast(_T('toast_password_changed') || 'Password updated', 'success');
      ['currentPwd','newPwd','confirmPwd'].forEach(id => {
        const el = document.getElementById(id); if (el) el.value = '';
      });
      if (pwStrengthFill)  pwStrengthFill.style.width = '0%';
      if (pwStrengthLabel) pwStrengthLabel.textContent = '';
    } catch (err) {
      if (errEl) { errEl.textContent = err.message || 'Failed to update password'; errEl.hidden = false; }
    }
  });

  document.getElementById('terminateOtherSessionsBtn')?.addEventListener('click', () => {
    showToast(_T('toast_sessions_terminated') || 'Other sessions terminated', 'success');
  });

  // ──────────────────────────────────────────────────────────
  //  SETTINGS — ROLE ASSIGNMENT
  // ──────────────────────────────────────────────────────────
  const _roleAssignments = JSON.parse(localStorage.getItem('servio_role_assignments') || '[]');

  function _saveRoleAssignments() {
    localStorage.setItem('servio_role_assignments', JSON.stringify(_roleAssignments));
  }

  function _renderRoleAssignments() {
    const listEl  = document.getElementById('roleAssignmentsList');
    const emptyEl = document.getElementById('roleAssignmentsEmpty');
    if (!listEl) return;

    // Remove old items (keep the empty notice)
    listEl.querySelectorAll('.role-assignment-item').forEach(el => el.remove());

    if (_roleAssignments.length === 0) {
      if (emptyEl) emptyEl.hidden = false;
      return;
    }
    if (emptyEl) emptyEl.hidden = true;

    const roleLabels = {
      support:    _T('admin_role_support'),
      finance:    _T('admin_role_finance'),
      moderator:  _T('admin_role_moderator'),
      super_admin:_T('admin_role_super_admin'),
    };

    _roleAssignments.forEach((ra, idx) => {
      const div = document.createElement('div');
      div.className = 'role-assignment-item';
      div.innerHTML = `
        <span class="role-assignment-item__name">${ra.userName}</span>
        <span class="role-assignment-item__role role-badge--${ra.role}">${roleLabels[ra.role] || ra.role}</span>
        <button type="button" class="role-assignment-item__remove" aria-label="Remove" data-idx="${idx}">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
        </button>`;
      listEl.appendChild(div);
    });

    listEl.querySelectorAll('.role-assignment-item__remove').forEach(btn => {
      btn.addEventListener('click', () => {
        _roleAssignments.splice(parseInt(btn.dataset.idx), 1);
        _saveRoleAssignments();
        _renderRoleAssignments();
      });
    });
  }
  _renderRoleAssignments();

  document.getElementById('adminRoleAssignForm')?.addEventListener('submit', e => {
    e.preventDefault();
    const userSel = document.getElementById('roleAssignUser');
    const roleSel = document.getElementById('roleAssignRole');
    if (!userSel?.value || !roleSel?.value) return;

    // Replace existing assignment for that user
    const existingIdx = _roleAssignments.findIndex(r => r.userId === userSel.value);
    const entry = { userId: userSel.value, userName: userSel.options[userSel.selectedIndex].text, role: roleSel.value };
    if (existingIdx !== -1) _roleAssignments[existingIdx] = entry;
    else _roleAssignments.push(entry);

    _saveRoleAssignments();
    _renderRoleAssignments();
    showToast(_T('toast_role_assigned'), 'success');
    userSel.value = '';
  });

  // ── Logout ─────────────────────────────────
  document.getElementById('adminLogout')?.addEventListener('click', () => {
    localStorage.removeItem('servio_session');
    window.location.href = './login.html';
  });

  // ── Export Report button ───────────────────────────────
  document.getElementById('exportReportBtn')?.addEventListener('click', () => {
    showToast(typeof window.t === 'function' ? window.t('toast_report_exported') : 'Report exported successfully', 'success');
  });

  // ── Analytics Filters ────────────────────────────────────
  const btnApplyAnalyticFilters = document.getElementById('applyAnalyticsFilters');
  const btnResetAnalyticFilters = document.getElementById('resetAnalyticsFilters');
  
  async function applyAnalyticsChartChanges(srvVal) {
    let stats = {};
    try {
      const res = await getAnalytics();
      stats = res || {};
    } catch {}

    const bookings = stats.bookings || {};
    const bCompleted = bookings.completed || 0;
    const bCancelled = bookings.cancelled || 0;
    const bPending   = bookings.pending   || 0;
    const bProgress  = bookings.in_progress || 0;
    const totalUsers = stats.users || 0;

    // Update vertical bar chart with real booking counts
    const barValues = [bPending, bProgress, bCompleted, bCancelled, totalUsers];
    const maxVal = Math.max(...barValues, 1);
    const vertBars = document.querySelectorAll('.analytics-bar');
    vertBars.forEach((bar, i) => {
      const val = barValues[i] != null ? barValues[i] : 0;
      const pct = Math.round((val / maxVal) * 100);
      bar.style.setProperty('--bar-height', pct + '%');
      bar.textContent = val;
    });

    // Update horizontal bar chart visibility
    const chartItems = document.querySelectorAll('#analyticsServicesChart .analytics-hbar-item');
    chartItems.forEach(item => {
      const itemSvc = item.dataset.service || '';
      if (srvVal === '' || itemSvc === srvVal) {
        item.style.display = 'flex';
      } else {
        item.style.display = 'none';
      }
    });
  }

  if (btnApplyAnalyticFilters) {
    btnApplyAnalyticFilters.addEventListener('click', async () => {
      const srvFilter = document.getElementById('analyticsServiceFilter');
      const srvVal = srvFilter ? srvFilter.value : '';
      await applyAnalyticsChartChanges(srvVal);
      showToast(window.__lang === 'ar' ? 'ØªÙ… ØªØ·Ø¨ÙŠÙ‚ Ø§Ù„ÙÙ„Ø§ØªØ± ÙˆØ§Ù„ØªØ­Ù„ÙŠÙ„Ø§Øª' : 'Analytics filters applied', 'success');
    });
  }

  if (btnResetAnalyticFilters) {
    btnResetAnalyticFilters.addEventListener('click', () => {
       const filters = ['analyticsDateFilter', 'analyticsServiceFilter', 'analyticsRegionFilter'];
       filters.forEach(id => {
         const el = document.getElementById(id);
         if (el) el.value = ''; 
       });
       const dFilter = document.getElementById('analyticsDateFilter');
       if (dFilter) dFilter.value = '30'; // Default is usually Last 30 Days

       applyAnalyticsChartChanges('');
       showToast(window.__lang === 'ar' ? 'ØªÙ… Ø¥Ø¹Ø§Ø¯Ø© Ø¶Ø¨Ø· Ø§Ù„ÙÙ„Ø§ØªØ±' : 'Filters reset successfully', 'info');
    });
  }

  // ── Overview date — set on init and on language switch ──
  _updateOverviewDate();
  document.addEventListener('langchange', () => {
    _updateOverviewDate();
    _updateUserCount();
    _loadAuditPage();
  });

  // ── Mobile sidebar toggle ──────────────────────────────
  const sidebar        = document.querySelector('.admin-sidebar');
  const overlay        = document.getElementById('sidebarOverlay');
  const mobileToggle   = document.getElementById('sidebarToggle');

  function openSidebar()  { sidebar?.classList.add('is-open');    overlay?.classList.add('is-active'); }
  function closeSidebar() { sidebar?.classList.remove('is-open'); overlay?.classList.remove('is-active'); }

  mobileToggle?.addEventListener('click', () => {
    sidebar?.classList.contains('is-open') ? closeSidebar() : openSidebar();
  });
  overlay?.addEventListener('click', closeSidebar);

  // Close sidebar on nav click on mobile
  navBtns.forEach(btn => btn.addEventListener('click', () => {
    if (window.innerWidth <= 768) closeSidebar();
  }));

  // ──────────────────────────────────────────────────────────
  //  AUDIT LOG — API-driven
  // ──────────────────────────────────────────────────────────
  let _auditPage = 1;
  let _auditTotalPages = 1;
  let _lastAuditLogs = [];

  const _auditTypeLabel = type => {
    const map = {
      auth:     _T('admin_audit_type_auth')     || 'Authentication',
      user:     _T('admin_audit_type_user')     || 'User Management',
      settings: _T('admin_audit_type_settings') || 'Settings',
      booking:  _T('admin_audit_type_booking')  || 'Booking',
      finance:  _T('admin_audit_type_finance')  || 'Finance',
      system:   _T('admin_audit_type_system')   || 'System',
    };
    return map[type] || type;
  };

  const _auditStatusLabel = s =>
    ({ ok: _T('admin_audit_status_ok') || 'OK', warn: _T('admin_audit_status_warn') || 'Warn', fail: _T('admin_audit_status_fail') || 'Fail' }[s] || s);

  function _renderAuditRows(logs) {
    const tbody   = document.getElementById('auditLogBody');
    const emptyEl = document.getElementById('auditTableEmpty');
    if (!tbody) return;

    if (!logs.length) {
      tbody.innerHTML = '';
      if (emptyEl) emptyEl.hidden = false;
      return;
    }
    if (emptyEl) emptyEl.hidden = true;

    tbody.innerHTML = logs.map(r => {
      const ts     = r.createdAt ? new Date(r.createdAt).toLocaleString('en-GB') : '—';
      const actor  = r.actor?.email || 'unknown';
      const icon   = r.status === 'ok' ? '✓' : r.status === 'warn' ? '⚠' : '✕';
      return `<tr>
        <td class="audit-ts">${ts}</td>
        <td class="audit-actor">${actor}</td>
        <td class="audit-action"><span class="audit-type-pill">${_auditTypeLabel(r.type)}</span><br>${r.action}</td>
        <td class="audit-target">${r.target || '—'}</td>
        <td class="audit-actions">
          <button class="bk-action-btn bk-action-btn--xs bk-action-btn--delete" data-audit-delete="${r._id}">
            ${_T('admin_audit_remove_btn') || 'Remove'}
          </button>
        </td>
        <td><span class="audit-badge audit-badge--${r.status}">${icon} ${_auditStatusLabel(r.status)}</span></td>
      </tr>`;
    }).join('');
  }

  async function _loadAuditPage() {
    const q    = document.getElementById('auditSearchInput')?.value || '';
    const type = document.getElementById('auditTypeFilter')?.value  || '';
    const days = document.getElementById('auditDateFilter')?.value  || '';

    try {
      const res = await getAuditLogs({ q, type, days, page: _auditPage, limit: 15 });
      const logs      = res.logs || [];
      const pagination = res.pagination || {};
      const stats     = res.stats || {};

      _lastAuditLogs  = logs;
      _auditTotalPages = pagination.totalPages || 1;

      _renderAuditRows(logs);

      const pageInfo = document.getElementById('auditPageInfo');
      const prevBtn  = document.getElementById('auditPrevBtn');
      const nextBtn  = document.getElementById('auditNextBtn');
      if (pageInfo) pageInfo.textContent = `${_auditPage} / ${_auditTotalPages}`;
      if (prevBtn)  prevBtn.disabled = _auditPage <= 1;
      if (nextBtn)  nextBtn.disabled = _auditPage >= _auditTotalPages;

      const totalEl = document.getElementById('auditTotalCount');
      const todayEl = document.getElementById('auditTodayCount');
      const failEl  = document.getElementById('auditFailedCount');
      if (totalEl) totalEl.textContent = stats.total  ?? pagination.total ?? '—';
      if (todayEl) todayEl.textContent = stats.todayCount ?? '—';
      if (failEl)  failEl.textContent  = stats.failCount  ?? '—';
    } catch (err) {
      console.error('Audit log fetch failed:', err);
    }
  }

  function _applyAuditFilters() {
    _auditPage = 1;
    _loadAuditPage();
  }

  document.getElementById('auditSearchInput')?.addEventListener('input', _applyAuditFilters);
  document.getElementById('auditTypeFilter')?.addEventListener('change', _applyAuditFilters);
  document.getElementById('auditDateFilter')?.addEventListener('change', _applyAuditFilters);

  document.getElementById('auditPrevBtn')?.addEventListener('click', () => { _auditPage = Math.max(1, _auditPage - 1); _loadAuditPage(); });
  document.getElementById('auditNextBtn')?.addEventListener('click', () => { _auditPage = Math.min(_auditTotalPages, _auditPage + 1); _loadAuditPage(); });

  document.getElementById('auditLogBody')?.addEventListener('click', async (e) => {
    const delBtn = e.target.closest('[data-audit-delete]');
    if (!delBtn) return;
    
    const id = delBtn.dataset.auditDelete;
    const confirmMsg = _T('admin_audit_delete_confirm') || 'Are you sure you want to remove this log entry?';
    if (!confirm(confirmMsg)) return;

    try {
      await deleteAuditLog(id);
      showToast(_T('toast_audit_deleted') || 'Audit log entry removed', 'success');
      _loadAuditPage(); // reload current page
    } catch (err) {
      console.error('Failed to delete audit log:', err);
      showToast(err.message || 'Failed to remove log', 'error');
    }
  });

  document.getElementById('auditExportBtn')?.addEventListener('click', () => {
    const rows = [[
      _T('admin_audit_col_time')   || 'Timestamp',
      _T('admin_audit_col_actor')  || 'Actor',
      _T('admin_audit_type_col')   || 'Type',
      _T('admin_audit_col_action') || 'Action',
      _T('admin_audit_col_target') || 'Target',
      _T('admin_audit_col_ip')     || 'IP Address',
      _T('admin_audit_col_status') || 'Status',
    ]];
    _lastAuditLogs.forEach(r => {
      rows.push([
        r.createdAt ? new Date(r.createdAt).toLocaleString('en-GB') : '—',
        r.actor?.email || 'unknown',
        _auditTypeLabel(r.type),
        r.action,
        r.target || '—',
        r.ip || '—',
        _auditStatusLabel(r.status),
      ]);
    });
    const csv  = rows.map(r => r.map(v => `"${String(v).replace(/"/g,'""')}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href = url; a.download = (_T('admin_audit_export_filename') || 'audit-log') + '.csv'; a.click();
    URL.revokeObjectURL(url);
    showToast(_T('toast_audit_exported') || 'Audit log exported', 'success');
  });

  // Refresh when switching to audit panel
  navBtns.forEach(btn => {
    if (btn.dataset.tab === 'audit') {
      btn.addEventListener('click', () => { _auditPage = 1; _loadAuditPage(); });
    }
    if (btn.dataset.tab === 'payments') {
      btn.addEventListener('click', () => {
        renderPendingApprovals();
        renderCashDebts();
      });
    }
  });

  // Initial load
  _loadAuditPage();

  // Expose local modal helpers to loadAdminData (defined at module scope)
  _openProfileModal     = openProfileModal;
  _openTechProfileModal = openTechProfileModal;

  loadAdminData();
  let _adminPollInterval = null;
  const startAdminPolling = () => {
    if (_adminPollInterval) clearInterval(_adminPollInterval);
    _adminPollInterval = setInterval(() => loadAdminData(), 30000);
  };
  const stopAdminPolling = () => { if (_adminPollInterval) clearInterval(_adminPollInterval); _adminPollInterval = null; };
  startAdminPolling();
  document.addEventListener('visibilitychange', () => { document.hidden ? stopAdminPolling() : startAdminPolling(); });
}

async function loadAdminData() {
  const _set = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = String(val); };

  // ── Users (Customers) ──────────────────────────────────────────────────────
  try {
    const res = await getAllUsers({ role: 'user', limit: 100 });
    const users = res.users || [];
    const total = res.pagination?.total ?? users.length;
    const active = users.filter(u => u.isActive).length;
    const suspended = users.filter(u => !u.isActive).length;
    const now = new Date();
    const newThisMonth = users.filter(u => {
      const d = new Date(u.createdAt);
      return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
    }).length;

    const usersRoot = document.querySelector('#usersTable tbody');
    if (usersRoot) {
      if (users.length === 0) {
        usersRoot.innerHTML = '<tr><td colspan="6" class="center-align" style="padding: 2rem;">No customers found.</td></tr>';
      } else {
        usersRoot.innerHTML = users.map(u => {
          const status = u.isActive ? 'active' : 'suspended';
          const badgeClass = u.isActive ? 'bk-badge--completed' : 'bk-badge--overdue';
          const date = u.createdAt ? new Date(u.createdAt).toLocaleDateString('en-US', {month:'short', day:'numeric', year:'numeric'}) : '—';
          return `<tr class="user-row" data-user-id="${u._id}" data-status="${status}">
            <td><div class="user-name" style="font-weight:600;">${u.name || '—'}</div></td>
            <td><div class="user-email" style="color:var(--color-text-muted);">${u.email || '—'}</div></td>
            <td>${date}</td>
            <td class="center-align" style="font-weight:600;color:var(--color-text);">—</td>
            <td><span class="bk-badge ${badgeClass} status-badge">${status === 'active' ? 'Active' : 'Suspended'}</span></td>
            <td>
              <div class="table-actions">
                <button class="bk-action-btn bk-action-btn--xs" data-view-user="${u._id}">View</button>
                <button class="bk-action-btn bk-action-btn--xs bk-action-btn--suspend" data-admin-toggle-user="${u._id}" data-active="${u.isActive}">
                  ${u.isActive ? 'Suspend' : 'Activate'}
                </button>
                <button class="bk-action-btn bk-action-btn--xs bk-action-btn--delete" data-admin-delete-user="${u._id}">Delete</button>
              </div>
            </td>
          </tr>`;
        }).join('');

        // Attach View modal listeners now that rows exist
        usersRoot.querySelectorAll('[data-view-user]').forEach(btn => {
          const u = users.find(usr => usr._id === btn.dataset.viewUser);
          if (!u) return;
          btn.addEventListener('click', () => {
            const date = u.createdAt ? new Date(u.createdAt).toLocaleDateString('en-US', {month:'short', day:'numeric', year:'numeric'}) : '—';
            const statusText = u.isActive ? 'Active' : 'Suspended';
            const initials = (u.name || 'U').split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
            document.getElementById('userModalAvatar').textContent    = initials;
            document.getElementById('userModalName').textContent      = u.name || '—';
            document.getElementById('userModalEmail').textContent     = u.email || '—';
            document.getElementById('userModalId').textContent        = `#U-${u._id.slice(-4)}`;
            document.getElementById('userModalJoinDate').textContent  = date;
            document.getElementById('userModalBookings').textContent  = '—';
            document.getElementById('userModalStatus').textContent    = statusText;
            const badge = document.getElementById('userModalStatusBadge');
            badge.textContent = statusText;
            badge.className = u.isActive ? 'bk-badge bk-badge--completed' : 'bk-badge bk-badge--overdue';
            _openProfileModal('userViewModal');
          });
        });
      }
    }

    _set('kpi-overview-users', total.toLocaleString());
    _set('kpi-users-total', total.toLocaleString());
    _set('kpi-users-active', active.toLocaleString());
    _set('kpi-users-suspended', suspended.toLocaleString());
    _set('kpi-users-new', newThisMonth.toLocaleString());

    // Update pagination footer with actual count
    const userInfoEl = document.getElementById('userPaginationInfo');
    if (userInfoEl) {
      const t = (typeof window.t === 'function') ? window.t : (k) => k;
      userInfoEl.setAttribute('data-i18n-v', users.length);
      userInfoEl.setAttribute('data-i18n-n', users.length);
      userInfoEl.textContent = t('admin_pagination_users').replace('{v}', users.length).replace('{n}', users.length);
    }
  } catch (err) { console.error('Error loading users:', err); }

  // ── Technicians (Workers) ───────────────────────────────────────────────────
  try {
    const res = await getAllUsers({ role: 'worker', limit: 100 });
    const techs = res.users || [];
    const techTotal = res.pagination?.total ?? techs.length;
    const pendingTechs = techs.filter(t => getVerificationStatus(t) === 'pending');
    const verifiedTechs = techs.filter(t => getVerificationStatus(t) === 'approved');
    const suspendedTechs = techs.filter(t => !t.isActive);

    const techsRoot = document.querySelector('#allTechsTable tbody');
    if (techsRoot) {
      if (techs.length === 0) {
        techsRoot.innerHTML = '<tr><td colspan="9" class="center-align" style="padding: 2rem;">No technicians found.</td></tr>';
      } else {
        techsRoot.innerHTML = techs.map((u) => {
          const status = getTechStatusLabel(u);
          const badgeClass = getTechStatusBadgeClass(u);
          return `
          <tr class="booking-row" data-status="${status}">
            <td><div class="t-name" style="font-weight:600;">${escapeHtml(u.name || '—')}</div></td>
            <td class="t-specialty">${escapeHtml((u.skills || []).join(', ') || (u.categories || []).join(', ') || 'General')}</td>
            <td><div style="color:var(--color-text-muted);text-transform:capitalize;">${escapeHtml(u.locationLabel || '—')}</div></td>
            <td><div class="th-rating">★ ${u.averageRating ?? '—'}</div></td>
            <td class="center-align" style="font-weight:700;color:var(--color-text);">${u.completedJobs ?? '—'}</td>
            <td class="bk-amount">— EGP</td>
            <td style="white-space:nowrap;"><span class="bk-badge ${badgeClass} status-badge">${status}</span></td>
            <td style="white-space:nowrap;">
              ${u.isAvailable
                ? '<span class="bk-badge bk-badge--completed" style="background:#dcfce7;color:#166534;border:1px solid #bbf7d0;">● Live</span>'
                : '<span class="bk-badge" style="background:#f3f4f6;color:#6b7280;border:1px solid #e5e7eb;">○ Offline</span>'
              }
            </td>
            <td>
              <div class="table-actions">
                <button class="bk-action-btn bk-action-btn--xs view-tech-link" data-id="${u._id}">Profile</button>
                <button class="bk-action-btn bk-action-btn--xs bk-action-btn--suspend" data-admin-toggle-user="${u._id}" data-active="${u.isActive}">
                  ${u.isActive ? 'Suspend' : 'Activate'}
                </button>
                <button class="bk-action-btn bk-action-btn--xs bk-action-btn--delete" data-admin-delete-user="${u._id}">Delete</button>
              </div>
            </td>
          </tr>`;
        }).join('');

        techsRoot.querySelectorAll('.view-tech-link[data-id]').forEach((btn) => {
          const user = techs.find((item) => item._id === btn.dataset.id);
          if (!user) return;
          btn.addEventListener('click', () => {
            _openTechProfileModal(buildTechProfileData(user));
          });
        });
      }

      const pendingGrid = document.querySelector('.pending-cards-grid');
      if (pendingGrid) {
        if (pendingTechs.length === 0) {
          pendingGrid.innerHTML = '<div style="grid-column:1/-1;text-align:center;color:var(--color-text-muted);padding:1rem;">No pending approvals.</div>';
        } else {
          pendingGrid.innerHTML = pendingTechs.map((pt) => {
            const initials = pt.name ? pt.name.split(' ').map(n => n[0]).join('').toUpperCase() : '??';
            const docTags = [
              pt.idFrontUrl && pt.idBackUrl ? 'National ID' : '',
              pt.idSelfieUrl ? 'ID Selfie' : '',
              pt.cvUrl ? 'CV / Resume' : '',
              Array.isArray(pt.portfolioFiles) && pt.portfolioFiles.length ? 'Portfolio (' + pt.portfolioFiles.length + ')' : '',
            ].filter(Boolean).map((label) => '<div class="th-doc th-doc--ok"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg> ' + escapeHtml(label) + '</div>').join('');

            return `
            <div class="th-verify-card" data-user-id="${pt._id}">
              <div class="th-verify-identity">
                <div class="th-avatar">${escapeHtml(initials)}</div>
                <div class="th-identity-text"><strong>${escapeHtml(pt.name || '—')}</strong><span>${escapeHtml((pt.skills || []).join(', ') || (pt.categories || []).join(', ') || 'General')}</span></div>
              </div>
              <div class="th-verify-docs">${docTags || '<div class="th-doc">No documents uploaded</div>'}</div>
              <div class="th-verify-actions">
                <button class="bk-action-btn th-btn-approve" data-approve-tech="${pt._id}">Approve</button>
                <button class="bk-action-btn th-btn-reject" data-reject-tech="${pt._id}">Reject</button>
                <button class="bk-action-btn bk-action-btn--xs" data-view-pending="${pt._id}">Profile</button>
              </div>
            </div>`;
          }).join('');

          pendingGrid.querySelectorAll('[data-view-pending]').forEach((btn) => {
            const user = pendingTechs.find((item) => item._id === btn.dataset.viewPending);
            if (!user) return;
            btn.addEventListener('click', () => {
              _openTechProfileModal(buildTechProfileData(user));
            });
          });
        }
      }
    }

    _set('kpi-overview-techs', techTotal.toLocaleString());
    _set('kpi-techs-total', techTotal.toLocaleString());
    _set('kpi-techs-pending', pendingTechs.length.toLocaleString());
    _set('kpi-techs-verified', verifiedTechs.length.toLocaleString());
    _set('kpi-techs-suspended', suspendedTechs.length.toLocaleString());
    _set('kpi-techs-pending-badge', pendingTechs.length);

    // Pending category expansion requests
    const techsWithPendingCats = techs.filter(t => Array.isArray(t.pendingCategories) && t.pendingCategories.length > 0);
    const pendingCatGrid = document.getElementById('pending-category-grid');
    if (pendingCatGrid) {
      if (!techsWithPendingCats.length) {
        pendingCatGrid.innerHTML = '<p style="color:var(--color-secondary,#9A8C73);font-size:0.875rem;padding:12px 0;">No pending category requests.</p>';
      } else {
        pendingCatGrid.innerHTML = techsWithPendingCats.map(tech => {
          const catBadges = (tech.pendingCategories || []).map(cat =>
            `<button class="bk-action-btn bk-action-btn--xs" data-approve-cat="${tech._id}" data-cat="${cat}" style="background:rgba(154,140,115,0.15);margin:2px;">Approve: ${cat}</button>`
          ).join('');
          return `<div class="th-verify-card" style="align-items:flex-start;flex-wrap:wrap;gap:8px;">
            <div class="th-verify-identity" style="flex:1;min-width:180px;">
              <div class="th-avatar">${escapeHtml((tech.name || '?').slice(0,2).toUpperCase())}</div>
              <div class="th-identity-text"><strong>${escapeHtml(tech.name || '—')}</strong><span>${escapeHtml(tech.email || '')}</span></div>
            </div>
            <div style="display:flex;flex-wrap:wrap;gap:4px;align-items:center;">${catBadges}</div>
          </div>`;
        }).join('');
        pendingCatGrid.querySelectorAll('[data-approve-cat]').forEach(btn => {
          btn.addEventListener('click', async () => {
            const workerId = btn.dataset.approveCat;
            const category = btn.dataset.cat;
            try {
              await approveWorkerCategory(workerId, category);
              btn.textContent = `✓ ${category}`;
              btn.disabled = true;
              btn.style.opacity = '0.5';
            } catch (e) {
              alert('Failed to approve category: ' + (e.message || e));
            }
          });
        });
      }
    }

    const techInfoEl = document.getElementById('techPaginationInfo');
    if (techInfoEl) {
      const t = (typeof window.t === 'function') ? window.t : (k) => k;
      techInfoEl.setAttribute('data-i18n-v', techs.length);
      techInfoEl.setAttribute('data-i18n-n', techs.length);
      techInfoEl.textContent = t('admin_pagination_techs').replace('{v}', techs.length).replace('{n}', techs.length);
    }
  } catch (err) { console.error('Error loading technicians:', err); }

  // ── Bookings ────────────────────────────────────────────────────────────────
  try {
    const res = await getAllBookings({ limit: 100 });
    const bookings = res.bookings || [];
    const bTotal = res.pagination?.total ?? bookings.length;
    const bActive = bookings.filter(b => ['pending','accepted','en_route','arrived','in_progress'].includes(b.status)).length;
    const bCompleted = bookings.filter(b => b.status === 'completed').length;
    const bDisputed = bookings.filter(b => b.status === 'disputed').length;
    const bCancelled = bookings.filter(b => b.status === 'cancelled').length;

    const bkRoot = document.querySelector('[data-panel="bookings"] tbody');
    if (bkRoot) {
      if (bookings.length === 0) {
        bkRoot.innerHTML = '<tr><td colspan="6" class="center-align" style="padding: 2rem;">No bookings found.</td></tr>';
      } else {
        bkRoot.innerHTML = bookings.slice(0, 50).map(b => {
          const sc = { pending:'bk-badge--active', accepted:'bk-badge--active', en_route:'bk-badge--active', arrived:'bk-badge--active', in_progress:'bk-badge--active', completed:'bk-badge--completed', cancelled:'bk-badge--cancelled', disputed:'bk-badge--overdue' }[b.status] || '';
          const date = b.scheduledDate ? new Date(b.scheduledDate).toLocaleDateString('en-US', {month:'short', day:'numeric', year:'numeric'}) : '—';
          return `<tr class="booking-row" data-status="${b.status}">
            <td class="bk-cust">${b.user?.name || '—'}</td>
            <td class="bk-tech">${b.worker?.name || '—'}</td>
            <td>${b.service?.title || b.serviceKey || '—'}</td>
            <td>${date}</td>
            <td><span class="bk-badge ${sc}">${b.status}</span></td>
            <td class="bk-amount">${b.totalPrice != null ? b.totalPrice + ' EGP' : '—'}</td>
          </tr>`;
        }).join('');
      }
    }

    const bkTotalVal = document.querySelector('.booking-status-total-val');
    if (bkTotalVal) bkTotalVal.textContent = bTotal.toLocaleString();

    _set('kpi-bookings-total', bTotal.toLocaleString());
    _set('kpi-bookings-active', bActive.toLocaleString());
    _set('kpi-bookings-completed', bCompleted.toLocaleString());
    _set('kpi-bookings-disputed', bDisputed.toLocaleString());

    if (bTotal > 0) {
      const pct = n => Math.round((n / bTotal) * 100) + '%';
      _set('bk-pct-completed', pct(bCompleted));
      _set('bk-pct-inprogress', pct(bActive));
      _set('bk-pct-scheduled', pct(bookings.filter(b => b.status === 'pending').length));
      _set('bk-pct-cancelled', pct(bCancelled));
      _set('bk-stat-successrate', pct(bCompleted));
    }

    _set('kpi-overview-disputes', bDisputed.toLocaleString());
    _set('kpi-disputes-total', (bDisputed + bCompleted).toLocaleString());
    _set('kpi-disputes-open', bDisputed.toLocaleString());
    _set('kpi-disputes-review', '0');
    _set('kpi-disputes-resolved', bCompleted.toLocaleString());
    _set('disputeCount', bDisputed);
    _set('qa-dispute-badge', bDisputed);

    // Update pagination footer with actual count
    const bkInfoEl = document.getElementById('bookingPaginationInfo');
    if (bkInfoEl) {
      const t = (typeof window.t === 'function') ? window.t : (k) => k;
      bkInfoEl.setAttribute('data-i18n-v', bookings.length);
      bkInfoEl.setAttribute('data-i18n-n', bookings.length);
      bkInfoEl.textContent = t('admin_pagination_bookings').replace('{v}', bookings.length).replace('{n}', bookings.length);
    }
  } catch (err) { console.error('Error loading bookings:', err); }

  bindAdminActions();
}

function bindAdminActions() {
  document.querySelectorAll('[data-admin-toggle-user]').forEach((btn) => {
    btn.onclick = async () => {
      const id = btn.dataset.adminToggleUser;
      const currentActive = btn.dataset.active === 'true';
      if (!confirm(`Are you sure you want to ${currentActive ? 'suspend' : 'activate'} this user?`)) return;
      try {
        await updateUserStatus(id, !currentActive);
        showToast(`User ${currentActive ? 'suspended' : 'activated'} successfully.`, 'success');
        loadAdminData();
      } catch (err) {
        showToast(err.message || 'Error occurred.', 'error');
      }
    };
  });

  document.querySelectorAll('[data-approve-tech]').forEach((btn) => {
    btn.onclick = async () => {
      const id = btn.dataset.approveTech;
      if (!confirm('Approve this technician for the platform?')) return;
      try {
        await reviewWorker(id, { decision: 'approved' });
        showToast('Technician approved and verified!', 'success');
        loadAdminData();
      } catch (err) {
        showToast(err.data?.message || err.message || 'Failed to verify technician.', 'error');
      }
    };
  });

  document.querySelectorAll('[data-reject-tech]').forEach((btn) => {
    btn.onclick = () => {
      _currentRejectWorkerId = btn.dataset.rejectTech || '';
      const reasonInput = document.getElementById('rejectWorkerReason');
      const errorEl = document.getElementById('rejectWorkerError');
      if (reasonInput) reasonInput.value = '';
      if (errorEl) {
        errorEl.hidden = true;
        errorEl.textContent = '';
      }
      _openProfileModal('rejectWorkerModal');
    };
  });

  const rejectSubmit = document.getElementById('rejectWorkerSubmit');
  if (rejectSubmit) {
    rejectSubmit.onclick = async () => {
      const reasonInput = document.getElementById('rejectWorkerReason');
      const errorEl = document.getElementById('rejectWorkerError');
      const reason = String(reasonInput?.value || '').trim();
      if (!reason) {
        if (errorEl) {
          errorEl.textContent = 'A rejection reason is required.';
          errorEl.hidden = false;
        }
        return;
      }
      try {
        await reviewWorker(_currentRejectWorkerId, { decision: 'rejected', rejectionReason: reason });
        const modal = document.getElementById('rejectWorkerModal');
        if (modal) modal.style.display = 'none';
        showToast('Technician rejected.', 'success');
        _currentRejectWorkerId = '';
        loadAdminData();
      } catch (err) {
        if (errorEl) {
          errorEl.textContent = err.data?.message || err.message || 'Failed to reject technician.';
          errorEl.hidden = false;
        }
      }
    };
  }

  document.querySelectorAll('[data-admin-delete-user]').forEach((btn) => {
    btn.onclick = async () => {
      const id = btn.dataset.adminDeleteUser;
      if (!confirm('Delete this user permanently?')) return;
      try {
        await deleteUser(id);
        showToast('User deleted.', 'success');
        loadAdminData();
      } catch (err) {
        showToast(err.data?.message || 'Failed to delete user.', 'error');
      }
    };
  });

  document.querySelectorAll('[data-admin-delete-service]').forEach((btn) => {
    btn.onclick = async () => {
      const id = btn.dataset.adminDeleteService;
      if (!confirm('Delete this service permanently?')) return;
      try {
        await apiDeleteService(id);
        showToast('Service deleted.', 'success');
        loadAdminData();
      } catch (err) {
        showToast(err.data?.message || 'Failed to delete service.', 'error');
      }
    };
  });
}

// ── Payments Tab ──────────────────────────────

async function renderPendingApprovals(filter = {}) {
  const container = document.getElementById('adminPendingApprovalsList');
  if (!container) return;
  container.innerHTML = '<p>Loading...</p>';

  try {
    const { items } = await getPendingApprovals(filter);
    if (!items.length) {
      container.innerHTML = '<p class="empty-state">No pending approvals.</p>';
      return;
    }

    container.innerHTML = `
      <table class="admin-table">
        <thead>
          <tr>
            <th>Customer</th><th>Worker</th><th>Service</th>
            <th>Method</th><th>Amount</th><th>Worker Earns</th>
            <th>Platform Fee</th><th>Confirmed At</th><th>Actions</th>
          </tr>
        </thead>
        <tbody>
          ${items.map(item => `
            <tr data-booking-id="${item.bookingId}" data-method="${item.paymentMethod}">
              <td>${item.customer?.name || '—'}</td>
              <td>${item.worker?.name || '—'}</td>
              <td>${item.service || '—'}</td>
              <td><span class="badge badge--${item.paymentMethod}">${item.paymentMethod}</span></td>
              <td>${item.totalPaid || item.amount || '—'} EGP</td>
              <td>${item.workerEarning != null ? item.workerEarning + ' EGP' : '—'}</td>
              <td>${item.platformFee != null ? item.platformFee + ' EGP' : '—'}</td>
              <td>${item.customerConfirmedAt ? new Date(item.customerConfirmedAt).toLocaleDateString() : '—'}</td>
              <td class="admin-actions">
                <button class="btn btn--sm btn--success js-approve-btn" data-id="${item.bookingId}">Approve</button>
                ${item.paymentMethod === 'cash' ? `<button class="btn btn--sm btn--danger js-reject-cash-btn" data-id="${item.bookingId}">Reject</button>` : ''}
                ${item.paymentId ? `<button class="btn btn--sm btn--warning js-refund-btn" data-id="${item.paymentId}">Refund</button>` : ''}
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;

    container.querySelectorAll('.js-approve-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm(window.t?.('admin_approve_confirm') || 'Approve this payment release? This cannot be undone.')) return;
        try {
          await adminApprovePayment(btn.dataset.id);
          showToast('Approved.', 'success');
          renderPendingApprovals(filter);
        } catch (err) {
          showToast(err?.response?.data?.message || 'Approval failed.', 'error');
        }
      });
    });

    container.querySelectorAll('.js-reject-cash-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const reason = prompt('Reason for rejection (required):');
        if (!reason) return;
        try {
          await adminRejectCash(btn.dataset.id, { reason });
          showToast('Rejected.', 'info');
          renderPendingApprovals(filter);
        } catch (err) {
          showToast(err?.response?.data?.message || 'Rejection failed.', 'error');
        }
      });
    });

    container.querySelectorAll('.js-refund-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm(window.t?.('admin_refund_confirm') || 'Issue a refund? Booking will be cancelled.')) return;
        const reason = prompt('Refund reason:');
        if (!reason) return;
        try {
          await adminRefund(btn.dataset.id, { reason });
          showToast('Refunded.', 'info');
          renderPendingApprovals(filter);
        } catch (err) {
          showToast(err?.response?.data?.message || 'Refund failed.', 'error');
        }
      });
    });
  } catch (err) {
    container.innerHTML = `<p class="error-state">Failed to load: ${err?.message}</p>`;
  }
}

async function renderCashDebts(filter = {}) {
  const container = document.getElementById('adminCashDebtsList');
  if (!container) return;
  container.innerHTML = '<p>Loading...</p>';

  try {
    const { items, summary } = await getCashDebts(filter);

    const summaryEl = document.getElementById('adminCashDebtsSummary');
    if (summaryEl) {
      summaryEl.innerHTML = `
        <span>Outstanding: <strong>${summary.totalOutstanding} EGP</strong></span>
        <span>Partial: <strong>${summary.totalPartiallyPaid} EGP</strong></span>
        <span>Collected: <strong>${summary.totalPaid} EGP</strong></span>
      `;
    }

    if (!items.length) {
      container.innerHTML = '<p class="empty-state">No cash debts found.</p>';
      return;
    }

    container.innerHTML = `
      <table class="admin-table">
        <thead>
          <tr>
            <th>Worker</th><th>Booking</th><th>Amount</th>
            <th>Paid</th><th>Status</th><th>Created</th><th>Actions</th>
          </tr>
        </thead>
        <tbody>
          ${items.map(d => `
            <tr>
              <td>${d.worker?.name || '—'}</td>
              <td>${d.bookingId || '—'}</td>
              <td>${d.amount} EGP</td>
              <td>${d.paidAmount} EGP</td>
              <td><span class="badge badge--${d.status}">${d.status.replace('_', ' ')}</span></td>
              <td>${new Date(d.createdAt).toLocaleDateString()}</td>
              <td>
                ${d.status !== 'paid' ? `<button class="btn btn--sm btn--primary js-mark-paid-btn" data-id="${d.debtId}" data-remaining="${d.amount - d.paidAmount}">
                  ${window.t?.('admin_mark_paid') || 'Mark Paid'}
                </button>` : '—'}
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;

    container.querySelectorAll('.js-mark-paid-btn').forEach(btn => {
      btn.addEventListener('click', () => openMarkPaidModal(btn.dataset.id, Number(btn.dataset.remaining)));
    });
  } catch (err) {
    container.innerHTML = `<p class="error-state">Failed to load: ${err?.message}</p>`;
  }
}

function openMarkPaidModal(debtId, remaining) {
  const modal = document.getElementById('adminMarkPaidModal');
  if (!modal) return;
  document.getElementById('markPaidDebtId').value = debtId;
  document.getElementById('markPaidRemaining').textContent = remaining + ' EGP';
  document.getElementById('markPaidAmount').value = remaining;
  document.getElementById('markPaidAmount').max = remaining;
  modal.hidden = false;
}

document.getElementById('markPaidSubmit')?.addEventListener('click', async () => {
  const debtId    = document.getElementById('markPaidDebtId').value;
  const amount    = Number(document.getElementById('markPaidAmount').value);
  const adminNote = document.getElementById('markPaidNote').value.trim() || undefined;
  if (!amount || amount <= 0) { showToast('Enter a valid amount.', 'error'); return; }
  try {
    await markCashDebtPaid(debtId, { amount, adminNote });
    document.getElementById('adminMarkPaidModal').hidden = true;
    showToast('Payment recorded.', 'success');
    renderCashDebts();
  } catch (err) {
    showToast(err?.response?.data?.message || 'Failed to record payment.', 'error');
  }
});

document.getElementById('markPaidCancel')?.addEventListener('click', () => {
  document.getElementById('adminMarkPaidModal').hidden = true;
});

initAdminDashboard();

// ── Preview Mode: View Site as Customer ───────
document.getElementById('viewSiteAsCustomer')?.addEventListener('click', () => {
  localStorage.setItem('servio_preview_mode', 'true');
  window.open('./index.html', '_blank');
});

// ── Language dropdown toggle ───────────────────
// navbar.js only runs on pages with [data-site-header]; the admin header uses
// .admin-header instead, so we wire the lang toggle here manually.
(function initAdminLangDropdown() {
  const langContainer = document.querySelector('.admin-header [data-lang]');
  if (!langContainer) return;

  const langBtn  = langContainer.querySelector('.lang-switch');
  const langMenu = langContainer.querySelector('.lang__menu');
  if (!langBtn || !langMenu) return;

  // Toggle open/close on button click
  langBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    const isOpen = langContainer.classList.toggle('is-open');
    langBtn.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
  });

  // Select a language on option click
  langMenu.querySelectorAll('[role="option"]').forEach((opt) => {
    opt.addEventListener('click', () => {
      const lang = opt.textContent.trim().toLowerCase();
      if (typeof window.applyLanguage === 'function') window.applyLanguage(lang);
      langContainer.classList.remove('is-open');
      langBtn.setAttribute('aria-expanded', 'false');
    });
  });

  // Close dropdown when clicking outside
  document.addEventListener('click', (e) => {
    if (!langContainer.contains(e.target)) {
      langContainer.classList.remove('is-open');
      langBtn.setAttribute('aria-expanded', 'false');
    }
  });

  // Close on Escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      langContainer.classList.remove('is-open');
      langBtn.setAttribute('aria-expanded', 'false');
    }
  });
})();

