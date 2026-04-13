/* ═══════════════════════════════════════════════
   Admin Dashboard — SERVIO
   ═══════════════════════════════════════════════ */

// Auth guard
const session = JSON.parse(localStorage.getItem('servio_session') || 'null');
if (!session) {
  const currentPath = window.location.pathname;
  const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
  const redirectParam = encodeURIComponent('./' + currentPage + window.location.search);
  window.location.href = './login.html?redirect=' + redirectParam;
}
if (session?.role !== 'admin') { window.location.href = './index.html'; }

function showToast(msg, type = 'success') {
  const t = document.createElement('div');
  t.className = `toast toast--${type}`;
  t.textContent = msg;
  document.body.appendChild(t);
  requestAnimationFrame(() => {
    requestAnimationFrame(() => t.classList.add('is-visible'));
  });
  setTimeout(() => {
    t.classList.remove('is-visible');
    setTimeout(() => t.remove(), 300);
  }, 2500);
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
      const matchStatus = status === '' || row.innerHTML.includes(status);

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


  // ── Settings: load ────────────────────────
  const saved = JSON.parse(localStorage.getItem('servio_admin_config') || 'null');
  if (saved) {
    if (saved.commissionRate)    document.getElementById('commissionRate').value    = saved.commissionRate;
    if (saved.maxCashLiability)  document.getElementById('maxCashLiability').value  = saved.maxCashLiability;
    if (saved.autoReleaseWindow) document.getElementById('autoReleaseWindow').value = saved.autoReleaseWindow;
    if (saved.minDepositPct)     document.getElementById('minDepositPct').value     = saved.minDepositPct;
  }

  // ── Settings: save ────────────────────────
  document.getElementById('adminSettingsForm')?.addEventListener('submit', e => {
    e.preventDefault();
    const config = {
      commissionRate:    document.getElementById('commissionRate')?.value,
      maxCashLiability:  document.getElementById('maxCashLiability')?.value,
      autoReleaseWindow: document.getElementById('autoReleaseWindow')?.value,
      minDepositPct:     document.getElementById('minDepositPct')?.value,
    };
    localStorage.setItem('servio_admin_config', JSON.stringify(config));
    showToast(typeof window.t === 'function' ? window.t('toast_admin_settings_saved') : 'Settings saved', 'success');
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
