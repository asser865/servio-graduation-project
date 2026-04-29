export function revealAll(container = document) {
  container.querySelectorAll("[data-reveal]").forEach((el) => {
    el.classList.add("is-visible");
  });
}

export function initScrollReveal() {
  if (!("IntersectionObserver" in window)) return;
  const elements = document.querySelectorAll("[data-reveal]");
  if (!elements.length) return;

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        const el = entry.target;
        el.classList.add("is-visible");
        observer.unobserve(el);
      }
    },
    {
      threshold: 0.15,
    }
  );

  elements.forEach((el) => {
    const delay = el.getAttribute("data-reveal-delay");
    if (delay) {
      el.style.transitionDelay = `${parseInt(delay, 10)}ms`;
    }
    observer.observe(el);
  });
}

window.initScrollReveal = initScrollReveal;


// .
