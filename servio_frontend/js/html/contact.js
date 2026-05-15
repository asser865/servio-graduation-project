// Scroll reveal and Hero Animation for contact page
document.addEventListener('DOMContentLoaded', () => {
  // ── Liquid Background Mouse Follower ────────────────────────
  const interactiveOrb = document.querySelector('.liquid-orb--interactive');
  const heroSection = document.querySelector('.contact-hero');

  if (interactiveOrb && heroSection) {
    let mouseX = 0;
    let mouseY = 0;
    let currentX = 0;
    let currentY = 0;
    const lerpAmount = 0.08;

    const updateOrbPosition = () => {
      currentX += (mouseX - currentX) * lerpAmount;
      currentY += (mouseY - currentY) * lerpAmount;

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

    updateOrbPosition();
  }

  // ── Scroll Reveal ────────────────────────
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
