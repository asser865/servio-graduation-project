/**
 * ai-finisher.js — Hero canvas animation only.
 * Wizard logic and backend integration removed.
 * Mobile app still has full room-finishing feature; web is visual placeholder.
 */

function setupHeroCanvas() {
  const canvas = document.getElementById('hero-ai-canvas');
  if (!canvas) return;

  const reducedMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const ctx = canvas.getContext('2d', { alpha: true });

  let dpr = Math.min(window.devicePixelRatio || 1, 1.5);
  let W = 0, H = 0;
  let rafId = 0, running = false, visible = true, pageVisible = !document.hidden;

  let mouseX = -9999, mouseY = -9999;
  let prevMouseX = -9999, prevMouseY = -9999;
  let mouseSpeed = 0;
  let t = 0;

  function getColors() {
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    return isDark
      ? { orb: ['rgba(254,193,149,{a})', 'rgba(219,203,180,{a})', 'rgba(180,160,130,{a})', 'rgba(255,220,180,{a})'],
          line: 'rgba(219,203,180,{a})',  cursor: 'rgba(254,193,149,{a})' }
      : { orb: ['rgba(140,85,30,{a})', 'rgba(200,130,60,{a})', 'rgba(254,150,60,{a})', 'rgba(110,60,20,{a})'],
          line: 'rgba(140,85,30,{a})',    cursor: 'rgba(200,120,40,{a})' };
  }
  const c = (tpl, a) => tpl.replace('{a}', Math.max(0, Math.min(1, a)).toFixed(3));

  const COUNT = 75;
  const CONNECT_DIST = 130;
  const REPEL_RADIUS = 160;
  const REPEL_FORCE  = 5.5;
  const particles = [];

  class Particle {
    constructor() { this.init(true); }
    init(scatter) {
      this.ox  = Math.random() * W;
      this.oy  = scatter ? Math.random() * H : (Math.random() > 0.5 ? -12 : H + 12);
      this.x   = this.ox;
      this.y   = this.oy;
      this.vx  = (Math.random() - 0.5) * 0.5;
      this.vy  = (Math.random() - 0.5) * 0.5;
      this.r   = 1.4 + Math.random() * 2.8;
      this.phase = Math.random() * Math.PI * 2;
      this.phaseSpeed = 0.007 + Math.random() * 0.013;
      this.ci  = Math.floor(Math.random() * 4);
      this.baseA = 0.35 + Math.random() * 0.45;
    }
    update() {
      const hasMouse = mouseX > -999;

      if (hasMouse) {
        const dx = this.x - mouseX;
        const dy = this.y - mouseY;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < REPEL_RADIUS && dist > 0.5) {
          const force = REPEL_FORCE * Math.pow(1 - dist / REPEL_RADIUS, 1.6)
                      * (1 + mouseSpeed * 0.04);
          const nx = dx / dist, ny = dy / dist;
          this.vx += nx * force;
          this.vy += ny * force;
        }
      }

      this.vx += (this.ox - this.x) * 0.002;
      this.vy += (this.oy - this.y) * 0.002;

      this.ox += (Math.random() - 0.5) * 0.08;
      this.oy += (Math.random() - 0.5) * 0.08;

      this.vx *= 0.94;
      this.vy *= 0.94;

      const spd = Math.sqrt(this.vx * this.vx + this.vy * this.vy);
      if (spd > 8) { this.vx = (this.vx / spd) * 8; this.vy = (this.vy / spd) * 8; }

      this.x += this.vx;
      this.y += this.vy;
      this.phase += this.phaseSpeed;

      if (this.x < -20) { this.x = W + 20; this.ox = W + 20; }
      else if (this.x > W + 20) { this.x = -20; this.ox = -20; }
      if (this.y < -20) { this.y = H + 20; this.oy = H + 20; }
      else if (this.y > H + 20) { this.y = -20; this.oy = -20; }
    }
    draw(colors) {
      const pulse = 0.5 + 0.5 * Math.sin(this.phase);

      let proximityBoost = 0;
      if (mouseX > -999) {
        const mdx = this.x - mouseX, mdy = this.y - mouseY;
        const md = Math.sqrt(mdx * mdx + mdy * mdy);
        if (md < REPEL_RADIUS * 1.4) {
          proximityBoost = (1 - md / (REPEL_RADIUS * 1.4)) * 0.7;
        }
      }

      const alpha  = this.baseA * (0.55 + 0.45 * pulse) + proximityBoost * 0.5;
      const radius = this.r   * (0.85 + 0.15 * pulse)   * (1 + proximityBoost * 0.6);
      const tpl    = colors.orb[this.ci];

      const glow = ctx.createRadialGradient(this.x, this.y, 0, this.x, this.y, radius * 5.5);
      glow.addColorStop(0, c(tpl, alpha * 0.5));
      glow.addColorStop(1, c(tpl, 0));
      ctx.beginPath();
      ctx.arc(this.x, this.y, radius * 5.5, 0, Math.PI * 2);
      ctx.fillStyle = glow;
      ctx.fill();

      const core = ctx.createRadialGradient(this.x, this.y, 0, this.x, this.y, radius);
      core.addColorStop(0, c(tpl, Math.min(1, alpha * 1.6)));
      core.addColorStop(1, c(tpl, 0));
      ctx.beginPath();
      ctx.arc(this.x, this.y, radius, 0, Math.PI * 2);
      ctx.fillStyle = core;
      ctx.fill();
    }
  }

  function initParticles() {
    particles.length = 0;
    for (let i = 0; i < COUNT; i++) particles.push(new Particle());
  }

  function drawFrame() {
    ctx.clearRect(0, 0, W, H);
    t += 0.016;

    if (mouseX > -999) {
      const dsx = mouseX - prevMouseX, dsy = mouseY - prevMouseY;
      mouseSpeed = Math.sqrt(dsx * dsx + dsy * dsy);
      prevMouseX = mouseX; prevMouseY = mouseY;
    } else {
      mouseSpeed = 0;
    }

    const colors = getColors();
    const hasMouse = mouseX > -999;

    for (let i = 0; i < particles.length; i++) {
      const a = particles[i];
      for (let j = i + 1; j < particles.length; j++) {
        const b = particles[j];
        const dx = a.x - b.x, dy = a.y - b.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist >= CONNECT_DIST * 1.5) continue;

        let baseA = (1 - dist / (CONNECT_DIST * 1.5)) * 0.15;

        if (hasMouse) {
          const mx = (a.x + b.x) / 2 - mouseX;
          const my = (a.y + b.y) / 2 - mouseY;
          const md = Math.sqrt(mx * mx + my * my);
          if (md < REPEL_RADIUS * 1.5) {
            baseA += (1 - md / (REPEL_RADIUS * 1.5)) * 0.45;
          }
        }

        ctx.beginPath();
        ctx.moveTo(a.x, a.y);
        ctx.lineTo(b.x, b.y);
        ctx.strokeStyle = c(colors.line, baseA);
        ctx.lineWidth = dist < CONNECT_DIST ? 0.9 : 0.4;
        ctx.stroke();
      }
    }

    for (let i = 0; i < particles.length; i++) {
      particles[i].update();
      particles[i].draw(colors);
    }

    if (hasMouse) {
      const rippleR = 28 + Math.sin(t * 4) * 5;

      const cursorGlow = ctx.createRadialGradient(mouseX, mouseY, 0, mouseX, mouseY, rippleR * 2.2);
      cursorGlow.addColorStop(0, c(colors.cursor, 0.22));
      cursorGlow.addColorStop(0.4, c(colors.cursor, 0.08));
      cursorGlow.addColorStop(1, c(colors.cursor, 0));
      ctx.beginPath();
      ctx.arc(mouseX, mouseY, rippleR * 2.2, 0, Math.PI * 2);
      ctx.fillStyle = cursorGlow;
      ctx.fill();
    }

    const wY = H * 0.73;
    ctx.beginPath();
    ctx.moveTo(0, wY);
    for (let x = 0; x <= W; x += 4) {
      const w = Math.sin((x / W) * Math.PI * 3 + t * 0.55) * 16
              + Math.sin((x / W) * Math.PI * 5 - t * 0.38) * 8;
      ctx.lineTo(x, wY + w);
    }
    ctx.strokeStyle = c(colors.cursor, 0.055);
    ctx.lineWidth = 1.4;
    ctx.stroke();
  }

  const tick  = () => { if (!running) return; drawFrame(); rafId = requestAnimationFrame(tick); };
  const start = () => { if (running || !visible || !pageVisible) return; running = true; rafId = requestAnimationFrame(tick); };
  const stop  = () => { running = false; if (rafId) cancelAnimationFrame(rafId); rafId = 0; };

  function resizeCanvas() {
    const rect = canvas.parentElement.getBoundingClientRect();
    W = rect.width; H = rect.height;
    canvas.width  = Math.round(W * dpr);
    canvas.height = Math.round(H * dpr);
    canvas.style.width  = W + 'px';
    canvas.style.height = H + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    initParticles();
  }

  let resizeRaf = 0;
  const scheduleResize = () => {
    if (resizeRaf) return;
    resizeRaf = requestAnimationFrame(() => { resizeRaf = 0; resizeCanvas(); });
  };

  let cachedRect = null;
  let pendingMouse = null, mRaf = 0;
  const heroSection = canvas.parentElement;

  heroSection.addEventListener('mousemove', (e) => {
    pendingMouse = { cx: e.clientX, cy: e.clientY };
    if (mRaf) return;
    mRaf = requestAnimationFrame(() => {
      mRaf = 0;
      if (!pendingMouse) return;
      const r = cachedRect || canvas.getBoundingClientRect();
      mouseX = pendingMouse.cx - r.left;
      mouseY = pendingMouse.cy - r.top;
      pendingMouse = null;
    });
  }, { passive: true });

  heroSection.addEventListener('mouseleave', () => {
    mouseX = -9999; mouseY = -9999;
    prevMouseX = -9999; prevMouseY = -9999;
  }, { passive: true });

  window.addEventListener('scroll',  () => { cachedRect = canvas.getBoundingClientRect(); }, { passive: true });
  window.addEventListener('resize',  scheduleResize, { passive: true });
  document.addEventListener('visibilitychange', () => {
    pageVisible = !document.hidden;
    if (pageVisible) start(); else stop();
  });

  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      visible = entries[0].isIntersecting;
      if (visible) start(); else stop();
    }, { rootMargin: '0px' });
    io.observe(canvas);
  }

  resizeCanvas();
  if (reducedMotion) { drawFrame(); return; }
  start();
}

setupHeroCanvas();
