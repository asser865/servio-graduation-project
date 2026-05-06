(function () {
  if (window.__SERVIO_HOME_FALLBACK_BOOTED) return;
  window.__SERVIO_HOME_FALLBACK_BOOTED = true;

  var HOME_CATEGORIES = [
    {
      key: "plumbing",
      cssClass: "category-card--plumbing",
      label: "Plumbing",
      desc: "Pipe repairs, leak fixes and water systems",
      icon: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z"></path><path d="M12.56 6.6A10.97 10.97 0 0 0 14 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 0 1-11.91 4.97"></path></svg>',
    },
    {
      key: "electrical",
      cssClass: "category-card--electrical",
      label: "Electrical",
      desc: "Wiring, panels, outlets and lighting",
      icon: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"></path></svg>',
    },
    {
      key: "hvac",
      cssClass: "category-card--ac",
      label: "HVAC and Climate",
      desc: "AC installation, repair and maintenance",
      icon: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12h20"></path><path d="M12 2v20"></path><path d="m20 16-4-4 4-4"></path><path d="m4 8 4 4-4 4"></path><path d="m16 4-4 4-4-4"></path><path d="m8 20 4-4 4 4"></path></svg>',
    },
    {
      key: "cleaning",
      cssClass: "category-card--cleaning",
      label: "Cleaning",
      desc: "Deep cleaning, maid services and sanitising",
      icon: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"></path><path d="M20 3v4"></path><path d="M22 5h-4"></path><path d="M4 17v2"></path><path d="M5 18H3"></path></svg>',
    },
    {
      key: "painting",
      cssClass: "category-card--painting",
      label: "Painting",
      desc: "Interior and exterior painting and finishing",
      icon: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9.06 11.9 8.07-8.06a2.85 2.85 0 1 1 4.03 4.03l-8.06 8.08"></path><path d="M7.07 14.94c-1.66 0-3 1.35-3 3.02 0 1.33-2.5 1.52-2 2.02 1.08 1.1 2.49 2.02 4 2.02 2.2 0 4-1.8 4-4.04a3.01 3.01 0 0 0-3-3.02z"></path></svg>',
    },
    {
      key: "carpentry",
      cssClass: "category-card--carpentry",
      label: "Carpentry",
      desc: "Custom woodwork, cabinets and furniture",
      icon: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 12-8.373 8.373a1 1 0 1 1-3-3L12 9"></path><path d="m18 15 4-4"></path><path d="m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172V7l-2.26-2.26a6 6 0 0 0-4.202-1.756L9 2.96l.92.82A6.18 6.18 0 0 1 12 8.4V10l2 2h1.172a2 2 0 0 1 1.414.586L18 14"></path></svg>',
    },
  ];

  var ARROW_SVG = '<svg class="category-card__arrow" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>';

  function renderStaticServicesGrid() {
    var grid = document.getElementById("home-services-grid");
    if (!grid || grid.querySelector(".category-card")) return false;

    grid.innerHTML = "";

    HOME_CATEGORIES.forEach(function (cat, index) {
      var card = document.createElement("a");
      card.href = "./services-marketplace.html?category=" + encodeURIComponent(cat.key);
      card.className = "category-card " + cat.cssClass;
      card.setAttribute("data-reveal", "");
      card.setAttribute("data-reveal-delay", String(index * 80));
      card.innerHTML =
        '<div class="category-card__icon">' + cat.icon + "</div>" +
        '<h3 class="category-card__title">' + cat.label + "</h3>" +
        '<p class="category-card__count">' + cat.desc + "</p>" +
        ARROW_SVG;
      grid.appendChild(card);
    });

    return true;
  }

  function initSplashLoaderFallback() {
    var splash = document.querySelector("[data-splash-loader]");
    if (!splash || !document.body.classList.contains("is-loading")) return;

    var navEntry = null;
    try {
      navEntry = performance.getEntriesByType("navigation")[0] || null;
    } catch (error) {
      navEntry = null;
    }

    var isReload = !!(navEntry && navEntry.type === "reload");
    var isFirstVisit = false;
    try {
      isFirstVisit = !sessionStorage.getItem("splash_seen");
      sessionStorage.setItem("splash_seen", "true");
    } catch (error) {
      isFirstVisit = true;
    }

    if (!isReload && !isFirstVisit) {
      splash.style.display = "none";
      document.body.classList.remove("is-loading");
      return;
    }

    var prefersReducedMotion = !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
    var letters = splash.querySelectorAll(".splash-loader__letter");
    var barFill = splash.querySelector(".splash-loader__bar-fill");

    if (prefersReducedMotion) {
      Array.prototype.forEach.call(letters, function (letter) {
        letter.classList.add("is-visible");
      });
      if (barFill) barFill.style.width = "100%";
      splash.classList.add("is-exiting");
      setTimeout(function () {
        splash.classList.add("is-done");
        document.body.classList.remove("is-loading");
      }, 400);
      return;
    }

    Array.prototype.forEach.call(letters, function (letter, index) {
      setTimeout(function () {
        letter.classList.add("is-visible");
        if (barFill) {
          barFill.style.width = (((index + 1) / letters.length) * 100).toFixed(2) + "%";
        }
      }, index * 300);
    });

    setTimeout(function () {
      var brand = document.querySelector(".brand__name") || document.querySelector(".brand");
      var word = splash.querySelector(".splash-loader__word");

      if (brand && word) {
        var brandRect = brand.getBoundingClientRect();
        var wordRect = word.getBoundingClientRect();
        var scale = brandRect.height / Math.max(wordRect.height, 1);
        var targetX = brandRect.left - wordRect.left;
        var targetY = brandRect.top + brandRect.height / 2 - (wordRect.top + wordRect.height / 2);

        splash.style.setProperty("--splash-target-x", targetX + "px");
        splash.style.setProperty("--splash-target-y", targetY + "px");
        splash.style.setProperty("--splash-scale", String(scale));
      }

      splash.classList.add("is-exiting");

      setTimeout(function () {
        splash.classList.add("is-done");
        document.body.classList.remove("is-loading");
      }, 1600);
    }, letters.length * 300 + 600);
  }

  function revealAllNow() {
    document.querySelectorAll("[data-reveal]").forEach(function (el) {
      el.classList.add("is-visible");
    });
  }

  function initScrollRevealFallback() {
    if (!("IntersectionObserver" in window)) {
      revealAllNow();
      return;
    }

    var elements = document.querySelectorAll("[data-reveal]");
    if (!elements.length) return;

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.15 }
    );

    elements.forEach(function (el) {
      var delay = el.getAttribute("data-reveal-delay");
      if (delay) el.style.transitionDelay = parseInt(delay, 10) + "ms";
      observer.observe(el);
    });
  }

  function initScrollEffectsFallback() {
    var progressBar = document.querySelector("[data-scroll-progress]");
    var header = document.querySelector("[data-site-header]");
    if (!progressBar && !header) return;

    var ticking = false;

    function update() {
      ticking = false;

      if (progressBar) {
        var doc = document.documentElement;
        var maxScroll = Math.max(1, doc.scrollHeight - doc.clientHeight);
        var progress = Math.max(0, Math.min(1, doc.scrollTop / maxScroll));
        progressBar.style.width = (progress * 100).toFixed(2) + "%";
        progressBar.style.opacity = progress > 0.02 ? "0.95" : "0";
      }

      if (header) {
        header.classList.toggle("is-elevated", window.scrollY > 8);
      }
    }

    function onScroll() {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(update);
    }

    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll, { passive: true });
    onScroll();
  }

  function bootFallback() {
    var renderedCards = renderStaticServicesGrid();
    var needsModuleFallback = typeof window.initScrollReveal !== "function";

    if (renderedCards && typeof window.initScrollReveal === "function") {
      window.initScrollReveal();
    }

    if (!needsModuleFallback) return;

    initSplashLoaderFallback();
    initScrollRevealFallback();
    initScrollEffectsFallback();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bootFallback, { once: true });
  } else {
    bootFallback();
  }
})();
