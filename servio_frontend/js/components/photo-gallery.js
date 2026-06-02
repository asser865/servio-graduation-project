/**
 * Photo gallery component — thumbnails with lightbox modal.
 * Used in admin Detail Drawer, dispute viewer, and customer evidence display.
 */

function isSafeImageScheme(url) {
  try {
    const u = new URL(url, window.location.href);
    return u.protocol === 'https:' || u.protocol === 'http:';
  } catch {
    return false;
  }
}

export function renderPhotoGallery(images, { emptyLabel = 'No photos uploaded.' } = {}) {
  if (!Array.isArray(images) || images.length === 0) {
    return `<p class="photo-gallery__empty">${emptyLabel}</p>`;
  }
  const safeImages = images.filter(isSafeImageScheme);
  if (safeImages.length === 0) return `<p class="photo-gallery__empty">${emptyLabel}</p>`;
  const thumbs = safeImages.map((url, i) => `
    <button class="photo-gallery__thumb" data-photo-index="${i}" data-photo-url="${encodeURI(url)}" type="button" aria-label="View photo ${i + 1}">
      <img src="${encodeURI(url)}" alt="Evidence ${i + 1}" loading="lazy" />
    </button>
  `).join('');
  return `<div class="photo-gallery">${thumbs}</div>`;
}

export function bindPhotoGallery(rootEl) {
  rootEl.querySelectorAll('.photo-gallery__thumb').forEach(btn => {
    btn.addEventListener('click', () => openLightbox(btn.dataset.photoUrl));
  });
}

function openLightbox(url) {
  if (!isSafeImageScheme(url)) {
    console.warn('photo-gallery: rejected unsafe image URL', url);
    return;
  }
  const overlay = document.createElement('div');
  overlay.className = 'photo-gallery__lightbox';
  overlay.innerHTML = `
    <button class="photo-gallery__close" aria-label="Close">×</button>
    <img src="${url}" alt="Full size" />
  `;
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay || e.target.classList.contains('photo-gallery__close')) {
      overlay.remove();
      document.body.classList.remove('lightbox-open');
    }
  });
  document.body.appendChild(overlay);
  document.body.classList.add('lightbox-open');
}
