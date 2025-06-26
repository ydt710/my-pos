<script lang="ts">
  export let message = '';
  export let show = false;
  export let duration = 3000;
  export let clickable = false;
  export let onClick: (() => void) | undefined = undefined;
  
  let timeout: ReturnType<typeof setTimeout>;

  $: if (show && message) {
    clearTimeout(timeout);
    timeout = setTimeout(() => {
      show = false;
    }, duration);
  }

  function handleClick() {
    if (clickable && onClick) {
      onClick();
      show = false; // Hide snackbar after click
    }
  }
</script>

{#if show}
  <div 
    class="snackbar" 
    class:clickable
    on:click={handleClick}
    on:keydown={(e) => e.key === 'Enter' && handleClick()}
    role={clickable ? 'button' : 'status'}
    tabindex={clickable ? 0 : -1}
    aria-label={clickable ? 'Click to open cart' : undefined}
  >
    {message}
    {#if clickable}
      <i class="fa-solid fa-external-link-alt click-icon"></i>
    {/if}
  </div>
{/if}

<style>
.snackbar {
  position: fixed;
  left: 50%;
  bottom: 2rem;
  transform: translateX(-50%);
  background: #323232;
  color: #fff;
  padding: 1rem 2rem;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.2);
  font-size: 1rem;
  z-index: 3000;
  animation: fadeInUp 0.3s;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  max-width: 90vw;
  word-wrap: break-word;
}

.snackbar.clickable {
  cursor: pointer;
  background: linear-gradient(135deg, #00f2fe, #4facfe);
  transition: all 0.2s ease;
  border: 1px solid transparent;
  color: #fff;
  font-weight: 600;
}

.snackbar.clickable:hover {
  transform: translateX(-50%) translateY(-2px);
  box-shadow: 0 4px 16px rgba(0,242,254,0.4), 0 0 20px rgba(0,242,254,0.3);
  border-color: #00f2fe;
  background: linear-gradient(135deg, #00f2fe, #00deff);
}

.snackbar.clickable:focus {
  outline: 2px solid #00f2fe;
  outline-offset: 2px;
  box-shadow: 0 4px 16px rgba(0,242,254,0.4), 0 0 20px rgba(0,242,254,0.3);
}

.click-icon {
  font-size: 0.9rem;
  opacity: 0.8;
  animation: pulse 2s infinite;
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateX(-50%) translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateX(-50%) translateY(0);
  }
}

@keyframes pulse {
  0%, 100% { opacity: 0.8; }
  50% { opacity: 1; }
}
</style> 