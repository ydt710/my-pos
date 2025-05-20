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

  interface Star {
    x: number;
    y: number;
    size: number;
    speed: number;
    brightness: number;
    opacity: number;
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
    trail: { x: number; y: number; opacity: number }[];
    opacity: number;
  }

  const categoryIcons = [
    { icon: 'fa-cannabis', color: '#4CAF50' },
    { icon: 'fa-vial', color: '#2196F3' },
    { icon: 'fa-joint', color: '#FF9800' },
    { icon: 'fa-cookie', color: '#9C27B0' },
    { icon: 'fa-store', color: '#E91E63' }
  ];

  function createStar(): Star {
    return {
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      size: Math.random() * 1.5 + 0.5,
      speed: Math.random() * 0.3 + 0.1,
      brightness: Math.random() * 0.5 + 0.5,
      opacity: Math.random() * 0.5 + 0.5
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
      size: Math.random() * 15 + 10,
      speed: Math.random() * 5 + 8,
      angle,
      trail: [],
      opacity: 1
    };
  }

  function initStars() {
    const starCount = Math.floor((canvas.width * canvas.height) / 2000);
    stars = Array.from({ length: starCount }, createStar);
    icons = Array.from({ length: 3 }, createFloatingIcon);
    shootingFlowers = [];
  }

  function drawStar(star: Star) {
    ctx.beginPath();
    ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(255, 255, 255, ${star.opacity * star.brightness})`;
    ctx.fill();
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
    // Draw trail
    ctx.save();
    for (let i = 0; i < flower.trail.length; i++) {
      const point = flower.trail[i];
      ctx.beginPath();
      ctx.arc(point.x, point.y, flower.size * 0.2, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(76, 175, 80, ${point.opacity})`;
      ctx.fill();
    }
    
    // Draw flower
    ctx.translate(flower.x, flower.y);
    ctx.rotate(flower.angle);
    ctx.globalAlpha = flower.opacity;
    
    // Draw flower petals
    const petalCount = 5;
    const petalSize = flower.size * 0.4;
    
    for (let i = 0; i < petalCount; i++) {
      const angle = (i * 2 * Math.PI) / petalCount;
      ctx.save();
      ctx.rotate(angle);
      ctx.beginPath();
      ctx.ellipse(0, -petalSize * 0.5, petalSize * 0.3, petalSize * 0.6, 0, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(76, 175, 80, 0.8)';
      ctx.fill();
      ctx.restore();
    }
    
    // Draw center
    ctx.beginPath();
    ctx.arc(0, 0, flower.size * 0.2, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(129, 199, 132, 0.9)';
    ctx.fill();
    
    ctx.restore();
  }

  function animate(currentTime: number) {
    if (currentTime - lastTime < frameInterval) {
      animationFrameId = requestAnimationFrame(animate);
      return;
    }
    lastTime = currentTime;

    ctx.fillStyle = 'rgba(0, 0, 20, 0.1)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Update and draw stars
    stars.forEach(star => {
      star.y += star.speed;
      if (star.y > canvas.height) {
        star.y = 0;
        star.x = Math.random() * canvas.width;
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
      // Update position
      flower.x += Math.cos(flower.angle) * flower.speed;
      flower.y += Math.sin(flower.angle) * flower.speed;
      
      // Add trail point
      flower.trail.push({
        x: flower.x,
        y: flower.y,
        opacity: 1
      });
      
      // Remove old trail points
      if (flower.trail.length > 10) {
        flower.trail.shift();
      }
      
      // Fade trail
      flower.trail.forEach(point => {
        point.opacity *= 0.9;
      });
      
      // Remove if off screen
      if (flower.y > canvas.height + 50 || flower.x > canvas.width + 50) {
        shootingFlowers.splice(index, 1);
      } else {
        drawShootingFlower(flower);
      }
    });

    // Randomly add new shooting flowers
    if (Math.random() < 0.02) { // 2% chance each frame
      shootingFlowers.push(createShootingFlower());
    }

    animationFrameId = requestAnimationFrame(animate);
  }

  function handleResize() {
    if (!canvas) return;
    
    // Set canvas size to match display size
    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();
    
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    
    // Scale context to match display size
    ctx.scale(dpr, dpr);
    
    initStars();
  }

  onMount(() => {
    if (!canvas) return;
    
    ctx = canvas.getContext('2d', { alpha: false })!;
    handleResize();
    animate(0);

    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      cancelAnimationFrame(animationFrameId);
    };
  });
</script>

<canvas
  bind:this={canvas}
  class="starry-background"
  aria-hidden="true"
/>

<style>
  .starry-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    z-index: -1;
    background: #000510;
  }
</style> 