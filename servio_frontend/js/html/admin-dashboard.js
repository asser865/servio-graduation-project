/* ═══════════════════════════════════════════════
   Admin Dashboard — SERVIO
   ═══════════════════════════════════════════════ */

import { showToast } from '../components/toast.js';

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

function initAdminDashboard() {
  // ── Tab switching ──────────────────────────
  const navBtns = document.querySelectorAll('.admin-nav__btn');
  const panels  = document.querySelectorAll('.admin-panel');

  const headerTitle = document.getElementById('admin-header-title');
  function switchTab(tabName) {
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
      countEl.textContent = t('admin_users_count_filtered').replace('{v}', visible).replace('{n}', total);
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

  // ── Users: view (no-op) ───────────────────
  document.querySelectorAll('[data-action="view"]').forEach(btn => {
    btn.addEventListener('click', () => showToast(typeof window.t === 'function' ? window.t('toast_feature_soon') : 'Feature coming soon', 'info'));
  });

  // ── Users: suspend/unsuspend ──────────────
  document.querySelectorAll('[data-action="suspend"]').forEach(btn => {
    btn.addEventListener('click', () => {
      const row   = btn.closest('tr');
      const badge = row.querySelector('.status-badge');
      const isActive = badge.classList.contains('badge--active');
      const t = typeof window.t === 'function' ? window.t : (k) => k;
      badge.textContent = isActive ? t('status_suspended') : t('status_active');
      badge.className = isActive ? 'badge badge--suspended status-badge' : 'badge badge--active status-badge';
      badge.setAttribute('data-i18n', isActive ? 'status_suspended' : 'status_active');
      btn.textContent  = isActive ? t('admin_action_unsuspend') : t('admin_action_suspend');
      btn.setAttribute('data-i18n', isActive ? 'admin_action_unsuspend' : 'admin_action_suspend');
      row.dataset.status = isActive ? 'suspended' : 'active';
      showToast(typeof window.t === 'function'
        ? (isActive ? window.t('toast_user_suspended') : window.t('toast_user_unsuspended'))
        : (isActive ? 'User suspended' : 'User unsuspended'), isActive ? 'error' : 'success');
    });
  });

  // ── Users: delete ─────────────────────────
  document.querySelectorAll('[data-action="delete"]').forEach(btn => {
    btn.addEventListener('click', () => {
      const confirmMsg = typeof window.t === 'function' ? window.t('confirm_delete_user') : 'Delete this user? This action cannot be undone.';
      if (confirm(confirmMsg)) {
        btn.closest('tr').remove();
        _updateUserCount();
        showToast(typeof window.t === 'function' ? window.t('toast_user_deleted') : 'User deleted', 'info');
      }
    });
  });

  // ── Technicians: approve / reject helpers ─
  function doApprove(btn) {
    const card  = btn.closest('.pending-card');
    const email = card?.dataset.email || btn.dataset.email || '';
    if (email) {
      try {
        const raw = localStorage.getItem('servio_account');
        if (raw) {
          const acct = JSON.parse(raw);
          if (acct?.role === 'technician' && acct?.email?.toLowerCase() === email.toLowerCase()) {
            acct.status = 'approved';
            localStorage.setItem('servio_account', JSON.stringify(acct));
          }
        }
      } catch {}
    }
    card?.remove();
    showToast(typeof window.t === 'function' ? window.t('toast_tech_approved') : 'Technician approved', 'success');
  }

  function doReject(btn) {
    btn.closest('.pending-card')?.remove();
    showToast(typeof window.t === 'function' ? window.t('toast_app_rejected') : 'Application rejected', 'error');
  }

  document.querySelectorAll('[data-action="approve"]').forEach(btn => {
    btn.addEventListener('click', () => doApprove(btn));
  });

  document.querySelectorAll('[data-action="reject"]').forEach(btn => {
    btn.addEventListener('click', () => doReject(btn));
  });

  // ── Inject pending technician from localStorage ──
  (function injectDynamicPendingTechnician() {
    let acct = null;
    try { acct = JSON.parse(localStorage.getItem('servio_account') || 'null'); } catch {}
    if (!acct || acct.role !== 'technician' || acct.status !== 'pending') return;

    const list = document.querySelector('.pending-cards-list');
    if (!list) return;
    if (list.querySelector(`[data-email="${CSS.escape(acct.email)}"]`)) return;

    const initials = (acct.fullName || 'TN')
      .split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
    const skillsText = (acct.skills || []).join(', ') || '—';

    const card = document.createElement('div');
    card.className = 'pending-card';
    card.dataset.email = acct.email;
    card.innerHTML = `
      <div class="pending-card__info">
        <div class="pending-card__avatar">${initials}</div>
        <div>
          <strong>${acct.fullName || acct.email}</strong>
          <div class="pending-card__skills">${skillsText}</div>
        </div>
      </div>
      <div class="pending-card__docs">
        <div class="doc-item doc-item--ok" data-i18n="doc_national_id">National ID</div>
        <div class="doc-item doc-item--ok" data-i18n="doc_selfie">Selfie</div>
      </div>
      <div class="pending-card__actions">
        <button class="btn btn--primary btn--sm" data-action="approve" data-i18n="admin_action_approve">Approve</button>
        <button class="btn btn--danger-outline btn--sm" data-action="reject" data-i18n="admin_action_reject">Reject</button>
      </div>
    `;

    const approveBtn = card.querySelector('[data-action="approve"]');
    const rejectBtn  = card.querySelector('[data-action="reject"]');
    approveBtn.addEventListener('click', () => doApprove(approveBtn));
    rejectBtn.addEventListener('click',  () => doReject(rejectBtn));

    list.prepend(card);
  })();

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
      infoEl.textContent = t('admin_tech_count_filtered')
        .replace('{v}', visibleCount)
        .replace('{n}', total);
    }
  }

  techSearch?.addEventListener('input', _applyTechFilters);
  techStatusFilter?.addEventListener('change', _applyTechFilters);

  document.getElementById('exportTechsBtn')?.addEventListener('click', () => {
    showToast(typeof window.t === 'function' ? window.t('toast_tech_exported') : 'Technician data exported', 'success');
  });

  document.querySelectorAll('.view-tech-link').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const id = btn.dataset.id;
      showToast(typeof window.t === 'function' ? window.t('toast_view_tech') : `Viewing ${id} profile — feature coming soon`, 'info');
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
    });
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

  // ── Disputes: resolve ─────────────────────
  document.querySelectorAll('[data-action="resolve"]').forEach(btn => {
    btn.addEventListener('click', () => {
      const card = btn.closest('.dispute-card');
      card.remove();
      // Update badge count
      const countEl = document.getElementById('disputeCount');
      if (countEl) {
        const curr = parseInt(countEl.textContent) - 1;
        countEl.textContent = curr;
      }
      showToast(typeof window.t === 'function' ? window.t('toast_dispute_resolved') : 'Dispute resolved', 'success');
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
  const defaultServices = [
    { id: 1, name: 'Standard Cleaning', category: 'Cleaning', price: 250, desc: 'Complete house cleaning service', status: 'Active' },
    { id: 2, name: 'Deep Cleaning', category: 'Cleaning', price: 500, desc: 'Thorough deep cleaning including windows', status: 'Active' },
    { id: 3, name: 'Leak Repair', category: 'Plumbing', price: 150, desc: 'Fixing water leaks and pipe issues', status: 'Active' },
    { id: 4, name: 'AC Maintenance', category: 'HVAC', price: 300, desc: 'Regular AC servicing and cleaning', status: 'Active' },
    { id: 5, name: 'Circuit Fix', category: 'Electrical', price: 200, desc: 'Repairing short circuits and wiring', status: 'Active' },
    { id: 6, name: 'Interior Painting', category: 'Painting', price: 1000, desc: 'Single room wall painting', status: 'Active' },
  ];

  let services = JSON.parse(localStorage.getItem('servio_services_data') || JSON.stringify(defaultServices));

  function saveServices() {
    localStorage.setItem('servio_services_data', JSON.stringify(services));
  }

  function renderServicesList() {
    const list = document.getElementById('servicesList');
    if (!list) return;

    list.innerHTML = '';
    services.forEach(svc => {
      const tr = document.createElement('tr');
      tr.className = 'booking-row'; // Use same row class for hover styles
      tr.dataset.category = svc.category;
      tr.dataset.status = svc.status;

      const nameKey = 'svc_' + svc.name.toLowerCase().replace(/ /g, '_');
      const catKey = 'skill_' + svc.category.toLowerCase();

      tr.innerHTML = `
        <td style="font-weight:600;" data-i18n="${nameKey}">${svc.name}</td>
        <td>
          <span class="bk-badge" style="background:rgba(154,140,115,0.1); color:var(--color-accent);" data-i18n="${catKey}">
            ${svc.category}
          </span>
        </td>
        <td class="bk-amount center-align" style="font-family: monospace;">
          ${svc.price} <span data-i18n="admin_currency">${typeof window.t === 'function' ? window.t('admin_currency') : 'EGP'}</span>
        </td>
        <td style="text-align:center;">
          <span class="bk-badge bk-badge--completed status-badge" data-i18n="status_active">Active</span>
        </td>
        <td>
          <div class="table-actions" style="justify-content:center;">
            <button class="bk-action-btn bk-action-btn--xs" data-id="${svc.id}" data-action="edit-service" title="Edit">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 113 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
            </button>
            <button class="bk-action-btn bk-action-btn--xs bk-action-btn--delete" data-id="${svc.id}" data-action="delete-service" title="Delete">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/></svg>
            </button>
          </div>
        </td>
      `;
      list.appendChild(tr);
    });


    // Re-attach listeners
    list.querySelectorAll('[data-action="edit-service"]').forEach(btn => {
      btn.addEventListener('click', () => editService(parseInt(btn.dataset.id)));
    });
    list.querySelectorAll('[data-action="delete-service"]').forEach(btn => {
      btn.addEventListener('click', () => deleteService(parseInt(btn.dataset.id)));
    });

    _updateServiceKPIs();
    _applyServiceFilters();
  }

  function _updateServiceKPIs() {
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
  }

  // Modal logic
  const serviceModal = document.getElementById('serviceModal');
  const serviceForm = document.getElementById('serviceForm');

  function openModal(svc = null) {
    const title = document.getElementById('serviceModalTitle');
    const saveBtnText = document.getElementById('saveServiceBtn');
    
    if (svc) {
      title.textContent = typeof window.t === 'function' ? window.t('admin_modal_edit_service_title') : 'Edit Service';
      title.setAttribute('data-i18n', 'admin_modal_edit_service_title');
      document.getElementById('serviceId').value = svc.id;
      document.getElementById('serviceName').value = svc.name;
      document.getElementById('serviceDesc').value = svc.desc;
      document.getElementById('serviceCategory').value = svc.category;
      document.getElementById('basePrice').value = svc.price;
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

  serviceForm?.addEventListener('submit', (e) => {
    e.preventDefault();
    const id = document.getElementById('serviceId').value;
    const name = document.getElementById('serviceName').value;
    const desc = document.getElementById('serviceDesc').value;
    const category = document.getElementById('serviceCategory').value;
    const price = parseInt(document.getElementById('basePrice').value);

    if (id) {
      // Edit
      const idx = services.findIndex(s => s.id === parseInt(id));
      if (idx !== -1) {
        services[idx] = { ...services[idx], name, desc, category, price };
      }
      showToast('Service updated', 'success');
    } else {
      // Add
      const newSvc = {
        id: Date.now(),
        name,
        desc,
        category,
        price,
        status: 'Active'
      };
      services.push(newSvc);
      showToast('New service added', 'success');
    }
    
    saveServices();
    closeModal();
    renderServicesList();
  });

  function editService(id) {
    const svc = services.find(s => s.id === id);
    if (svc) openModal(svc);
  }

  function deleteService(id) {
    if (confirm('Are you sure you want to delete this service?')) {
      services = services.filter(s => s.id !== id);
      saveServices();
      renderServicesList();
      showToast('Service deleted', 'error');
    }
  }

  // Init services
  renderServicesList();


  // ══════════════════════════════════════════════════════════
  //  SETTINGS — STAB TAB SWITCHING
  // ══════════════════════════════════════════════════════════
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

  // ══════════════════════════════════════════════════════════
  //  SETTINGS — TOGGLE SWITCH HANDLER
  // ══════════════════════════════════════════════════════════
  document.querySelectorAll('.stab-toggle').forEach(btn => {
    btn.addEventListener('click', () => {
      const on = btn.getAttribute('aria-checked') !== 'true';
      btn.setAttribute('aria-checked', on ? 'true' : 'false');
      btn.classList.toggle('stab-toggle--on', on);
    });
  });

  // ══════════════════════════════════════════════════════════
  //  SETTINGS — LOAD / SAVE (localStorage)
  // ══════════════════════════════════════════════════════════
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

  // Load all settings
  const saved = JSON.parse(localStorage.getItem('servio_admin_config') || 'null');
  if (saved) {
    // Platform
    if (saved.commissionRate    != null) document.getElementById('commissionRate').value    = saved.commissionRate;
    if (saved.maxCashLiability  != null) document.getElementById('maxCashLiability').value  = saved.maxCashLiability;
    if (saved.autoReleaseWindow != null) document.getElementById('autoReleaseWindow').value = saved.autoReleaseWindow;
    if (saved.minDepositPct     != null) document.getElementById('minDepositPct').value     = saved.minDepositPct;
    if (saved.minBookingAmount  != null) document.getElementById('minBookingAmount').value  = saved.minBookingAmount;
    if (saved.cashPaymentsEnabled != null) _setToggle('toggleCashPayments', saved.cashPaymentsEnabled);
    // Moderation
    if (saved.reqNationalId   != null) _setToggle('toggleReqNationalId', saved.reqNationalId);
    if (saved.reqTradeLicense != null) _setToggle('toggleReqTradeLicense', saved.reqTradeLicense);
    if (saved.autoSuspendDisputes != null) document.getElementById('autoSuspendDisputes').value = saved.autoSuspendDisputes;
    if (saved.minRatingFlag   != null) document.getElementById('minRatingFlag').value   = saved.minRatingFlag;
    if (saved.maxCashJobsDay  != null) document.getElementById('maxCashJobsDay').value  = saved.maxCashJobsDay;
    // Notifications
    if (saved.notifNewUser       != null) _setToggle('notifNewUser', saved.notifNewUser);
    if (saved.notifNewTech       != null) _setToggle('notifNewTech', saved.notifNewTech);
    if (saved.notifNewDispute    != null) _setToggle('notifNewDispute', saved.notifNewDispute);
    if (saved.notifOverduePayment!= null) _setToggle('notifOverduePayment', saved.notifOverduePayment);
    if (saved.notifDailySummary  != null) _setToggle('notifDailySummary', saved.notifDailySummary);
    if (saved.adminAlertEmail    != null && document.getElementById('adminAlertEmail'))
      document.getElementById('adminAlertEmail').value = saved.adminAlertEmail;
    // Security
    if (saved.twoFAEnabled    != null) _setToggle('toggle2FA', saved.twoFAEnabled);
    if (saved.sessionTimeout  != null) document.getElementById('sessionTimeout').value = saved.sessionTimeout;
    // System
    if (saved.maintenanceMode != null) _setToggle('toggleMaintenance', saved.maintenanceMode);
    if (saved.platformName    != null) document.getElementById('platformName').value    = saved.platformName;
    if (saved.supportEmail    != null) document.getElementById('supportEmail').value    = saved.supportEmail;
    if (saved.maxUploadSize   != null) document.getElementById('maxUploadSize').value   = saved.maxUploadSize;
    if (saved.flagAiMatch     != null) _setToggle('flagAiMatch',     saved.flagAiMatch);
    if (saved.flagCashPayments!= null) _setToggle('flagCashPayments',saved.flagCashPayments);
    if (saved.flagTechSignup  != null) _setToggle('flagTechSignup',  saved.flagTechSignup);
    if (saved.flagReviews     != null) _setToggle('flagReviews',     saved.flagReviews);
  }

  function _saveConfig(patch) {
    const current = JSON.parse(localStorage.getItem('servio_admin_config') || '{}');
    localStorage.setItem('servio_admin_config', JSON.stringify({ ...current, ...patch }));
  }

  // Platform form
  document.getElementById('adminSettingsForm')?.addEventListener('submit', e => {
    e.preventDefault();
    _saveConfig({
      commissionRate:       document.getElementById('commissionRate')?.value,
      maxCashLiability:     document.getElementById('maxCashLiability')?.value,
      autoReleaseWindow:    document.getElementById('autoReleaseWindow')?.value,
      minDepositPct:        document.getElementById('minDepositPct')?.value,
      minBookingAmount:     document.getElementById('minBookingAmount')?.value,
      cashPaymentsEnabled:  _getToggle('toggleCashPayments'),
    });
    showToast(_T('toast_admin_settings_saved'), 'success');
  });

  // Moderation form
  document.getElementById('adminModerationForm')?.addEventListener('submit', e => {
    e.preventDefault();
    _saveConfig({
      reqNationalId:        _getToggle('toggleReqNationalId'),
      reqTradeLicense:      _getToggle('toggleReqTradeLicense'),
      autoSuspendDisputes:  document.getElementById('autoSuspendDisputes')?.value,
      minRatingFlag:        document.getElementById('minRatingFlag')?.value,
      maxCashJobsDay:       document.getElementById('maxCashJobsDay')?.value,
    });
    showToast(_T('toast_admin_settings_saved'), 'success');
  });

  // Notifications form
  document.getElementById('adminNotifForm')?.addEventListener('submit', e => {
    e.preventDefault();
    _saveConfig({
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
  document.getElementById('adminSystemForm')?.addEventListener('submit', e => {
    e.preventDefault();
    _saveConfig({
      maintenanceMode:  _getToggle('toggleMaintenance'),
      platformName:     document.getElementById('platformName')?.value,
      supportEmail:     document.getElementById('supportEmail')?.value,
      maxUploadSize:    document.getElementById('maxUploadSize')?.value,
      flagAiMatch:      _getToggle('flagAiMatch'),
      flagCashPayments: _getToggle('flagCashPayments'),
      flagTechSignup:   _getToggle('flagTechSignup'),
      flagReviews:      _getToggle('flagReviews'),
    });
    const isMaint = _getToggle('toggleMaintenance');
    showToast(isMaint ? _T('toast_maintenance_on') : _T('toast_admin_settings_saved'), isMaint ? 'warn' : 'success');
  });

  // ══════════════════════════════════════════════════════════
  //  SETTINGS — PASSWORD STRENGTH METER
  // ══════════════════════════════════════════════════════════
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

  document.getElementById('adminPwdForm')?.addEventListener('submit', e => {
    e.preventDefault();
    const newPw  = document.getElementById('newPwd')?.value;
    const confPw = document.getElementById('confirmPwd')?.value;
    const errEl  = document.getElementById('adminPwdError');
    if (newPw !== confPw) {
      if (errEl) errEl.hidden = false;
      return;
    }
    if (errEl) errEl.hidden = true;
    showToast(_T('toast_password_changed') || 'Password updated', 'success');
    ['currentPwd','newPwd','confirmPwd'].forEach(id => {
      const el = document.getElementById(id); if (el) el.value = '';
    });
    if (pwStrengthFill)  pwStrengthFill.style.width = '0%';
    if (pwStrengthLabel) pwStrengthLabel.textContent = '';
  });

  document.getElementById('terminateOtherSessionsBtn')?.addEventListener('click', () => {
    showToast(_T('toast_sessions_terminated') || 'Other sessions terminated', 'success');
  });

  // ══════════════════════════════════════════════════════════
  //  SETTINGS — ROLE ASSIGNMENT
  // ══════════════════════════════════════════════════════════
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
  
  function applyAnalyticsChartChanges(srvVal) {
      // Update horizontal bar chart visibility (service demand)
      const chartItems = document.querySelectorAll('#analyticsServicesChart .analytics-hbar-item');
      chartItems.forEach(item => {
        const itemSvc = item.dataset.service || '';
        if (srvVal === '' || itemSvc === srvVal) {
          item.style.display = 'flex';
          // Simulate data shifting
          const randomPct = Math.floor(Math.random() * 60) + 30; // 30 to 90
          const fill = item.querySelector('.analytics-hbar-fill');
          const pct = item.querySelector('.analytics-hbar-pct');
          if (fill) fill.style.setProperty('--bar-width', randomPct + '%');
          if (pct) pct.textContent = randomPct + '%';
        } else {
          item.style.display = 'none';
        }
      });

      // Also randomize vertical bar chart to simulate data update
      const randomBars = document.querySelectorAll('.analytics-bar');
      randomBars.forEach(bar => {
         const newH = Math.floor(Math.random() * 70) + 30; 
         bar.style.setProperty('--bar-height', newH + '%');
         bar.textContent = Math.floor(newH / 1.5);
      });
  }

  if (btnApplyAnalyticFilters) {
    btnApplyAnalyticFilters.addEventListener('click', () => {
      const srvFilter = document.getElementById('analyticsServiceFilter');
      const srvVal = srvFilter ? srvFilter.value : '';
      
      applyAnalyticsChartChanges(srvVal);
      showToast(window.__lang === 'ar' ? 'تم تطبيق الفلاتر والتحليلات' : 'Analytics filters applied', 'success');
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
       showToast(window.__lang === 'ar' ? 'تم إعادة ضبط الفلاتر' : 'Filters reset successfully', 'info');
    });
  }

  // ── Overview date — set on init and on language switch ──
  _updateOverviewDate();
  document.addEventListener('langchange', () => {
    _updateOverviewDate();
    _updateUserCount();
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

  // ══════════════════════════════════════════════════════════
  //  AUDIT LOG
  // ══════════════════════════════════════════════════════════
  const AUDIT_ROWS_PER_PAGE = 15;
  let _auditPage = 1;
  let _auditFiltered = [];

  // Mock data
  const _auditData = [
    { ts: '2026-04-14 11:42:03', actor: 'admin@servio.eg', type: 'settings', action: 'Updated commission rate to 12%', target: 'Platform Settings', ip: '196.158.4.21', status: 'ok' },
    { ts: '2026-04-14 11:30:17', actor: 'admin@servio.eg', type: 'user',     action: 'Suspended user account',        target: 'U-1080 Ahmed Yasser',  ip: '196.158.4.21', status: 'ok' },
    { ts: '2026-04-14 10:58:44', actor: 'sara.m@servio.eg',type: 'booking',  action: 'Resolved dispute #D-4412',      target: 'Booking #BK-9920',     ip: '41.72.100.5',  status: 'ok' },
    { ts: '2026-04-14 10:45:11', actor: 'admin@servio.eg', type: 'auth',     action: 'Admin login',                   target: 'Admin Dashboard',      ip: '196.158.4.21', status: 'ok' },
    { ts: '2026-04-14 09:22:30', actor: 'unknown',         type: 'auth',     action: 'Failed login attempt',          target: 'Admin Dashboard',      ip: '185.220.101.3',status: 'fail' },
    { ts: '2026-04-14 09:18:55', actor: 'omar.t@servio.eg',type: 'finance',  action: 'Processed settlement EGP 4,200',target: 'T-0042 Fady Naguib',   ip: '102.33.9.8',   status: 'ok' },
    { ts: '2026-04-13 17:05:22', actor: 'admin@servio.eg', type: 'settings', action: 'Enabled Maintenance Mode',      target: 'System Settings',      ip: '196.158.4.21', status: 'warn' },
    { ts: '2026-04-13 16:48:09', actor: 'admin@servio.eg', type: 'settings', action: 'Disabled Maintenance Mode',     target: 'System Settings',      ip: '196.158.4.21', status: 'ok' },
    { ts: '2026-04-13 14:33:47', actor: 'nour.h@servio.eg',type: 'user',     action: 'Assigned role: Finance Manager',target: 'U-1083 Nour Hassan',   ip: '41.65.200.14', status: 'ok' },
    { ts: '2026-04-13 13:11:00', actor: 'admin@servio.eg', type: 'user',     action: 'Approved technician',           target: 'T-0061 Khaled Saber',  ip: '196.158.4.21', status: 'ok' },
    { ts: '2026-04-13 11:27:38', actor: 'sara.m@servio.eg',type: 'user',     action: 'Rejected technician application',target:'T-0062 Tarek Mahmoud', ip: '41.72.100.5',  status: 'ok' },
    { ts: '2026-04-12 16:55:12', actor: 'admin@servio.eg', type: 'system',   action: 'Exported Bookings Report (CSV)','target':'Reports',             ip: '196.158.4.21', status: 'ok' },
    { ts: '2026-04-12 15:00:00', actor: 'unknown',         type: 'auth',     action: 'Failed login attempt',          target: 'Admin Dashboard',      ip: '91.108.4.55',  status: 'fail' },
    { ts: '2026-04-12 09:14:29', actor: 'omar.t@servio.eg',type: 'booking',  action: 'Cancelled booking by admin',    target: 'Booking #BK-9911',     ip: '102.33.9.8',   status: 'ok' },
    { ts: '2026-04-11 18:30:01', actor: 'admin@servio.eg', type: 'settings', action: 'Updated cash debt ceiling',     target: 'Platform Settings',    ip: '196.158.4.21', status: 'ok' },
    { ts: '2026-04-11 14:22:17', actor: 'admin@servio.eg', type: 'user',     action: 'Reset user password',           target: 'U-1081 Sara Mohamed',  ip: '196.158.4.21', status: 'ok' },
    { ts: '2026-04-10 11:45:00', actor: 'nour.h@servio.eg',type: 'finance',  action: 'Processed settlement EGP 2,800',target: 'T-0038 Youssef Ali',   ip: '41.65.200.14', status: 'ok' },
    { ts: '2026-04-10 09:03:55', actor: 'admin@servio.eg', type: 'auth',     action: 'Admin login',                   target: 'Admin Dashboard',      ip: '196.158.4.21', status: 'ok' },
    { ts: '2026-04-09 17:12:44', actor: 'admin@servio.eg', type: 'system',   action: 'Changed platform support email','target':'System Settings',     ip: '196.158.4.21', status: 'ok' },
    { ts: '2026-04-09 10:58:11', actor: 'sara.m@servio.eg',type: 'user',     action: 'Suspended user (fraud flag)',   target: 'U-1085 Hana Mostafa',  ip: '41.72.100.5',  status: 'warn' },
  ];

  function _renderAuditTable() {
    const tbody    = document.getElementById('auditLogBody');
    const emptyEl  = document.getElementById('auditTableEmpty');
    const pageInfo = document.getElementById('auditPageInfo');
    const prevBtn  = document.getElementById('auditPrevBtn');
    const nextBtn  = document.getElementById('auditNextBtn');
    if (!tbody) return;

    const totalPages = Math.max(1, Math.ceil(_auditFiltered.length / AUDIT_ROWS_PER_PAGE));
    _auditPage = Math.max(1, Math.min(_auditPage, totalPages));

    const start = (_auditPage - 1) * AUDIT_ROWS_PER_PAGE;
    const slice = _auditFiltered.slice(start, start + AUDIT_ROWS_PER_PAGE);

    if (_auditFiltered.length === 0) {
      tbody.innerHTML = '';
      if (emptyEl) emptyEl.hidden = false;
    } else {
      if (emptyEl) emptyEl.hidden = true;
      tbody.innerHTML = slice.map(r => `
        <tr>
          <td class="audit-ts">${r.ts}</td>
          <td class="audit-actor">${r.actor}</td>
          <td class="audit-action">
            <span class="audit-type-pill">${r.type}</span><br>${r.action}
          </td>
          <td class="audit-target">${r.target}</td>
          <td class="audit-ip">${r.ip}</td>
          <td>
            <span class="audit-badge audit-badge--${r.status}">
              ${r.status === 'ok' ? '✓ OK' : r.status === 'warn' ? '⚠ Warn' : '✕ Fail'}
            </span>
          </td>
        </tr>`).join('');
    }

    if (pageInfo) pageInfo.textContent = `${_auditPage} / ${totalPages}`;
    if (prevBtn)  prevBtn.disabled = _auditPage <= 1;
    if (nextBtn)  nextBtn.disabled = _auditPage >= totalPages;

    // Update stat pills
    const today = new Date().toISOString().slice(0, 10);
    document.getElementById('auditTotalCount').textContent = _auditData.length;
    document.getElementById('auditTodayCount').textContent = _auditData.filter(r => r.ts.startsWith(today)).length;
    document.getElementById('auditFailedCount').textContent= _auditData.filter(r => r.status === 'fail').length;
  }

  function _applyAuditFilters() {
    const q    = (document.getElementById('auditSearchInput')?.value || '').toLowerCase();
    const type = document.getElementById('auditTypeFilter')?.value || '';
    const days = parseInt(document.getElementById('auditDateFilter')?.value) || 0;
    const cutoff = days ? new Date(Date.now() - days * 86400000).toISOString().slice(0, 10) : '';

    _auditFiltered = _auditData.filter(r => {
      if (type && r.type !== type) return false;
      if (cutoff && r.ts.slice(0, 10) < cutoff) return false;
      if (q && !r.actor.toLowerCase().includes(q) && !r.action.toLowerCase().includes(q) && !r.ip.includes(q)) return false;
      return true;
    });
    _auditPage = 1;
    _renderAuditTable();
  }

  // Init audit
  _auditFiltered = [..._auditData];
  _renderAuditTable();

  document.getElementById('auditSearchInput')?.addEventListener('input', _applyAuditFilters);
  document.getElementById('auditTypeFilter')?.addEventListener('change', _applyAuditFilters);
  document.getElementById('auditDateFilter')?.addEventListener('change', _applyAuditFilters);

  document.getElementById('auditPrevBtn')?.addEventListener('click', () => { _auditPage--; _renderAuditTable(); });
  document.getElementById('auditNextBtn')?.addEventListener('click', () => { _auditPage++; _renderAuditTable(); });

  document.getElementById('auditExportBtn')?.addEventListener('click', () => {
    const rows = [['Timestamp','Actor','Type','Action','Target','IP','Status']];
    _auditFiltered.forEach(r => rows.push([r.ts, r.actor, r.type, r.action, r.target, r.ip, r.status]));
    const csv = rows.map(r => r.map(v => `"${v}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href = url; a.download = 'audit-log.csv'; a.click();
    URL.revokeObjectURL(url);
    showToast(_T('toast_report_exported') || 'Audit log exported', 'success');
  });

  // Re-render audit table when switching to the audit panel (for stat refresh)
  navBtns.forEach(btn => {
    if (btn.dataset.tab === 'audit') {
      btn.addEventListener('click', () => { _auditPage = 1; _renderAuditTable(); });
    }
  });
}

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

// .
