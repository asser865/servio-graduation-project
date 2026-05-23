/* ═══════════════════════════════════════════════════════════
   boot-init.js — Sitewide first-paint stabiliser
   ─────────────────────────────────────────────
   Runs synchronously in <head> before any stylesheet parses.

   Goals:
   • Hide <body> until styles applied + first layout (prevents FOUC).
   • Skip header / chrome intro animations on reload + bfcache restore
     (those replay on every refresh and create perceived "flicker").
   • Pre-reveal any [data-reveal] elements that live inside an already-
     active panel / above-the-fold container so they don't wait for the
     ES module to call revealAll().

   Removed automatically after DOMContentLoaded + 2× requestAnimationFrame,
   with a safety timeout in case DOMContentLoaded never fires (e.g. error).
   ═══════════════════════════════════════════════════════════ */
(function () {
  var html = document.documentElement;

  // Inject FOUC-guard stylesheet synchronously so the rule applies
  // before <body> is parsed. Cannot live in an external CSS file —
  // by the time main.css parses, the body has often already painted.
  try {
    var style = document.createElement('style');
    style.setAttribute('data-boot-gate', '');
    style.textContent = [
      'html.is-booting body{opacity:0!important;pointer-events:none!important}',
      'body{opacity:1;transition:opacity 320ms cubic-bezier(0.22,1,0.36,1)}',
      '.servio-boot-bar{position:fixed;top:0;left:0;right:0;height:2px;z-index:2147483647;background:transparent;overflow:hidden;pointer-events:none}',
      '.servio-boot-bar::before{content:"";position:absolute;inset:0;width:40%;background:linear-gradient(90deg,transparent,#2563eb,#60a5fa,transparent);animation:servioBootSlide 1.1s ease-in-out infinite}',
      '@keyframes servioBootSlide{0%{transform:translateX(-100%)}100%{transform:translateX(350%)}}',
      'html:not(.is-booting) .servio-boot-bar{opacity:0;transition:opacity 240ms ease 60ms}',
      '@media (prefers-reduced-motion: reduce){body{transition:none}.servio-boot-bar::before{animation:none}}'
    ].join('');
    document.head.appendChild(style);
  } catch (e) { /* head may not exist yet in exotic doc states */ }

  html.classList.add('is-booting');

  // Record boot start so we can enforce a minimum display time for the
  // progress bar — otherwise on fast/cached pages it would mount and remove
  // within a frame and the user never sees it sweep.
  var bootStart = (performance && performance.now) ? performance.now() : Date.now();
  var MIN_BOOT_MS = 480;

  // Insert top progress bar immediately. position:fixed so parent doesn't
  // matter — attaching to <html> works even before <body> exists.
  function mountBootBar() {
    if (document.querySelector('.servio-boot-bar')) return;
    var bar = document.createElement('div');
    bar.className = 'servio-boot-bar';
    bar.setAttribute('aria-hidden', 'true');
    (document.body || document.documentElement).appendChild(bar);
  }
  mountBootBar();
  // Re-attach to <body> once it exists (some browsers clear <html>-direct
  // children when body parses).
  if (!document.body) {
    document.addEventListener('DOMContentLoaded', function () {
      var existing = document.querySelector('.servio-boot-bar');
      if (!existing || existing.parentNode === document.body) return;
      document.body.appendChild(existing);
    }, { once: true });
  }

  // Suppress intro animations on reload / bfcache restore.
  try {
    var nav = performance.getEntriesByType('navigation')[0];
    if (nav && (nav.type === 'reload' || nav.type === 'back_forward')) {
      html.classList.add('no-intro');
    }
  } catch (e) { /* PerformanceNavigationTiming may be unavailable */ }

  var finished = false;
  function finishBoot() {
    if (finished) return;
    finished = true;
    html.classList.remove('is-booting');
    // Remove progress bar after its fade-out transition completes.
    setTimeout(function () {
      var bar = document.querySelector('.servio-boot-bar');
      if (bar && bar.parentNode) bar.parentNode.removeChild(bar);
    }, 380);
  }
  // Expose so page-specific inline scripts can trigger early reveal if needed.
  window.__servioFinishBoot = finishBoot;

  function onReady() {
    // Pre-reveal any [data-reveal] inside elements that are already marked
    // visible at parse-time (active dashboard panels, hero sections, etc.).
    try {
      var roots = document.querySelectorAll('.is-active[data-panel], [data-reveal-root]');
      roots.forEach(function (root) {
        root.querySelectorAll('[data-reveal]').forEach(function (el) {
          el.classList.add('is-visible');
        });
      });

      // Pre-reveal any [data-reveal] currently above the fold so the user does
      // not see a blank hero / first cards while the IntersectionObserver
      // schedules its first callback (which can lag a couple of frames).
      var vh = window.innerHeight || document.documentElement.clientHeight;
      document.querySelectorAll('[data-reveal]:not(.is-visible)').forEach(function (el) {
        var r = el.getBoundingClientRect();
        if (r.top < vh && r.bottom > 0) el.classList.add('is-visible');
      });
    } catch (e) { /* ignore */ }

    var now = (performance && performance.now) ? performance.now() : Date.now();
    var elapsed = now - bootStart;
    var remaining = Math.max(0, MIN_BOOT_MS - elapsed);
    setTimeout(function () {
      requestAnimationFrame(function () {
        requestAnimationFrame(finishBoot);
      });
    }, remaining);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', onReady, { once: true });
  } else {
    onReady();
  }

  // Safety net — never leave the page hidden indefinitely.
  setTimeout(finishBoot, 1500);

  // Restore on bfcache navigations that fire pageshow without DCL.
  window.addEventListener('pageshow', function (e) {
    if (e.persisted) finishBoot();
  });
})();
