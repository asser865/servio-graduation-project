import { addFavorite, removeFavorite } from '../api/favorites.js';
import { showToast } from './toast.js';

const ICONS = {
  empty:  '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>',
  filled: '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>',
};

export function createHeartToggle({ workerId, isFavorited, onChange }) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'heart-toggle' + (isFavorited ? ' heart-toggle--on' : '');
  btn.setAttribute('aria-pressed', String(!!isFavorited));
  btn.setAttribute('aria-label', isFavorited ? 'Remove from favourites' : 'Add to favourites');
  btn.innerHTML = isFavorited ? ICONS.filled : ICONS.empty;
  btn.dataset.workerId = workerId;

  let busy = false;
  let state = !!isFavorited;

  btn.addEventListener('click', async (e) => {
    e.stopPropagation();
    e.preventDefault();
    if (busy) return;
    busy = true;

    const previous = state;
    state = !state;
    paint();

    try {
      if (state) await addFavorite(workerId);
      else        await removeFavorite(workerId);
      onChange?.(state);
    } catch (err) {
      state = previous;
      paint();
      showToast(err?.message || 'Could not update favourites', 'error');
    } finally {
      busy = false;
    }
  });

  function paint() {
    btn.classList.toggle('heart-toggle--on', state);
    btn.setAttribute('aria-pressed', String(state));
    btn.setAttribute('aria-label', state ? 'Remove from favourites' : 'Add to favourites');
    btn.innerHTML = state ? ICONS.filled : ICONS.empty;
  }

  return btn;
}
