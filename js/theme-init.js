(function () {
  var storedTheme = localStorage.getItem("servio-theme");
  var theme =
    storedTheme === "dark" || storedTheme === "light"
      ? storedTheme
      : matchMedia("(prefers-color-scheme: dark)").matches
        ? "dark"
        : "light";

  document.documentElement.setAttribute("data-theme", theme);
})();

// .
