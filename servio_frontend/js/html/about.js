// Animated counters for stats
document.addEventListener('DOMContentLoaded', () => {
  // ── Liquid Background Mouse Follower ────────────────────────
  const interactiveOrb = document.querySelector('.liquid-orb--interactive');
  const heroSection = document.querySelector('.about-hero');

  if (interactiveOrb && heroSection) {
    let mouseX = 0;
    let mouseY = 0;
    let currentX = 0;
    let currentY = 0;
    const lerpAmount = 0.08; // Buttery smooth lag

    const updateOrbPosition = () => {
      // Linear interpolation for smooth motion
      currentX += (mouseX - currentX) * lerpAmount;
      currentY += (mouseY - currentY) * lerpAmount;

      // Center the orb on the cursor
      const xOffset = currentX - interactiveOrb.offsetWidth / 2;
      const yOffset = currentY - interactiveOrb.offsetHeight / 2;

      interactiveOrb.style.transform = `translate3d(${xOffset}px, ${yOffset}px, 0)`;
      requestAnimationFrame(updateOrbPosition);
    };

    heroSection.addEventListener('mousemove', (e) => {
      const rect = heroSection.getBoundingClientRect();
      mouseX = e.clientX - rect.left;
      mouseY = e.clientY - rect.top;
    });

    // Start the animation loop
    updateOrbPosition();
  }

  const counters = document.querySelectorAll('[data-count]');
        const observerOptions = { threshold: 0.5 };

        const animateCounter = (el) => {
          const target = parseInt(el.dataset.count, 10);
          const suffix = el.dataset.suffix || '';
          const duration = 2000;
          const start = performance.now();

          const tick = (now) => {
            const elapsed = now - start;
            const progress = Math.min(elapsed / duration, 1);
            const eased = 1 - Math.pow(1 - progress, 3);
            const current = Math.round(eased * target);
            el.textContent = current.toLocaleString() + suffix;
            if (progress < 1) requestAnimationFrame(tick);
          };
          requestAnimationFrame(tick);
        };

        const observer = new IntersectionObserver((entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              animateCounter(entry.target);
              observer.unobserve(entry.target);
            }
          });
        }, observerOptions);

        counters.forEach((c) => observer.observe(c));

        // Scroll reveal for about page
        const revealElements = document.querySelectorAll('[data-reveal]');
        const revealObserver = new IntersectionObserver((entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              entry.target.classList.add('is-visible');
              revealObserver.unobserve(entry.target);
            }
          });
        }, { threshold: 0.15, rootMargin: '0px 0px -40px 0px' });

        revealElements.forEach((el) => revealObserver.observe(el));
      });
// .
