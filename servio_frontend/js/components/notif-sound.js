/* ═══════════════════════════════════════════════════════════
   notif-sound.js — Role-based notification chimes
   Web Audio API. No files. Honors mute preference + autoplay.
   ═══════════════════════════════════════════════════════════ */

let ctx = null;
let unlocked = false;
let unlockBound = false;
let visibilityBound = false;

function getCtx() {
  if (ctx) return ctx;
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return null;
    ctx = new Ctx();
    bindVisibility();
    return ctx;
  } catch { return null; }
}

function bindVisibility() {
  if (visibilityBound) return;
  visibilityBound = true;
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && ctx && ctx.state === 'suspended') {
      ctx.resume().catch(() => {});
    }
  });
}

function bindUnlock() {
  if (unlockBound) return;
  unlockBound = true;
  const unlock = () => {
    const c = getCtx();
    if (c && c.state === 'suspended') c.resume().catch(() => {});
    unlocked = true;
    window.removeEventListener('pointerdown', unlock);
    window.removeEventListener('keydown', unlock);
    window.removeEventListener('touchstart', unlock);
  };
  window.addEventListener('pointerdown', unlock, { once: true, passive: true });
  window.addEventListener('keydown', unlock, { once: true });
  window.addEventListener('touchstart', unlock, { once: true, passive: true });
}

function getSessionRole() {
  try {
    const s = JSON.parse(sessionStorage.getItem('servio_session') || localStorage.getItem('servio_session') || 'null');
    return s?.role || 'customer';
  } catch { return 'customer'; }
}

function isMuted() {
  const role = getSessionRole();
  try {
    if (role === 'technician') {
      const prefs = JSON.parse(localStorage.getItem('servio_tech_notif_prefs') || '{}');
      if (prefs.sound === false) return true;
    } else {
      const prefs = JSON.parse(localStorage.getItem('servio_notif_prefs') || '{}');
      if (prefs.sound === false) return true;
    }
  } catch {}
  return false;
}

/**
 * Play a tone. Optional partials array for harmonics (bell-like).
 * partials: [{ ratio, gain }] — each adds an oscillator at freq*ratio with gain*partial.gain
 */
function playTone(c, baseDelay, freq, startOffset, duration, gainPeak = 0.35, type = 'triangle', partials = []) {
  const t0 = c.currentTime + baseDelay + startOffset;

  const makeOsc = (frequency, peak, oscType) => {
    const osc = c.createOscillator();
    const gain = c.createGain();
    osc.type = oscType;
    osc.frequency.setValueAtTime(frequency, t0);
    gain.gain.setValueAtTime(0.0001, t0);
    gain.gain.exponentialRampToValueAtTime(peak, t0 + 0.018);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + duration);
    osc.connect(gain);
    gain.connect(c.destination);
    osc.start(t0);
    osc.stop(t0 + duration + 0.05);
  };

  makeOsc(freq, gainPeak, type);
  partials.forEach((p) => makeOsc(freq * p.ratio, gainPeak * p.gain, p.type || 'sine'));
}

function schedule(c, role) {
  // Lookahead: schedule slightly in the future so a still-resuming context catches up
  const lookahead = 0.05;

  if (role === 'technician' || role === 'admin') {
    // Warm two-note bell — workshop chime
    // Fundamental + octave partial for richness, sine for soft body
    const partials = [
      { ratio: 2.0,  gain: 0.30, type: 'sine' },
      { ratio: 3.0,  gain: 0.10, type: 'sine' },
    ];
    playTone(c, lookahead, 587.33, 0.00, 0.55, 0.34, 'sine', partials); // D5
    playTone(c, lookahead, 440.00, 0.22, 0.70, 0.30, 'sine', partials); // A4
  } else {
    // Bright crystal chime — customer
    const partials = [
      { ratio: 2.0,  gain: 0.22, type: 'sine' },
    ];
    playTone(c, lookahead, 880.00, 0.00, 0.32, 0.30, 'triangle', partials);  // A5
    playTone(c, lookahead, 1318.5, 0.13, 0.42, 0.28, 'triangle', partials);  // E6
  }
}

export function playNotifSound(roleOverride) {
  bindUnlock();
  if (isMuted()) return;
  const c = getCtx();
  if (!c) {
    console.warn('[notif-sound] No AudioContext support');
    return;
  }

  const role = roleOverride || getSessionRole();

  const playNow = () => {
    try { schedule(c, role); }
    catch (err) { console.warn('[notif-sound] schedule failed:', err); }
  };

  if (c.state === 'running') {
    playNow();
    return;
  }

  // Suspended — try resume + then play. Retry once if still not running.
  c.resume().then(() => {
    if (c.state === 'running') {
      playNow();
    } else {
      setTimeout(() => {
        if (c.state === 'running') playNow();
        else console.warn('[notif-sound] still suspended after resume. User gesture needed.');
      }, 120);
    }
  }).catch((err) => {
    console.warn('[notif-sound] resume failed:', err);
  });
}

export function primeNotifSound() {
  bindUnlock();
  bindVisibility();
  getCtx();
}
