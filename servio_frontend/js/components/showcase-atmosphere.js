/**
 * showcase-atmosphere.js
 * Shared canvas flow-particle atmosphere animation used on auth pages (login + signup).
 */

export function initShowcaseAtmosphere() {
  const showcase = document.querySelector('.auth-showcase');
  if (!showcase) return;

  // Extra blobs
  ['c', 'd'].forEach(id => {
    const blob = document.createElement('div');
    blob.className = `auth-blob-${id}`;
    blob.setAttribute('aria-hidden', 'true');
    showcase.appendChild(blob);
  });

  // Floating ember particles
  const emberDefs = [
    { x: '10%', dur: '9s',    delay: '0s',    drift: '16px'  },
    { x: '23%', dur: '13s',   delay: '1.6s',  drift: '-22px' },
    { x: '36%', dur: '10s',   delay: '3.2s',  drift: '26px'  },
    { x: '50%', dur: '15s',   delay: '0.8s',  drift: '-12px' },
    { x: '63%', dur: '11s',   delay: '4.8s',  drift: '20px'  },
    { x: '75%', dur: '8.5s',  delay: '2.2s',  drift: '-28px' },
    { x: '87%', dur: '14s',   delay: '5.4s',  drift: '14px'  },
    { x: '18%', dur: '12s',   delay: '6.5s',  drift: '-18px' },
    { x: '44%', dur: '9.5s',  delay: '7.2s',  drift: '24px'  },
    { x: '70%', dur: '11.5s', delay: '3.8s',  drift: '-15px' },
  ];
  emberDefs.forEach(({ x, dur, delay, drift }) => {
    const p = document.createElement('div');
    p.className = 'auth-particle';
    p.setAttribute('aria-hidden', 'true');
    p.style.setProperty('--x', x);
    p.style.setProperty('--dur', dur);
    p.style.setProperty('--delay', delay);
    p.style.setProperty('--drift', drift);
    showcase.appendChild(p);
  });

  // ── Canvas flow field ───────────────────────────────────
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  const canvas = showcase.querySelector('.auth-showcase__canvas');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  const N = 320;
  const COLS = 32, ROWS = 20;
  let W, H, t = 0, mouse = { x: -999, y: -999 };

  function fieldNoise(x, y, t) {
    return Math.sin(x * 0.8 + t * 0.6) * Math.cos(y * 0.9 - t * 0.4)
         + 0.5  * Math.sin(x * 1.5 - y * 1.1 + t * 0.9)
         + 0.25 * Math.cos(x * 2.3 + y * 1.8 + t * 0.5);
  }

  class FlowParticle {
    constructor() { this.reset(); }
    reset() {
      this.x     = Math.random() * W;
      this.y     = Math.random() * H;
      this.vx    = 0;
      this.vy    = 0;
      this.life  = Math.random() * 180 + 60;
      this.age   = 0;
      this.speed = Math.random() * 0.55 + 0.22;
      this.r     = Math.random() * 1.2 + 0.4;
      const f    = Math.random();
      this.col   = [210 + (185 - 210) * f | 0, 162 + (140 - 162) * f | 0, 80 + (55 - 80) * f | 0];
    }
    update() {
      const col   = Math.floor(this.x / W * COLS);
      const row   = Math.floor(this.y / H * ROWS);
      const angle = fieldNoise(col * 0.18, row * 0.18, t) * Math.PI * 2.2;
      const mdx   = this.x - mouse.x;
      const mdy   = this.y - mouse.y;
      const md    = Math.sqrt(mdx * mdx + mdy * mdy);
      const mf    = md < 100 ? (100 - md) / 100 * 2 : 0;
      this.vx    += Math.cos(angle) * 0.03 * this.speed + mdx / (md + 1) * mf * 0.2;
      this.vy    += Math.sin(angle) * 0.03 * this.speed + mdy / (md + 1) * mf * 0.2;
      this.vx    *= 0.92;
      this.vy    *= 0.92;
      this.x     += this.vx;
      this.y     += this.vy;
      this.age++;
      if (this.x < 0 || this.x > W || this.y < 0 || this.y > H || this.age > this.life) this.reset();
    }
    draw() {
      const alpha = Math.min(1, this.age / 20) * Math.min(1, (this.life - this.age) / 20) * 0.65;
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.r, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${this.col}, ${alpha})`;
      ctx.fill();
    }
  }

  let particles = [];

  function resize() {
    const rect = showcase.getBoundingClientRect();
    W = canvas.width  = rect.width;
    H = canvas.height = rect.height;
    particles = Array.from({ length: N }, () => new FlowParticle());
  }

  function loop() {
    ctx.fillStyle = 'rgba(16,8,6,0.18)';
    ctx.fillRect(0, 0, W, H);
    t += 0.0018;
    particles.forEach(p => { p.update(); p.draw(); });
    requestAnimationFrame(loop);
  }

  showcase.addEventListener('mousemove', e => {
    const r = canvas.getBoundingClientRect();
    mouse = { x: e.clientX - r.left, y: e.clientY - r.top };
  });
  showcase.addEventListener('mouseleave', () => { mouse = { x: -999, y: -999 }; });

  window.addEventListener('resize', resize);
  resize();
  loop();
}
