/* ═══════════════════════════════════════════════════════════════
   lang-init.js  — Zero-flicker language initialiser
   Must be loaded as a SYNCHRONOUS <script> in <head>, BEFORE
   any CSS or content renders. Reads localStorage and sets
   dir/lang/class on <html> immediately so there is no flash
   of the wrong direction or font.
═══════════════════════════════════════════════════════════════ */
(function () {
  var lang = 'en';
  try { lang = localStorage.getItem('servio_lang') || 'en'; } catch (e) {}

  var html = document.documentElement;
  html.setAttribute('data-lang', lang);

  /* 
     If the language is NOT English, we must hide the body immediately 
     to prevent a Flash of Unlocalized Content (FOUT). lang.js will
     make it visible again once translation is done.
  */
  if (lang !== 'en') {
    html.classList.add('is-translating');
    var hideStyle = document.createElement('style');
    hideStyle.id = 'fout-prevention';
    hideStyle.textContent = 'body { opacity: 0 !important; visibility: hidden !important; pointer-events: none !important; }';
    document.head.appendChild(hideStyle);
  }

  if (lang === 'ar') {
    html.setAttribute('dir', 'rtl');
    html.setAttribute('lang', 'ar');
    html.classList.add('lang-ar');
    /* body may not exist yet — add class via a tiny inline style block */
    var s = document.createElement('style');
    s.id = 'lang-init-rtl';
    s.textContent = 'body{direction:rtl;text-align:right;font-family:"Cairo","Tajawal","Arial",sans-serif;}';
    document.head.appendChild(s);
  } else {
    html.setAttribute('dir', 'ltr');
    html.setAttribute('lang', 'en');
  }
})();

// .
