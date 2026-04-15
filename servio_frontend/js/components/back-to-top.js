/* ═══════════════════════════════════════════════════════════
   Back to top floating action button
   ═══════════════════════════════════════════════════════════ */

export function initBackToTop() {
  // Wait for the DOM to be ready, but actually the module is usually deferred
  if (document.body.querySelector(".back-to-top")) return;

  const btn = document.createElement("button");
  btn.className = "back-to-top";
  btn.setAttribute("aria-label", "Scroll back to top");
  btn.setAttribute("data-i18n-aria-label", "back_to_top_aria");
  btn.setAttribute("data-i18n-title", "back_to_top_title");
  btn.title = "Back to top";
  btn.innerHTML = `
    <svg class="svgIcon" viewBox="0 0 384 512">
      <path d="M214.6 41.4c-12.5-12.5-32.8-12.5-45.3 0l-160 160c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L160 141.2V448c0 17.7 14.3 32 32 32s32-14.3 32-32V141.2L329.4 246.6c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3l-160-160z"></path>
    </svg>
  `;

  document.body.appendChild(btn);

  function updateBtnLang() {
    var i18n = window.i18n;
    var lang = window.__lang || 'en';
    var dict = (i18n && i18n[lang]) || (i18n && i18n.en) || {};
    var title = dict.back_to_top_title || (i18n && i18n.en && i18n.en.back_to_top_title) || 'Back to top';
    var aria  = dict.back_to_top_aria  || (i18n && i18n.en && i18n.en.back_to_top_aria)  || 'Scroll back to top';
    btn.title = title;
    btn.setAttribute('aria-label', aria);
  }

  document.addEventListener('langchange', updateBtnLang);
  updateBtnLang();

  let isVisible = false;

  // Determine the primary scroll container. Dashboards use internal scrolling.
  const getScrollContainer = () => {
    return document.querySelector('.admin-content') || document.querySelector('.dash-content');
  };

  const handleScroll = () => {
    const container = getScrollContainer();
    
    // Capture from every standard scrolling element
    let scrollY = window.scrollY || window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop || 0;
    
    if (container && container.scrollTop !== undefined) {
      scrollY = container.scrollTop;
    }
    
    // Show button after scrolling down 200px (eager)
    const shouldBeVisible = scrollY > 200;

    if (shouldBeVisible !== isVisible) {
      isVisible = shouldBeVisible;
      btn.classList.toggle("is-visible", isVisible);
      
      // Inline styles guarantee it shows despite potential CSS specificity bugs
      if (isVisible) {
        btn.style.setProperty("opacity", "1", "important");
        btn.style.setProperty("visibility", "visible", "important");
        btn.style.setProperty("transform", "translateX(-50%) translateY(0)", "important");
        btn.style.setProperty("display", "flex", "important");
      } else {
        btn.style.setProperty("opacity", "0", "important");
        btn.style.setProperty("visibility", "hidden", "important");
        btn.style.setProperty("transform", "translateX(-50%) translateY(30px)", "important");
      }
    }
  };

  // Listen thoroughly everywhere
  window.addEventListener("scroll", () => requestAnimationFrame(handleScroll), { passive: true });
  document.body.addEventListener("scroll", () => requestAnimationFrame(handleScroll), { passive: true }, true);
  document.addEventListener("scroll", () => requestAnimationFrame(handleScroll), { passive: true }, true);
  
  // Also watch potential dashboard scroll containers (using event delegation essentially or direct)
  const attachDashboardScroll = () => {
    const adminContent = document.querySelector('.admin-content');
    if (adminContent) {
      adminContent.addEventListener("scroll", () => requestAnimationFrame(handleScroll), { passive: true });
    }
    const dashContent = document.querySelector('.dash-content');
    if (dashContent) {
      dashContent.addEventListener("scroll", () => requestAnimationFrame(handleScroll), { passive: true });
    }
  };
  
  // Small delay to ensure dashboard js might have rendered them
  setTimeout(attachDashboardScroll, 500);

  btn.addEventListener("click", () => {
    // Scroll the dashboard inner container if applicable
    const container = getScrollContainer();
    if (container && typeof container.scrollTo === "function" && container !== document.body) {
      container.scrollTo({ top: 0, behavior: "smooth" });
    }

    // Scroll both html and body directly — window.scrollTo can silently fail
    // when scrollbar-width: none / overflow-x: clip is set on html (reset.css).
    document.documentElement.scrollTo({ top: 0, behavior: "smooth" });
    document.body.scrollTo({ top: 0, behavior: "smooth" });
    window.scrollTo({ top: 0, behavior: "smooth" });
  });

  // Initial check
  handleScroll();
}

// .
