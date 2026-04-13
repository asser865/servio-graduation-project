function closeOnEscape(headerEl) {
  const onKeyDown = (e) => {
    if (e.key !== "Escape") return;
    headerEl.classList.remove("is-open");
    const btn = headerEl.querySelector("[data-nav-toggle]");
    if (btn) btn.setAttribute("aria-expanded", "false");
  };

  document.addEventListener("keydown", onKeyDown);
}

function closeOnResize(headerEl) {
  const onResize = () => {
    if (window.matchMedia("(min-width: 821px)").matches) {
      headerEl.classList.remove("is-open");
      const btn = headerEl.querySelector("[data-nav-toggle]");
      if (btn) btn.setAttribute("aria-expanded", "false");
    }
  };

  window.addEventListener("resize", onResize, { passive: true });
}

export function initNavbar() {
  const headerEl = document.querySelector("[data-site-header]");
  if (!headerEl) return;

  const toggleBtn = headerEl.querySelector("[data-nav-toggle]");
  if (toggleBtn) {
    toggleBtn.addEventListener("click", () => {
      const isOpen = headerEl.classList.toggle("is-open");
      toggleBtn.setAttribute("aria-expanded", isOpen ? "true" : "false");
    });
  }

  const lang = headerEl.querySelector("[data-lang]");
  const langButton = lang?.querySelector(".lang-switch");
  if (lang && langButton) {
    langButton.addEventListener("click", () => {
      const open = lang.classList.toggle("is-open");
      langButton.setAttribute("aria-expanded", open ? "true" : "false");
    });
  }

  const navLinks = headerEl.querySelectorAll(".primary-nav__list .nav-link");
  const brandLink = headerEl.querySelector(".brand");

  // Function to set active link based on current path
  const setActiveLink = () => {
    const currentPath = window.location.pathname.toLowerCase();
    
    navLinks.forEach((link) => {
      const href = link.getAttribute("href")?.toLowerCase();
      if (!href) return;

      // Handle homepage specially (root path or index.html)
      const isHomePath = currentPath === "/" || currentPath.endsWith("/index.html") || currentPath.endsWith("/graduation%20project/") || currentPath.endsWith("/html/");
      const isHomeHref = href.includes("index.html") || href === "./" || href === "/";

      if (isHomePath && isHomeHref) {
        link.classList.add("nav-link--active");
      } else if (!isHomeHref && href && currentPath.includes(href.replace("./", ""))) {
        link.classList.add("nav-link--active");
      } else {
        link.classList.remove("nav-link--active");
      }
    });
  };

  // Run on init
  setActiveLink();

  const handleHomeLink = (e) => {
    const link = e.currentTarget;
    const href = link.getAttribute("href");
    
    // Check if the link goes to home AND we're currently on the home page
    if (href === "./index.html" || href === "index.html" || href === "/") {
      const path = window.location.pathname;
      if (path.endsWith("index.html") || path.endsWith("/")) {
        e.preventDefault();
        window.scrollTo({ top: 0, behavior: "smooth" });
      }
    }
  };

  if (brandLink) {
    brandLink.addEventListener("click", handleHomeLink);
  }

  if (navLinks.length) {
    navLinks.forEach((link) => {
      link.addEventListener("click", (e) => {
        // UI active state
        navLinks.forEach((l) => l.classList.remove("nav-link--active"));
        link.classList.add("nav-link--active");

        // Custom smooth scroll logic for Home
        handleHomeLink(e);
      });
    });
  }

  closeOnEscape(headerEl);
  closeOnResize(headerEl);
}


// .
