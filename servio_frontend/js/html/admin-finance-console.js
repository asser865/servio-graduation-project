import {
  adminApprovePayment,
  adminApprovePayout,
  adminRejectSettlement,
  adminListCashDebtsGrouped,
  adminListPayments,
  adminListPayouts,
  adminListSettlements,
  adminPaymentsStats,
  adminRefund,
  adminRejectPayout,
  adminSendDebtReminder,
  adminVerifySettlement,
  adminWorkerDebts,
  bulkReleaseFinance,
  getCashDebts,
  getDisputes,
  getPendingApprovals,
  resolveDispute,
} from '../api/payments.js';
import { updateUserStatus } from '../api/users.js';
import { getRefusalsAwaitingResponse } from '../api/bookings.js';
import { getAdminRevenue } from '../api/admin.js';
import { openFinanceDrawer } from '../components/finance-drawer.js';
import { showToast } from '../components/toast.js';
import { confirmDialog, promptDialog } from '../components/confirm-dialog.js';
import { createPoller } from '../utils/live-poll.js';
import { classify } from '../utils/queue-priority.js';
import { REASONS } from '../utils/queue-priority.constants.js';
import { escapeHtml } from '../utils/string.js';

const POLL_INTERVAL_MS = 30_000;
const PANEL_SELECTOR = '.admin-panel[data-panel="finance"]';
const ACTIVE_DISPUTE_STATUSES = new Set(['open', 'reviewing', 'awaiting_evidence', 'appealed', 'escalated']);
// Payouts below this amount with no risk flag are auto-approved by backend — only exceptions surface here
const PAYOUT_EXCEPTION_THRESHOLD = 500;
const BUCKETS = [
  ['requires_action', 'Requires Action'],
  ['waiting_customer', 'Waiting on Customer'],
  ['waiting_technician', 'Waiting on Technician'],
  ['waiting_system', 'Waiting on System'],
];

const state = {
  data: emptyData(),
  filters: { method: 'all', type: 'all', priority: 'all', reason: 'all', search: '', dateFrom: '', dateTo: '' },
  sort: { key: 'priority', dir: 'asc' },
  initialized: false,
  eventsBound: false,
  poller: null,
  refreshPromise: null,
  selected: new Set(),
  expandedBuckets: new Set(['requires_action']),
  activeTab: 'queue',
  loading: false,
  lastError: null,
  expandedWorkers: new Set(),
  individualDebts: {},
  paidDebts: [],
  revenuePeriod: 30,
  revenuePeriods: [
    { days: 30, label: 'Revenue (30d)' },
    { days: 180, label: 'Revenue (6m)' },
    { days: 365, label: 'Revenue (Max)' },
    { days: 7, label: 'Revenue (7d)' }
  ],
  revenuePeriodIndex: (() => { try { return Number(localStorage.getItem('adminFinanceRevenuePeriodIndex')) || 0; } catch { return 0; } })(),
  revenueCache: {},
  revenueLoading: false,
};

function emptyData() {
  return { stats: {}, approvals: [], cashDebts: [], payouts: [], disputes: [], refusals: [], payments: [], settlements: [], paidDebts: [] };
}

function list(value) {
  return Array.isArray(value) ? value : [];
}

function number(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function shortId(value) {
  return String(value || '').slice(-6) || '------';
}

function money(value) {
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'EGP',
    maximumFractionDigits: 2,
  }).format(number(value));
}

function dateTime(value) {
  if (!value) return '-';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '-' : date.toLocaleString();
}

function title(value) {
  return String(value || '')
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, char => char.toUpperCase());
}

const SETTLEMENT_METHOD_LABELS = {
  auto_offset: 'Future earnings',
  wallet_balance: 'Wallet balance',
  instapay: 'InstaPay',
  vodafone_cash: 'Vodafone Cash',
  bank_transfer: 'Bank transfer',
  cash_to_office: 'Cash to office',
  card: 'Card payment',
  admin_override: 'Admin override',
};

const DEBT_TYPE_LABELS = {
  platform_fee: 'Platform fee',
  refund_recovery: 'Refund recovery',
  penalty: 'Penalty',
};

function settlementMethodLabel(value, fallback = 'Awaiting payment') {
  return SETTLEMENT_METHOD_LABELS[value] || (value ? title(value) : fallback);
}

function debtTypeLabel(value) {
  return DEBT_TYPE_LABELS[value] || title(value || 'platform fee');
}

function debtPaidByLabel(value) {
  if (value === 'auto_wallet') return 'Automatic';
  if (value === 'manual_admin') return 'Admin verified';
  return 'Recorded payment';
}

function workerInitials(value) {
  return String(value || 'Worker')
    .split(/\s+/)
    .filter(Boolean)
    .map(part => part[0])
    .join('')
    .toUpperCase()
    .slice(0, 2) || 'W';
}

function daysOpen(value) {
  const createdAt = new Date(value || 0).getTime();
  if (!Number.isFinite(createdAt) || !value) return '-';
  const days = Math.max(0, Math.floor((Date.now() - createdAt) / 86_400_000));
  return days === 0 ? 'Today' : `${days}d open`;
}

function debtRecoveryPercent(item = {}) {
  const recovered = number(item.amountRecovered);
  const original = number(item.originalTotal) || recovered + number(item.totalOwed);
  return original > 0 ? Math.min(100, Math.max(0, Math.round((recovered / original) * 100))) : 0;
}

function collectionState(item = {}) {
  if (number(item.pendingSettlementCount) > 0) {
    return { label: 'Proof waiting for review', tone: 'review', note: `${item.pendingSettlementCount} proof(s) totaling ${money(item.pendingSettlementAmount)}` };
  }
  const ageDays = Math.max(0, Math.floor((Date.now() - new Date(item.oldest || 0).getTime()) / 86_400_000));
  if (Number.isFinite(ageDays) && ageDays >= 7) {
    return { label: 'Follow-up needed', tone: 'attention', note: 'Debt has been open for 7+ days' };
  }
  return { label: 'Waiting for payment', tone: 'open', note: 'Technician can pay from Earnings' };
}

function normalizeDebtWorkspace(value = {}) {
  if (Array.isArray(value)) return { debts: value, settlements: [], failed: false };
  return {
    debts: list(value?.debts ?? value?.items),
    settlements: list(value?.settlements),
    failed: Boolean(value?.failed),
  };
}

function searchText(...values) {
  return values.flat().filter(Boolean).join(' ').toLowerCase();
}

function classifyItem(item) {
  const dueAt = item.slaDueAt ? new Date(item.slaDueAt).getTime() : NaN;
  return {
    ...item,
    ...classify({
      type: item.type,
      slaBreached: Number.isFinite(dueAt) && dueAt < Date.now(),
      techStrikes: item.techStrikes,
      customerStrikes: item.customerStrikes,
      fraudFlag: item.fraudFlag,
      amount: item.amount,
      threshold: item.threshold,
      techRisk: item.techRisk,
      customerRisk: item.customerRisk,
      escalated: item.escalated,
      refusalPending: item.refusalVerification === 'pending',
    }),
  };
}

function mapApprovalItem(item = {}) {
  const method = item.paymentMethod === 'cash' ? 'cash' : 'online';
  return classifyItem({
    id: item.paymentId || item.bookingId || '',
    paymentId: item.paymentId || '',
    sourceId: item.bookingId || '',
    when: item.customerConfirmedAt || item.createdAt || '',
    type: 'card_release',
    typeLabel: method === 'cash' ? 'Cash payout' : 'Card payout',
    customer: item.customer?.name || '-',
    worker: item.worker?.name || '-',
    method,
    amount: number(item.totalPaid) || number(item.amount),
    basis: item.customerConfirmedAt ? 'Customer confirmed' : 'Manual review',
    slaDueAt: item.releaseEligibleAt || '',
    techRisk: item.techRisk,
    customerRisk: item.customerRisk,
    searchText: searchText(item.bookingId, item.paymentId, item.customer?.name, item.worker?.name, item.service),
    raw: item,
  });
}

export function mapPayoutItem(item = {}) {
  return classifyItem({
    id: item._id || item.id || '',
    sourceId: item._id || item.id || '',
    when: item.createdAt || item.requestedAt || '',
    type: 'payout_verify',
    typeLabel: 'Verify payout',
    customer: '-',
    worker: item.worker?.name || '-',
    method: 'online',
    amount: item.amount,
    basis: `Payout ${item.status || 'pending'}`,
    techRisk: item.techRisk,
    searchText: searchText(item._id, item.worker?.name, item.worker?.email, item.status, item.method),
    raw: item,
  });
}

export function mapDisputeItem(item = {}) {
  const booking = item.booking && typeof item.booking === 'object' ? item.booking : {};
  const payment = item.payment && typeof item.payment === 'object' ? item.payment : {};
  return classifyItem({
    id: item._id || item.id || '',
    sourceId: item._id || item.id || '',
    when: item.createdAt || '',
    type: 'dispute',
    typeLabel: 'Dispute',
    customer: item.raisedBy?.name || booking.user?.name || '-',
    worker: booking.worker?.name || '-',
    method: booking.paymentMethod === 'cash' ? 'cash' : 'online',
    amount: booking.totalPrice ?? payment.amount,
    basis: item.category || item.reason || 'New dispute',
    slaDueAt: item.slaResolveDueAt || '',
    escalated: item.status === 'escalated',
    evidenceRequestedFromTech: item.status === 'awaiting_evidence',
    techRisk: item.techRisk,
    customerRisk: item.customerRisk,
    searchText: searchText(item._id, item.category, item.reason, item.raisedBy?.name, booking.user?.name, booking.worker?.name),
    raw: item,
  });
}

export function mapRefusalItem(item = {}) {
  const verification = item.refusalVerification || {};
  const outcome = item.completionOutcome || {};
  return classifyItem({
    id: item._id || item.id || '',
    sourceId: item._id || item.id || '',
    when: outcome.submittedAt || item.updatedAt || '',
    type: 'refusal_verify',
    typeLabel: 'Cancellation check',
    customer: item.user?.name || '-',
    worker: item.worker?.name || '-',
    method: 'cash',
    amount: item.totalPrice,
    basis: outcome.refusalReason || 'Payment refusal',
    refusalVerification: verification.status || 'pending',
    awaitingCustomer: verification.status === 'pending',
    techRisk: item.techRisk,
    customerRisk: item.customerRisk,
    searchText: searchText(item._id, item.user?.name, item.worker?.name, outcome.refusalReason),
    raw: item,
  });
}

function activeDisputeList() {
  return state.data.disputes.filter(item => ACTIVE_DISPUTE_STATUSES.has(item.status));
}

function updateSortHeaders(root) {
  root.querySelectorAll('th[data-finance-sort]').forEach(th => {
    const isActive = th.dataset.financeSort === state.sort.key;
    th.setAttribute('aria-sort', !isActive ? 'none' : state.sort.dir === 'asc' ? 'ascending' : 'descending');
    th.classList.toggle('is-sorted', isActive);
    th.classList.toggle('is-sorted-desc', isActive && state.sort.dir === 'desc');
  });
}

function updateFreshness(root) {
  const el = root.querySelector('#financeUpdatedAt');
  if (!el || !state.lastUpdated) return;
  const seconds = Math.max(1, Math.round((Date.now() - state.lastUpdated) / 1000));
  el.textContent = seconds < 60 ? `· updated ${seconds}s ago` : `· updated ${Math.round(seconds / 60)}m ago`;
}

const TIER_RANK = { critical: 0, high: 1, medium: 2, low: 3 };

const SORTERS = {
  priority: item => TIER_RANK[item.tier] ?? 99,
  when:     item => new Date(item.when || 0).getTime(),
  amount:   item => number(item.amount),
  sla:      item => item.slaDueAt ? new Date(item.slaDueAt).getTime() : Number.POSITIVE_INFINITY,
};

function isPayoutException(raw = {}) {
  return number(raw.amount) >= PAYOUT_EXCEPTION_THRESHOLD
    || raw.fraudFlag
    || ['high', 'critical'].includes(String(raw.techRisk || '').toLowerCase());
}

function queueItems() {
  const items = [
    ...state.data.approvals.map(mapApprovalItem),
    ...state.data.payouts.filter(isPayoutException).map(mapPayoutItem),
    ...state.data.refusals.map(mapRefusalItem),
  ].filter(item => item.id && item.type);
  const sortKey = state.sort?.key || 'priority';
  const dir = state.sort?.dir === 'desc' ? -1 : 1;
  const getter = SORTERS[sortKey] || SORTERS.priority;
  return items.sort((left, right) => {
    const diff = (getter(left) - getter(right)) * dir;
    if (diff) return diff;
    return (TIER_RANK[left.tier] ?? 99) - (TIER_RANK[right.tier] ?? 99);
  });
}

function resolveBucket(item) {
  if (item.awaitingCustomer || item.refusalVerification === 'pending') return 'waiting_customer';
  if (item.evidenceRequestedFromTech) return 'waiting_technician';
  if (number(item.autoConfirmIn) > 0) return 'waiting_system';
  return 'requires_action';
}

function grouped(items) {
  return Object.fromEntries(BUCKETS.map(([key]) => [key, items.filter(item => resolveBucket(item) === key)]));
}

function matchesFilters(item) {
  const { method, type, priority, reason, search, dateFrom, dateTo } = state.filters;
  if (method !== 'all' && item.method !== method) return false;
  if (type !== 'all' && item.type !== type) return false;
  if (priority !== 'all' && item.tier !== priority) return false;
  if (reason !== 'all' && item.reason !== reason) return false;
  if (search && !item.searchText.includes(search)) return false;
  const when = item.when ? new Date(item.when).getTime() : NaN;
  if (dateFrom && (!Number.isFinite(when) || when < new Date(`${dateFrom}T00:00:00`).getTime())) return false;
  if (dateTo && (!Number.isFinite(when) || when > new Date(`${dateTo}T23:59:59.999`).getTime())) return false;
  return true;
}

const REASON_LABELS = {
  DISPUTE_FILED: 'New dispute',
  SLA_BREACH: 'Overdue',
  HIGH_VALUE: 'High value',
  FRAUD_INDICATOR: 'Possible fraud',
  PAYMENT_REFUSAL: 'Payment refused',
  AUTO_RELEASE_BLOCK: 'Release blocked',
  MANUAL_ESCALATION: 'Needs review',
  REPEAT_OFFENDER: 'Repeat offender',
};

const REASON_EXPLANATIONS = {
  DISPUTE_FILED: 'Customer opened a dispute on this booking',
  SLA_BREACH: 'Past the resolution deadline',
  HIGH_VALUE: 'Amount above auto-release limit',
  FRAUD_INDICATOR: 'System detected fraud risk signals',
  PAYMENT_REFUSAL: 'Customer refused to pay after service',
  AUTO_RELEASE_BLOCK: 'System blocked automatic release',
  MANUAL_ESCALATION: 'Flagged for human review',
  REPEAT_OFFENDER: 'Party has prior strikes on record',
};

function reasonLabel(reason) {
  return REASON_LABELS[reason] || title(String(reason || '').replace(/_/g, ' ').toLowerCase());
}

function reasonExplanation(reason) {
  return REASON_EXPLANATIONS[reason] || 'Flagged by finance rules';
}

function sla(value) {
  const okBadge = '<span class="finance-console__sla-timer finance-console__sla-timer--ok">On time</span>';
  if (!value) return okBadge;
  const dueAt = new Date(value).getTime();
  if (!Number.isFinite(dueAt)) return okBadge;
  const remaining = dueAt - Date.now();
  const overdue = remaining < 0;
  const absMs = Math.abs(remaining);
  const days = Math.floor(absMs / 86_400_000);
  const hours = Math.max(1, Math.ceil(absMs / 3_600_000));
  const label = days >= 1
    ? (overdue ? `${days}d late` : `${days}d left`)
    : (overdue ? `${hours}h late` : `${hours}h left`);
  const tone = overdue ? 'breach' : remaining <= 21_600_000 ? 'warn' : 'ok';
  return `<span class="finance-console__sla-timer finance-console__sla-timer--${tone}">${escapeHtml(label)}</span>`;
}

function riskTone(value) {
  const normalized = String(value ?? '').toLowerCase();
  if (value === true || ['critical', 'high'].includes(normalized)) return 'high';
  if (['medium', 'moderate'].includes(normalized)) return 'medium';
  if (['low', 'clean'].includes(normalized)) return 'low';
  return 'unknown';
}

function riskSignals(item) {
  const signals = [
    ['T', 'Technician risk', riskTone(item.techRisk)],
    ['C', 'Customer risk', riskTone(item.customerRisk)],
  ];
  return `<span class="finance-console__risk-signals" aria-label="Party risk signals">${
    signals.map(([letter, label, tone]) => `
      <span class="finance-console__risk-signal finance-console__risk-signal--${tone}" title="${escapeHtml(`${label}: ${title(tone)}`)}">
        <i></i>${letter}
      </span>`).join('')
  }</span>`;
}

function miniTimeline(item) {
  const raw = item.raw || {};
  const booking = raw.booking && typeof raw.booking === 'object' ? raw.booking : raw;
  const outcome = booking.completionOutcome || {};
  const feedback = booking.customerFeedback || {};
  const nodes = [
    ['Created', true],
    ['Evidence', list(outcome.afterPhotos).length > 0 || list(raw.evidence).length > 0],
    ['Confirmed', Boolean(booking.customerConfirmedAt || feedback.action === 'confirmed')],
    ['Review', resolveBucket(item) === 'requires_action'],
  ];
  return `<span class="finance-console__timeline" aria-label="Finance item progress">${
    nodes.map(([label, complete], index) => `
      <i class="${complete ? 'is-complete' : ''}" title="${escapeHtml(label)}"></i>${index < nodes.length - 1 ? '<b></b>' : ''}`
    ).join('')
  }</span>`;
}

function actionLabel(item) {
  if (item.type === 'card_release') return { label: 'Release', cls: 'finance-row-btn--ok' };
  if (item.type === 'payout_verify') return { label: 'Approve Payout', cls: '' };
  if (item.type === 'refusal_verify') return { label: 'Review', cls: '' };
  return { label: 'Review', cls: '' };
}

function row(item, hidden) {
  const selectable = item.type === 'card_release' && item.tier === 'low';
  const checked = state.selected.has(item.sourceId);
  const { label: btnLabel, cls: btnCls } = actionLabel(item);
  return `
    <tr class="finance-console__item-row finance-console__item-row--${escapeHtml(item.tier)}" data-bucket-item="${escapeHtml(resolveBucket(item))}" data-finance-row-open="${escapeHtml(item.id)}" tabindex="0" ${hidden ? 'hidden' : ''}>
      <td class="finance-console__col-check">${selectable ? `<input type="checkbox" data-finance-select="${escapeHtml(item.sourceId)}" ${checked ? 'checked' : ''} aria-label="Select #${escapeHtml(shortId(item.sourceId))}" />` : ''}</td>
      <td class="finance-console__col-flag">
        <span class="finance-console__reason finance-console__reason--${escapeHtml(item.tier)}" title="${escapeHtml(reasonExplanation(item.reason))}">${escapeHtml(reasonLabel(item.reason))}</span>
        ${riskSignals(item)}
      </td>
      <td class="finance-console__cell-when">${escapeHtml(dateTime(item.when))}</td>
      <td class="finance-console__col-case">
        <span class="finance-console__reference">
          <span class="finance-console__type">${escapeHtml(item.typeLabel)}</span>
          <strong>#${escapeHtml(shortId(item.sourceId))}</strong>
        </span>
        <span class="finance-console__basis">${escapeHtml(item.basis)}</span>
      </td>
      <td><span class="finance-console__party">
        <span class="finance-console__party-row"><span class="finance-console__party-label">Customer</span><strong>${escapeHtml(item.customer || '—')}</strong></span>
        <span class="finance-console__party-row"><span class="finance-console__party-label">Worker</span><small>${escapeHtml(item.worker || '—')}</small></span>
      </span></td>
      <td><span class="fp-method fp-method--${escapeHtml(item.method)}">${escapeHtml(item.method === 'cash' ? 'CASH' : 'CARD')}</span></td>
      <td class="finance-console__col-num">${escapeHtml(money(item.amount))}</td>
      <td>${sla(item.slaDueAt)}</td>
      <td><span class="finance-console__row-actions">
        ${selectable ? `<button type="button" class="finance-row-btn finance-row-btn--ok" data-finance-quick-release="${escapeHtml(item.sourceId)}">Release</button>` : ''}
        <button type="button" class="finance-row-btn ${selectable ? '' : btnCls}" data-finance-open="${escapeHtml(item.id)}">${escapeHtml(selectable ? 'Review' : btnLabel)}</button>
      </span></td>
    </tr>`;
}

function renderQueue(root) {
  const host = root.querySelector('#financeQueueRows');
  if (!host) return;
  renderReasonOptions(root);
  const items = queueItems().filter(matchesFilters);
  const itemsBySource = new Set(items.map(item => item.sourceId));
  [...state.selected].forEach(id => { if (!itemsBySource.has(id)) state.selected.delete(id); });
  const count = root.querySelector('#financeQueueCount');
  if (count) count.textContent = String(items.length);
  const buckets = grouped(items);
  host.innerHTML = items.length
    ? BUCKETS.filter(([key]) => buckets[key].length > 0).map(([key, label]) => {
        const expanded = state.expandedBuckets.has(key);
        return `
          <tr class="finance-console__bucket-row">
            <td colspan="9">
              <button type="button" data-finance-bucket-toggle="${key}" aria-expanded="${expanded}">
                <span>${escapeHtml(label)}</span><strong>${buckets[key].length}</strong>
              </button>
            </td>
          </tr>
          ${buckets[key].map(item => row(item, !expanded)).join('')}`;
      }).join('')
    : '<tr><td colspan="9" class="finance-console__empty"><strong>Queue clear</strong><span>No finance items match the current filters.</span></td></tr>';
  renderBulkBar(root, items);
  updateFilterSummary(root);
}

function renderBulkBar(root, items = queueItems()) {
  let bar = root.querySelector('#financeBulkBar');
  if (!bar) {
    bar = document.createElement('div');
    bar.id = 'financeBulkBar';
    bar.className = 'finance-console__bulk-bar';
    root.querySelector('.finance-console__queue-table-wrap')?.before(bar);
  }
  const selected = items.filter(item => state.selected.has(item.sourceId));
  if (!selected.length) {
    bar.hidden = true;
    bar.innerHTML = '';
    return;
  }
  const total = selected.reduce((sum, item) => sum + number(item.amount), 0);
  bar.hidden = false;
  bar.innerHTML = `
    <strong>${selected.length} selected - ${escapeHtml(money(total))}</strong>
    <span>Low-risk card releases only</span>
    <button type="button" class="finance-row-btn" data-finance-bulk-export>Export CSV</button>
    <button type="button" class="finance-row-btn" data-finance-bulk-dismiss>Clear</button>
    <button type="button" class="finance-row-btn" disabled title="Cash-debt selection is not available in this queue">Settle All</button>
    <button type="button" class="finance-row-btn finance-row-btn--ok" data-finance-bulk-release>Approve All</button>`;
}

function renderReasonOptions(root) {
  const host = root.querySelector('#financeReasonChips');
  if (!host) return;
  const reasons = Object.values(REASONS).sort();
  const current = reasons.includes(state.filters.reason) ? state.filters.reason : 'all';
  state.filters.reason = current;
  host.innerHTML = [
    `<button class="finance-console__chip${current === 'all' ? ' is-active' : ''}" data-reason="all">All reasons</button>`,
    ...reasons.map(reason => `<button class="finance-console__chip finance-console__chip--reason-${reasonTone(reason)}${current === reason ? ' is-active' : ''}" data-reason="${escapeHtml(reason)}">${escapeHtml(title(reason))}</button>`),
  ].join('');
}

function reasonTone(reason) {
  if ([REASONS.SLA_BREACH, REASONS.FRAUD_INDICATOR, REASONS.REPEAT_OFFENDER].includes(reason)) return 'critical';
  if ([REASONS.DISPUTE_FILED, REASONS.MANUAL_ESCALATION, REASONS.HIGH_VALUE].includes(reason)) return 'high';
  if ([REASONS.PAYMENT_REFUSAL, REASONS.AUTO_RELEASE_BLOCK].includes(reason)) return 'medium';
  return 'low';
}

function updateFilterSummary(root) {
  const active = Object.entries(state.filters)
    .filter(([key, value]) => key === 'search' ? Boolean(value) : Boolean(value && value !== 'all'))
    .length;
  const host = root.querySelector('#financeActiveFilterCount');
  if (host) host.textContent = String(active);
}

function kpiCard({ id, label, value, sub, tone = 'neutral', type = '', section = '', priority = '', ops = false }) {
  const stateLabel = { alert: 'Action needed', warn: 'Monitor', positive: 'Healthy' }[tone];
  return `
    <button type="button" ${id ? `id="${escapeHtml(id)}"` : ''} class="finance-console__kpi finance-console__kpi--${escapeHtml(tone)}${ops ? ' finance-console__kpi--ops' : ''}"
      data-finance-kpi data-kpi-type="${escapeHtml(type)}" data-kpi-section="${escapeHtml(section)}" data-kpi-priority="${escapeHtml(priority)}"
      aria-label="${escapeHtml(`${label}: ${value}. ${sub}`)}">
      <span class="finance-console__kpi-label">${escapeHtml(label)}
        ${type === 'revenue' ? '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="margin-left: 4px; vertical-align: middle;"><polyline points="6 9 12 15 18 9"></polyline></svg>' : ''}
      </span>
      <strong class="finance-console__kpi-value">${escapeHtml(value)}</strong>
      <span class="finance-console__kpi-sub">${escapeHtml(sub)}</span>
      ${stateLabel ? `<span class="finance-console__kpi-state finance-console__kpi-state--${escapeHtml(tone)}">${escapeHtml(stateLabel)}</span>` : ''}
    </button>`;
}

function renderKpis(root) {
  const host = root.querySelector('#financeKpiStrip');
  if (!host) return;
  const { stats, cashDebts } = state.data;
  const debt = cashDebts.reduce((sum, item) => sum + number(item.totalOwed), 0);
  const revPeriodObj = state.revenuePeriods[state.revenuePeriodIndex];
  
  // Base initial value on stats if cache is empty for 30d
  let revValue = '--';
  let revTone = 'neutral';
  
  if (state.revenueLoading) {
    revValue = '...';
  } else if (state.revenueCache[revPeriodObj.days] !== undefined) {
    const val = state.revenueCache[revPeriodObj.days];
    revValue = money(val);
    revTone = val ? 'positive' : 'neutral';
  } else if (revPeriodObj.days === 30) {
    const rawRev = stats.revenue30d ?? stats.platformRevenue30d;
    if (rawRev !== undefined) {
      const val = number(rawRev);
      revValue = money(val);
      revTone = val > 0 ? 'positive' : 'neutral';
    } else {
      revValue = '--';
    }
  }

  const cards = [
    {
      id: 'financeKpiRevenue',
      type: 'revenue',
      label: revPeriodObj.label,
      value: revValue,
      sub: 'Platform commission earned',
      tone: revTone,
    },
    {
      label: 'Owed to Workers',
      value: money(state.data.payouts.reduce((sum, p) => sum + number(p.amount), 0)),
      sub: state.data.payouts.length ? `${state.data.payouts.length} pending payout(s)` : 'No pending payouts',
      tone: state.data.payouts.length ? 'warn' : 'neutral',
      type: 'payout_verify',
    },
    {
      label: 'On Hold',
      value: money(stats.heldTotal),
      sub: 'Frozen — awaiting release',
      tone: number(stats.heldTotal) ? 'warn' : 'neutral',
      type: 'card_release',
    },
    {
      label: 'Funds at Risk',
      value: money(stats.disputeExposureTotal),
      sub: 'Tied up in active disputes',
      tone: number(stats.disputeExposureTotal) ? 'alert' : 'neutral',
    },
    {
      label: 'Worker Debt',
      value: money(debt),
      sub: 'Cash owed by workers',
      tone: debt ? 'warn' : 'neutral',
      section: 'cash-debts',
    },
  ];
  host.innerHTML = cards.map(kpiCard).join('');
  root.querySelector('#financeOpsShell')?.remove();
}

function renderDisputes(root) {
  const host = root.querySelector('#financeDisputesList');
  const count = root.querySelector('#disputesSectionCount');
  const disputes = activeDisputeList();
  if (count) count.textContent = String(disputes.length);
  if (!host) return;
  host.innerHTML = disputes.length
    ? disputes.map(mapDisputeItem).map(item => `
      <article class="finance-console__summary-row finance-console__summary-row--${escapeHtml(item.tier)}">
        <div class="finance-console__summary-main">
          <span class="finance-console__summary-chips">
            <strong>#${escapeHtml(shortId(item.id))}</strong>
            <span>Dispute</span>
            <span class="finance-console__reason finance-console__reason--${escapeHtml(item.tier)}">${escapeHtml(reasonLabel(item.reason))}</span>
          </span>
          <span>${escapeHtml(item.customer)} · ${escapeHtml(item.basis)}</span>
        </div>
        <strong class="finance-console__summary-amount">${escapeHtml(money(item.amount))}</strong>
        ${sla(item.slaDueAt)}
        <button type="button" class="finance-row-btn${item.reason === REASONS.SLA_BREACH ? ' finance-row-btn--danger' : ''}" data-finance-open="${escapeHtml(item.id)}">${item.reason === REASONS.SLA_BREACH ? 'Escalate' : 'Review'}</button>
      </article>`).join('')
    : '<p class="finance-console__placeholder">No open disputes.</p>';
  setSectionState(root, 'disputes', disputes.length);
}

function debtWorkerRows() {
  return state.data.cashDebts.map(item => {
    const workerId = String(item.worker?._id || item.worker?.id || item.workerId || '');
    const workerName = item.worker?.name || 'Unknown worker';
    const expanded = workerId && state.expandedWorkers.has(workerId);
    const workspace = workerId ? (state.individualDebts[workerId] ?? null) : null;
    const collection = collectionState(item);
    const recoveryPercent = debtRecoveryPercent(item);
    const summaryMethods = list(item.pendingSettlementMethods);
    let expandedContent = '';
    if (expanded) {
      if (workspace === null) {
        expandedContent = '<div class="finance-console__debt-item finance-console__debt-item--loading">Loading debt details...</div>';
      } else if (workspace.failed) {
        expandedContent = '<div class="finance-console__debt-item finance-console__debt-item--loading">Could not load debt details. Close and reopen this worker to retry.</div>';
      } else {
        const settlementsHtml = workspace.settlements.length
          ? workspace.settlements.map(settlement => `
              <article class="finance-console__proof-card">
                <div class="finance-console__proof-main">
                  <span class="finance-console__proof-label">Payment proof</span>
                  <strong>${escapeHtml(settlementMethodLabel(settlement.method))}</strong>
                  <small>Ref ${escapeHtml(settlement.reference || '-')} &middot; submitted ${escapeHtml(dateTime(settlement.submittedAt || settlement.createdAt))}</small>
                </div>
                <strong class="finance-console__proof-amount">${escapeHtml(money(settlement.totalAmount))}</strong>
                <span class="finance-console__debt-status-badge finance-console__debt-status-badge--pending_verification">Pending review</span>
                <div class="finance-console__proof-actions">
                  <button type="button" class="finance-row-btn finance-row-btn--ok" data-debt-settlement-verify="${escapeHtml(settlement._id || settlement.id || '')}" data-debt-worker="${escapeHtml(workerId)}">Verify</button>
                  <button type="button" class="finance-row-btn finance-row-btn--danger" data-debt-settlement-reject="${escapeHtml(settlement._id || settlement.id || '')}" data-debt-worker="${escapeHtml(workerId)}">Reject</button>
                </div>
              </article>`).join('')
          : '<p class="finance-console__debt-empty-note">No payment proof is waiting for admin review.</p>';
        const debtsHtml = workspace.debts.length
          ? workspace.debts.map(debt => {
              const remaining = debt.remaining ?? (number(debt.amount) - number(debt.paidAmount));
              const method = debt.settlementMethod
                ? settlementMethodLabel(debt.settlementMethod)
                : debt.status === 'paid' ? 'Method not recorded' : 'Waiting for technician to pay';
              return `
                <div class="finance-console__debt-item">
                  <span title="Booking ID">Booking #${escapeHtml(shortId(debt.bookingId || debt.booking || debt._id))}</span>
                  <span>${escapeHtml(debtTypeLabel(debt.debtType))}</span>
                  <span>${escapeHtml(daysOpen(debt.createdAt))}</span>
                  <strong>${escapeHtml(money(remaining))}<small> of ${escapeHtml(money(debt.amount))}</small></strong>
                  <span>${escapeHtml(method)}</span>
                  <span class="finance-console__debt-status-badge finance-console__debt-status-badge--${escapeHtml(debt.status || 'outstanding')}">${escapeHtml(title(debt.status || 'outstanding'))}</span>
                </div>`;
            }).join('')
          : '<p class="finance-console__debt-empty-note">No individual debt records found.</p>';
        expandedContent = `
          <section class="finance-console__proof-section">
            <header><strong>Submitted payments</strong><span>Review worker proof before clearing debt.</span></header>
            ${settlementsHtml}
          </section>
          <section class="finance-console__debt-breakdown">
            <header><strong>Debt breakdown</strong><span>See what is owed, why, and how it was paid.</span></header>
            <div class="finance-console__debt-item finance-console__debt-item--head" aria-hidden="true">
              <span>Booking</span><span>Reason</span><span>Age</span><span>Remaining</span><span>Payment method</span><span>Status</span>
            </div>
            ${debtsHtml}
          </section>`;
      }
    }
    return `
      <article class="finance-console__debt-card">
        <header class="finance-console__debt-card-head">
          <div class="finance-console__debt-worker">
            <span class="finance-console__debt-avatar" aria-hidden="true">${escapeHtml(workerInitials(workerName))}</span>
            <span>
              <strong>${escapeHtml(workerName)}</strong>
              <small>${escapeHtml(item.worker?.email || 'No email on file')}</small>
            </span>
          </div>
          <span class="finance-console__collection-badge finance-console__collection-badge--${escapeHtml(collection.tone)}">${escapeHtml(collection.label)}</span>
        </header>
        <div class="finance-console__debt-stats">
          <div>
            <span>Outstanding</span>
            <strong class="finance-console__debt-total">${escapeHtml(money(item.totalOwed))}</strong>
          </div>
          <div>
            <span>Unpaid jobs</span>
            <strong>${escapeHtml(String(item.debtCount || 0))}</strong>
          </div>
          <div>
            <span>Oldest debt</span>
            <strong>${escapeHtml(daysOpen(item.oldest))}</strong>
          </div>
          <div>
            <span>Payment method</span>
            <strong>${escapeHtml(summaryMethods.length ? summaryMethods.map(settlementMethodLabel).join(', ') : 'Future earnings or Earnings page')}</strong>
          </div>
        </div>
        <div class="finance-console__debt-card-foot">
          <div class="finance-console__debt-progress">
            <span><strong>${escapeHtml(String(recoveryPercent))}% recovered</strong><small>${escapeHtml(collection.note)}</small></span>
            <progress max="100" value="${escapeHtml(String(recoveryPercent))}" aria-label="${escapeHtml(String(recoveryPercent))}% debt recovered"></progress>
          </div>
          <div class="finance-console__debt-actions">
            ${workerId ? `<button type="button" class="finance-row-btn" data-debt-remind="${escapeHtml(workerId)}">Send reminder</button>` : ''}
            ${workerId ? `<button type="button" class="finance-row-btn finance-row-btn--danger" data-debt-suspend="${escapeHtml(workerId)}">Suspend</button>` : ''}
            ${workerId ? `<button type="button" class="finance-row-btn finance-row-btn--accent" data-debt-expand="${escapeHtml(workerId)}" aria-expanded="${expanded}">${expanded ? 'Hide details' : 'Review debt'}</button>` : ''}
          </div>
        </div>
      </article>
      ${expanded ? `<div class="finance-console__debt-workspace">${expandedContent}</div>` : ''}`;
  }).join('');
}

function renderCashDebts(root) {
  const host = root.querySelector('#financeCashDebtsList');
  const count = root.querySelector('#cashDebtsSectionCount');
  if (count) count.textContent = String(state.data.cashDebts.length);
  if (!host) return;
  const activeHtml = state.data.cashDebts.length
    ? debtWorkerRows()
    : '<p class="finance-console__placeholder">No outstanding cash debts.</p>';
  const paidHtml = state.data.paidDebts.length
    ? state.data.paidDebts.map(debt => `
        <div class="finance-console__paid-debt-row">
          <div><span>Booking</span><strong>#${escapeHtml(shortId(debt.bookingId || debt._id))}</strong></div>
          <div><span>Technician</span><strong>${escapeHtml(debt.worker?.name || '-')}</strong></div>
          <div><span>Paid on</span><strong>${escapeHtml(dateTime(debt.paidAt || debt.updatedAt))}</strong></div>
          <div><span>Amount</span><strong>${escapeHtml(money(debt.paidAmount ?? debt.amount))}</strong></div>
          <div><span>Paid through</span><strong>${escapeHtml(settlementMethodLabel(debt.settlementMethod, 'Method not recorded'))}</strong></div>
          <div><span>Recorded by</span><strong>${escapeHtml(debtPaidByLabel(debt.paidBy))}</strong></div>
          <span class="finance-console__debt-paid-badge">Paid</span>
        </div>`).join('')
    : '<p class="finance-console__placeholder">No paid debt history yet.</p>';
  host.innerHTML = `
    <aside class="finance-console__debt-guide">
      <strong>Ways to pay</strong>
      <span>Future earnings</span>
      <span>Wallet balance</span>
      <span>InstaPay, Vodafone Cash, bank transfer, or office cash</span>
    </aside>
    <div class="finance-console__debt-list">${activeHtml}</div>
    <details class="finance-console__debt-history">
      <summary>Paid Debt History <span>(${state.data.paidDebts.length})</span></summary>
      <div class="finance-console__debt-history-rows">${paidHtml}</div>
    </details>`;
  setSectionState(root, 'cash-debts', state.data.cashDebts.length);
}

function renderInvestigations(root) {
  const host = root.querySelector('#financeInvestigationsList');
  const count = root.querySelector('#investigationsSectionCount');
  const investigations = state.data.refusals.map(mapRefusalItem);
  if (count) count.textContent = String(investigations.length);
  if (!host) return;
  host.innerHTML = investigations.length
    ? investigations.map(item => `
      <button type="button" class="finance-console__section-item" data-finance-open="${escapeHtml(item.id)}">
        <strong>#${escapeHtml(shortId(item.id))}</strong>
        <span>${escapeHtml(item.worker)} - ${escapeHtml(item.basis)}</span>
      </button>`).join('')
    : '<p class="finance-console__placeholder">No open investigations.</p>';
  setSectionState(root, 'investigations', investigations.length);
}

const ACTIVITY_STATUS_TONE = {
  released: 'positive',
  refunded: 'warn',
  held: 'info',
  disputed: 'alert',
  'partial refund': 'warn',
  verified: 'positive',
  rejected: 'alert',
  settled: 'positive',
};

function activityTone(label) {
  return ACTIVITY_STATUS_TONE[label.toLowerCase()] || 'neutral';
}

function buildDisputeIndex() {
  const index = new Map();
  for (const d of state.data.disputes) {
    const bookingId = (d.booking && typeof d.booking === 'object' ? d.booking._id : d.booking) || d.bookingId;
    if (bookingId) index.set(String(bookingId), d);
  }
  return index;
}

function paymentActivity(item = {}, disputeIndex = new Map()) {
  const booking = item.booking && typeof item.booking === 'object' ? item.booking : {};
  const bookingId = String(booking._id || booking.id || item.bookingId || '');
  const linkedDispute = bookingId ? disputeIndex.get(bookingId) : null;
  const label = title(item.status || 'update');
  return {
    id: item._id || item.id || '',
    label,
    tone: activityTone(label),
    type: 'Payment',
    when: item.releasedAt || item.refundedAt || item.updatedAt || item.createdAt,
    amount: item.refundedAmount || item.amount,
    method: booking.paymentMethod || item.paymentMethod || 'online',
    customer: booking.user?.name || item.customer?.name || '',
    worker: booking.worker?.name || item.worker?.name || '',
    note: item.refundReason || item.note || '',
    disputeId: linkedDispute ? (linkedDispute._id || linkedDispute.id) : null,
    disputeStatus: linkedDispute?.status || null,
  };
}

function settlementActivity(item = {}) {
  const label = title(item.status || 'settlement');
  return {
    id: item._id || item.id || '',
    label,
    tone: activityTone(label),
    type: 'Settlement',
    when: item.updatedAt || item.createdAt,
    amount: item.totalAmount || item.amount,
    method: item.method || 'cash',
    customer: '',
    worker: item.worker?.name || '',
    note: item.rejectionReason || '',
  };
}

function renderActivity(root) {
  const host = root.querySelector('#financeActivityFeed');
  if (!host) return;
  const disputeIndex = buildDisputeIndex();
  const activity = [
    ...state.data.payments.map(item => paymentActivity(item, disputeIndex)),
    ...state.data.settlements.map(settlementActivity),
  ]
    .filter(item => item.id)
    .sort((left, right) => new Date(right.when || 0) - new Date(left.when || 0))
    .slice(0, 20);
  host.innerHTML = activity.length
    ? activity.map(item => {
        const sourceTag = item.disputeId
          ? `<span class="finance-console__activity-source">from Dispute #${escapeHtml(shortId(item.disputeId))} · ${escapeHtml(title(item.disputeStatus || ''))}</span>`
          : '';
        return `
      <article class="finance-console__activity-row">
        <span class="finance-console__activity-status finance-console__activity-status--${escapeHtml(item.tone)}">${escapeHtml(item.label)}</span>
        <div class="finance-console__activity-body">
          <strong>#${escapeHtml(shortId(item.id))} <small>${escapeHtml(item.type)}</small></strong>
          <span>${[item.customer, item.worker].filter(Boolean).join(' → ') || 'No parties'}</span>
          ${sourceTag}
          ${item.note ? `<em>${escapeHtml(item.note)}</em>` : ''}
        </div>
        <div class="finance-console__activity-right">
          <strong>${escapeHtml(money(item.amount))}</strong>
          <span>${escapeHtml(dateTime(item.when))}</span>
          <span class="fp-method fp-method--${escapeHtml(item.method === 'cash' ? 'cash' : 'online')}">${escapeHtml(item.method === 'cash' ? 'CASH' : 'CARD')}</span>
        </div>
      </article>`;
      }).join('')
    : '<p class="finance-console__placeholder">No recent finance activity.</p>';
  setSectionState(root, 'recent-activity', activity.length);
}

function setSectionState(root, sectionName, itemCount) {
  const section = root.querySelector(`[data-finance-panel="${sectionName}"]`);
  if (!section) return;
  section.classList.toggle('is-empty', itemCount === 0);
}

function applyActiveTab(root) {
  root.querySelectorAll('[data-finance-tab]').forEach(tab => {
    const active = tab.dataset.financeTab === state.activeTab;
    tab.classList.toggle('is-active', active);
    tab.setAttribute('aria-selected', String(active));
  });
  root.querySelectorAll('[data-finance-panel]').forEach(panel => {
    panel.hidden = panel.dataset.financePanel !== state.activeTab;
  });
}

function updateTabBadges(root) {
  const queueCount = queueItems().filter(matchesFilters).length;
  const setBadge = (key, value) => {
    const el = root.querySelector(`#financeTabBadge-${key}`);
    if (el) el.textContent = String(value);
  };
  setBadge('queue', queueCount);
  setBadge('cash-debts', state.data.cashDebts.length);
  setBadge('investigations', state.data.refusals.length);
}

function loadingRowsHtml(count = 5) {
  const row = `
    <tr class="finance-console__skeleton-row" aria-hidden="true">
      <td colspan="9"><span class="finance-console__skeleton-bar"></span></td>
    </tr>`;
  return row.repeat(count);
}

function renderLoadingState(root) {
  const host = root.querySelector('#financeQueueRows');
  if (host) host.innerHTML = loadingRowsHtml();
  ['financeCashDebtsList', 'financeInvestigationsList', 'financeActivityFeed'].forEach(id => {
    const el = root.querySelector(`#${id}`);
    if (el) el.innerHTML = '<p class="finance-console__placeholder">Loading...</p>';
  });
}

function renderErrorState(root, message) {
  const host = root.querySelector('#financeQueueRows');
  if (host) {
    host.innerHTML = `
      <tr><td colspan="9" class="finance-console__empty finance-console__empty--error">
        <strong>Could not load finance data</strong>
        <span>${escapeHtml(message || 'Unexpected error')}</span>
        <button type="button" class="finance-row-btn" data-finance-retry>Try again</button>
      </td></tr>`;
  }
}

function render(root) {
  renderKpis(root);
  renderQueue(root);
  renderCashDebts(root);
  renderInvestigations(root);
  renderActivity(root);
  updateTabBadges(root);
  applyActiveTab(root);
}

function exportSelectedRows() {
  const selected = queueItems().filter(item => state.selected.has(item.sourceId));
  if (!selected.length) return;
  const values = [
    ['booking', 'type', 'worker', 'customer', 'method', 'amount', 'reason'],
    ...selected.map(item => [item.sourceId, item.typeLabel, item.worker, item.customer, item.method, item.amount, item.reason]),
  ];
  const csv = values.map(columns => columns.map(value => JSON.stringify(String(value ?? ''))).join(',')).join('\n');
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = 'finance-selection.csv';
  link.click();
  URL.revokeObjectURL(url);
}

async function fetchData() {
  const sources = await Promise.allSettled([
    adminPaymentsStats(),
    getPendingApprovals(),
    adminListCashDebtsGrouped(),
    adminListPayouts({ status: 'pending' }),
    getDisputes({ page: 1, limit: 100 }),
    getRefusalsAwaitingResponse(),
    adminListPayments({ limit: 12 }),
    adminListSettlements({ limit: 12 }),
    getCashDebts({ status: 'paid', limit: 20 }),
    state.revenuePeriods[state.revenuePeriodIndex].days !== 30 ? getAdminRevenue(state.revenuePeriods[state.revenuePeriodIndex].days) : Promise.resolve(null),
  ]);
  const names = ['stats', 'approvals', 'cash debts', 'payouts', 'disputes'];
  const failures = sources.slice(0, names.length).flatMap((result, index) => result.status === 'rejected' ? [names[index]] : []);
  const [stats, approvals, cashDebts, payouts, disputes, refusals, payments, settlements, paidDebts, activeRev] = sources;

  if (activeRev?.status === 'fulfilled' && activeRev.value) {
    state.revenueCache[state.revenuePeriods[state.revenuePeriodIndex].days] = Number(activeRev.value.currentTotal) || 0;
  }

  return {
    failures,
    data: {
      stats: stats.status === 'fulfilled' ? stats.value || {} : {},
      approvals: approvals.status === 'fulfilled' ? list(approvals.value?.items) : [],
      cashDebts: cashDebts.status === 'fulfilled' ? list(cashDebts.value) : [],
      payouts: payouts.status === 'fulfilled' ? list(payouts.value) : [],
      disputes: disputes.status === 'fulfilled' ? list(disputes.value?.disputes) : [],
      refusals: refusals.status === 'fulfilled' ? list(refusals.value?.items ?? refusals.value) : [],
      payments: payments.status === 'fulfilled' ? list(payments.value?.items ?? payments.value) : [],
      settlements: settlements.status === 'fulfilled' ? list(settlements.value?.items ?? settlements.value) : [],
      paidDebts: paidDebts.status === 'fulfilled' ? list(paidDebts.value?.items ?? paidDebts.value) : [],
    },
  };
}

export async function refreshFinanceConsole({ notifyOnError = false, showLoading = false } = {}) {
  const root = document.querySelector(PANEL_SELECTOR);
  if (!root) return false;
  if (state.refreshPromise) return state.refreshPromise;
  if (showLoading) {
    state.loading = true;
    renderLoadingState(root);
  }
  state.refreshPromise = fetchData()
    .then(result => {
      state.loading = false;
      state.lastError = null;
      state.data = result.data;
      state.lastUpdated = Date.now();
      render(root);
      updateFreshness(root);
      if (result.failures.length && notifyOnError) showToast(`Finance console loaded with limited data: ${result.failures.join(', ')}.`, 'error');
      return result.failures.length === 0;
    })
    .catch(error => {
      state.loading = false;
      state.lastError = error?.message || 'Failed to load finance console.';
      state.data = emptyData();
      render(root);
      renderErrorState(root, state.lastError);
      showToast(state.lastError, 'error');
      return false;
    })
    .finally(() => { state.refreshPromise = null; });
  return state.refreshPromise;
}

export function openUniversalDrawer(item) {
  openFinanceDrawer(item.type, item.id, { ...item.raw, ...item, paymentId: item.paymentId });
}

export function focusFinanceSection(sectionName) {
  const root = document.querySelector(PANEL_SELECTOR);
  if (!root) return;
  const tab = root.querySelector(`[data-finance-tab="${sectionName}"]`);
  state.activeTab = tab ? sectionName : 'queue';
  applyActiveTab(root);
  const section = root.querySelector(`[data-finance-panel="${state.activeTab}"]`);
  section?.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function itemForId(id) {
  return queueItems().find(item => String(item.id) === String(id));
}

async function handleDrawerAction(event) {
  const { action, id, item = {} } = event.detail || {};
  const bookingId = item.sourceId || item.bookingId;
  try {
    if (action === 'release') {
      const ok = await confirmDialog({
        title: 'Release funds to technician?',
        body: 'Confirm that you have reviewed the evidence. The held payment will be released to the technician.',
        confirmLabel: 'Release funds',
      });
      if (!ok) return;
      await adminApprovePayment(bookingId, { reasonCode: 'customer_confirmed' });
    } else if (action === 'refund' || action === 'approve_refund') {
      const reason = await promptDialog({
        title: 'Refund customer',
        label: 'Refund reason',
        placeholder: 'Explain why this payment is being refunded…',
        confirmLabel: 'Issue refund',
        tone: 'danger',
      });
      if (!reason) return;
      await adminRefund(item.paymentId || id, { reason });
    } else if (action === 'approve_payout') {
      await adminApprovePayout(id);
    } else if (action === 'reject_payout') {
      const reason = await promptDialog({
        title: 'Reject payout',
        label: 'Rejection reason',
        placeholder: 'Explain why this payout is being rejected…',
        confirmLabel: 'Reject payout',
        tone: 'danger',
      });
      if (!reason) return;
      await adminRejectPayout(id, { reason });
    } else if (['tech_at_fault', 'customer_at_fault', 'order_revisit', 'split_50_50'].includes(action)) {
      const resolution = await promptDialog({
        title: 'Resolve dispute',
        label: 'Resolution note for both parties',
        placeholder: 'Describe the resolution shared with the customer and technician…',
        confirmLabel: 'Submit resolution',
      });
      if (!resolution) return;
      const decisions = {
        tech_at_fault: { decision: 'refund', refundAmount: number(item.amount) },
        customer_at_fault: { decision: 'release' },
        order_revisit: { decision: 'redo' },
        split_50_50: { decision: 'partial_refund', refundAmount: Math.round(number(item.amount) / 2) },
      };
      await resolveDispute(id, { resolution, ...decisions[action] });
    } else if (action === 'confirm_refusal' || action === 'dispute_refusal') {
      showToast('Refusal responses are recorded by the customer. This drawer is review-only.', 'info');
      return;
    } else {
      showToast('This finance action is not available yet.', 'info');
      return;
    }
    showToast('Finance action completed.', 'success');
    await refreshFinanceConsole({ notifyOnError: true });
  } catch (error) {
    showToast(error?.data?.message || error?.message || 'Finance action failed.', 'error');
  }
}

function loadWorkerDebtDetails(root, workerId) {
  state.individualDebts[workerId] = null;
  renderCashDebts(root);
  return adminWorkerDebts(workerId)
    .then(workspace => {
      state.individualDebts[workerId] = normalizeDebtWorkspace(workspace);
      renderCashDebts(root);
    })
    .catch(() => {
      state.individualDebts[workerId] = normalizeDebtWorkspace({ failed: true });
      renderCashDebts(root);
    });
}

function bindEvents(root) {
  if (state.eventsBound) return;
  root.querySelector('#financeMethodChips')?.addEventListener('click', event => {
    const chip = event.target.closest('[data-method]');
    if (!chip) return;
    state.filters.method = chip.dataset.method || 'all';
    chip.parentElement.querySelectorAll('.finance-console__chip').forEach(item => item.classList.toggle('is-active', item === chip));
    renderQueue(root);
  });
  root.querySelector('#financeTypeChips')?.addEventListener('click', event => {
    const chip = event.target.closest('[data-type]');
    if (!chip) return;
    state.filters.type = chip.dataset.type || 'all';
    chip.parentElement.querySelectorAll('.finance-console__chip').forEach(item => item.classList.toggle('is-active', item === chip));
    renderQueue(root);
  });
  root.querySelector('#financePriorityChips')?.addEventListener('click', event => {
    const chip = event.target.closest('[data-priority]');
    if (!chip) return;
    state.filters.priority = chip.dataset.priority || 'all';
    chip.parentElement.querySelectorAll('.finance-console__chip').forEach(item => item.classList.toggle('is-active', item === chip));
    renderQueue(root);
  });
  root.querySelector('#financeReasonChips')?.addEventListener('click', event => {
    const chip = event.target.closest('[data-reason]');
    if (!chip) return;
    state.filters.reason = chip.dataset.reason || 'all';
    renderQueue(root);
  });
  root.querySelector('#financeAdvancedFiltersToggle')?.addEventListener('click', event => {
    const target = root.querySelector('#financeAdvancedFilters');
    if (!target) return;
    target.hidden = !target.hidden;
    event.currentTarget.setAttribute('aria-expanded', String(!target.hidden));
  });
  root.querySelector('#financeSearch')?.addEventListener('input', event => {
    state.filters.search = event.target.value.trim().toLowerCase();
    renderQueue(root);
  });
  root.querySelector('#financeDateFrom')?.addEventListener('change', event => {
    state.filters.dateFrom = event.target.value;
    renderQueue(root);
  });
  root.querySelector('#financeDateTo')?.addEventListener('change', event => {
    state.filters.dateTo = event.target.value;
    renderQueue(root);
  });
  root.addEventListener('click', async event => {
    const kpi = event.target.closest('[data-finance-kpi]');
    if (kpi) {
      if (kpi.dataset.kpiType === 'revenue') {
        if (state.revenueLoading) return;
        state.revenuePeriodIndex = (state.revenuePeriodIndex + 1) % state.revenuePeriods.length;
        try { localStorage.setItem('adminFinanceRevenuePeriodIndex', String(state.revenuePeriodIndex)); } catch (e) {}
        const period = state.revenuePeriods[state.revenuePeriodIndex];
        
        state.revenueLoading = true;
        renderKpis(root); // Show loading state
        
        try {
          if (period.days !== 30) {
            const data = await getAdminRevenue(period.days);
            state.revenueCache[period.days] = Number(data?.currentTotal) || 0;
          }
        } catch (err) {
          console.error('Error fetching revenue kpi', err);
          state.revenueCache[period.days] = 0; // Fallback
        } finally {
          state.revenueLoading = false;
          renderKpis(root); // Re-render with new data
        }
        return; // Prevent normal filtering logic
      }

      state.filters.type = kpi.dataset.kpiType || 'all';
      state.filters.priority = kpi.dataset.kpiPriority || 'all';
      root.querySelectorAll('#financeTypeChips [data-type]').forEach(item => item.classList.toggle('is-active', item.dataset.type === state.filters.type));
      root.querySelectorAll('#financePriorityChips [data-priority]').forEach(item => item.classList.toggle('is-active', item.dataset.priority === state.filters.priority));
      const sectionName = kpi.dataset.kpiSection;
      const targetTab = sectionName && root.querySelector(`[data-finance-tab="${sectionName}"]`) ? sectionName : 'queue';
      state.activeTab = targetTab;
      applyActiveTab(root);
      renderQueue(root);
      const target = root.querySelector(`[data-finance-panel="${state.activeTab}"]`);
      target?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      return;
    }
    const toggle = event.target.closest('[data-finance-bucket-toggle]');
    if (toggle) {
      const key = toggle.dataset.financeBucketToggle;
      state.expandedBuckets.has(key) ? state.expandedBuckets.delete(key) : state.expandedBuckets.add(key);
      renderQueue(root);
      return;
    }
    if (event.target.closest('[data-finance-bulk-export]')) {
      exportSelectedRows();
      return;
    }
    if (event.target.closest('[data-finance-bulk-dismiss]')) {
      state.selected.clear();
      renderQueue(root);
      return;
    }
    const quickRelease = event.target.closest('[data-finance-quick-release]');
    if (quickRelease) {
      const bookingId = quickRelease.dataset.financeQuickRelease;
      const ok = await confirmDialog({
        title: 'Approve card release?',
        body: `Release the low-risk card payment for booking #${shortId(bookingId)}.`,
        confirmLabel: 'Approve release',
      });
      if (!ok) return;
      try {
        await adminApprovePayment(bookingId, { reasonCode: 'customer_confirmed' });
        showToast('Payment released.', 'success');
        await refreshFinanceConsole({ notifyOnError: true });
      } catch (error) {
        showToast(error?.data?.message || error?.message || 'Payment release failed.', 'error');
      }
      return;
    }
    const review = event.target.closest('[data-finance-open]');
    if (review) {
      const item = itemForId(review.dataset.financeOpen) || state.data.disputes.map(mapDisputeItem).find(row => row.id === review.dataset.financeOpen);
      if (!item) return;
      if (review.dataset.financeAction === 'escalate') {
        const ok = await confirmDialog({
          title: `Escalate dispute #${shortId(item.sourceId)}?`,
          body: 'This flags the dispute for the senior team and notifies both parties.',
          confirmLabel: 'Escalate to senior review',
        });
        if (!ok) return;
        showToast(`Escalated #${shortId(item.sourceId)} - opening review drawer.`, 'info');
      }
      openUniversalDrawer(item);
      return;
    }
    if (!event.target.closest('input, button, a, label, [data-finance-bucket-toggle]')) {
      const rowEl = event.target.closest('[data-finance-row-open]');
      if (rowEl) {
        const item = itemForId(rowEl.dataset.financeRowOpen);
        if (item) openUniversalDrawer(item);
        return;
      }
    }
    if (event.target.closest('[data-finance-bulk-release]')) {
      const ids = [...state.selected];
      const selected = queueItems().filter(item => state.selected.has(item.sourceId));
      const summary = selected.map(item => `#${shortId(item.sourceId)} - ${item.worker} - ${money(item.amount)}`).join('\n');
      if (!ids.length) return;
      const ok = await confirmDialog({
        title: `Release ${ids.length} card payment${ids.length === 1 ? '' : 's'}?`,
        body: `These low-risk card payments will be released to technicians:\n${summary}`,
        confirmLabel: `Release ${ids.length} payment${ids.length === 1 ? '' : 's'}`,
      });
      if (!ok) return;
      try {
        await bulkReleaseFinance(ids);
        state.selected.clear();
        showToast('Selected payments released.', 'success');
        await refreshFinanceConsole({ notifyOnError: true });
      } catch (error) {
        showToast(error?.data?.message || error?.message || 'Bulk release failed.', 'error');
      }
    }
  });
  root.addEventListener('change', event => {
    const checkbox = event.target.closest('[data-finance-select]');
    if (!checkbox) return;
    checkbox.checked ? state.selected.add(checkbox.dataset.financeSelect) : state.selected.delete(checkbox.dataset.financeSelect);
    renderBulkBar(root);
  });
  root.addEventListener('click', async event => {
    const tab = event.target.closest('[data-finance-tab]');
    if (tab) {
      state.activeTab = tab.dataset.financeTab;
      applyActiveTab(root);
      return;
    }
    if (event.target.closest('[data-finance-retry]')) {
      refreshFinanceConsole({ notifyOnError: true, showLoading: true }).catch(() => {});
      return;
    }
    const expandBtn = event.target.closest('[data-debt-expand]');
    if (expandBtn) {
      const workerId = expandBtn.dataset.debtExpand;
      if (state.expandedWorkers.has(workerId)) {
        state.expandedWorkers.delete(workerId);
        renderCashDebts(root);
      } else {
        state.expandedWorkers.add(workerId);
        loadWorkerDebtDetails(root, workerId);
      }
      return;
    }
    const verifySettlementBtn = event.target.closest('[data-debt-settlement-verify]');
    if (verifySettlementBtn) {
      const settlementId = verifySettlementBtn.dataset.debtSettlementVerify;
      const workerId = verifySettlementBtn.dataset.debtWorker;
      if (!settlementId) return;
      const ok = await confirmDialog({
        title: 'Verify payment proof?',
        body: 'This confirms the payment proof and applies it to the technician\'s outstanding debt.',
        confirmLabel: 'Verify proof',
      });
      if (!ok) return;
      verifySettlementBtn.disabled = true;
      adminVerifySettlement(settlementId)
        .then(async () => {
          showToast('Payment proof verified and debt balance updated.', 'success');
          await refreshFinanceConsole({ notifyOnError: true });
          if (workerId && state.expandedWorkers.has(workerId)) loadWorkerDebtDetails(root, workerId);
        })
        .catch(err => showToast(err?.data?.message || 'Could not verify payment proof.', 'error'))
        .finally(() => { verifySettlementBtn.disabled = false; });
      return;
    }
    const rejectSettlementBtn = event.target.closest('[data-debt-settlement-reject]');
    if (rejectSettlementBtn) {
      const settlementId = rejectSettlementBtn.dataset.debtSettlementReject;
      const workerId = rejectSettlementBtn.dataset.debtWorker;
      if (!settlementId) return;
      const reason = await promptDialog({
        title: 'Reject payment proof',
        label: 'Rejection reason',
        placeholder: 'Explain why this proof is being rejected…',
        body: 'The technician will be able to resubmit a corrected proof.',
        confirmLabel: 'Reject proof',
        tone: 'danger',
      });
      if (!reason) return;
      rejectSettlementBtn.disabled = true;
      adminRejectSettlement(settlementId, { reason })
        .then(async () => {
          showToast('Payment proof rejected. The technician can resubmit it.', 'success');
          await refreshFinanceConsole({ notifyOnError: true });
          if (workerId && state.expandedWorkers.has(workerId)) loadWorkerDebtDetails(root, workerId);
        })
        .catch(err => showToast(err?.data?.message || 'Could not reject payment proof.', 'error'))
        .finally(() => { rejectSettlementBtn.disabled = false; });
      return;
    }
    const remindBtn = event.target.closest('[data-debt-remind]');
    if (remindBtn) {
      const workerId = remindBtn.dataset.debtRemind;
      remindBtn.disabled = true;
      adminSendDebtReminder(workerId)
        .then(() => showToast('Reminder sent to technician\'s dashboard.', 'success'))
        .catch(err => showToast(err?.data?.message || 'Could not send reminder.', 'error'))
        .finally(() => { remindBtn.disabled = false; });
      return;
    }
    const suspendBtn = event.target.closest('[data-debt-suspend]');
    if (suspendBtn) {
      const workerId = suspendBtn.dataset.debtSuspend;
      const workerName = suspendBtn.closest('article')?.querySelector('.finance-console__debt-worker strong')?.textContent || 'this worker';
      const ok = await confirmDialog({
        title: `Suspend ${workerName}?`,
        body: 'They will be blocked from accepting new jobs until their debt is cleared and you reactivate them.',
        confirmLabel: 'Suspend technician',
        tone: 'danger',
      });
      if (!ok) return;
      updateUserStatus(workerId, false)
        .then(() => {
          showToast(`${workerName} suspended.`, 'success');
        })
        .catch(err => showToast(err?.data?.message || 'Suspension failed.', 'error'));
      return;
    }
  });
  root.addEventListener('click', event => {
    const sortTh = event.target.closest('th[data-finance-sort]');
    if (!sortTh) return;
    const key = sortTh.dataset.financeSort;
    if (state.sort.key === key) {
      state.sort.dir = state.sort.dir === 'asc' ? 'desc' : 'asc';
    } else {
      state.sort.key = key;
      state.sort.dir = 'asc';
    }
    renderQueue(root);
    updateSortHeaders(root);
  });
  updateSortHeaders(root);
  root.addEventListener('keydown', event => {
    const tab = event.target.closest('[data-finance-tab]');
    if (tab && ['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) {
      const tabs = [...root.querySelectorAll('[data-finance-tab]')];
      const index = tabs.indexOf(tab);
      const next = event.key === 'ArrowLeft' ? tabs[(index - 1 + tabs.length) % tabs.length]
        : event.key === 'ArrowRight' ? tabs[(index + 1) % tabs.length]
        : event.key === 'Home' ? tabs[0]
        : tabs[tabs.length - 1];
      event.preventDefault();
      next.focus();
      state.activeTab = next.dataset.financeTab;
      applyActiveTab(root);
      return;
    }
    if (event.key !== 'Enter' && event.key !== ' ') return;
    if (event.target.closest('input, button, a, label, textarea, select')) return;
    const rowEl = event.target.closest('[data-finance-row-open]');
    if (!rowEl) return;
    event.preventDefault();
    const item = itemForId(rowEl.dataset.financeRowOpen);
    if (item) openUniversalDrawer(item);
  });
  document.addEventListener('finance-drawer:action', handleDrawerAction);
  state.eventsBound = true;
}

export function initFinanceConsole() {
  const root = document.querySelector(PANEL_SELECTOR);
  if (!root) return;
  bindEvents(root);
  if (!state.poller) {
    state.poller = createPoller({
      name: 'admin-finance-console',
      intervalMs: POLL_INTERVAL_MS,
      tick: () => refreshFinanceConsole(),
    });
    state.poller.start();
  }
  if (!state.freshnessTimer) {
    state.freshnessTimer = setInterval(() => updateFreshness(root), 15_000);
  }
  if (state.initialized) return;
  state.initialized = true;
  refreshFinanceConsole({ notifyOnError: true, showLoading: true }).catch(() => {});
}
