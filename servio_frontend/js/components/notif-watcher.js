import { getNotifications } from '../api/notifications.js';
import { playNotifSound, primeNotifSound } from './notif-sound.js';

const POLL_INTERVAL = 20_000;
const POPUP_DURATION = 5500;
const EXIT_DURATION = 520;
const SESSION_KEY = 'servio_notif_seen_ids';
const MAX_VISIBLE = 3;

function getSession() {
  try {
    return JSON.parse(localStorage.getItem('servio_session') || sessionStorage.getItem('servio_session') || 'null');
  } catch { return null; }
}

function getSeenIds() {
  try { return new Set(JSON.parse(sessionStorage.getItem(SESSION_KEY) || '[]')); }
  catch { return new Set(); }
}

function saveSeenIds(set) {
  sessionStorage.setItem(SESSION_KEY, JSON.stringify([...set]));
}

function rewriteForRole(raw) {
  if (!raw) return raw;
  const session = getSession();
  const role = session?.role;
  if (role !== 'technician') return raw;
  // Legacy tech-targeted notifs point to booking-details.html — bounces off role guard
  if (raw.includes('booking-details.html')) {
    return './technician-dashboard.html#job-queue';
  }
  if (raw.includes('customer-dashboard.html')) {
    return raw.replace(/customer-dashboard\.html/, 'technician-dashboard.html');
  }
  return raw;
}

function normalizeNotifUrl(raw) {
  if (!raw) return null;
  const rewritten = rewriteForRole(raw);
  try {
    const u = new URL(rewritten, window.location.href);
    return u.pathname + u.search + u.hash;
  } catch { return rewritten; }
}

function navigateToNotif(viewUrl) {
  if (!viewUrl) return;
  try {
    const target = new URL(viewUrl, window.location.href);
    const samePath = target.pathname === window.location.pathname;
    if (samePath && target.hash) {
      if (window.location.hash === target.hash) {
        window.dispatchEvent(new HashChangeEvent('hashchange'));
      } else {
        window.location.hash = target.hash;
      }
      return;
    }
  } catch (_) {}
  window.location.href = viewUrl;
}

const TYPE_TONE = {
  booking_created:           'info',
  booking_accepted:          'success',
  booking_rejected:          'warn',
  booking_en_route:          'info',
  booking_arrived:           'info',
  booking_in_progress:       'info',
  booking_completed:         'success',
  booking_cancelled:         'warn',
  booking_action_required:   'warn',
  tech_available:            'info',
  review_received:           'star',
  dispute_opened:            'danger',
  dispute_resolved:          'success',
  dispute_evidence_requested:'warn',
  dispute_evidence_added:    'info',
  dispute_status_changed:    'info',
  dispute_appealed:          'danger',
  support_issue_opened:      'danger',
  support_issue_updated:     'info',
  support_issue_resolved:    'success',
  system:                    'info',
};

const TONE_COLORS = {
  success: { stripe: '#22c55e', tint: 'rgba(34,197,94,0.16)', glow: 'rgba(34,197,94,0.35)' },
  warn:    { stripe: '#f59e0b', tint: 'rgba(245,158,11,0.18)', glow: 'rgba(245,158,11,0.40)' },
  danger:  { stripe: '#ef4444', tint: 'rgba(239,68,68,0.18)',  glow: 'rgba(239,68,68,0.40)' },
  info:    { stripe: '#3b82f6', tint: 'rgba(59,130,246,0.16)', glow: 'rgba(59,130,246,0.35)' },
  star:    { stripe: '#eab308', tint: 'rgba(234,179,8,0.18)',  glow: 'rgba(234,179,8,0.40)' },
};

const TYPE_ICON = {
  booking_created:    '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="3" y1="10" x2="21" y2="10"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="16" y1="2" x2="16" y2="6"/></svg>',
  booking_accepted:   '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
  booking_rejected:   '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>',
  booking_en_route:   '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>',
  booking_arrived:    '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>',
  booking_completed:  '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
  booking_cancelled:  '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>',
  review_received:    '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>',
  dispute_opened:     '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
  system:             '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>',
};

function iconFor(type) {
  return TYPE_ICON[type]
      || (type?.startsWith('dispute')  ? TYPE_ICON.dispute_opened : null)
      || (type?.startsWith('support')  ? TYPE_ICON.dispute_opened : null)
      || (type?.startsWith('booking')  ? TYPE_ICON.booking_created : null)
      || TYPE_ICON.system;
}

function toneFor(type) { return TYPE_TONE[type] || 'info'; }

const TYPE_KICKER = {
  booking_created:           'New Booking',
  booking_accepted:          'Confirmed',
  booking_rejected:          'Declined',
  booking_en_route:          'En Route',
  booking_arrived:           'Arrived',
  booking_in_progress:       'In Progress',
  booking_completed:         'Completed',
  booking_cancelled:         'Cancelled',
  booking_action_required:   'Action Needed',
  tech_available:            'Available',
  review_received:           'New Review',
  dispute_opened:            'Dispute',
  dispute_resolved:          'Resolved',
  dispute_evidence_requested:'Evidence',
  dispute_evidence_added:    'Evidence',
  dispute_status_changed:    'Update',
  dispute_appealed:          'Appealed',
  support_issue_opened:      'Support',
  support_issue_updated:     'Update',
  support_issue_resolved:    'Resolved',
  system:                    'System',
};

function kickerFor(type) {
  return TYPE_KICKER[type]
      || (type?.startsWith('booking') ? 'Booking' : null)
      || (type?.startsWith('dispute') ? 'Dispute' : null)
      || (type?.startsWith('support') ? 'Support' : null)
      || 'Notification';
}

function escapeHtml(s) {
  return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function injectStyles() {
  if (document.getElementById('notif-watcher-styles')) return;
  const style = document.createElement('style');
  style.id = 'notif-watcher-styles';
  style.textContent = `
    .nw-stack {
      position: fixed;
      top: 5.5rem;
      left: 50%;
      transform: translateX(-50%);
      z-index: 9000;
      display: flex;
      flex-direction: column;
      gap: 0.85rem;
      width: min(460px, calc(100vw - 2rem));
      pointer-events: none;
      perspective: 1200px;
    }
    .nw-toast {
      --tone-stripe: #3b82f6;
      --tone-tint:   rgba(59,130,246,0.20);
      --tone-glow:   rgba(59,130,246,0.45);
      --tone-mid:    rgba(59,130,246,0.10);
      position: relative;
      overflow: hidden;
      isolation: isolate;
      pointer-events: all;
      cursor: pointer;
      display: grid;
      grid-template-columns: auto 1fr auto;
      align-items: flex-start;
      gap: 0.95rem;
      padding: 1.05rem 1.1rem 1.1rem 1.4rem;
      border-radius: 18px;
      color: #f4f4f6;
      background:
        linear-gradient(135deg, var(--tone-mid) 0%, transparent 55%),
        linear-gradient(180deg, rgba(38, 38, 44, 0.86) 0%, rgba(22, 22, 28, 0.92) 100%);
      backdrop-filter: blur(28px) saturate(190%);
      -webkit-backdrop-filter: blur(28px) saturate(190%);
      border: 1px solid rgba(255,255,255,0.08);
      box-shadow:
        0 24px 60px -10px rgba(0,0,0,0.55),
        0 8px 20px -8px var(--tone-glow),
        0 1px 0 rgba(255,255,255,0.06) inset,
        0 -1px 0 rgba(0,0,0,0.30) inset;
      opacity: 0;
      transform: translateY(-130%) scale(0.85) rotateX(20deg);
      filter: blur(10px);
      transition:
        transform 320ms cubic-bezier(0.22, 1, 0.36, 1),
        box-shadow 320ms ease;
      animation: nw-enter 720ms cubic-bezier(0.34, 1.56, 0.64, 1) forwards;
      will-change: transform, opacity, filter;
    }
    /* Animated border-gradient — premium accent */
    .nw-toast::before {
      content: "";
      position: absolute;
      inset: 0;
      border-radius: inherit;
      padding: 1px;
      background: linear-gradient(135deg, var(--tone-stripe), transparent 35%, transparent 65%, var(--tone-stripe));
      -webkit-mask:
        linear-gradient(#000 0 0) content-box,
        linear-gradient(#000 0 0);
      -webkit-mask-composite: xor;
              mask-composite: exclude;
      opacity: 0;
      animation: nw-border-fade 520ms ease 200ms forwards;
      pointer-events: none;
    }
    /* Sweep sheen on entry */
    .nw-toast::after {
      content: "";
      position: absolute;
      top: 0; bottom: 0;
      left: -60%;
      width: 60%;
      background: linear-gradient(115deg,
        transparent 20%,
        rgba(255,255,255,0.10) 50%,
        transparent 80%);
      transform: skewX(-18deg);
      animation: nw-sheen 1100ms cubic-bezier(0.22, 1, 0.36, 1) 250ms 1;
      pointer-events: none;
    }
    .nw-toast.is-leaving {
      animation: nw-exit ${EXIT_DURATION}ms cubic-bezier(0.55, 0, 0.7, 0.2) forwards;
    }
    .nw-toast:hover {
      transform: translateY(-3px) scale(1.005);
      box-shadow:
        0 32px 72px -10px rgba(0,0,0,0.65),
        0 14px 30px -10px var(--tone-glow),
        0 1px 0 rgba(255,255,255,0.10) inset,
        0 -1px 0 rgba(0,0,0,0.30) inset;
    }

    /* Icon wrapper with radial halo */
    .nw-toast__icon-wrap {
      position: relative;
      flex-shrink: 0;
      width: 44px; height: 44px;
      display: grid;
      place-items: center;
    }
    .nw-toast__icon-wrap::before {
      content: "";
      position: absolute;
      inset: -10px;
      border-radius: 50%;
      background: radial-gradient(circle, var(--tone-glow) 0%, transparent 65%);
      opacity: 0.85;
      filter: blur(3px);
      animation: nw-halo 2400ms ease-in-out infinite;
    }
    .nw-toast__icon {
      position: relative;
      width: 44px; height: 44px;
      border-radius: 14px;
      background: linear-gradient(135deg, var(--tone-stripe), color-mix(in oklab, var(--tone-stripe), #000 35%));
      color: #ffffff;
      display: grid;
      place-items: center;
      box-shadow:
        0 6px 16px -4px var(--tone-glow),
        0 1px 0 rgba(255,255,255,0.25) inset,
        0 -2px 6px rgba(0,0,0,0.30) inset;
      animation: nw-icon-pop 700ms cubic-bezier(0.34, 1.56, 0.64, 1) 80ms backwards;
    }
    .nw-toast__icon svg {
      filter: drop-shadow(0 1px 2px rgba(0,0,0,0.35));
    }

    .nw-toast__body { min-width: 0; padding-top: 0.1rem; }
    .nw-toast__kicker {
      display: inline-flex;
      align-items: center;
      gap: 0.35rem;
      font-size: 0.66rem;
      font-weight: 700;
      letter-spacing: 0.09em;
      text-transform: uppercase;
      color: var(--tone-stripe);
      margin-bottom: 0.28rem;
      opacity: 0.95;
    }
    .nw-toast__kicker::before {
      content: "";
      width: 6px; height: 6px;
      border-radius: 50%;
      background: var(--tone-stripe);
      box-shadow: 0 0 8px var(--tone-glow);
      animation: nw-dot-pulse 1.4s ease-in-out infinite;
    }
    .nw-toast__title {
      font-weight: 650;
      font-size: 0.965rem;
      line-height: 1.3;
      margin: 0 0 0.22rem;
      letter-spacing: -0.012em;
      color: #ffffff;
    }
    .nw-toast__text {
      font-size: 0.84rem;
      line-height: 1.5;
      margin: 0;
      color: rgba(255,255,255,0.72);
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }
    .nw-toast__cta {
      appearance: none;
      border: none;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 0.3rem;
      margin-top: 0.65rem;
      padding: 0.4rem 0.75rem 0.4rem 0.85rem;
      font-family: inherit;
      font-size: 0.74rem;
      font-weight: 650;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      color: #fff;
      background: linear-gradient(135deg, var(--tone-stripe), color-mix(in oklab, var(--tone-stripe), #000 25%));
      border-radius: 999px;
      box-shadow:
        0 4px 12px -4px var(--tone-glow),
        0 1px 0 rgba(255,255,255,0.20) inset;
      transition: transform 180ms ease, box-shadow 180ms ease, filter 180ms ease;
    }
    .nw-toast__cta:hover {
      transform: translateY(-1px);
      filter: brightness(1.08);
      box-shadow:
        0 8px 18px -4px var(--tone-glow),
        0 1px 0 rgba(255,255,255,0.25) inset;
    }
    .nw-toast__cta svg { transition: transform 200ms ease; }
    .nw-toast__cta:hover svg,
    .nw-toast:hover .nw-toast__cta svg { transform: translateX(3px); }
    .nw-toast__close {
      background: rgba(255,255,255,0.06);
      border: 1px solid rgba(255,255,255,0.08);
      color: #ffffff;
      cursor: pointer;
      width: 28px;
      height: 28px;
      border-radius: 50%;
      display: grid;
      place-items: center;
      flex-shrink: 0;
      opacity: 0.6;
      transition: background 180ms ease, opacity 180ms ease, transform 280ms cubic-bezier(0.22, 1, 0.36, 1);
    }
    .nw-toast__close:hover {
      background: rgba(255,255,255,0.16);
      opacity: 1;
      transform: rotate(90deg);
    }
    .nw-toast__progress {
      position: absolute;
      left: 0; right: 0; bottom: 0;
      height: 3px;
      background: linear-gradient(90deg, var(--tone-stripe), color-mix(in oklab, var(--tone-stripe), #fff 35%));
      transform-origin: left center;
      box-shadow: 0 0 12px var(--tone-glow);
      animation: nw-progress ${POPUP_DURATION}ms linear forwards;
    }
    .nw-toast.is-paused .nw-toast__progress { animation-play-state: paused; }

    /* Light theme */
    [data-theme="light"] .nw-toast {
      color: #1a1a1a;
      background:
        linear-gradient(135deg, var(--tone-mid) 0%, transparent 55%),
        linear-gradient(180deg, rgba(255, 255, 255, 0.92) 0%, rgba(248, 248, 250, 0.96) 100%);
      border-color: rgba(34, 40, 49, 0.08);
      box-shadow:
        0 24px 60px -12px rgba(34, 40, 49, 0.20),
        0 8px 20px -8px var(--tone-glow),
        0 1px 0 rgba(255,255,255,0.80) inset,
        0 -1px 0 rgba(34,40,49,0.05) inset;
    }
    [data-theme="light"] .nw-toast__title { color: #0e0e12; }
    [data-theme="light"] .nw-toast__text  { color: rgba(34,40,49,0.72); }
    [data-theme="light"] .nw-toast__close {
      background: rgba(0,0,0,0.04);
      border-color: rgba(34,40,49,0.06);
      color: #1a1a1a;
    }
    [data-theme="light"] .nw-toast__close:hover { background: rgba(0,0,0,0.10); }

    @keyframes nw-enter {
      0%   { transform: translateY(-130%) scale(0.85) rotateX(20deg); opacity: 0; filter: blur(10px); }
      60%  { transform: translateY(6%)    scale(1.025) rotateX(-2deg); opacity: 1; filter: blur(0); }
      82%  { transform: translateY(-2%)   scale(0.998) rotateX(0.5deg); }
      100% { transform: translateY(0)     scale(1)     rotateX(0);    opacity: 1; filter: blur(0); }
    }
    @keyframes nw-exit {
      0%   { transform: translateY(0)     scale(1)    rotateX(0);     opacity: 1; filter: blur(0); }
      35%  { transform: translateY(-10%)  scale(1.02) rotateX(-3deg); opacity: 0.9; filter: blur(1px); }
      100% { transform: translateY(-70%)  scale(0.86) rotateX(-15deg);opacity: 0; filter: blur(8px); }
    }
    @keyframes nw-border-fade {
      from { opacity: 0; }
      to   { opacity: 0.55; }
    }
    @keyframes nw-sheen {
      0%   { left: -60%; }
      100% { left: 130%; }
    }
    @keyframes nw-icon-pop {
      0%   { transform: scale(0) rotate(-30deg); opacity: 0; }
      70%  { transform: scale(1.15) rotate(6deg); opacity: 1; }
      100% { transform: scale(1) rotate(0); opacity: 1; }
    }
    @keyframes nw-halo {
      0%, 100% { opacity: 0.55; transform: scale(0.95); }
      50%      { opacity: 0.95; transform: scale(1.10); }
    }
    @keyframes nw-dot-pulse {
      0%, 100% { transform: scale(1);   opacity: 1;    }
      50%      { transform: scale(1.4); opacity: 0.55; }
    }
    @keyframes nw-progress {
      from { transform: scaleX(1); }
      to   { transform: scaleX(0); }
    }

    @media (prefers-reduced-motion: reduce) {
      .nw-toast { animation-duration: 200ms; }
      .nw-toast::after { animation: none; display: none; }
      .nw-toast.is-leaving { animation-duration: 200ms; }
      .nw-toast__icon-wrap::before { animation: none; }
      .nw-toast__kicker::before { animation: none; }
      @keyframes nw-enter { from { opacity: 0; } to { opacity: 1; } }
      @keyframes nw-exit  { from { opacity: 1; } to { opacity: 0; } }
    }

    @media (max-width: 560px) {
      .nw-stack { top: 4.5rem; width: calc(100vw - 1.5rem); }
      .nw-toast { padding: 0.95rem 0.95rem 1rem 1.15rem; gap: 0.8rem; }
      .nw-toast__icon, .nw-toast__icon-wrap { width: 40px; height: 40px; }
      .nw-toast__title { font-size: 0.92rem; }
      .nw-toast__text  { font-size: 0.81rem; }
    }
  `;
  document.head.appendChild(style);
}

function getStack() {
  let stack = document.querySelector('.nw-stack');
  if (!stack) {
    stack = document.createElement('div');
    stack.className = 'nw-stack';
    document.body.appendChild(stack);
  }
  return stack;
}

function enforceMax(stack) {
  const toasts = stack.querySelectorAll('.nw-toast:not(.is-leaving)');
  if (toasts.length <= MAX_VISIBLE) return;
  const overflow = toasts.length - MAX_VISIBLE;
  for (let i = 0; i < overflow; i++) {
    dismissToast(toasts[i]);
  }
}

function dismissToast(toast) {
  if (!toast || toast.classList.contains('is-leaving')) return;
  toast.classList.add('is-leaving');
  setTimeout(() => toast.remove(), EXIT_DURATION + 50);
}

function showPopup(notif) {
  const stack = getStack();
  const tone = toneFor(notif.type);
  const colors = TONE_COLORS[tone] || TONE_COLORS.info;
  const viewUrl = normalizeNotifUrl(notif.referenceUrl);
  const icon = iconFor(notif.type);

  const toast = document.createElement('div');
  toast.className = 'nw-toast';
  toast.style.setProperty('--tone-stripe', colors.stripe);
  toast.style.setProperty('--tone-tint',   colors.tint);
  toast.style.setProperty('--tone-glow',   colors.glow);
  toast.setAttribute('role', 'alert');
  toast.setAttribute('aria-live', 'polite');

  toast.innerHTML = `
    <span class="nw-toast__icon-wrap" aria-hidden="true">
      <span class="nw-toast__icon">${icon}</span>
    </span>
    <div class="nw-toast__body">
      <span class="nw-toast__kicker">${escapeHtml(kickerFor(notif.type))}</span>
      <p class="nw-toast__title">${escapeHtml(notif.title)}</p>
      <p class="nw-toast__text">${escapeHtml(notif.body)}</p>
      ${viewUrl ? `<button class="nw-toast__cta" type="button" data-nw-view>View<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg></button>` : ''}
    </div>
    <button class="nw-toast__close" type="button" aria-label="Dismiss">
      <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
    </button>
    <div class="nw-toast__progress" aria-hidden="true"></div>`;

  stack.appendChild(toast);
  enforceMax(stack);

  let dismissTimer = setTimeout(() => dismissToast(toast), POPUP_DURATION);
  let remaining = POPUP_DURATION;
  let startedAt = Date.now();

  toast.addEventListener('mouseenter', () => {
    clearTimeout(dismissTimer);
    remaining -= (Date.now() - startedAt);
    toast.classList.add('is-paused');
  });
  toast.addEventListener('mouseleave', () => {
    toast.classList.remove('is-paused');
    startedAt = Date.now();
    dismissTimer = setTimeout(() => dismissToast(toast), Math.max(remaining, 800));
  });

  toast.querySelector('.nw-toast__close').addEventListener('click', (e) => {
    e.stopPropagation();
    e.preventDefault();
    clearTimeout(dismissTimer);
    dismissToast(toast);
  });

  if (viewUrl) {
    const fire = (e) => {
      e.preventDefault();
      e.stopPropagation();
      clearTimeout(dismissTimer);
      navigateToNotif(viewUrl);
    };
    toast.style.cursor = 'pointer';
    toast.addEventListener('click', fire);
    const cta = toast.querySelector('[data-nw-view]');
    if (cta) cta.addEventListener('click', fire);
  }

  try { playNotifSound(); } catch (err) { console.warn('[notif-watcher] sound err', err); }
}

let seeded = false;

async function poll() {
  try {
    const res = await getNotifications(50);
    const notifs = res.notifications || [];
    const seenIds = getSeenIds();

    if (!seeded) {
      notifs.forEach(n => seenIds.add(n._id));
      saveSeenIds(seenIds);
      seeded = true;
      return;
    }

    const newUnread = notifs.filter(n => !n.isRead && !seenIds.has(n._id));
    newUnread.forEach(n => {
      seenIds.add(n._id);
      showPopup(n);
    });
    if (newUnread.length) saveSeenIds(seenIds);
  } catch (_) {}
}

export function initNotifWatcher() {
  const session = getSession();
  if (!session) return;

  injectStyles();
  primeNotifSound();
  poll();
  setInterval(poll, POLL_INTERVAL);
}
