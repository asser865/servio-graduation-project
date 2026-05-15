export function initFooterAnimation() {
  const footer = document.querySelector('.site-footer');
  if (!footer) return;

  if (!document.getElementById('footer-sparks')) {
    const canvasEl = document.createElement('canvas');
    canvasEl.id = 'footer-sparks';
    Object.assign(canvasEl.style, {
      position: 'absolute',
      width: '100%',
      height: '100%',
      top: 0,
      left: 0,
      background: 'transparent',
      pointerEvents: 'none',
      zIndex: 0
    });
    footer.insertBefore(canvasEl, footer.firstChild);
  }

  const canvas = document.getElementById('footer-sparks');
  const ctx = canvas.getContext('2d');

  const OPT = {
    amount: 80,
    speed: 0.05,
    lifetime: 300,
    direction: { x: -0.2, y: -0.8 },
    size: [1.5, 1.5],
    maxopacity: 0.8,
    randColor: true,
    acceleration: [5, 40]
  };

  let sparks = [];
  let animationFrame;
  let isVisible = false;

  function setCanvasWidth() {
    if (ctx.canvas.width !== footer.offsetWidth || ctx.canvas.height !== footer.offsetHeight) {
      ctx.canvas.width = footer.offsetWidth;
      ctx.canvas.height = footer.offsetHeight;
    }
  }

  function rand(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  function Spark(x, y) {
    this.x = x;
    this.y = y;
    this.age = 0;
    this.acceleration = rand(OPT.acceleration[0], OPT.acceleration[1]);
    const colors = ['181, 153, 116', '112, 85, 51', '227, 213, 202', '255, 255, 255'];
    this.color = OPT.randColor ? colors[rand(0, colors.length - 1)] : '181, 153, 116';
    this.opacity = OPT.maxopacity - this.age / (OPT.lifetime * rand(1, 10));
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    if (!isDark && this.color === '255, 255, 255') {
      this.color = '154, 140, 115';
    }
    this.go = function () {
      this.x += OPT.speed * OPT.direction.x * this.acceleration / 2;
      this.y += OPT.speed * OPT.direction.y * this.acceleration / 2;
      this.opacity = OPT.maxopacity - ++this.age / OPT.lifetime;
    };
  }

  function addSpark() {
    let x = rand(-100, footer.offsetWidth + 100);
    let y = rand(footer.offsetHeight - 20, footer.offsetHeight + 80);
    sparks.push(new Spark(x, y));
  }

  function drawSpark(spark) {
    spark.go();
    ctx.beginPath();
    ctx.fillStyle = `rgba(${spark.color}, ${spark.opacity})`;
    ctx.arc(spark.x, spark.y, OPT.size[0], 0, Math.PI * 2);
    ctx.fill();
  }

  function draw() {
    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    sparks.forEach((spark, i, array) => {
      if (spark.opacity <= 0 || spark.y < -50) {
        array.splice(i, 1);
      } else {
        drawSpark(spark);
      }
    });
    animationFrame = window.requestAnimationFrame(draw);
  }

  let sparkInterval;

  function start() {
    if (isVisible) return;
    isVisible = true;
    setCanvasWidth();
    sparkInterval = setInterval(() => {
      if (sparks.length < OPT.amount) addSpark();
    }, 1000 / OPT.amount);
    animationFrame = window.requestAnimationFrame(draw);
  }

  function stop() {
    isVisible = false;
    clearInterval(sparkInterval);
    cancelAnimationFrame(animationFrame);
    sparks = [];
  }

  const observer = new IntersectionObserver((entries) => {
    entries[0].isIntersecting ? start() : stop();
  }, { threshold: 0.1 });

  observer.observe(footer);
  window.addEventListener('resize', setCanvasWidth);
}

// .
