/**
 * splash-loader.js
 * ─────────────────
 * Self-contained SERVIO splash screen.
 * Letters appear one-by-one, progress bar fills,
 * then the word morphs toward the header brand
 * and the overlay reveals the page underneath.
 *
 * Only runs on the homepage (index.html) where the
 * [data-splash-loader] element exists. Plays on
 * every page load / refresh.
 */

export function initSplashLoader() {
  const splash = document.querySelector('[data-splash-loader]');
  if (!splash) return;

  // Check if this is a page refresh or first session visit
  const navEntry = performance.getEntriesByType("navigation")[0];
  const isReload = navEntry && navEntry.type === "reload";
  const isFirstVisit = !sessionStorage.getItem('splash_seen');

  if (!isReload && !isFirstVisit) {
    // Navigated from another page (like Contact -> Home). Hide loader instantly.
    splash.style.display = 'none';
    document.body.classList.remove('is-loading');
    return;
  }

  // Record that the user has seen the splash this session
  sessionStorage.setItem('splash_seen', 'true');

  // ── Reduced-motion check ──
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  document.body.classList.add('is-loading');

  if (prefersReducedMotion) {
    // Skip all stagger/letter animations; show splash briefly then exit
    const letters = splash.querySelectorAll('.splash-loader__letter');
    const barFill = splash.querySelector('.splash-loader__bar-fill');

    // Make all letters immediately visible and fill the bar instantly
    letters.forEach(letter => letter.classList.add('is-visible'));
    if (barFill) barFill.style.width = '100%';

    setTimeout(() => {
      splash.classList.add('is-exiting');
      setTimeout(() => {
        splash.classList.add('is-done');
        document.body.classList.remove('is-loading');
      }, 400);
    }, 400);

    return;
  }

  const letters = splash.querySelectorAll('.splash-loader__letter');
  const barFill = splash.querySelector('.splash-loader__bar-fill');
  const totalLetters = letters.length;

  // ── Phase 1: Reveal letters one-by-one ──
  const letterDelay = 300;   // ms between each letter
  const holdAfter   = 600;   // ms to hold after last letter

  letters.forEach((letter, i) => {
    setTimeout(() => {
      letter.classList.add('is-visible');

      // Update progress bar in sync
      const progress = ((i + 1) / totalLetters) * 100;
      barFill.style.width = progress + '%';
    }, i * letterDelay);
  });

  // ── Phase 2: Calculate target position (header brand) ──
  const totalLetterTime = totalLetters * letterDelay + holdAfter;

  setTimeout(() => {
    const brand = document.querySelector('.brand__name') || document.querySelector('.brand');
    const word  = splash.querySelector('.splash-loader__word');

    if (brand && word) {
      const brandRect = brand.getBoundingClientRect();
      const wordRect  = word.getBoundingClientRect();

      // Exact scale: match splash word height to brand text height
      const scale = brandRect.height / wordRect.height;

      // With transform-origin: left center, the anchor point is
      // the left-center of the word. Translate that to the brand's left-center.
      const wordAnchorX = wordRect.left;
      const wordAnchorY = wordRect.top + wordRect.height / 2;
      const brandAnchorX = brandRect.left;
      const brandAnchorY = brandRect.top + brandRect.height / 2;

      const targetX = brandAnchorX - wordAnchorX;
      const targetY = brandAnchorY - wordAnchorY;

      splash.style.setProperty('--splash-target-x', targetX + 'px');
      splash.style.setProperty('--splash-target-y', targetY + 'px');
      splash.style.setProperty('--splash-scale', scale);
    }

    // ── Phase 3: Trigger exit animation ──
    splash.classList.add('is-exiting');

    // Clean up after animation completes
    const exitDuration = 1600; // 1500ms animations running together + buffer
    setTimeout(() => {
      splash.classList.add('is-done');
      document.body.classList.remove('is-loading');
    }, exitDuration);
  }, totalLetterTime);
}

// .
