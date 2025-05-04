<script lang="ts">
  export let size = '40px';
</script>

<div class="spinner" style="width: {size}; height: {size};" aria-label="Loading..."></div>

<style>
  .spinner {
    border: 4px solid rgba(0, 0, 0, 0.1);
    border-radius: 50%;
    border-top: 4px solid #007bff;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
</style> 