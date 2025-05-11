<script lang="ts">
  export let message = '';
  export let show = false;
  export let duration = 3000;
  let timeout: ReturnType<typeof setTimeout>;

  $: if (show && message) {
    clearTimeout(timeout);
    timeout = setTimeout(() => {
      show = false;
    }, duration);
  }
</script>

{#if show}
  <div class="snackbar">{message}</div>
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
  z-index: 2000;
  animation: fadeInUp 0.3s;
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
</style> 