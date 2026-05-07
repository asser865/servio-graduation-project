const STORAGE_KEY = "servio-theme";

function getPreferredTheme() {
  const storedTheme = localStorage.getItem(STORAGE_KEY);
  if (storedTheme === "dark" || storedTheme === "light") {
    return storedTheme;
  }

  return window.matchMedia("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
}

function syncThemeButtons(theme) {
  const nextTheme = theme === "dark" ? "light" : "dark";
  const ariaLabel =
    theme === "dark" ? "Switch to light mode" : "Switch to dark mode";

  document.querySelectorAll("[data-theme-button]").forEach((button) => {
    button.dataset.themeState = theme;
    button.dataset.themeTarget = nextTheme;
    button.setAttribute("aria-label", ariaLabel);
    button.setAttribute("title", ariaLabel);
  });
}

function applyTheme(theme, persist = true) {
  document.documentElement.setAttribute("data-theme", theme);
  syncThemeButtons(theme);

  if (persist) {
    localStorage.setItem(STORAGE_KEY, theme);
  }
}

export function initThemeToggle() {
  // theme-init.js already applied the correct data-theme before first paint.
  // We only need to sync button state — NOT re-apply the theme (which would
  // cause a second setAttribute and a style recalculation flash).
  const initialTheme = document.documentElement.getAttribute('data-theme') || getPreferredTheme();
  syncThemeButtons(initialTheme);

  document.querySelectorAll("[data-theme-button]").forEach((button) => {
    button.addEventListener("click", () => {
      const currentTheme =
        document.documentElement.getAttribute("data-theme") === "dark"
          ? "dark"
          : "light";
      applyTheme(currentTheme === "dark" ? "light" : "dark");
    });
  });

  window
    .matchMedia("(prefers-color-scheme: dark)")
    .addEventListener("change", (event) => {
      if (localStorage.getItem(STORAGE_KEY)) {
        return;
      }

      applyTheme(event.matches ? "dark" : "light", false);
    });
}

// .
