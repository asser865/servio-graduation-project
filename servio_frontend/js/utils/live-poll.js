/**
 * Live-poll utilities for background data refresh without UX disruption.
 *
 * Patterns used by professional dashboards (Linear, Stripe, GitHub):
 *   - Focus-pause: skip refresh while user types or a modal is open
 *   - Hash-diff:   skip DOM rebuild when payload unchanged
 *   - Form-snapshot: preserve focused input value/caret across rerender
 *   - Visibility backoff: slow/halt polling when tab hidden
 */

/* ── Focus / busy detection ─────────────────────────────────────────────── */

const INPUT_TAGS = new Set(['INPUT', 'TEXTAREA', 'SELECT']);
const MODAL_SELECTORS = [
  '.modal.show',
  '.modal.is-open',
  '.modal[aria-hidden="false"]',
  '[data-modal-open="true"]',
  'dialog[open]'
].join(',');

export function isUserBusy() {
  const ae = document.activeElement;
  if (ae && ae !== document.body) {
    if (INPUT_TAGS.has(ae.tagName)) return true;
    if (ae.isContentEditable) return true;
  }
  if (document.querySelector(MODAL_SELECTORS)) return true;
  // Active text selection — user reading/copying
  const sel = window.getSelection?.();
  if (sel && sel.toString().length > 0) return true;
  return false;
}

/* ── Hash diff (skip rerender when nothing changed) ─────────────────────── */

const _hashCache = new Map();

// djb2 — fast, good enough for change detection
function hashString(str) {
  let h = 5381;
  for (let i = 0; i < str.length; i++) h = ((h << 5) + h) ^ str.charCodeAt(i);
  return h >>> 0;
}

export function hasChanged(key, payload) {
  let str;
  try { str = JSON.stringify(payload); } catch { return true; }
  const h = hashString(str);
  if (_hashCache.get(key) === h) return false;
  _hashCache.set(key, h);
  return true;
}

export function clearHash(key) {
  if (key == null) _hashCache.clear();
  else _hashCache.delete(key);
}

/* ── Form snapshot / restore (preserve focus + value + caret) ───────────── */

export function snapshotFocus(rootEl = document) {
  const ae = document.activeElement;
  if (!ae || ae === document.body) return null;
  if (!INPUT_TAGS.has(ae.tagName) && !ae.isContentEditable) return null;
  if (rootEl !== document && !rootEl.contains(ae)) return null;
  return {
    selector: cssPath(ae),
    value: ae.value,
    start: ae.selectionStart ?? null,
    end: ae.selectionEnd ?? null,
    scrollTop: ae.scrollTop
  };
}

export function restoreFocus(snap, rootEl = document) {
  if (!snap) return;
  const el = rootEl.querySelector(snap.selector);
  if (!el) return;
  try {
    if ('value' in el && snap.value !== undefined) el.value = snap.value;
    el.focus({ preventScroll: true });
    if (typeof el.setSelectionRange === 'function' && snap.start != null) {
      el.setSelectionRange(snap.start, snap.end ?? snap.start);
    }
    if (snap.scrollTop) el.scrollTop = snap.scrollTop;
  } catch (_) { /* ignore */ }
}

function cssPath(el) {
  if (el.id) return `#${CSS.escape(el.id)}`;
  if (el.name) return `${el.tagName.toLowerCase()}[name="${CSS.escape(el.name)}"]`;
  const parts = [];
  let node = el;
  while (node && node.nodeType === 1 && parts.length < 6) {
    let part = node.tagName.toLowerCase();
    if (node.classList.length) part += '.' + [...node.classList].map(CSS.escape).join('.');
    const parent = node.parentNode;
    if (parent) {
      const sibs = [...parent.children].filter(c => c.tagName === node.tagName);
      if (sibs.length > 1) part += `:nth-of-type(${sibs.indexOf(node) + 1})`;
    }
    parts.unshift(part);
    node = node.parentElement;
  }
  return parts.join(' > ');
}

/* ── Poller factory ─────────────────────────────────────────────────────── */

/**
 * Creates a polite poller that:
 *   - skips ticks while user is busy (typing / modal open)
 *   - pauses entirely when tab is hidden
 *   - prevents overlapping runs
 *
 * @param {object} opts
 * @param {() => Promise<void>} opts.tick  Work to run each interval
 * @param {number} opts.intervalMs        Base interval
 * @param {string} [opts.name]            For debugging
 * @returns {{ start: () => void, stop: () => void, isRunning: () => boolean }}
 */
export function createPoller({ tick, intervalMs, name = 'poller' }) {
  let timer = null;
  let inFlight = false;

  const run = async () => {
    if (inFlight) return;
    if (document.hidden) return;
    if (isUserBusy()) return;
    inFlight = true;
    try { await tick(); }
    catch (err) { console.warn(`[${name}] tick failed:`, err); }
    finally { inFlight = false; }
  };

  const start = () => {
    if (timer) return;
    timer = setInterval(run, intervalMs);
  };
  const stop = () => {
    if (timer) { clearInterval(timer); timer = null; }
  };

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) stop();
    else start();
  });

  return { start, stop, isRunning: () => !!timer };
}
