document.addEventListener('DOMContentLoaded', () => {
  const composer = document.getElementById('ai-query-input');
  const btnSubmit = document.getElementById('ai-match-btn');
  const processingArea = document.getElementById('ai-processing');
  const resultsArea = document.getElementById('ai-results');
  const suggestions = document.querySelectorAll('.ai-suggestion');

  // Background Canvas Animation Logic (from 21st MCP component inspiration)
  const canvas = document.getElementById('hero-ai-canvas');
  if (canvas) {
    const ctx = canvas.getContext('2d');
    let animationFrameId;
    const points = [];
    const gridSize = 45;
    let mousePos = { x: undefined, y: undefined };
    let frame = 0;

    class Point {
      constructor(x, y) {
        this.x = x;
        this.y = y;
        this.originX = x;
        this.originY = y;
        this.z = 0;
      }
      update() {
        if (mousePos.x === undefined) {
          this.x += (this.originX - this.x) * 0.05;
          this.y += (this.originY - this.y) * 0.05;
          this.z += (0 - this.z) * 0.05;
          return;
        }
        const dx = this.x - mousePos.x;
        const dy = this.y - mousePos.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        const maxDist = 200;

        if (dist < maxDist) {
          const angle = Math.atan2(dy, dx);
          const force = (maxDist - dist) / maxDist;
          this.x += Math.cos(angle) * force * 5;
          this.y += Math.sin(angle) * force * 5;
          this.z = force * 20;
        }
        
        // Return to origin
        this.x += (this.originX - this.x) * 0.05;
        this.y += (this.originY - this.y) * 0.05;
        this.z += (0 - this.z) * 0.05;
      }
    }
    
    const initCanvas = () => {
      points.length = 0;
      const cols = Math.ceil(canvas.width / gridSize);
      const rows = Math.ceil(canvas.height / gridSize);
      for (let i = 0; i <= cols; i++) {
        for (let j = 0; j <= rows; j++) {
          points.push(new Point(i * gridSize, j * gridSize));
        }
      }
    };

    const animateCanvas = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      frame++;

      const cols = Math.ceil(canvas.width / gridSize);
      const rows = Math.ceil(canvas.height / gridSize);

      points.forEach(p => p.update());
      
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
      
      if (isDark) {
        gradient.addColorStop(0, "rgba(219, 203, 180, 0.25)"); 
        gradient.addColorStop(1, "rgba(100, 100, 100, 0.1)");
      } else {
        gradient.addColorStop(0, "rgba(30, 27, 75, 0.25)"); // darker indigo for contrast
        gradient.addColorStop(1, "rgba(154, 140, 115, 0.45)"); // stronger warm brand tone
      }
      ctx.strokeStyle = gradient;

      for (let i = 0; i < cols; i++) {
        for (let j = 0; j < rows; j++) {
          const p1 = points[i * (rows + 1) + j];
          const p2 = points[i * (rows + 1) + (j + 1)];
          const p3 = points[(i + 1) * (rows + 1) + j];

          if (p1 && p2) {
            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(p2.x, p2.y);
            ctx.lineWidth = (isDark ? 1 : 1.2) + p1.z / 12;
            ctx.stroke();
          }
          if (p1 && p3) {
            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(p3.x, p3.y);
            ctx.lineWidth = (isDark ? 1 : 1.2) + p1.z / 12;
            ctx.stroke();
          }
        }
      }
      animationFrameId = requestAnimationFrame(animateCanvas);
    };
    
    const resizeCanvas = () => {
      const rect = canvas.parentElement.getBoundingClientRect();
      canvas.width = rect.width;
      canvas.height = rect.height;
      initCanvas();
    };

    const handleCanvasMouseMove = (e) => {
      const rect = canvas.getBoundingClientRect();
      mousePos = { x: e.clientX - rect.left, y: e.clientY - rect.top };
    };
    
    const handleCanvasMouseOut = () => {
      mousePos = { x: undefined, y: undefined };
    }

    window.addEventListener('resize', resizeCanvas);
    canvas.parentElement.addEventListener('mousemove', handleCanvasMouseMove);
    canvas.parentElement.addEventListener('mouseleave', handleCanvasMouseOut);

    resizeCanvas();
    animateCanvas();
  }

  if (!composer || !btnSubmit) return;

  // Handle typing to enable/disable button
  composer.addEventListener('input', () => {
    btnSubmit.disabled = composer.value.trim().length === 0;
  });

  // Handle suggestions click
  suggestions.forEach(sug => {
    sug.addEventListener('click', () => {
      composer.value = sug.textContent.trim();
      btnSubmit.disabled = false;
      composer.focus();
    });
  });

  // Handle Match process
  btnSubmit.addEventListener('click', async () => {
    if (composer.value.trim() === '') return;

    // Reset UI
    processingArea.innerHTML = '';
    processingArea.hidden = false;
    resultsArea.hidden = true;
    btnSubmit.disabled = true;
    composer.disabled = true;

    // Simulate Fake AI Step Delays
    const steps = [
      "Analyzing semantic intent...",
      "Extracting parameters: [Plumbing, Leak, Nasr City, <50, EGP 1 Hour]...",
      "Querying Elite Technician Network...",
      "Filtering 158 local plumbers down to 4 matching criteria...",
      "Rank-ordering by response speed and satisfaction score...",
      "Match Found."
    ];

    for (let i = 0; i < steps.length; i++) {
      await generateProcessingLog(steps[i], i === steps.length - 1);
    }

    // Show Results
    processingArea.hidden = true;
    resultsArea.hidden = false;
    composer.disabled = false;
    btnSubmit.disabled = false;
    
    // Smooth scroll to results
    resultsArea.scrollIntoView({ behavior: 'smooth', block: 'start' });

    // Link result card to profile
    const matchCard = resultsArea.querySelector('.tech-card');
    if (matchCard) {
      matchCard.style.cursor = 'pointer';
      matchCard.addEventListener('click', () => {
        window.location.href = './technician-profile.html';
      });
    }
  });

  function generateProcessingLog(text, isFinal) {
    return new Promise(resolve => {
      // Mark previous logs as done
      const previous = processingArea.querySelectorAll('.ai-processing__log.active');
      previous.forEach(p => {
        p.classList.remove('active');
        p.classList.add('done');
      });

      const logNode = document.createElement('div');
      logNode.className = 'ai-processing__log active';
      
      const spinnerNode = document.createElement('div');
      spinnerNode.className = 'ai-processing__spinner';

      const textNode = document.createElement('span');
      textNode.textContent = text;

      if (!isFinal) logNode.appendChild(spinnerNode);
      logNode.appendChild(textNode);
      
      processingArea.appendChild(logNode);

      // Random delay between 400ms and 1000ms
      setTimeout(resolve, isFinal ? 400 : Math.random() * 600 + 400);
    });
  }
});

// .
