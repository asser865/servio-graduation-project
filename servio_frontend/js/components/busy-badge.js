export function renderBusyBadge(busyState) {
  if (!busyState || !busyState.isBusy) return null;
  const el = document.createElement('span');
  el.className = 'busy-badge ' + (busyState.label === 'finishing_up' ? 'busy-badge--finishing' : 'busy-badge--busy');
  if (busyState.label === 'finishing_up') {
    el.innerHTML = `<span class="busy-badge__dot"></span> Finishing up`;
  } else {
    const extended = busyState.extensionCount > 0 ? ' (extended)' : '';
    el.innerHTML = `<span class="busy-badge__dot"></span> Busy — ~${busyState.remainingMin} min left${extended}`;
  }
  return el;
}
