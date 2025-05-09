<script lang="ts">
  import { browser } from '$app/environment';
  import { onMount } from 'svelte';

  let error: Error | null = null;
  let hasRecovered = false;

  function handleError(e: ErrorEvent) {
    error = e.error;
    console.error('Error caught by boundary:', e.error);
  }

  onMount(() => {
    if (browser) {
      window.addEventListener('error', handleError);
      return () => window.removeEventListener('error', handleError);
    }
  });

  function retry() {
    error = null;
    hasRecovered = true;
    // Force a re-render of children
    setTimeout(() => {
      hasRecovered = false;
    }, 0);
  }
</script>

{#if error}
  <div class="error-container" role="alert">
    <div class="error-content">
      <h2>Oops! Something went wrong</h2>
      <p class="error-message">{error.message}</p>
      <button class="retry-button" on:click={retry}>
        Try Again
      </button>
    </div>
  </div>
{:else}
  <slot />
{/if}

<style>
  .error-container {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.9);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 2rem;
    z-index: 1000;
  }

  .error-content {
    background: white;
    padding: 2rem;
    border-radius: 8px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    text-align: center;
    max-width: 400px;
  }

  h2 {
    color: #dc3545;
    margin: 0 0 1rem;
  }

  .error-message {
    color: #666;
    margin-bottom: 1.5rem;
  }

  .retry-button {
    background: #0d6efd;
    color: white;
    border: none;
    padding: 0.5rem 1.5rem;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
    transition: background-color 0.2s;
  }

  .retry-button:hover {
    background: #0b5ed7;
  }
</style> 