/* ───────────────────────────────────────────────
   Admin Dashboard — SERVIO
   ─────────────────────────────────────────────── */

import { showToast } from '../components/toast.js';
import { skList, skTableRows } from '../components/skeleton.js';
import { getAllUsers, deleteUser, updateUserStatus, updatePassword, reviewWorker, approveWorkerCategory } from '../api/users.js';
import { getServices, createService, updateService, deleteService as apiDeleteService } from '../api/services.js';
import { getAllBookings } from '../api/bookings.js';
import { getAuditLogs, deleteAuditLog, deleteAllAuditLogs, deleteSelectedAuditLogs, getAdminSettings, updateAdminSettings, getAnalytics } from '../api/admin.js';
import {
  getPendingApprovals,
  adminApprovePayment,
  adminRejectCash,
  adminRefund,
  getCashDebts,
  markCashDebtPaid,
  getDisputes,
  resolveDispute,
  reviewDispute,
  getDisputeById,
  assignDispute,
  addDisputeNote,
  requestDisputeEvidence,
  resolveDisputeAppeal,
  adminListPayments,
  adminPaymentsStats,
  adminPartialRefund,
  adminListCashDebtsGrouped,
  adminWorkerDebts,
  adminListSettlements,
  adminListPayouts,
  adminForceRelease,
  adminForceLock,
  adminForceUnlock,
} from '../api/payments.js';
import { openPaymentConfirmModal } from '../components/payment-confirm-modal.js';
import { openSettlementVerifyModal } from '../components/settlement-verify-modal.js';
import { openPayoutDecisionModal } from '../components/payout-decision-modal.js';
import { openPartialRefundModal } from '../components/partial-refund-modal.js';
import {
  getAdminSupportIssues,
  updateSupportIssueStatus,
  resolveSupportIssue,
  escalateSupportIssueToDispute,
} from '../api/support.js';

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
let _adminDisputes = [];
let _disputesLoadedOnce = false;
let _adminSupportIssues = [];
let _supportLoadedOnce = false;

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

function formatMoney(value) {
  const amount = Number(value);
  return Number.isFinite(amount) ? `${amount.toLocaleString()} EGP` : '-';
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
      } else {
        headerTitle.textContent = activeBtn.textContent.trim();
        headerTitle.removeAttribute('data-i18n');
      }
    }
    // Persist tab state
    if (save) {
      sessionStorage.setItem('servio_admin_active_tab', tabName);
    }
  }

  // Restore active tab from sessionStorage or default to overview
  let savedTab = sessionStorage.getItem('servio_admin_active_tab');
  if (savedTab === 'payments' || savedTab === 'settlements') {
    sessionStorage.setItem('servio_admin_fin_tab', savedTab);
    savedTab = 'finance';
    sessionStorage.setItem('servio_admin_active_tab', 'finance');
  }
  if (savedTab) {
    switchTab(savedTab, false);
  } else {
    switchTab('overview', false);
  }

  navBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      switchTab(btn.dataset.tab);
      if (btn.dataset.tab === 'disputes') renderDisputes().catch(err => console.error('Error loading disputes:', err));
      if (btn.dataset.tab === 'support') renderSupportIssues().catch(err => console.error('Error loading support issues:', err));
    });
  });

  // ── Quick action buttons (data-goto-tab) ──
  document.querySelectorAll('[data-goto-tab]').forEach(btn => {
    btn.addEventListener('click', () => {
      switchTab(btn.dataset.gotoTab);
      if (btn.dataset.gotoTab === 'disputes') renderDisputes().catch(err => console.error('Error loading disputes:', err));
      if (btn.dataset.gotoTab === 'support') renderSupportIssues().catch(err => console.error('Error loading support issues:', err));
      if (btn.dataset.gotoFin && typeof switchFinanceTab === 'function') {
        switchFinanceTab(btn.dataset.gotoFin);
      }
    });
  });

  // ── Finance inner tabs (Payments | Cash Settlements) ──
  document.querySelectorAll('.fin-tab').forEach(t => {
    t.addEventListener('click', () => window.switchFinanceTab && window.switchFinanceTab(t.dataset.finTab));
  });
  const savedFin = sessionStorage.getItem('servio_admin_fin_tab');
  // Defer until window.switchFinanceTab is assigned later in this file
  queueMicrotask(() => window.switchFinanceTab && window.switchFinanceTab(savedFin || 'payments'));

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
      list.style.visibility = '';
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

  // ── Reports Page Download Buttons ───────────────────────────────
  document.querySelectorAll('.report-download-btn').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      const btnEl = e.currentTarget;
      const card = btnEl.closest('.report-card');
      const title = card?.querySelector('h3')?.textContent || 'Report';
      
      try {
        btnEl.disabled = true;
        const originalText = btnEl.innerHTML;
        btnEl.innerHTML = '<span style="display: inline-block; width: 14px; height: 14px; border: 2px solid rgba(255,255,255,0.3); border-top-color: #fff; border-radius: 50%; animation: spin 1s linear infinite; margin-right: 8px;"></span> Downloading...';
        
        let fileContent = '';
        let fileExt = 'csv';
        let mimeType = 'text/csv';
        
        const formatSelect = card?.querySelector('select[aria-label="Format"], #auditReportFormat');
        const format = formatSelect ? formatSelect.value : 'csv';
        if (format === 'json') {
           fileExt = 'json';
           mimeType = 'application/json';
        }
        
        // Fetch data based on card title
        if (title.toLowerCase().includes('audit')) {
           const daysSelect = document.getElementById('auditReportDateRange');
           const days = daysSelect ? daysSelect.value : '';
           const res = await getAuditLogs({ days: days === 'all' ? '' : days, limit: 10000 });
           const logs = res.logs || (Array.isArray(res) ? res : []);
           if (format === 'json') {
             fileContent = JSON.stringify(logs, null, 2);
           } else {
             const rows = [['Timestamp', 'Actor', 'Type', 'Action', 'Target', 'IP Address', 'Status']];
             logs.forEach(r => rows.push([
               r.createdAt ? new Date(r.createdAt).toLocaleString('en-GB') : '—',
               r.actor?.email || 'unknown', r.type || '—', r.action || '—', r.target || '—', r.ip || '—', r.status || '—'
             ]));
             fileContent = rows.map(r => r.map(v => `"${String(v).replace(/"/g,'""')}"`).join(',')).join('\n');
           }
        } else if (title.toLowerCase().includes('users')) {
           const res = await getAllUsers({ limit: 10000 }) || {};
           const users = res.users || (Array.isArray(res) ? res : []);
           const customers = users.filter(u => u.role !== 'admin' && u.role !== 'worker');
           if (format === 'json') {
             fileContent = JSON.stringify(customers, null, 2);
           } else {
             const rows = [['Name', 'Email', 'Role', 'Status', 'Joined Date']];
             customers.forEach(u => rows.push([
               u.name || '—', u.email || '—', u.role || '—', u.isActive ? 'Active' : 'Inactive', u.createdAt ? new Date(u.createdAt).toLocaleDateString() : '—'
             ]));
             fileContent = rows.map(r => r.map(v => `"${String(v).replace(/"/g,'""')}"`).join(',')).join('\n');
             fileExt = 'csv'; // fallback to csv
           }
        } else if (title.toLowerCase().includes('tech')) {
           const res = await getAllUsers({ limit: 10000 }) || {};
           const users = res.users || (Array.isArray(res) ? res : []);
           const techs = users.filter(u => u.role === 'worker');
           if (format === 'json') {
             fileContent = JSON.stringify(techs, null, 2);
           } else {
             const rows = [['Name', 'Email', 'Verification', 'Rating', 'Joined Date']];
             techs.forEach(u => rows.push([
               u.name || '—', u.email || '—', u.verificationStatus || '—', u.rating || '0', u.createdAt ? new Date(u.createdAt).toLocaleDateString() : '—'
             ]));
             fileContent = rows.map(r => r.map(v => `"${String(v).replace(/"/g,'""')}"`).join(',')).join('\n');
             fileExt = 'csv';
           }
        } else if (title.toLowerCase().includes('bookings')) {
           const res = await getAllBookings({ limit: 10000 }) || {};
           const bookings = res.bookings || (Array.isArray(res) ? res : []);
           if (format === 'json') {
             fileContent = JSON.stringify(bookings, null, 2);
           } else {
             const rows = [['Booking ID', 'Customer', 'Service', 'Status', 'Total Price', 'Date']];
             bookings.forEach(b => rows.push([
               b._id || '—', b.customer?.name || '—', b.service?.title || '—', b.status || '—', b.totalPrice || '—', b.createdAt ? new Date(b.createdAt).toLocaleDateString() : '—'
             ]));
             fileContent = rows.map(r => r.map(v => `"${String(v).replace(/"/g,'""')}"`).join(',')).join('\n');
             fileExt = 'csv';
           }
        } else {
           fileContent = "Report Data\nData export for this section is being processed.";
           fileExt = 'csv';
        }
        
        const blob = new Blob([fileContent], { type: mimeType });
        const url  = URL.createObjectURL(blob);
        const a    = document.createElement('a');
        a.href = url; 
        const sanitizedTitle = title.toLowerCase().replace(/[^a-z0-9]/g, '-');
        a.download = `${sanitizedTitle}-${new Date().toISOString().split('T')[0]}.${fileExt}`; 
        document.body.appendChild(a); // Crucial for Firefox compatibility
        a.click();
        document.body.removeChild(a); // Clean up
        URL.revokeObjectURL(url);
        
        showToast(title + ' downloaded successfully.', 'success');
        btnEl.disabled = false;
        btnEl.innerHTML = originalText;
      } catch (err) {
        console.error('Failed to export report:', err);
        showToast('Failed to export ' + title, 'error');
        btnEl.disabled = false;
        btnEl.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                  <span data-i18n="admin_download">Download</span>`;
      }
    });
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
      _updateAuditBulkBar();
      return;
    }
    if (emptyEl) emptyEl.hidden = true;

    tbody.innerHTML = logs.map(r => {
      const ts     = r.createdAt ? new Date(r.createdAt).toLocaleString('en-GB') : '—';
      const actor  = r.actor?.email || 'unknown';
      const icon   = r.status === 'ok' ? '✓' : r.status === 'warn' ? '⚠' : '✕';
      return `<tr data-audit-id="${r._id}">
        <td class="audit-col-check">
          <label class="audit-checkbox-wrap" aria-label="Select row">
            <input type="checkbox" class="audit-checkbox audit-row-check" data-id="${r._id}" />
            <span class="audit-checkmark"></span>
          </label>
        </td>
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

    // Re-attach row-checkbox listeners
    tbody.querySelectorAll('.audit-row-check').forEach(cb => {
      cb.addEventListener('change', _updateAuditBulkBar);
    });
    _updateAuditBulkBar();
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

  // ── Audit: selection helpers ──────────────────────────────
  function _getSelectedAuditIds() {
    return [...document.querySelectorAll('.audit-row-check:checked')].map(cb => cb.dataset.id);
  }

  function _updateAuditBulkBar() {
    const checked = _getSelectedAuditIds();
    const bulkBar    = document.getElementById('auditBulkBar');
    const countEl   = document.getElementById('auditSelectedCount');
    const selectAll  = document.getElementById('auditSelectAll');
    const allBoxes   = [...document.querySelectorAll('.audit-row-check')];

    if (bulkBar)  bulkBar.hidden  = checked.length === 0;
    if (countEl)  countEl.textContent = checked.length;
    if (selectAll) {
      selectAll.checked       = allBoxes.length > 0 && allBoxes.every(cb => cb.checked);
      selectAll.indeterminate = checked.length > 0 && !selectAll.checked;
    }
  }

  // Select-all checkbox
  document.getElementById('auditSelectAll')?.addEventListener('change', e => {
    document.querySelectorAll('.audit-row-check').forEach(cb => { cb.checked = e.target.checked; });
    _updateAuditBulkBar();
  });

  // Delete Selected
  document.getElementById('auditDeleteSelectedBtn')?.addEventListener('click', async () => {
    const ids = _getSelectedAuditIds();
    if (!ids.length) return;
    const msg = `Delete ${ids.length} selected log entr${ids.length === 1 ? 'y' : 'ies'}? This cannot be undone.`;
    if (!confirm(msg)) return;
    try {
      await deleteSelectedAuditLogs(ids);
      showToast(`${ids.length} log entr${ids.length === 1 ? 'y' : 'ies'} deleted`, 'success');
      _loadAuditPage();
    } catch (err) {
      console.error('Bulk delete failed:', err);
      showToast(err.message || 'Failed to delete selected logs', 'error');
    }
  });

  // Delete All
  document.getElementById('auditDeleteAllBtn')?.addEventListener('click', async () => {
    if (!confirm('Delete ALL audit log entries? This will permanently clear the entire log and cannot be undone.')) return;
    try {
      await deleteAllAuditLogs();
      showToast('All audit logs cleared', 'success');
      _loadAuditPage();
    } catch (err) {
      console.error('Delete all failed:', err);
      showToast(err.message || 'Failed to clear logs', 'error');
    }
  });

  // Clear selection
  document.getElementById('auditClearSelectionBtn')?.addEventListener('click', () => {
    document.querySelectorAll('.audit-row-check').forEach(cb => { cb.checked = false; });
    const selectAll = document.getElementById('auditSelectAll');
    if (selectAll) { selectAll.checked = false; selectAll.indeterminate = false; }
    _updateAuditBulkBar();
  });

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
    if (btn.dataset.tab === 'finance') {
      btn.addEventListener('click', () => {
        renderPendingApprovals();
      });
    }
  });

  document.getElementById('disputeStatusFilter')?.addEventListener('change', () => renderDisputes({ reuseCache: true }).catch(err => console.error('Error filtering disputes:', err)));
  document.getElementById('disputeSearch')?.addEventListener('input', () => renderDisputes({ reuseCache: true }).catch(err => console.error('Error searching disputes:', err)));
  document.getElementById('disputeRefreshBtn')?.addEventListener('click', () => renderDisputes({ force: true }).catch(err => console.error('Error refreshing disputes:', err)));
  ['supportStatusFilter', 'supportPriorityFilter', 'supportTypeFilter'].forEach((id) => {
    document.getElementById(id)?.addEventListener('change', () => renderSupportIssues({ force: true }).catch(err => console.error('Error filtering support issues:', err)));
  });
  document.getElementById('supportSearch')?.addEventListener('input', () => renderSupportIssues({ reuseCache: true }).catch(err => console.error('Error searching support issues:', err)));
  document.getElementById('supportRefreshBtn')?.addEventListener('click', () => renderSupportIssues({ force: true }).catch(err => console.error('Error refreshing support issues:', err)));

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
      bkRoot.style.visibility = '';
      if (bookings.length === 0) {
        bkRoot.innerHTML = '<tr><td colspan="6" class="center-align" style="padding: 2rem;">No bookings found.</td></tr>';
      } else {
        bkRoot.innerHTML = bookings.slice(0, 50).map(b => {
          const sc = { pending:'bk-badge--active', accepted:'bk-badge--active', en_route:'bk-badge--active', arrived:'bk-badge--active', in_progress:'bk-badge--active', completed:'bk-badge--completed', cancelled:'bk-badge--cancelled', disputed:'bk-badge--overdue' }[b.status] || '';
          const date = b.scheduledDate ? new Date(b.scheduledDate).toLocaleDateString('en-US', {month:'short', day:'numeric', year:'numeric'}) : '—';
          return `<tr class="booking-row" data-status="${b.status}">
            <td><div style="font-weight:600;">${b.user?.name || '—'}</div></td>
            <td><div style="color:var(--color-text-muted);">${b.worker?.name || '—'}</div></td>
            <td>${b.service?.title || b.serviceKey || '—'}</td>
            <td>
              <div style="font-weight:500; margin-bottom:2px;">${date}</div>
              <div style="font-size:0.75rem; color:var(--color-text-light);">${b.scheduledDate ? new Date(b.scheduledDate).toLocaleTimeString('en-US', {hour: '2-digit', minute:'2-digit'}) : '—'}</div>
            </td>
            <td><span class="bk-badge ${sc}">${b.status}</span></td>
            <td style="text-transform: capitalize;">${b.paymentMethod || '—'}</td>
            <td><span class="bk-pay-badge bk-pay--${(b.paymentStatus || 'pending').toLowerCase()}">${b.paymentStatus || 'pending'}</span></td>
            <td class="bk-amount right-align">${b.totalPrice != null ? b.totalPrice + ' EGP' : '—'}</td>
            <td><button class="bk-action-btn" data-action="view-booking" data-id="${b._id}">View</button></td>
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

    if (!_disputesLoadedOnce) {
      renderDisputes().catch(err => console.error('Error loading disputes:', err));
    }
    if (!_supportLoadedOnce) {
      renderSupportIssues().catch(err => console.error('Error loading support issues:', err));
    }

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

function setAdminText(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = String(value);
}

function getDisputeBooking(dispute) {
  return dispute?.booking && typeof dispute.booking === 'object' ? dispute.booking : {};
}

function getDisputeCustomer(dispute) {
  const booking = getDisputeBooking(dispute);
  return booking.user || dispute?.raisedBy || {};
}

function getDisputeWorker(dispute) {
  return getDisputeBooking(dispute).worker || {};
}

function getDisputeService(dispute) {
  const booking = getDisputeBooking(dispute);
  return booking.service?.title || booking.serviceCategory || 'Service booking';
}

function formatDisputeStatusAdmin(status) {
  return ({
    open: 'Open',
    reviewing: 'Reviewing',
    awaiting_evidence: 'Awaiting evidence',
    resolved_refund: 'Refunded',
    resolved_release: 'Released',
    resolved_partial: 'Partial refund',
    resolved_redo: 'Sent for redo',
    appealed: 'Appealed',
    closed: 'Closed',
  })[status] || 'Open';
}

function disputeStatusClass(status) {
  return ({
    open: 'admin-dispute-status--open',
    reviewing: 'admin-dispute-status--reviewing',
    awaiting_evidence: 'admin-dispute-status--reviewing',
    resolved_refund: 'admin-dispute-status--resolved',
    resolved_release: 'admin-dispute-status--resolved',
    resolved_partial: 'admin-dispute-status--resolved',
    resolved_redo: 'admin-dispute-status--resolved',
    appealed: 'admin-dispute-status--open',
    closed: 'admin-dispute-status--resolved',
  })[status] || 'admin-dispute-status--open';
}

function disputeMatchesSearch(dispute, query) {
  if (!query) return true;
  const booking = getDisputeBooking(dispute);
  const customer = getDisputeCustomer(dispute);
  const worker = getDisputeWorker(dispute);
  const haystack = [
    dispute?._id,
    booking?._id,
    customer?.name,
    customer?.email,
    worker?.name,
    worker?.email,
    getDisputeService(dispute),
    dispute?.category,
    dispute?.reason,
    dispute?.status,
  ].filter(Boolean).join(' ').toLowerCase();
  return haystack.includes(query.toLowerCase());
}

async function fetchAdminDisputes() {
  const first = await getDisputes({ limit: 100, page: 1 });
  const disputes = [...(first?.disputes || [])];
  const totalPages = Number(first?.pagination?.totalPages || 1);
  if (totalPages > 1) {
    const pages = [];
    for (let page = 2; page <= totalPages; page += 1) {
      pages.push(getDisputes({ limit: 100, page }));
    }
    const rest = await Promise.all(pages);
    rest.forEach(result => disputes.push(...(result?.disputes || [])));
  }
  return disputes;
}

function updateDisputeKpis(disputes) {
  const total = disputes.length;
  const open = disputes.filter(d => d.status === 'open').length;
  const reviewing = disputes.filter(d => d.status === 'reviewing').length;
  const resolved = disputes.filter(d => String(d.status || '').startsWith('resolved_')).length;
  setAdminText('kpi-overview-disputes', open + reviewing);
  setAdminText('kpi-disputes-total', total.toLocaleString());
  setAdminText('kpi-disputes-open', open.toLocaleString());
  setAdminText('kpi-disputes-review', reviewing.toLocaleString());
  setAdminText('kpi-disputes-resolved', resolved.toLocaleString());
  setAdminText('disputeCount', open + reviewing);
  setAdminText('qa-dispute-badge', open + reviewing);
}

async function renderDisputes(options = {}) {
  const tbody = document.querySelector('#disputesTable tbody');
  if (!tbody) return;

  const shouldFetch = options.force || !options.reuseCache || !_disputesLoadedOnce;
  if (shouldFetch) {
    tbody.innerHTML = skTableRows(6, 8);
    _adminDisputes = await fetchAdminDisputes();
    _disputesLoadedOnce = true;
  }

  updateDisputeKpis(_adminDisputes);

  const statusFilter = document.getElementById('disputeStatusFilter')?.value || '';
  const searchQuery = String(document.getElementById('disputeSearch')?.value || '').trim();
  const visible = _adminDisputes.filter(dispute => {
    const statusOk = !statusFilter || dispute.status === statusFilter;
    return statusOk && disputeMatchesSearch(dispute, searchQuery);
  });

  if (!visible.length) {
    tbody.innerHTML = '<tr><td colspan="8" class="center-align" style="padding: 3rem; color: var(--color-text-muted);">No disputes match the current filters.</td></tr>';
    return;
  }

  tbody.innerHTML = visible.map(dispute => {
    const booking = getDisputeBooking(dispute);
    const customer = getDisputeCustomer(dispute);
    const worker = getDisputeWorker(dispute);
    const status = dispute.status || 'open';
    const amount = booking.totalPrice ?? booking.estimatedTotal ?? dispute.payment?.amount;
    const paymentLabel = booking.paymentMethod ? `${booking.paymentMethod} / ${booking.paymentStatus || 'pending'}` : (dispute.payment?.status || 'No payment');
    const slaBadge = renderSlaBadge(dispute);
    return `
      <tr>
        <td><strong>${escapeHtml(String(dispute._id || '').slice(-8) || '-')}</strong></td>
        <td>
          <div class="admin-dispute-booking">${escapeHtml(getDisputeService(dispute))}</div>
          <small>${escapeHtml(formatMoney(amount))} - ${escapeHtml(paymentLabel)}</small>
        </td>
        <td>
          <div>${escapeHtml(customer.name || '-')}</div>
          <small>${escapeHtml(customer.email || '')}</small>
        </td>
        <td>
          <div>${escapeHtml(worker.name || '-')}</div>
          <small>${escapeHtml(worker.email || '')}</small>
        </td>
        <td>
          <div class="admin-dispute-issue">${escapeHtml(dispute.category || 'other')} <span class="admin-dispute-sev admin-dispute-sev--${escapeHtml(dispute.severity || 'medium')}">${escapeHtml(dispute.severity || 'medium')}</span></div>
          <small>${escapeHtml(dispute.reason || '').slice(0, 72)}${String(dispute.reason || '').length > 72 ? '...' : ''}</small>
        </td>
        <td>
          <span class="admin-dispute-status ${disputeStatusClass(status)}">${escapeHtml(formatDisputeStatusAdmin(status))}</span>
          ${slaBadge}
        </td>
        <td>${escapeHtml(formatAdminDate(dispute.createdAt))}</td>
        <td class="center-align">
          <div class="admin-dispute-actions">
            <button class="bk-action-btn bk-action-btn--xs" type="button" data-dispute-manage="${escapeHtml(dispute._id)}">Manage</button>
          </div>
        </td>
      </tr>
    `;
  }).join('');

  bindDisputeActions();
}

function renderSlaBadge(dispute) {
  const due = dispute.slaResolveDueAt ? new Date(dispute.slaResolveDueAt).getTime() : null;
  if (!due || ['resolved_refund','resolved_release','resolved_partial','resolved_redo','closed'].includes(dispute.status)) return '';
  const remaining = due - Date.now();
  const hours = Math.round(remaining / 3600000);
  if (remaining < 0) return `<small class="admin-dispute-sla admin-dispute-sla--breach">SLA breached ${Math.abs(hours)}h ago</small>`;
  if (hours <= 6) return `<small class="admin-dispute-sla admin-dispute-sla--urgent">${hours}h left</small>`;
  return `<small class="admin-dispute-sla">${hours}h left</small>`;
}

function bindDisputeActions() {
  document.querySelectorAll('[data-dispute-manage]').forEach(btn => {
    btn.onclick = () => openAdminDisputeModal(btn.dataset.disputeManage);
  });
}

const RESOLVED_DISPUTE_STATUSES = ['resolved_refund', 'resolved_release', 'resolved_partial', 'resolved_redo', 'closed'];

function isResolved(dispute) {
  return RESOLVED_DISPUTE_STATUSES.includes(dispute.status);
}

function renderEvidenceItem(file) {
  const url = file?.url || file?.secureUrl || file?.path || (typeof file === 'string' ? file : '');
  const name = file?.name || file?.originalName || file?.filename || 'Evidence';
  const role = file?.uploadedByRole || file?.role || '';
  const by = file?.uploadedBy?.name || '';
  const meta = [role && `by ${role}`, by].filter(Boolean).join(' - ');
  if (!url) return `<span class="admin-dispute-evidence__missing">${escapeHtml(name)}</span>`;
  const ext = (name.includes('.') ? name.split('.').pop() : (url.split('?')[0].split('.').pop() || 'file')).toLowerCase();
  const isImage = /^(png|jpe?g|gif|webp|bmp|avif|svg)$/i.test(ext) || /^image\//.test(file?.mime || '');
  const fallback = `this.style.display='none';this.nextElementSibling.style.display='grid';`;
  return `
    <a href="${escapeHtml(url)}" target="_blank" rel="noopener noreferrer" class="admin-dispute-evidence__item${isImage ? '' : ' admin-dispute-evidence__item--file'}">
      ${isImage
        ? `<img src="${escapeHtml(url)}" alt="${escapeHtml(name)}" onerror="${fallback}"><div class="admin-dispute-evidence__file" style="display:none">${escapeHtml(ext.toUpperCase())}</div>`
        : `<div class="admin-dispute-evidence__file">${escapeHtml(ext.toUpperCase())}</div>`}
      <div class="admin-dispute-evidence__meta">
        <span>${escapeHtml(name)}</span>
        ${meta ? `<small>${escapeHtml(meta)}</small>` : ''}
      </div>
    </a>
  `;
}

function renderHistoryTimeline(history) {
  if (!Array.isArray(history) || !history.length) {
    return '<p class="admin-dispute-empty">No history yet.</p>';
  }
  return `<ol class="admin-dispute-history">
    ${history.slice().reverse().map(h => {
      const statusRaw = h?.status || '';
      const status = escapeHtml(formatDisputeStatusAdmin(statusRaw));
      const roleRaw = escapeHtml(h?.byRole || 'system');
      
      let roleFriendly = 'System';
      if (roleRaw === 'user') roleFriendly = 'Customer';
      else if (roleRaw === 'worker') roleFriendly = 'Technician';
      else if (roleRaw === 'admin') roleFriendly = 'Support Admin';

      const who = h?.by?.name ? escapeHtml(h.by.name) : roleFriendly;
      
      let actionDesc = `Status updated to ${status}`;
      if (statusRaw === 'open') actionDesc = 'Dispute opened';
      else if (statusRaw === 'reviewing') actionDesc = 'Review started';
      else if (statusRaw === 'awaiting_evidence') actionDesc = 'Requested evidence';
      else if (statusRaw === 'appealed') actionDesc = 'Decision appealed';
      else if (statusRaw.startsWith('resolved')) actionDesc = `Dispute resolved: ${status}`;
      else if (statusRaw === 'closed') actionDesc = 'Dispute closed';

      return `
      <li>
        <div><strong>${actionDesc}</strong><small>${escapeHtml(formatAdminDate(h.at))}</small></div>
        <div class="admin-dispute-history__meta">By: <strong>${who}</strong> <span style="opacity:0.7;">(${roleFriendly})</span></div>
        ${h.note ? `<div class="admin-dispute-history__note">"${escapeHtml(h.note)}"</div>` : ''}
      </li>
      `;
    }).join('')}
  </ol>`;
}

function renderInternalNotes(notes) {
  if (!Array.isArray(notes) || !notes.length) return '<p class="admin-dispute-empty">No internal notes.</p>';
  return notes.slice().reverse().map(n => `
    <div class="admin-dispute-note">
      <header><strong>${escapeHtml(n.by?.name || 'Admin')}</strong><small>${escapeHtml(formatAdminDate(n.at))}</small></header>
      <p>${escapeHtml(n.note)}</p>
    </div>
  `).join('');
}

async function openAdminDisputeModal(disputeId) {
  const body = document.getElementById('adminDisputeBody');
  if (!body) return;
  body.innerHTML = skList(4);
  if (_openProfileModal) _openProfileModal('adminDisputeModal');
  else document.getElementById('adminDisputeModal')?.removeAttribute('hidden');

  let dispute;
  try {
    const res = await getDisputeById(disputeId);
    dispute = res?.data || res;
    const idx = _adminDisputes.findIndex(d => d._id === disputeId);
    if (idx >= 0) _adminDisputes[idx] = dispute;
    else _adminDisputes.push(dispute);
  } catch (err) {
    body.innerHTML = `<p class="admin-dispute-empty">Failed to load dispute: ${escapeHtml(err.message || 'error')}</p>`;
    return;
  }

  renderDisputeModal(dispute);
}

function renderDisputeModal(dispute) {
  const body = document.getElementById('adminDisputeBody');
  if (!body) return;
  const booking = getDisputeBooking(dispute);
  const customer = getDisputeCustomer(dispute);
  const worker = getDisputeWorker(dispute);
  const evidence = Array.isArray(dispute.evidence) ? dispute.evidence : [];
  const customerEvidence = evidence.filter(e => (e?.uploadedByRole || 'user') === 'user');
  const workerEvidence = evidence.filter(e => e?.uploadedByRole === 'worker');
  const adminEvidence = evidence.filter(e => e?.uploadedByRole === 'admin');
  const amount = booking.totalPrice ?? booking.estimatedTotal ?? dispute.payment?.amount ?? 0;
  const paymentAmount = Number(dispute.payment?.amount || amount || 0);
  const resolved = isResolved(dispute);
  const isAppealed = dispute.status === 'appealed';
  const hasEscrow = Boolean(dispute.payment);
  const slaBadge = renderSlaBadge(dispute);
  const assignedName = dispute.assignedAdmin?.name || '';
  const sessionUser = (() => { try { return JSON.parse(localStorage.getItem('servio_session') || '{}'); } catch { return {}; } })();
  const isMineAssigned = dispute.assignedAdmin?._id && sessionUser?.id && String(dispute.assignedAdmin._id) === String(sessionUser.id);

  body.innerHTML = `
    <div class="admin-dispute-detail" data-dispute-id="${escapeHtml(dispute._id)}">
      <header class="admin-dispute-detail__head">
        <div>
          <span class="admin-dispute-status ${disputeStatusClass(dispute.status)}">${escapeHtml(formatDisputeStatusAdmin(dispute.status))}</span>
          <span class="admin-dispute-sev admin-dispute-sev--${escapeHtml(dispute.severity || 'medium')}">${escapeHtml(dispute.severity || 'medium')}</span>
          ${slaBadge}
        </div>
        <div class="admin-dispute-detail__assign">
          <small>${assignedName ? `Assigned: ${escapeHtml(assignedName)}` : 'Unassigned'}</small>
          ${!resolved && !isMineAssigned ? `<button class="bk-action-btn bk-action-btn--xs" type="button" data-action="assign-me">Assign to me</button>` : ''}
        </div>
      </header>

      <section class="admin-dispute-detail__summary">
        <h4>${escapeHtml(getDisputeService(dispute))} <small>#${escapeHtml(String(dispute._id).slice(-8))}</small></h4>
        <p>${escapeHtml(dispute.reason || 'No reason provided.')}</p>
      </section>

      <section class="admin-dispute-detail__grid">
        <div><span>Customer</span><strong>${escapeHtml(customer.name || '-')}</strong><small>${escapeHtml(customer.email || customer.phone || '')}</small></div>
        <div><span>Technician</span><strong>${escapeHtml(worker.name || '-')}</strong><small>${escapeHtml(worker.email || worker.phone || '')}</small></div>
        <div><span>Booking</span><strong>${escapeHtml(String(booking._id || dispute.booking || '-').slice(-10))}</strong><small>${escapeHtml(booking.status || '-')}</small></div>
        <div><span>Payment</span><strong>${escapeHtml(formatMoney(amount))}</strong><small>${escapeHtml(`${booking.paymentMethod || '-'} / ${booking.paymentStatus || dispute.payment?.status || '-'}`)}</small></div>
        <div><span>Category</span><strong>${escapeHtml(dispute.category || 'other')}</strong><small>Opened ${escapeHtml(formatAdminDate(dispute.createdAt))}</small></div>
        <div><span>Decision</span><strong>${escapeHtml(dispute.decision || 'Pending')}</strong><small>${escapeHtml(dispute.refundAmount ? `Refund ${formatMoney(dispute.refundAmount)}` : (dispute.resolution || ''))}</small></div>
      </section>

      ${isAppealed || dispute.appealStatus ? `
        <section class="admin-dispute-appeal">
          <h4>Appeal - <span>${escapeHtml(dispute.appealStatus || '-')}</span></h4>
          <p>${escapeHtml(dispute.appealReason || '')}</p>
          <small>By ${escapeHtml(dispute.appealedByRole || '-')} - ${escapeHtml(formatAdminDate(dispute.appealedAt))}</small>
          ${dispute.appealStatus === 'pending' ? `
            <div class="admin-dispute-appeal__actions">
              <button class="bk-action-btn bk-action-btn--xs" data-action="appeal-uphold">Uphold appeal</button>
              <button class="bk-action-btn bk-action-btn--xs" data-action="appeal-overturn">Overturn appeal</button>
            </div>
          ` : ''}
        </section>
      ` : ''}

      <section class="admin-dispute-evidence-section">
        <h4>Evidence (${evidence.length})</h4>
        <div class="admin-dispute-evidence-grid">
          <div>
            <h5>Customer (${customerEvidence.length})</h5>
            <div class="admin-dispute-evidence">${customerEvidence.length ? customerEvidence.map(renderEvidenceItem).join('') : '<p class="admin-dispute-empty">No customer evidence.</p>'}</div>
          </div>
          <div>
            <h5>Technician (${workerEvidence.length})</h5>
            <div class="admin-dispute-evidence">${workerEvidence.length ? workerEvidence.map(renderEvidenceItem).join('') : '<p class="admin-dispute-empty">No technician evidence.</p>'}</div>
          </div>
          ${adminEvidence.length ? `
            <div>
              <h5>Admin (${adminEvidence.length})</h5>
              <div class="admin-dispute-evidence">${adminEvidence.map(renderEvidenceItem).join('')}</div>
            </div>
          ` : ''}
        </div>
        ${!resolved ? `
          <div class="admin-dispute-evidence-actions">
            <label>Request more evidence:</label>
            <select data-field="evidence-target">
              <option value="both">Both parties</option>
              <option value="user">Customer only</option>
              <option value="worker">Technician only</option>
            </select>
            <input type="text" data-field="evidence-message" placeholder="Optional message" maxlength="200">
            <button class="bk-action-btn bk-action-btn--xs" data-action="request-evidence">Request</button>
          </div>
        ` : ''}
      </section>

      <section class="admin-dispute-history-section">
        <h4>Timeline</h4>
        ${renderHistoryTimeline(dispute.history)}
      </section>

      <section class="admin-dispute-notes-section">
        <h4>Internal notes (not visible to parties)</h4>
        ${renderInternalNotes(dispute.internalNotes)}
        ${!resolved ? `
          <div class="admin-dispute-notes-actions">
            <textarea data-field="internal-note" rows="2" maxlength="2000" placeholder="Add an internal note..."></textarea>
            <button class="bk-action-btn bk-action-btn--xs" data-action="add-note">Save note</button>
          </div>
        ` : ''}
      </section>

      ${!resolved ? `
        <section class="admin-dispute-decision">
          <h4>Decision</h4>
          ${dispute.status === 'open' ? `
            <button class="bk-action-btn bk-action-btn--xs" data-action="mark-reviewing">Mark as reviewing</button>
          ` : ''}
          <div class="admin-dispute-decision__form">
            <label>Outcome
              <select data-field="decision">
                ${hasEscrow ? '<option value="refund">Full refund to customer</option>' : ''}
                <option value="release">Release to technician${hasEscrow ? '' : ' (close cash booking)'}</option>
                ${hasEscrow ? '<option value="partial_refund">Partial refund</option>' : ''}
                <option value="redo">Send back for redo</option>
              </select>
            </label>
            <label class="admin-dispute-decision__refund" hidden>
              <span class="admin-dispute-decision__refund-label">Refund amount: <strong data-field="refund-display">${formatMoney(Math.floor(paymentAmount / 2))}</strong> <small>of ${formatMoney(paymentAmount)}</small></span>
              <input type="range" min="1" max="${Math.max(1, Math.floor(paymentAmount) - 1)}" step="1" value="${Math.floor(paymentAmount / 2)}" data-field="refund-range">
              <input type="number" min="1" max="${Math.max(1, Math.floor(paymentAmount) - 1)}" step="1" value="${Math.floor(paymentAmount / 2)}" data-field="refund-amount">
            </label>
            <label>Resolution note (sent to both parties)
              <textarea data-field="resolution" rows="3" required minlength="10" placeholder="Explain decision to customer and technician..."></textarea>
            </label>
            <label>Internal note (admin-only, optional)
              <textarea data-field="decision-internal-note" rows="2" maxlength="2000" placeholder="Private rationale..."></textarea>
            </label>
            <div class="admin-dispute-decision__actions">
              <button class="bk-action-btn admin-dispute-actions__release" data-action="resolve">Resolve dispute</button>
            </div>
          </div>
        </section>
      ` : `
        <section class="admin-dispute-decision admin-dispute-decision--resolved">
          <h4>Resolved</h4>
          <p><strong>${escapeHtml(dispute.decision || '-')}</strong>${dispute.refundAmount ? ` - Refund ${escapeHtml(formatMoney(dispute.refundAmount))}` : ''}</p>
          <p>${escapeHtml(dispute.resolution || '')}</p>
          <small>By ${escapeHtml(dispute.resolvedBy?.name || '-')} at ${escapeHtml(formatAdminDate(dispute.resolvedAt))}</small>
        </section>
      `}
    </div>
  `;

  wireDisputeModalActions(dispute._id);
}

function wireDisputeModalActions(disputeId) {
  const body = document.getElementById('adminDisputeBody');
  if (!body) return;

  const decisionSelect = body.querySelector('[data-field="decision"]');
  const refundWrap = body.querySelector('.admin-dispute-decision__refund');
  const refundRange = body.querySelector('[data-field="refund-range"]');
  const refundAmount = body.querySelector('[data-field="refund-amount"]');

  const syncRefundVisibility = () => {
    if (!decisionSelect || !refundWrap) return;
    refundWrap.hidden = decisionSelect.value !== 'partial_refund';
  };
  decisionSelect?.addEventListener('change', syncRefundVisibility);
  syncRefundVisibility();

  const refundDisplay = body.querySelector('[data-field="refund-display"]');
  const syncRefundDisplay = (v) => { if (refundDisplay) refundDisplay.textContent = formatMoney(Number(v) || 0); };
  if (refundRange && refundAmount) {
    refundRange.addEventListener('input', () => { refundAmount.value = refundRange.value; syncRefundDisplay(refundRange.value); });
    refundAmount.addEventListener('input', () => {
      const v = Number(refundAmount.value);
      if (Number.isFinite(v)) { refundRange.value = String(v); syncRefundDisplay(v); }
    });
  }

  body.querySelector('[data-action="assign-me"]')?.addEventListener('click', () => safeRun(async () => {
    await assignDispute(disputeId);
    showToast('Assigned to you.', 'success');
    await refreshDisputeAndModal(disputeId);
  }));

  body.querySelector('[data-action="mark-reviewing"]')?.addEventListener('click', () => safeRun(async () => {
    await reviewDispute(disputeId);
    showToast('Marked as reviewing.', 'success');
    await refreshDisputeAndModal(disputeId);
  }));

  body.querySelector('[data-action="request-evidence"]')?.addEventListener('click', () => safeRun(async () => {
    const target = body.querySelector('[data-field="evidence-target"]')?.value || 'both';
    const message = body.querySelector('[data-field="evidence-message"]')?.value || '';
    await requestDisputeEvidence(disputeId, target, message);
    showToast('Evidence requested.', 'success');
    await refreshDisputeAndModal(disputeId);
  }));

  body.querySelector('[data-action="add-note"]')?.addEventListener('click', () => safeRun(async () => {
    const noteEl = body.querySelector('[data-field="internal-note"]');
    const note = String(noteEl?.value || '').trim();
    if (!note) { showToast('Note is empty.', 'error'); return; }
    await addDisputeNote(disputeId, note);
    showToast('Note added.', 'success');
    if (noteEl) noteEl.value = '';
    await refreshDisputeAndModal(disputeId);
  }));

  body.querySelector('[data-action="resolve"]')?.addEventListener('click', () => safeRun(async () => {
    const decision = decisionSelect?.value;
    const resolution = String(body.querySelector('[data-field="resolution"]')?.value || '').trim();
    const internalNote = String(body.querySelector('[data-field="decision-internal-note"]')?.value || '').trim();
    if (resolution.length < 10) { showToast('Resolution note must be at least 10 chars.', 'error'); return; }
    const payload = { decision, resolution };
    if (decision === 'partial_refund') {
      payload.refundAmount = Number(refundAmount?.value || refundRange?.value || 0);
    }
    if (internalNote) payload.internalNote = internalNote;
    const label = decision === 'refund' ? 'refund customer in full'
      : decision === 'release' ? 'release payment to technician'
      : decision === 'partial_refund' ? `partially refund ${payload.refundAmount} EGP`
      : 'send job back for redo';
    if (!confirm(`Confirm: ${label}?`)) return;
    await resolveDispute(disputeId, payload);
    showToast('Dispute resolved.', 'success');
    await renderDisputes({ force: true });
    loadAdminData();
    await refreshDisputeAndModal(disputeId);
  }));

  body.querySelector('[data-action="appeal-uphold"]')?.addEventListener('click', () => safeRun(async () => {
    const note = prompt('Optional note for upholding appeal:') || '';
    await resolveDisputeAppeal(disputeId, 'upheld', note);
    showToast('Appeal upheld.', 'success');
    await refreshDisputeAndModal(disputeId);
  }));
  body.querySelector('[data-action="appeal-overturn"]')?.addEventListener('click', () => safeRun(async () => {
    const note = prompt('Optional note for overturning appeal:') || '';
    await resolveDisputeAppeal(disputeId, 'overturned', note);
    showToast('Appeal overturned. Case re-opened for review.', 'success');
    await refreshDisputeAndModal(disputeId);
  }));
}

async function refreshDisputeAndModal(disputeId) {
  try {
    const res = await getDisputeById(disputeId);
    const dispute = res?.data || res;
    const idx = _adminDisputes.findIndex(d => d._id === disputeId);
    if (idx >= 0) _adminDisputes[idx] = dispute;
    renderDisputeModal(dispute);
    updateDisputeKpis(_adminDisputes);
  } catch (err) {
    showToast(err?.message || 'Failed to refresh dispute.', 'error');
  }
}

function safeRun(fn) {
  return Promise.resolve()
    .then(fn)
    .catch(err => {
      showToast(err?.response?.data?.message || err?.data?.message || err?.message || 'Action failed.', 'error');
    });
}

function formatSupportIssueType(type) {
  return ({
    late: 'Late arrival',
    no_show: 'No-show',
    during_work_problem: 'During-work problem',
    safety: 'Safety',
    post_completion: 'Post-completion',
    other: 'Other',
  })[type] || 'Other';
}

function formatSupportIssueStatus(status) {
  return ({
    open: 'Open',
    reviewing: 'Reviewing',
    waiting_customer: 'Waiting customer',
    waiting_worker: 'Waiting worker',
    resolved: 'Resolved',
    closed: 'Closed',
  })[status] || 'Open';
}

function getSupportBooking(issue) {
  return issue?.booking && typeof issue.booking === 'object' ? issue.booking : {};
}

function supportIssueMatchesSearch(issue, query) {
  if (!query) return true;
  const booking = getSupportBooking(issue);
  const haystack = [
    issue._id,
    booking._id,
    issue.customer?.name,
    issue.customer?.email,
    issue.worker?.name,
    issue.worker?.email,
    booking.service?.title,
    booking.serviceCategory,
    issue.type,
    issue.description,
    issue.status,
    issue.priority,
  ].filter(Boolean).join(' ').toLowerCase();
  return haystack.includes(query.toLowerCase());
}

async function fetchAdminSupportIssues() {
  const params = {
    limit: 100,
    status: document.getElementById('supportStatusFilter')?.value || '',
    priority: document.getElementById('supportPriorityFilter')?.value || '',
    type: document.getElementById('supportTypeFilter')?.value || '',
  };
  Object.keys(params).forEach(key => { if (!params[key]) delete params[key]; });
  const result = await getAdminSupportIssues(params);
  return result?.issues || [];
}

async function renderSupportIssues(options = {}) {
  const tbody = document.querySelector('#supportIssuesTable tbody');
  if (!tbody) return;

  const shouldFetch = options.force || !options.reuseCache || !_supportLoadedOnce;
  if (shouldFetch) {
    tbody.innerHTML = skTableRows(6, 8);
    _adminSupportIssues = await fetchAdminSupportIssues();
    _supportLoadedOnce = true;
  }

  const openCount = _adminSupportIssues.filter(item => !['resolved', 'closed'].includes(item.status)).length;
  const badge = document.getElementById('adminSupportBadge');
  if (badge) {
    badge.textContent = String(openCount);
    badge.hidden = openCount === 0;
  }

  const query = String(document.getElementById('supportSearch')?.value || '').trim();
  const visible = _adminSupportIssues.filter(issue => supportIssueMatchesSearch(issue, query));
  if (!visible.length) {
    tbody.innerHTML = '<tr><td colspan="8" class="center-align" style="padding: 3rem; color: var(--color-text-muted);">No support issues match the current filters.</td></tr>';
    return;
  }

  tbody.innerHTML = visible.map(issue => {
    const booking = getSupportBooking(issue);
    const service = booking.service?.title || booking.serviceCategory || 'Service booking';
    const canAct = !['resolved', 'closed'].includes(issue.status);
    return `
      <tr class="admin-support-row admin-support-row--${escapeHtml(issue.priority || 'normal')}">
        <td><strong>${escapeHtml(formatSupportIssueType(issue.type))}</strong><small>${escapeHtml(String(issue._id || '').slice(-8))}</small></td>
        <td><div>${escapeHtml(service)}</div><small>${escapeHtml(booking.status || '-')}</small></td>
        <td><div>${escapeHtml(issue.customer?.name || '-')}</div><small>${escapeHtml(issue.customer?.email || '')}</small></td>
        <td><div>${escapeHtml(issue.worker?.name || '-')}</div><small>${escapeHtml(issue.worker?.email || '')}</small></td>
        <td><span class="admin-support-priority admin-support-priority--${escapeHtml(issue.priority || 'normal')}">${escapeHtml(issue.priority || 'normal')}</span></td>
        <td><span class="admin-dispute-status">${escapeHtml(formatSupportIssueStatus(issue.status))}</span></td>
        <td>${escapeHtml(formatAdminDate(issue.createdAt))}</td>
        <td class="center-align">
          <div class="admin-dispute-actions">
            <button class="bk-action-btn bk-action-btn--xs" type="button" data-support-view="${escapeHtml(issue._id)}">View</button>
            ${canAct ? `<button class="bk-action-btn bk-action-btn--xs" type="button" data-support-status="reviewing" data-id="${escapeHtml(issue._id)}">Review</button>` : ''}
            ${canAct ? `<button class="bk-action-btn bk-action-btn--xs" type="button" data-support-status="waiting_customer" data-id="${escapeHtml(issue._id)}">Ask Customer</button>` : ''}
            ${canAct ? `<button class="bk-action-btn bk-action-btn--xs" type="button" data-support-status="waiting_worker" data-id="${escapeHtml(issue._id)}">Ask Tech</button>` : ''}
            ${canAct ? `<button class="bk-action-btn bk-action-btn--xs admin-dispute-actions__release" type="button" data-support-resolve="${escapeHtml(issue._id)}">Resolve</button>` : ''}
            ${canAct && booking.status === 'awaiting_customer_confirmation' ? `<button class="bk-action-btn bk-action-btn--xs admin-dispute-actions__refund" type="button" data-support-escalate="${escapeHtml(issue._id)}">Escalate</button>` : ''}
          </div>
        </td>
      </tr>
    `;
  }).join('');

  bindSupportIssueActions();
}

function bindSupportIssueActions() {
  document.querySelectorAll('[data-support-view]').forEach(btn => {
    btn.onclick = () => openAdminSupportModal(btn.dataset.supportView);
  });
  document.querySelectorAll('[data-support-status]').forEach(btn => {
    btn.onclick = async () => {
      try {
        await updateSupportIssueStatus(btn.dataset.id, { status: btn.dataset.supportStatus });
        showToast('Support issue updated.', 'success');
        await renderSupportIssues({ force: true });
      } catch (err) {
        showToast(err?.data?.message || err.message || 'Failed to update support issue.', 'error');
      }
    };
  });
  document.querySelectorAll('[data-support-resolve]').forEach(btn => {
    btn.onclick = async () => {
      const resolution = prompt('Resolution note for this support issue:');
      if (!resolution) return;
      try {
        await resolveSupportIssue(btn.dataset.supportResolve, { resolution });
        showToast('Support issue resolved.', 'success');
        await renderSupportIssues({ force: true });
      } catch (err) {
        showToast(err?.data?.message || err.message || 'Failed to resolve support issue.', 'error');
      }
    };
  });
  document.querySelectorAll('[data-support-escalate]').forEach(btn => {
    btn.onclick = async () => {
      if (!confirm('Escalate this support issue into a payment dispute?')) return;
      try {
        await escalateSupportIssueToDispute(btn.dataset.supportEscalate, {});
        showToast('Support issue escalated to dispute.', 'success');
        await Promise.all([renderSupportIssues({ force: true }), renderDisputes({ force: true })]);
      } catch (err) {
        showToast(err?.data?.message || err.message || 'Failed to escalate support issue.', 'error');
      }
    };
  });
}

function openAdminSupportModal(issueId) {
  const issue = _adminSupportIssues.find(item => item._id === issueId);
  const body = document.getElementById('adminSupportBody');
  if (!issue || !body) return;
  const booking = getSupportBooking(issue);
  const service = booking.service?.title || booking.serviceCategory || 'Service booking';
  const evidence = Array.isArray(issue.evidence) ? issue.evidence : [];
  body.innerHTML = `
    <div class="admin-dispute-detail">
      <div class="admin-dispute-detail__summary">
        <span class="admin-support-priority admin-support-priority--${escapeHtml(issue.priority || 'normal')}">${escapeHtml(issue.priority || 'normal')} priority</span>
        <h4>${escapeHtml(formatSupportIssueType(issue.type))} - ${escapeHtml(service)}</h4>
        <p>${escapeHtml(issue.description || '')}</p>
      </div>
      <div class="admin-dispute-detail__grid">
        <div><span>Customer</span><strong>${escapeHtml(issue.customer?.name || '-')}</strong><small>${escapeHtml(issue.customer?.email || '')}</small></div>
        <div><span>Technician</span><strong>${escapeHtml(issue.worker?.name || '-')}</strong><small>${escapeHtml(issue.worker?.email || '')}</small></div>
        <div><span>Status</span><strong>${escapeHtml(formatSupportIssueStatus(issue.status))}</strong><small>${escapeHtml(formatAdminDate(issue.createdAt))}</small></div>
        <div><span>Booking</span><strong>${escapeHtml(String(booking._id || '-').slice(-10))}</strong><small>${escapeHtml(booking.status || '-')}</small></div>
        <div><span>Admin notes</span><strong>${escapeHtml(issue.adminNotes || '-')}</strong></div>
        <div><span>Resolution</span><strong>${escapeHtml(issue.resolution || 'Pending')}</strong></div>
      </div>
      <div class="admin-dispute-evidence">
        <h4>Evidence</h4>
        ${evidence.length ? evidence.map(url => `<a href="${escapeHtml(url)}" target="_blank" rel="noopener noreferrer"><img src="${escapeHtml(url)}" alt="Support evidence"><span>${escapeHtml(url)}</span></a>`).join('') : '<p>No evidence files uploaded.</p>'}
      </div>
    </div>
  `;
  _openProfileModal?.('adminSupportModal');
}

async function renderPendingApprovals(filter = {}) {
  const container = document.getElementById('adminPendingApprovalsList');
  if (!container) return;
  container.innerHTML = skList(4);

  try {
    const { items } = await getPendingApprovals(filter);
    if (!items.length) {
      container.innerHTML = '<p class="empty-state">No pending approvals.</p>';
      return;
    }

    container.innerHTML = `
      <div class="fp-table-wrap">
      <table class="admin-table fp-table">
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
      </div>
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
  container.innerHTML = skList(4);

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
      <div class="fp-table-wrap">
      <table class="admin-table fp-table">
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
      </div>
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

// CSV export — anchor tags cannot send Authorization, so fetch as blob and trigger download manually.
document.getElementById('btnExportSettlementsCsv')?.addEventListener('click', async () => {
  try {
    const apiBase = (window.SERVIO_CONFIG && window.SERVIO_CONFIG.API_BASE) || '';
    const token   = localStorage.getItem('servio_token');
    const res = await fetch(`${apiBase}/payments/admin/settlements/history.csv`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const blob = await res.blob();
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href     = url;
    a.download = `settlements-history-${new Date().toISOString().slice(0,10)}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  } catch (err) {
    showToast(err.message || 'Failed to export CSV.', 'error');
  }
});

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

// ─── Escrow Payments Tab (Plan 1 Task 18) ───────────────────────────────

const _payState = { page: 1, limit: 20, filters: {} };

function _payFmtMoney(n) {
  return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'EGP' }).format(Number(n) || 0);
}
function _payFmtDate(d) { return d ? new Date(d).toLocaleDateString() : '—'; }
function _payAge(d) {
  if (!d) return '—';
  const h = Math.floor((Date.now() - new Date(d).getTime()) / 3600000);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

async function loadPaymentsKpis() {
  try {
    const r = await adminPaymentsStats();
    const data = r?.data || r || {};
    for (const [k, v] of Object.entries(data)) {
      const el = document.querySelector(`#paymentsKpis .kpi[data-key="${k}"] .kpi__value`);
      if (!el) continue;
      el.textContent = (typeof v === 'number' && /Total$/i.test(k)) ? _payFmtMoney(v) : String(v ?? '—');
    }
  } catch (e) { console.warn('kpi load failed', e); }
}

async function loadPaymentsTable() {
  const tbody = document.getElementById('paymentsTbody');
  if (!tbody) return;
  try {
    const r = await adminListPayments({ ..._payState.filters, page: _payState.page, limit: _payState.limit });
    const items = r?.data || [];
    tbody.innerHTML = items.length
      ? items.map(_payRowHtml).join('')
      : '<tr><td colspan="10" class="center-align" style="padding:1.5rem;">No payments found.</td></tr>';
    tbody.querySelectorAll('[data-action="view"]').forEach((btn) => {
      btn.onclick = () => openPaymentDetailDrawer(btn.dataset.bookingId);
    });
  } catch (e) { console.warn('payments table load failed', e); }
}

function _payRowHtml(p) {
  const b = p.booking || {};
  const cust = b.user || b.customer || {};
  const tech = b.worker || b.technician || {};
  const svc = b.service || {};
  return `<tr>
    <td>#${(b._id || p._id || '').toString().slice(-4) || '—'}</td>
    <td>${_payFmtDate(p.createdAt)}</td>
    <td>${cust.name || '—'}</td>
    <td>${tech.name || '—'}</td>
    <td>${svc.title || '—'}</td>
    <td>${_payFmtMoney(p.amount)}</td>
    <td>${_payFmtMoney(b.platformFeeAmount || 0)}</td>
    <td><span class="status-chip status-chip--${p.status}">${p.status}</span></td>
    <td>${_payAge(p.createdAt)}</td>
    <td><button class="btn btn--small" data-action="view" data-booking-id="${b._id || ''}">View</button></td>
  </tr>`;
}

async function openPaymentDetailDrawer(bookingId) {
  const drawer = document.getElementById('paymentDrawer');
  if (!drawer || !bookingId) return;
  drawer.hidden = false;
  drawer.innerHTML = '<p style="padding:1rem;">Loading…</p>';
  try {
    const r = await adminListPayments({ bookingId, limit: 1 });
    const p = (r?.data || [])[0];
    if (!p) { drawer.innerHTML = '<p style="padding:1rem;">Not found</p>'; return; }
    drawer.innerHTML = _payDrawerHtml(p);
    drawer.querySelector('[data-close]').onclick = () => { drawer.hidden = true; };
    const approveBtn = drawer.querySelector('[data-action="approve"]');
    if (approveBtn) approveBtn.onclick = () => {
      const tech = p.booking?.worker?.name || p.booking?.technician?.name || 'tech';
      const earn = (p.booking?.basePrice || p.booking?.totalPrice || p.amount) - (p.booking?.platformFeeAmount || 0);
      openPaymentConfirmModal({
        title: 'Approve & Release',
        body: `Release ${_payFmtMoney(earn)} to ${tech}?`,
        onConfirm: async () => {
          await adminApprovePayment(p.booking._id);
          drawer.hidden = true;
          await renderPaymentsTab();
        },
      });
    };
    const refundBtn = drawer.querySelector('[data-action="partial-refund"]');
    if (refundBtn) refundBtn.onclick = () => {
      openPartialRefundModal({
        payment: p,
        onConfirm: async (payload) => {
          await adminPartialRefund(p.booking._id, payload);
          drawer.hidden = true;
          await renderPaymentsTab();
        },
      });
    };
    const forceReleaseBtn = drawer.querySelector('[data-action="force-release"]');
    if (forceReleaseBtn) forceReleaseBtn.onclick = () => {
      const reason = window.prompt('Emergency force-release reason (required, min 10 chars):');
      if (!reason || reason.trim().length < 10) { showToast('Reason required (min 10 chars)', 'error'); return; }
      openPaymentConfirmModal({
        title: 'Force-release (emergency)',
        body: `Bypass workflow and release ${_payFmtMoney(p.amount)} now? Logged for audit.`,
        onConfirm: async () => {
          try {
            await adminForceRelease(p._id, { reason: reason.trim() });
            showToast('Payment force-released', 'success');
            drawer.hidden = true;
            await renderPaymentsTab();
          } catch (err) { showToast(err.message || 'Force-release failed', 'error'); }
        },
      });
    };
    const forceLockBtn = drawer.querySelector('[data-action="force-lock"]');
    if (forceLockBtn) forceLockBtn.onclick = () => {
      const reason = window.prompt('Lock reason (required, min 10 chars):');
      if (!reason || reason.trim().length < 10) { showToast('Reason required (min 10 chars)', 'error'); return; }
      openPaymentConfirmModal({
        title: 'Lock payment',
        body: 'Lock prevents auto-release and worker actions until unlocked.',
        onConfirm: async () => {
          try {
            await adminForceLock(p._id, { reason: reason.trim() });
            showToast('Payment locked', 'success');
            drawer.hidden = true;
            await renderPaymentsTab();
          } catch (err) { showToast(err.message || 'Lock failed', 'error'); }
        },
      });
    };
    const forceUnlockBtn = drawer.querySelector('[data-action="force-unlock"]');
    if (forceUnlockBtn) forceUnlockBtn.onclick = () => {
      const reason = window.prompt('Unlock reason (required, min 10 chars):');
      if (!reason || reason.trim().length < 10) { showToast('Reason required (min 10 chars)', 'error'); return; }
      openPaymentConfirmModal({
        title: 'Unlock payment',
        body: 'Resume normal escrow flow for this payment.',
        onConfirm: async () => {
          try {
            await adminForceUnlock(p._id, { reason: reason.trim() });
            showToast('Payment unlocked', 'success');
            drawer.hidden = true;
            await renderPaymentsTab();
          } catch (err) { showToast(err.message || 'Unlock failed', 'error'); }
        },
      });
    };
  } catch (e) {
    drawer.innerHTML = `<p style="padding:1rem;">Error: ${e.message || e}</p>`;
  }
}

function _payDrawerHtml(p) {
  const b = p.booking || {};
  const cust = b.user || b.customer || {};
  const tech = b.worker || b.technician || {};
  const total = b.basePrice || b.totalPrice || p.amount;
  const fee = b.platformFeeAmount || 0;
  return `<div class="drawer__head">
      <h3>Payment ${_payFmtMoney(p.amount)}</h3>
      <button data-close aria-label="Close">&times;</button>
    </div>
    <dl class="drawer__meta">
      <dt>Status</dt><dd><span class="status-chip status-chip--${p.status}">${p.status}</span></dd>
      <dt>Booking</dt><dd>#${b._id || ''}</dd>
      <dt>Customer</dt><dd>${cust.name || '—'}</dd>
      <dt>Tech</dt><dd>${tech.name || '—'}</dd>
      <dt>Service</dt><dd>${(b.service && b.service.title) || '—'}</dd>
      <dt>Tech earns</dt><dd>${_payFmtMoney(total - fee)}</dd>
      <dt>Platform fee</dt><dd>${_payFmtMoney(fee)}</dd>
    </dl>
    <div class="drawer__actions">
      ${p.status === 'held' || p.status === 'pending_review' ? '<button class="btn btn--primary" data-action="approve">Approve &amp; Release</button>' : ''}
      ${p.status === 'held' || p.status === 'released' ? '<button class="btn btn--warn" data-action="partial-refund">Partial refund…</button>' : ''}
      ${p.status === 'held' && !p.locked ? '<button class="btn btn--danger" data-action="force-release">Force-release (emergency)</button>' : ''}
      ${p.status === 'held' && !p.locked ? '<button class="btn btn--ghost" data-action="force-lock">Lock</button>' : ''}
      ${p.locked ? '<button class="btn btn--ghost" data-action="force-unlock">Unlock</button>' : ''}
    </div>`;
}

export async function renderPaymentsTab() {
  await Promise.all([loadPaymentsKpis(), loadPaymentsTable(), renderPendingApprovals()]);
  const statusEl = document.getElementById('payStatusFilter');
  if (statusEl) statusEl.onchange = (e) => {
    _payState.filters.status = e.target.value === 'all' ? '' : e.target.value;
    _payState.page = 1;
    loadPaymentsTable();
  };
  const custEl = document.getElementById('payCustomerFilter');
  if (custEl) custEl.onchange = (e) => { _payState.filters.customer = e.target.value; loadPaymentsTable(); };
  const wrkEl = document.getElementById('payWorkerFilter');
  if (wrkEl) wrkEl.onchange = (e) => { _payState.filters.worker = e.target.value; loadPaymentsTable(); };
  const fromEl = document.getElementById('payFromDate');
  if (fromEl) fromEl.onchange = (e) => { _payState.filters.from = e.target.value; loadPaymentsTable(); };
  const toEl = document.getElementById('payToDate');
  if (toEl) toEl.onchange = (e) => { _payState.filters.to = e.target.value; loadPaymentsTable(); };
  const resetEl = document.getElementById('payResetFilters');
  if (resetEl) resetEl.onclick = () => {
    _payState.filters = {};
    _payState.page = 1;
    document.querySelectorAll('.filters-bar input, .filters-bar select').forEach((el) => { el.value = ''; });
    loadPaymentsTable();
  };
  const approvalMethodEl = document.getElementById('approvalMethodFilter');
  if (approvalMethodEl) approvalMethodEl.onchange = (e) => renderPendingApprovals(e.target.value ? { method: e.target.value } : {});
}

// Finance inner tab switching (global so other modules can call)
window.switchFinanceTab = function switchFinanceTab(name) {
  const target = name === 'settlements' ? 'settlements' : 'payments';
  document.querySelectorAll('.fin-tab').forEach(t => {
    const on = t.dataset.finTab === target;
    t.classList.toggle('is-active', on);
    t.setAttribute('aria-selected', on ? 'true' : 'false');
  });
  document.querySelectorAll('.fin-section').forEach(s => {
    s.hidden = (s.dataset.finSection !== target);
  });
  sessionStorage.setItem('servio_admin_fin_tab', target);
  if (target === 'payments' && typeof renderPaymentsTab === 'function') {
    setTimeout(() => renderPaymentsTab(), 30);
  }
  if (target === 'settlements' && typeof renderSettlementsTab === 'function') {
    setTimeout(() => renderSettlementsTab(), 30);
  }
};

// Auto-render when finance tab opened
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.admin-nav__btn[data-tab="finance"]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const sub = sessionStorage.getItem('servio_admin_fin_tab') || 'payments';
      setTimeout(() => window.switchFinanceTab(sub), 50);
    });
  });
  if (document.querySelector('.admin-panel[data-panel="finance"].is-active')) {
    const sub = sessionStorage.getItem('servio_admin_fin_tab') || 'payments';
    window.switchFinanceTab(sub);
  }
});
/* ── Plan 2 Task 17: Cash Settlements 3 sub-tabs ──────────────────── */

function _fmtMoney(n) {
  try { return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'EGP', maximumFractionDigits: 2 }).format(Number(n) || 0); }
  catch (_) { return (Number(n || 0)).toFixed(2) + ' EGP'; }
}

function _ageOf(d) {
  if (!d) return '—';
  const h = Math.floor((Date.now() - new Date(d).getTime()) / 3600000);
  if (h < 1) return 'now';
  if (h < 24) return h + 'h';
  return Math.floor(h / 24) + 'd';
}

function _setKpi(key, val) {
  const el = document.querySelector('#settlementsKpis .kpi[data-key="' + key + '"] .kpi__value');
  if (el) el.textContent = val;
}

function switchSettlementSubtab(name) {
  document.querySelectorAll('.subtab').forEach(t => {
    const on = t.dataset.subtab === name;
    t.classList.toggle('is-active', on);
    t.setAttribute('aria-selected', on ? 'true' : 'false');
  });
  const map = { 'worker-debts': 'subWorkerDebts', 'payout-requests': 'subPayoutRequests', 'history': 'subHistory' };
  Object.entries(map).forEach(([k, id]) => {
    const el = document.getElementById(id);
    if (el) el.hidden = (k !== name);
  });
}

async function renderWorkerDebts() {
  const tbody = document.getElementById('workerDebtsTbody');
  if (!tbody) return;
  try {
    const r = await adminListCashDebtsGrouped();
    const rows = r?.data || [];
    if (!rows.length) {
      tbody.innerHTML = '<tr><td colspan="7" class="center-align" style="padding:3rem;color:var(--color-text-muted);">No outstanding debts.</td></tr>';
      return;
    }
    tbody.innerHTML = rows.map(row => {
      const name = row.worker?.name || '—';
      const email = row.worker?.email || '';
      const blocked = (row.totalOwed || 0) >= 300 ? '<span style="color:#dc2626;">BLOCKED</span>' : '';
      return '<tr>'
        + '<td>' + name + '<br><small style="color:#6b7280;">' + email + '</small></td>'
        + '<td class="right-align">' + _fmtMoney(row.totalOwed) + '</td>'
        + '<td>' + (row.oldest ? _ageOf(row.oldest) : '—') + '</td>'
        + '<td class="right-align">' + row.debtCount + '</td>'
        + '<td>' + (row.statusMix || []).join(', ') + '</td>'
        + '<td>' + blocked + '</td>'
        + '<td><button class="btn-premium btn-premium--sm" data-action="view" data-worker-id="' + row.workerId + '">View</button></td>'
        + '</tr>';
    }).join('');
    tbody.querySelectorAll('[data-action="view"]').forEach(b => {
      b.onclick = () => openWorkerDebtDrawer(b.dataset.workerId);
    });
  } catch (e) {
    console.error('[workerDebts]', e);
    tbody.innerHTML = '<tr><td colspan="7" class="center-align" style="color:#dc2626;">Load failed: ' + (e.message || e) + '</td></tr>';
  }
}

async function renderPayoutRequests() {
  const tbody = document.getElementById('payoutRequestsTbody');
  if (!tbody) return;
  try {
    const r = await adminListPayouts();
    const items = r?.data || [];
    if (!items.length) {
      tbody.innerHTML = '<tr><td colspan="6" class="center-align" style="padding:3rem;color:var(--color-text-muted);">No payout requests.</td></tr>';
      return;
    }
    tbody.innerHTML = items.map(p => {
      const name = p.worker?.name || '—';
      const email = p.worker?.email || '';
      return '<tr>'
        + '<td>' + name + '<br><small style="color:#6b7280;">' + email + '</small></td>'
        + '<td>' + _ageOf(p.requestedAt || p.createdAt) + '</td>'
        + '<td class="right-align">' + _fmtMoney(p.amount) + '</td>'
        + '<td>' + p.payoutMethod + '</td>'
        + '<td><span class="status-chip status-chip--' + p.status + '">' + p.status + '</span></td>'
        + '<td><button class="btn-premium btn-premium--sm" data-payout-id="' + p._id + '" data-status="' + p.status + '">View</button></td>'
        + '</tr>';
    }).join('');
    tbody.querySelectorAll('button[data-payout-id]').forEach(b => {
      b.onclick = () => openPayoutDecisionModal({
        payoutId: b.dataset.payoutId,
        currentStatus: b.dataset.status,
        onSuccess: () => { renderPayoutRequests(); renderSettlementsKpis(); },
      });
    });
  } catch (e) {
    console.error('[payouts]', e);
    tbody.innerHTML = '<tr><td colspan="6" class="center-align" style="color:#dc2626;">Load failed: ' + (e.message || e) + '</td></tr>';
  }
}

async function renderSettlementHistory() {
  const tbody = document.getElementById('historyTbody');
  if (!tbody) return;
  try {
    const r = await adminListSettlements({ status: 'verified' });
    const items = r?.data || [];
    if (!items.length) {
      tbody.innerHTML = '<tr><td colspan="6" class="center-align" style="padding:3rem;color:var(--color-text-muted);">No verified settlements.</td></tr>';
      return;
    }
    tbody.innerHTML = items.map(s => '<tr>'
      + '<td>' + new Date(s.createdAt).toLocaleString() + '</td>'
      + '<td>' + (s.worker?.name || '—') + '</td>'
      + '<td>' + s.method + '</td>'
      + '<td class="right-align">' + _fmtMoney(s.totalAmount) + '</td>'
      + '<td>' + s.status + '</td>'
      + '<td>' + (s.verifiedBy?.name || '—') + '</td>'
      + '</tr>').join('');
  } catch (e) {
    console.error('[history]', e);
    tbody.innerHTML = '<tr><td colspan="6" class="center-align" style="color:#dc2626;">Load failed: ' + (e.message || e) + '</td></tr>';
  }
}

async function renderSettlementsKpis() {
  try {
    const [debts, payouts, verified] = await Promise.all([
      adminListCashDebtsGrouped().catch(() => ({ data: [] })),
      adminListPayouts().catch(() => ({ data: [] })),
      adminListSettlements({ status: 'verified' }).catch(() => ({ data: [] })),
    ]);
    const drows = debts?.data || [];
    const outstanding = drows.reduce((a, r) => a + (Number(r.totalOwed) || 0), 0);
    const blocked = drows.filter(r => (r.totalOwed || 0) >= 300).length;
    const queue = (payouts?.data || []).filter(p => ['pending', 'approved'].includes(p.status)).reduce((a, p) => a + (Number(p.amount) || 0), 0);
    const todayStart = new Date(); todayStart.setHours(0, 0, 0, 0);
    const settledTodayCount = (verified?.data || []).filter(s => new Date(s.verifiedAt || s.createdAt) >= todayStart).length;
    _setKpi('outstandingDebt', _fmtMoney(outstanding));
    _setKpi('blockedWorkers', String(blocked));
    _setKpi('payoutQueue', _fmtMoney(queue));
    _setKpi('settledToday', String(settledTodayCount));
  } catch (e) {
    console.error('[kpis]', e);
  }
}

async function openWorkerDebtDrawer(workerId) {
  const drawer = document.getElementById('settlementDrawer');
  if (!drawer) return;
  drawer.hidden = false;
  drawer.innerHTML = '<p>Loading…</p>';
  try {
    const r = await adminWorkerDebts(workerId);
    drawer.innerHTML = workerDrawerHtml(r?.data || {});
    drawer.querySelector('[data-close]').onclick = () => { drawer.hidden = true; };
    drawer.querySelectorAll('[data-action="verify-settlement"]').forEach(b => {
      b.onclick = () => openSettlementVerifyModal({
        settlementId: b.dataset.id,
        onSuccess: () => { drawer.hidden = true; renderWorkerDebts(); renderSettlementHistory(); renderSettlementsKpis(); },
      });
    });
    drawer.querySelectorAll('[data-action="mark-debt-paid"]').forEach(b => {
      b.onclick = async () => {
        if (!confirm('Mark this debt paid by admin override?')) return;
        try {
          await markCashDebtPaid(b.dataset.id, { amount: parseFloat(b.dataset.amount), adminNote: 'admin_override' });
          openWorkerDebtDrawer(workerId);
          renderWorkerDebts();
          renderSettlementsKpis();
        } catch (e) { alert(e.message || e); }
      };
    });
  } catch (e) {
    drawer.innerHTML = '<p style="color:#dc2626;">Load failed: ' + (e.message || e) + '</p><button data-close type="button">Close</button>';
    drawer.querySelector('[data-close]').onclick = () => { drawer.hidden = true; };
  }
}

function workerDrawerHtml(data) {
  const debts = data?.debts || [];
  const settlements = data?.settlements || [];
  const pending = settlements.length
    ? settlements.map(s => '<div class="drawer__settlement" style="padding:12px;border:1px solid #e5e7eb;border-radius:8px;margin-bottom:8px;">'
        + '<div><strong>' + _fmtMoney(s.totalAmount) + '</strong> via ' + s.method + ' · ref ' + (s.reference || '—') + '</div>'
        + (s.proofUrl ? '<div><a href="' + s.proofUrl + '" target="_blank" rel="noopener">View proof</a></div>' : '')
        + '<button class="btn-premium btn-premium--sm" data-action="verify-settlement" data-id="' + s._id + '" style="margin-top:8px;">Verify…</button>'
        + '</div>').join('')
    : '<p class="empty" style="color:#6b7280;">No pending settlements.</p>';
  const debtRows = debts.length
    ? debts.map(d => {
        const remaining = d.remaining ?? d.amount;
        const actionBtn = d.status !== 'paid'
          ? '<button class="btn-premium btn-premium--sm" data-action="mark-debt-paid" data-id="' + d._id + '" data-amount="' + remaining + '">Mark paid</button>'
          : '';
        return '<tr>'
          + '<td>#' + String(d.booking || '').toString().slice(-4) + '</td>'
          + '<td>' + _fmtMoney(remaining) + ' / ' + _fmtMoney(d.amount) + '</td>'
          + '<td>' + _ageOf(d.createdAt) + '</td>'
          + '<td><span class="status-chip status-chip--' + d.status + '">' + d.status + '</span></td>'
          + '<td>' + actionBtn + '</td>'
          + '</tr>';
      }).join('')
    : '<tr><td colspan="5" style="color:#6b7280;">No debts.</td></tr>';
  return '<div class="drawer__head" style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">'
    + '<h3 style="margin:0;">Worker debts</h3>'
    + '<button data-close type="button" style="background:none;border:none;font-size:24px;cursor:pointer;">×</button>'
    + '</div>'
    + '<section style="margin-bottom:24px;"><h4>Pending settlements</h4>' + pending + '</section>'
    + '<section><h4>Debt rows</h4>'
    + '<table class="bk-table"><thead><tr><th>Booking</th><th>Owed</th><th>Age</th><th>Status</th><th></th></tr></thead>'
    + '<tbody>' + debtRows + '</tbody></table></section>';
}

async function renderSettlementsTab() {
  await renderSettlementsKpis();
  await Promise.all([renderWorkerDebts(), renderPayoutRequests(), renderSettlementHistory()]);
  document.querySelectorAll('.subtab').forEach(t => {
    t.onclick = () => switchSettlementSubtab(t.dataset.subtab);
  });
  const initial = (location.hash || '').replace('#', '');
  if (['worker-debts', 'payout-requests', 'history'].includes(initial)) {
    switchSettlementSubtab(initial);
  } else {
    switchSettlementSubtab('worker-debts');
  }
}

// Settlements render is now driven by switchFinanceTab
