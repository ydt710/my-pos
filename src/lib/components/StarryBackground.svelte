<script lang="ts">
  import { onMount } from 'svelte';

  let canvas: HTMLCanvasElement;
  let ctx: CanvasRenderingContext2D;
  let animationFrameId: number;
  let stars: Star[] = [];
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

  const categoryIcons = [
    { icon: 'fa-cannabis', color: '#4CAF50' },
    { icon: 'fa-vial', color: '#2196F3' },
    { icon: 'fa-joint', color: '#FF9800' },
    { icon: 'fa-cookie', color: '#9C27B0' },
    { icon: 'fa-store', color: '#E91E63' }
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
      OPTIMIZED.shootingFlowerChance = 0;
    }
  }

  function createStar(): Star {
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

  function initStars() {
    const starCount = Math.floor((canvas.width * canvas.height) / OPTIMIZED.starDensity);
    stars = Array.from({ length: starCount }, createStar);
  }

  function drawStar(star: Star) {
    ctx.beginPath();
    ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
    ctx.fillStyle = star.color;
    ctx.globalAlpha = star.opacity;
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  function drawStaticStarfield() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#000510';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    stars.forEach(star => {
      drawStar(star);
    });
  }

  function animate() {
    if (document.hidden) {
      animationFrameId = requestAnimationFrame(animate);
      return;
    }
    // Move stars gently downward on desktop only
    if (!isMobile) {
      stars.forEach(star => {
        star.y += star.speed * 0.007; // Slow downward movement
        if (star.y > canvas.height) {
          star.y = 0;
          star.x = Math.random() * canvas.width;
        }
      });
    }
    // Twinkle only white stars
    stars.forEach(star => {
      if (star.blinkSpeed > 0) {
        star.blinkPhase += star.blinkSpeed;
        star.opacity = 0.7 + 0.3 * Math.sin(star.blinkPhase);
      }
    });
    drawStaticStarfield();
    animationFrameId = requestAnimationFrame(animate);
  }

  function updateStarPositions() {
    stars.forEach(star => {
      star.x = star.xPct * canvas.width;
      star.y = star.yPct * canvas.height;
    });
  }

  function handleResize() {
    if (!canvas) return;

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
      canvas.style.width = '100vw';
      canvas.style.height = '100vh';
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
    
    ctx = canvas.getContext('2d', { alpha: false })!;
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
    width: 100vw;
    height: 100vh;
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