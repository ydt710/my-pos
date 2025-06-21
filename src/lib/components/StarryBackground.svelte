<script lang="ts">
  import { onMount } from 'svelte';

  let canvas: HTMLCanvasElement;
  let ctx: CanvasRenderingContext2D | null = null;
  let animationFrameId: number;
  let stars: (Star | null)[] = [];
  let shootingStars: ShootingStar[] = [];
  let lastTime = 0;
  const FPS = 30;
  const frameInterval = 1000 / FPS;
  let isMobile = false;
  let prevWidth = 0;
  let prevHeight = 0;
  let fadeIn = false;

  interface Star {
    x: number;
    y: number;
    xPct: number;
    yPct: number;
    size: number;
    speed: number;
    color: string;
    opacity: number;
    blinkSpeed: number;
    blinkPhase: number;
  }

  interface ShootingStar {
    x: number;
    y: number;
    len: number;
    width: number;
    speedX: number;
    speedY: number;
    opacity: number;
  }

  const categoryIcons = [
    { icon: '\u{f55f}', name: 'fa-cannabis', color: '#4CAF50' },
    { icon: '\u{f492}', name: 'fa-vial', color: '#2196F3' },
    { icon: '\u{f595}', name: 'fa-joint', color: '#FF9800' },
    { icon: '\u{f563}', name: 'fa-cookie', color: '#9C27B0' },
    { icon: '\u{f54e}', name: 'fa-store', color: '#E91E63' }
  ];

  function detectMobile() {
    return /Mobi|Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  }

  let OPTIMIZED = {
    starDensity: 1000, // px per star
    iconCount: 0, // Set to 0 to remove icons
    FPS: 30,
    shootingFlowerChance: 0 // Set to 0 to remove shooting flowers
  };

  function applyOptimizations() {
    isMobile = detectMobile();
    if (isMobile) {
      OPTIMIZED.starDensity = 2000; // fewer stars
      OPTIMIZED.iconCount = 0;
      OPTIMIZED.FPS = 18;
      OPTIMIZED.shootingFlowerChance = 0;
    } else {
      OPTIMIZED.starDensity = 1000;
      OPTIMIZED.iconCount = 0;
      OPTIMIZED.FPS = 30;
      OPTIMIZED.shootingFlowerChance = 0.005;
    }
  }

  function createStar(): Star | null {
    if (!canvas) return null;
    const xPct = Math.random();
    const yPct = Math.random();
    const colors = [
      'rgba(255, 255, 255, 0.8)', // White
      'rgba(76, 175, 80, 0.8)',   // Green
      'rgba(255, 235, 59, 0.8)',  // Yellow
      'rgba(244, 67, 54, 0.8)'    // Red
    ];
    const color = colors[Math.floor(Math.random() * colors.length)];
    const isWhite = color === 'rgba(255, 255, 255, 0.8)';
    return {
      x: xPct * canvas.width,
      y: yPct * canvas.height,
      xPct,
      yPct,
      size: Math.random() * 2 + 1,
      speed: 10, // No movement (user's custom value)
      color,
      opacity: 0.8,
      blinkSpeed: isWhite ? (Math.random() * 0.015 + 0.008) : 0,
      blinkPhase: Math.random() * Math.PI * 2,
    };
  }

  function createShootingStar() {
    if (!canvas) return;
    const side = Math.floor(Math.random() * 4);
    let x, y, speedX, speedY;
    const speedMagnitude = Math.random() * 0.5 + 0.5;

    switch(side) {
      case 0: // from top
        x = Math.random() * canvas.width;
        y = -20;
        speedX = (Math.random() - 0.5) * 1;
        speedY = speedMagnitude;
        break;
      case 1: // from right
        x = canvas.width + 20;
        y = Math.random() * canvas.height;
        speedX = -speedMagnitude;
        speedY = (Math.random() - 0.5) * 1;
        break;
      case 2: // from bottom
        x = Math.random() * canvas.width;
        y = canvas.height + 20;
        speedX = (Math.random() - 0.5) * 1;
        speedY = -speedMagnitude;
        break;
      default: // from left
        x = -20;
        y = Math.random() * canvas.height;
        speedX = speedMagnitude;
        speedY = (Math.random() - 0.5) * 1;
        break;
    }

    shootingStars.push({
      x,
      y,
      len: Math.random() * 80 + 50,
      width: Math.random() * 2 + 0.5,
      speedX,
      speedY,
      opacity: 0,
    });
  }

  function initStars() {
    if (!canvas) return;
    const starCount = Math.floor((canvas.width * canvas.height) / OPTIMIZED.starDensity);
    stars = Array.from({ length: starCount }, createStar).filter(Boolean);
  }

  function drawStar(star: Star) {
    if (!ctx || !star) return;
    ctx.beginPath();
    ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
    ctx.fillStyle = star.color;
    ctx.globalAlpha = star.opacity;
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  function drawShootingStar(star: ShootingStar) {
    if (!ctx || !star) return;

    const angle = Math.atan2(star.speedY, star.speedX);
    const tailX = star.x - star.len * Math.cos(angle);
    const tailY = star.y - star.len * Math.sin(angle);
    
    const gradient = ctx.createLinearGradient(star.x, star.y, tailX, tailY);
    gradient.addColorStop(0, `rgba(255, 255, 255, ${star.opacity})`);
    gradient.addColorStop(1, 'rgba(255, 255, 255, 0)');
    
    ctx.beginPath();
    ctx.moveTo(tailX, tailY);
    ctx.lineTo(star.x, star.y);
    ctx.lineWidth = star.width;
    ctx.strokeStyle = gradient;
    ctx.stroke();
  }

  function drawStaticStarfield() {
    if (!canvas || !ctx) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#000510';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    stars.forEach(star => {
      if (star) drawStar(star);
    });

    // Animate shooting stars
    shootingStars = shootingStars.filter(star => {
      star.x += star.speedX;
      star.y += star.speedY;

      // Fade in and out
      if (star.x < -100 || star.x > canvas.width + 100 || star.y < -100 || star.y > canvas.height + 100) {
        return false; // remove if off-screen
      } else {
        star.opacity = Math.min(star.opacity + 0.05, 0.7);
      }
      
      drawShootingStar(star);
      return true;
    });

    animationFrameId = requestAnimationFrame(animate);
  }

  function animate() {
    if (!canvas || !ctx) {
      animationFrameId = requestAnimationFrame(animate);
      return;
    }
    if (document.hidden) {
      animationFrameId = requestAnimationFrame(animate);
      return;
    }
    // Move stars gently downward on desktop only
    if (!isMobile) {
      stars.forEach(star => {
        if (!star) return;
        star.y += star.speed * 0.007; // Slow downward movement
        if (star.y > canvas.height) {
          star.y = 0;
          star.x = Math.random() * canvas.width;
        }
      });
    }
    // Twinkle only white stars
    stars.forEach(star => {
      if (!star) return;
      if (star.blinkSpeed > 0) {
        star.blinkPhase += star.blinkSpeed;
        star.opacity = 0.7 + 0.3 * Math.sin(star.blinkPhase);
      }
    });

    if (!isMobile && Math.random() < OPTIMIZED.shootingFlowerChance) {
      createShootingStar();
    }

    drawStaticStarfield();
  }

  function updateStarPositions() {
    if (!canvas) return;
    stars.forEach(star => {
      if (!star) return;
      star.x = star.xPct * canvas.width;
      star.y = star.yPct * canvas.height;
    });
  }

  function handleResize() {
    if (!canvas || !ctx) return;

    applyOptimizations();
    const dpr = window.devicePixelRatio || 1;
    const newWidth = window.innerWidth * dpr;
    const newHeight = window.innerHeight * dpr;

    // Only re-initialize if the size changed drastically (by more than 20%)
    const widthChange = Math.abs(newWidth - prevWidth) / (prevWidth || 1);
    const heightChange = Math.abs(newHeight - prevHeight) / (prevHeight || 1);
    if (widthChange > 0.2 || heightChange > 0.2 || stars.length === 0) {
      canvas.width = newWidth;
      canvas.height = newHeight;
    
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.scale(dpr, dpr);
      initStars();
      prevWidth = newWidth;
      prevHeight = newHeight;
    } else if (Math.abs(newWidth - prevWidth) > 2 || Math.abs(newHeight - prevHeight) > 2) {
      canvas.width = newWidth;
      canvas.height = newHeight;
      canvas.style.width = '100vw';
      canvas.style.height = '100vh';
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.scale(dpr, dpr);
      updateStarPositions();
      prevWidth = newWidth;
      prevHeight = newHeight;
    }
  }

  onMount(() => {
    if (!canvas) return;
    
    ctx = canvas.getContext('2d', { alpha: false });
    if (!ctx) return;
    
    applyOptimizations();
    handleResize();
    drawStaticStarfield();
    fadeIn = true;
    animate();

    window.addEventListener('resize', handleResize);
    // Pause animation when not visible
    const handleVisibility = () => {
      if (!document.hidden) {
        animate();
      }
    };
    document.addEventListener('visibilitychange', handleVisibility);

    return () => {
      window.removeEventListener('resize', handleResize);
      document.removeEventListener('visibilitychange', handleVisibility);
      cancelAnimationFrame(animationFrameId);
    };
  });
</script>

<canvas
  bind:this={canvas}
  class="starry-background {fadeIn ? 'fade-in' : ''}"
  aria-hidden="true"
></canvas>

<style>
  .starry-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    min-height: 100vh;
    height: 100%;
    z-index: -1;
    background: #000510;
    pointer-events: none; /* Ensure no interaction with elements below */
    opacity: 0;
  }
  .starry-background.fade-in {
    opacity: 1;
    transition: opacity 1.2s cubic-bezier(0.4,0,0.2,1);
  }
</style> 