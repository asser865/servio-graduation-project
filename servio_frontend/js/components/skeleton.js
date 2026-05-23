/* ============================================================
   SERVIO global skeleton renderer helpers
   Pair with css/components/skeleton.css
   ============================================================ */

const N = (n) => Math.max(1, Number(n) || 1);

/** Card with avatar + 3 lines. */
export function skCard() {
  return `
    <div class="sk-card">
      <div class="sk-card__row">
        <div class="sk sk-circle"></div>
        <div class="sk-card__lines">
          <div class="sk sk-line sk-w-60"></div>
          <div class="sk sk-line sk-line--sm sk-w-40"></div>
        </div>
      </div>
      <div class="sk sk-line sk-w-90"></div>
      <div class="sk sk-line sk-w-75"></div>
      <div class="sk sk-line sk-line--sm sk-w-50"></div>
    </div>`;
}

/** Grid of card skeletons. */
export function skCardGrid(count = 3, opts = {}) {
  const wide = opts.wide ? ' sk-grid--wide' : '';
  return `<div class="sk-grid${wide}">${Array.from({ length: N(count) }, skCard).join('')}</div>`;
}

/** Compact list item: thumb + 2 lines. */
export function skListItem() {
  return `
    <div class="sk-list-item">
      <div class="sk sk-thumb"></div>
      <div class="sk-card__lines">
        <div class="sk sk-line sk-w-60"></div>
        <div class="sk sk-line sk-line--sm sk-w-40"></div>
      </div>
      <div class="sk sk-pill" style="width:80px;"></div>
    </div>`;
}

/** Vertical stack of list-item skeletons. */
export function skList(count = 4) {
  return `<div class="sk-list">${Array.from({ length: N(count) }, skListItem).join('')}</div>`;
}

/** Single stat card skeleton (label + big number). */
export function skStat() {
  return `
    <div class="sk-stat">
      <div class="sk sk-line sk-line--sm sk-w-40"></div>
      <div class="sk sk-line sk-line--xl sk-w-60"></div>
    </div>`;
}

/** Grid of stat skeletons. */
export function skStatGrid(count = 4) {
  return `<div class="sk-grid">${Array.from({ length: N(count) }, skStat).join('')}</div>`;
}

/** Table-body rows. Pass column count. */
export function skTableRows(rows = 5, cols = 6) {
  const r = N(rows);
  const c = N(cols);
  let html = '';
  for (let i = 0; i < r; i++) {
    let tds = '';
    for (let j = 0; j < c; j++) {
      const w = [60, 90, 50, 75, 40][j % 5];
      tds += `<td><div class="sk sk-line sk-w-${w}"></div></td>`;
    }
    html += `<tr class="sk-trow">${tds}</tr>`;
  }
  return html;
}

/** Inline text-line skeleton. */
export function skLine(widthClass = 'sk-w-60') {
  return `<div class="sk sk-line ${widthClass}"></div>`;
}

/** Quick utility: replace a container's HTML with a skeleton variant. */
export function skMount(el, variant = 'cards', opts = {}) {
  if (!el) return;
  const node = (typeof el === 'string') ? document.getElementById(el) || document.querySelector(el) : el;
  if (!node) return;
  let html = '';
  switch (variant) {
    case 'cards':  html = skCardGrid(opts.count ?? 3, opts); break;
    case 'list':   html = skList(opts.count ?? 4); break;
    case 'stats':  html = skStatGrid(opts.count ?? 4); break;
    case 'rows':   html = skTableRows(opts.rows ?? 5, opts.cols ?? 6); break;
    case 'line':   html = skLine(opts.width || 'sk-w-60'); break;
    default:       html = skCardGrid(3);
  }
  node.innerHTML = html;
}
