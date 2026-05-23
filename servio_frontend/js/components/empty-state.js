const escapeHtml = (str) => String(str ?? '')
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;');

export function emptyState({ icon = '📭', title, body, action } = {}) {
  const safeIcon  = escapeHtml(icon);
  const safeTitle = escapeHtml(title || '');
  const safeBody  = escapeHtml(body || '');
  const actionHtml = action
    ? `<button class="btn-primary" id="empty-action-btn" data-action="${escapeHtml(action.id || '')}">${escapeHtml(action.label || '')}</button>`
    : '';
  return `
    <div class="empty-state">
      <div class="empty-state__icon">${safeIcon}</div>
      <h3 class="empty-state__title">${safeTitle}</h3>
      <p class="empty-state__body">${safeBody}</p>
      ${actionHtml}
    </div>`;
}

export function renderEmptyInto(container, opts) {
  if (!container) return;
  container.innerHTML = emptyState(opts);
}
