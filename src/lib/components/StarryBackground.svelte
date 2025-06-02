<script lang="ts">
  import { onMount } from 'svelte';

  let canvas: HTMLCanvasElement;
  let ctx: CanvasRenderingContext2D;
  let animationFrameId: number;
  let stars: Star[] = [];
  let icons: FloatingIcon[] = [];
  let shootingFlowers: ShootingFlower[] = [];
  let lastTime = 0;
  const FPS = 30;
  const frameInterval = 1000 / FPS;
  let isMobile = false;

  interface Star {
    x: number;
    y: number;
    size: number;
    speed: number;
    color: string;
    opacity: number;
    blinkSpeed: number;
    blinkPhase: number;
  }

  interface FloatingIcon {
    x: number;
    y: number;
    size: number;
    speed: number;
    rotation: number;
    rotationSpeed: number;
    icon: string;
    opacity: number;
  }

  interface ShootingFlower {
    x: number;
    y: number;
    size: number;
    speed: number;
    angle: number;
    trail: { x: number; y: number; opacity: number; size: number }[];
    opacity: number;
    rotation: number;
    rotationSpeed: number;
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
    iconCount: 3,
    FPS: 30,
    shootingFlowerChance: 0.005
  };

  function applyOptimizations() {
    isMobile = detectMobile();
    if (isMobile) {
      OPTIMIZED.starDensity = 2000; // fewer stars
      OPTIMIZED.iconCount = 1;
      OPTIMIZED.FPS = 18;
      OPTIMIZED.shootingFlowerChance = 0.002;
    } else {
      OPTIMIZED.starDensity = 1000;
      OPTIMIZED.iconCount = 3;
      OPTIMIZED.FPS = 30;
      OPTIMIZED.shootingFlowerChance = 0.005;
    }
  }

  function createStar(): Star {
    const colors = [
      'rgba(255, 255, 255, 0.8)', // White
      'rgba(76, 175, 80, 0.8)',   // Green
      'rgba(255, 235, 59, 0.8)',  // Yellow
      'rgba(244, 67, 54, 0.8)'    // Red
    ];
    const color = colors[Math.floor(Math.random() * colors.length)];
    const isWhite = color === 'rgba(255, 255, 255, 0.8)';
    
    return {
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      size: Math.random() * 2 + 1,
      speed: Math.random() * 0.3 + 0.1,
      color,
      opacity: isWhite ? 0.8 : 0,
      blinkSpeed: isWhite ? 0 : Math.random() * 0.02 + 0.01,
      blinkPhase: Math.random() * Math.PI * 2
    };
  }

  function createFloatingIcon(): FloatingIcon {
    const iconData = categoryIcons[Math.floor(Math.random() * categoryIcons.length)];
    return {
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      size: Math.random() * 15 + 10,
      speed: Math.random() * 0.2 + 0.05,
      rotation: Math.random() * Math.PI * 2,
      rotationSpeed: (Math.random() - 0.5) * 0.01,
      icon: iconData.icon,
      opacity: Math.random() * 0.2 + 0.1
    };
  }

  function createShootingFlower(): ShootingFlower {
    const angle = Math.random() * Math.PI / 4 + Math.PI / 8; // Angle between 22.5 and 67.5 degrees
    const x = Math.random() * canvas.width;
    const y = -20; // Start above the canvas
    return {
      x,
      y,
      size: Math.random() * 1 + 0.5, // Smaller size
      speed: Math.random() * 15 + 20, // Faster speed for smoother motion
      angle,
      trail: [],
      opacity: 1,
      rotation: Math.random() * Math.PI * 2,
      rotationSpeed: (Math.random() - 0.5) * 0.01 // Reduced curve amount
    };
  }

  function initStars() {
    const starCount = Math.floor((canvas.width * canvas.height) / OPTIMIZED.starDensity);
    stars = Array.from({ length: starCount }, createStar);
    icons = Array.from({ length: OPTIMIZED.iconCount }, createFloatingIcon);
    shootingFlowers = [];
  }

  function drawStar(star: Star) {
    ctx.beginPath();
    ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
    ctx.fillStyle = star.color;
    ctx.globalAlpha = star.opacity;
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  function drawIcon(icon: FloatingIcon) {
    ctx.save();
    ctx.translate(icon.x, icon.y);
    ctx.rotate(icon.rotation);
    ctx.globalAlpha = icon.opacity;
    
    ctx.fillStyle = 'rgba(255, 255, 255, 0.8)';
    ctx.beginPath();
    ctx.arc(0, 0, icon.size * 0.3, 0, Math.PI * 2);
    ctx.fill();
    
    ctx.restore();
  }

  function drawShootingFlower(flower: ShootingFlower) {
    ctx.save();
    
    // Draw main trail
    const gradient = ctx.createLinearGradient(
      flower.x, 
      flower.y, 
      flower.x - Math.cos(flower.angle) * 120, 
      flower.y - Math.sin(flower.angle) * 120
    );
    gradient.addColorStop(0, 'rgba(255, 255, 255, 0.9)');
    gradient.addColorStop(0.1, 'rgba(255, 255, 255, 0.5)');
    gradient.addColorStop(0.3, 'rgba(255, 255, 255, 0.2)');
    gradient.addColorStop(0.6, 'rgba(255, 255, 255, 0.05)');
    gradient.addColorStop(1, 'rgba(255, 255, 255, 0)');

    ctx.beginPath();
    ctx.moveTo(flower.x, flower.y);
    ctx.lineTo(
      flower.x - Math.cos(flower.angle) * 120,
      flower.y - Math.sin(flower.angle) * 120
    );
    ctx.strokeStyle = gradient;
    ctx.lineWidth = flower.size * 1.2; // Thinner main trail
    ctx.stroke();

    // Draw secondary trail (more spread out)
    const secondaryGradient = ctx.createLinearGradient(
      flower.x, 
      flower.y, 
      flower.x - Math.cos(flower.angle) * 150, 
      flower.y - Math.sin(flower.angle) * 150
    );
    secondaryGradient.addColorStop(0, 'rgba(255, 255, 255, 0.2)');
    secondaryGradient.addColorStop(0.2, 'rgba(255, 255, 255, 0.1)');
    secondaryGradient.addColorStop(0.5, 'rgba(255, 255, 255, 0.02)');
    secondaryGradient.addColorStop(1, 'rgba(255, 255, 255, 0)');

    ctx.beginPath();
    ctx.moveTo(flower.x, flower.y);
    ctx.lineTo(
      flower.x - Math.cos(flower.angle) * 150,
      flower.y - Math.sin(flower.angle) * 150
    );
    ctx.strokeStyle = secondaryGradient;
    ctx.lineWidth = flower.size * 2; // Thinner secondary trail
    ctx.stroke();

    // Draw bright head with glow
    const headGradient = ctx.createRadialGradient(
      flower.x, flower.y, 0,
      flower.x, flower.y, flower.size * 2
    );
    headGradient.addColorStop(0, 'rgba(255, 255, 255, 1)');
    headGradient.addColorStop(0.4, 'rgba(255, 255, 255, 0.6)');
    headGradient.addColorStop(0.7, 'rgba(255, 255, 255, 0.2)');
    headGradient.addColorStop(1, 'rgba(255, 255, 255, 0)');

    ctx.beginPath();
    ctx.arc(flower.x, flower.y, flower.size * 2, 0, Math.PI * 2);
    ctx.fillStyle = headGradient;
    ctx.fill();

    // Draw core
    ctx.beginPath();
    ctx.arc(flower.x, flower.y, flower.size * 0.5, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(255, 255, 255, 1)';
    ctx.fill();

    ctx.restore();
  }

  function animate(currentTime: number) {
    if (document.hidden) {
      animationFrameId = requestAnimationFrame(animate);
      return;
    }
    if (currentTime - lastTime < frameInterval) {
      animationFrameId = requestAnimationFrame(animate);
      return;
    }
    lastTime = currentTime;

    // Clear the entire canvas completely
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#000510';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Update and draw stars
    stars.forEach(star => {
      star.y += star.speed;
      if (star.y > canvas.height) {
        star.y = 0;
        star.x = Math.random() * canvas.width;
      }
      
      // Update blinking for colored stars
      if (star.blinkSpeed > 0) {
        star.blinkPhase += star.blinkSpeed;
        star.opacity = (Math.sin(star.blinkPhase) + 1) * 0.4;
      }
      
      drawStar(star);
    });

    // Update and draw floating icons
    icons.forEach(icon => {
      icon.y += icon.speed;
      icon.rotation += icon.rotationSpeed;
      
      if (icon.y > canvas.height) {
        icon.y = -icon.size;
        icon.x = Math.random() * canvas.width;
      }
      
      drawIcon(icon);
    });

    // Update and draw shooting flowers
    shootingFlowers.forEach((flower, index) => {
      // Update position with very slight curve
      flower.rotation += flower.rotationSpeed;
      const curveFactor = Math.sin(flower.rotation) * 0.05; // Reduced curve amount
      flower.x += Math.cos(flower.angle + curveFactor) * flower.speed;
      flower.y += Math.sin(flower.angle + curveFactor) * flower.speed;
      
      // Remove if off screen
      if (flower.y > canvas.height + 50 || flower.x > canvas.width + 50) {
        shootingFlowers.splice(index, 1);
      } else {
        drawShootingFlower(flower);
      }
    });

    // Randomly add new shooting flowers
    if (Math.random() < OPTIMIZED.shootingFlowerChance) {
      shootingFlowers.push(createShootingFlower());
    }

    animationFrameId = requestAnimationFrame(animate);
  }

  function handleResize() {
    if (!canvas) return;

    applyOptimizations();
    const dpr = window.devicePixelRatio || 1;
    // Always use window.innerWidth/innerHeight for full viewport coverage
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    canvas.style.width = '100vw';
    canvas.style.height = '100vh';

    ctx.setTransform(1, 0, 0, 1, 0, 0); // Reset transform before scaling
    ctx.scale(dpr, dpr);

    initStars();
  }

  onMount(() => {
    if (!canvas) return;
    
    ctx = canvas.getContext('2d', { alpha: false })!;
    applyOptimizations();
    handleResize();
    animate(0);

    window.addEventListener('resize', handleResize);
    // Pause animation when not visible
    const handleVisibility = () => {
      if (!document.hidden) {
        animate(0);
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
  class="starry-background"
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
    pointer-events: none; /* Prevents accidental scroll/drag on canvas */
    touch-action: none;
  }
</style> 