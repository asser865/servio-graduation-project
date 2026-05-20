// Scroll performance harness for smart-match page.
// Uses playwright-core w/ system Chrome. Measures frame budget during programmatic scroll.

import { chromium } from 'playwright-core';

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const URL = 'http://localhost:8765/html/smart-match.html';

const browser = await chromium.launch({
  executablePath: CHROME,
  headless: true,
  args: ['--enable-precise-memory-info', '--disable-features=CalculateNativeWinOcclusion'],
});

const ctx = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  deviceScaleFactor: 1,
});
const page = await ctx.newPage();

const consoleErrors = [];
page.on('pageerror', (e) => consoleErrors.push('pageerror: ' + e.message));
page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push('console: ' + m.text()); });

console.log('navigating...');
await page.goto(URL, { waitUntil: 'networkidle', timeout: 30000 });

// Settle: let aurora/canvas warm up
await page.waitForTimeout(1500);

// Install frame-timing collector + long-task observer
await page.evaluate(() => {
  window.__perf = {
    frames: [],
    longTasks: [],
    layoutShifts: 0,
    startTime: 0,
  };

  let lastFrame = performance.now();
  let rafId;
  function frameTick(now) {
    window.__perf.frames.push(now - lastFrame);
    lastFrame = now;
    rafId = requestAnimationFrame(frameTick);
  }

  window.__startPerf = () => {
    window.__perf.frames = [];
    window.__perf.longTasks = [];
    window.__perf.layoutShifts = 0;
    window.__perf.startTime = performance.now();
    lastFrame = performance.now();
    rafId = requestAnimationFrame(frameTick);
  };

  window.__stopPerf = () => {
    cancelAnimationFrame(rafId);
    return {
      ...window.__perf,
      duration: performance.now() - window.__perf.startTime,
    };
  };

  try {
    const lt = new PerformanceObserver((list) => {
      for (const e of list.getEntries()) {
        window.__perf.longTasks.push({ dur: e.duration, start: e.startTime });
      }
    });
    lt.observe({ type: 'longtask', buffered: true });
  } catch (e) {}

  try {
    const ls = new PerformanceObserver((list) => {
      for (const e of list.getEntries()) {
        if (!e.hadRecentInput) window.__perf.layoutShifts += e.value;
      }
    });
    ls.observe({ type: 'layout-shift', buffered: true });
  } catch (e) {}
});

// === PHASE 1: idle baseline (3s, no scroll) ===
console.log('PHASE 1: idle baseline 3s');
await page.evaluate(() => window.__startPerf());
await page.waitForTimeout(3000);
const idle = await page.evaluate(() => window.__stopPerf());
report('IDLE', idle);

// === PHASE 2: programmatic smooth scroll down ===
console.log('PHASE 2: smooth scroll down 4s');
await page.evaluate(() => window.__startPerf());
await page.evaluate(async () => {
  const totalHeight = document.documentElement.scrollHeight - window.innerHeight;
  const duration = 3800;
  const start = performance.now();
  await new Promise((resolve) => {
    function step(now) {
      const t = Math.min(1, (now - start) / duration);
      window.scrollTo(0, totalHeight * t);
      if (t < 1) requestAnimationFrame(step);
      else resolve();
    }
    requestAnimationFrame(step);
  });
});
const scrollDown = await page.evaluate(() => window.__stopPerf());
report('SCROLL DOWN', scrollDown);

// === PHASE 3: fast wheel-style scroll bursts ===
console.log('PHASE 3: wheel burst scroll 3s');
await page.evaluate(() => window.scrollTo(0, 0));
await page.waitForTimeout(400);
await page.evaluate(() => window.__startPerf());
await page.evaluate(async () => {
  const start = performance.now();
  let y = 0;
  await new Promise((resolve) => {
    const id = setInterval(() => {
      y = (y + 220) % (document.documentElement.scrollHeight - window.innerHeight);
      window.scrollTo({ top: y, behavior: 'instant' });
      if (performance.now() - start > 2800) { clearInterval(id); resolve(); }
    }, 32);
  });
});
const burst = await page.evaluate(() => window.__stopPerf());
report('WHEEL BURST', burst);

// === PHASE 4: scroll w/ simulated mouse move (worst case) ===
console.log('PHASE 4: scroll + mousemove 3s');
await page.evaluate(() => window.scrollTo(0, 0));
await page.waitForTimeout(400);
await page.evaluate(() => window.__startPerf());
const moveTask = (async () => {
  for (let i = 0; i < 80; i++) {
    await page.mouse.move(200 + (i % 40) * 20, 300 + (i % 30) * 10);
    await page.waitForTimeout(35);
  }
})();
const scrollTask = page.evaluate(async () => {
  const totalHeight = document.documentElement.scrollHeight - window.innerHeight;
  const start = performance.now();
  await new Promise((resolve) => {
    function step(now) {
      const t = Math.min(1, (now - start) / 2800);
      window.scrollTo(0, totalHeight * t);
      if (t < 1) requestAnimationFrame(step);
      else resolve();
    }
    requestAnimationFrame(step);
  });
});
await Promise.all([moveTask, scrollTask]);
const combo = await page.evaluate(() => window.__stopPerf());
report('SCROLL+MOUSE', combo);

console.log('\n=== ERRORS ===');
console.log(consoleErrors.length ? consoleErrors.join('\n') : '(none)');

await browser.close();

function report(label, p) {
  const frames = p.frames.filter((f) => f > 0 && f < 1000);
  frames.sort((a, b) => a - b);
  const n = frames.length;
  const sum = frames.reduce((a, b) => a + b, 0);
  const avg = sum / n;
  const p50 = frames[Math.floor(n * 0.5)];
  const p95 = frames[Math.floor(n * 0.95)];
  const p99 = frames[Math.floor(n * 0.99)];
  const max = frames[n - 1];
  const dropped60 = frames.filter((f) => f > 16.7).length;
  const dropped30 = frames.filter((f) => f > 33.4).length;
  const longTaskCount = p.longTasks.length;
  const longTaskTotal = p.longTasks.reduce((a, t) => a + t.dur, 0);
  console.log(`\n--- ${label} (${p.duration.toFixed(0)}ms, ${n} frames) ---`);
  console.log(`  avg ${avg.toFixed(2)}ms  p50 ${p50?.toFixed(2)}ms  p95 ${p95?.toFixed(2)}ms  p99 ${p99?.toFixed(2)}ms  max ${max?.toFixed(2)}ms`);
  console.log(`  est FPS: ${(1000 / avg).toFixed(1)}`);
  console.log(`  dropped >16.7ms: ${dropped60} (${(dropped60/n*100).toFixed(1)}%)  >33.4ms: ${dropped30} (${(dropped30/n*100).toFixed(1)}%)`);
  console.log(`  longTasks: ${longTaskCount} totaling ${longTaskTotal.toFixed(0)}ms`);
  console.log(`  CLS: ${p.layoutShifts.toFixed(4)}`);
}
