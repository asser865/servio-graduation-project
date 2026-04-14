export function initScrollEffects() {
  const progress = document.querySelector("[data-scroll-progress]");
  const header = document.querySelector("[data-site-header]");
  const fxEls = Array.from(document.querySelectorAll("[data-scroll-fx]"));
  const counters = Array.from(document.querySelectorAll("[data-count-to]"));

  if (!progress && !header && !fxEls.length && !counters.length) return;

  const lerp = (a, b, t) => a + (b - a) * t;
  const clamp01 = (v) => Math.max(0, Math.min(1, v));

  const fxState = new Map();
  fxEls.forEach((el) => fxState.set(el, { x: 0, y: 0, scale: 1 }));

  const prefersReducedMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;

  let ticking = false;

  const updateFx = () => {
    if (!fxEls.length) return;
    const vh = window.innerHeight || 1;

    fxEls.forEach((el) => {
      const rect = el.getBoundingClientRect();
      const progress = clamp01((vh - rect.top) / (vh + rect.height));
      const centered = (progress - 0.5) * 2; // -1..1

      const maxY = parseFloat(el.getAttribute("data-fx-y") || "0");
      const maxX = parseFloat(el.getAttribute("data-fx-x") || "0");
      const maxScale = parseFloat(el.getAttribute("data-fx-scale") || "0");

      const targetY = prefersReducedMotion ? 0 : centered * maxY;
      const targetX = prefersReducedMotion ? 0 : centered * maxX;
      const targetScale = prefersReducedMotion ? 1 : 1 + centered * maxScale;

      const prev = fxState.get(el) || { x: 0, y: 0, scale: 1 };
      const next = {
        x: lerp(prev.x, targetX, 0.12),
        y: lerp(prev.y, targetY, 0.12),
        scale: lerp(prev.scale, targetScale, 0.12),
      };
      fxState.set(el, next);

      el.style.setProperty("--fx-x", `${next.x.toFixed(2)}px`);
      el.style.setProperty("--fx-y", `${next.y.toFixed(2)}px`);
      el.style.setProperty("--fx-scale", `${next.scale.toFixed(4)}`);
    });
  };

  const animateCount = (el, to, suffix = "") => {
    const start = performance.now();
    const dur = 900;
    const from = 0;

    const step = (now) => {
      const t = clamp01((now - start) / dur);
      const eased = 1 - Math.pow(1 - t, 3);
      const value = Math.round(lerp(from, to, eased));
      el.textContent = value.toLocaleString("en-US") + suffix;
      if (t < 1) requestAnimationFrame(step);
    };

    requestAnimationFrame(step);
  };

  const initCounters = () => {
    if (!counters.length || !("IntersectionObserver" in window)) return;
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          const el = entry.target;
          const to = parseInt(el.getAttribute("data-count-to") || "0", 10);
          const suffix = el.getAttribute("data-count-suffix") || "";
          animateCount(el, to, suffix);
          io.unobserve(el);
        });
      },
      { threshold: 0.45 }
    );
    counters.forEach((el) => io.observe(el));
  };

  const onScroll = () => {
    if (ticking) return;
    ticking = true;

    window.requestAnimationFrame(() => {
      ticking = false;

      if (progress) {
        const doc = document.documentElement;
        const max = Math.max(1, doc.scrollHeight - doc.clientHeight);
        const pct = Math.min(1, Math.max(0, doc.scrollTop / max));
        progress.style.width = `${(pct * 100).toFixed(2)}%`;
        progress.style.opacity = pct > 0.02 ? "0.95" : "0";
      }

      if (header) {
        const elevated = window.scrollY > 8;
        header.classList.toggle("is-elevated", elevated);
      }

      updateFx();
    });
  };

  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", onScroll, { passive: true });
  initCounters();
  onScroll();
}


// .
