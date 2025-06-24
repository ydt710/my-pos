<script lang="ts">
  export let message = 'Are you sure?';
  export let onConfirm: () => void;
  export let onCancel: () => void;
</script>

<div class="modal-backdrop" role="dialog" aria-modal="true" aria-labelledby="modal-title">
  <div class="modal-content confirm-modal" role="document">
    <div class="modal-header">
      <h2 id="modal-title" tabindex="-1" class="neon-text-cyan">Confirm</h2>
      <button class="modal-close" on:click={onCancel} aria-label="Close">&times;</button>
    </div>
    <div class="modal-body">
      <p class="neon-text-white">{message}</p>
      <div class="modal-actions">
        <button class="btn btn-danger" on:click={onConfirm}>Yes</button>
        <button class="btn btn-secondary" on:click={onCancel}>No</button>
      </div>
    </div>
  </div>
</div>

<style>
  .confirm-modal {
    max-width: 400px;
    width: 90vw;
  }

  .modal-actions {
    display: flex;
    gap: 1rem;
    justify-content: center;
    margin-top: 1.5rem;
  }

  .modal-body p {
    margin: 0 0 1.5rem 0;
    font-size: 1.1rem;
    line-height: 1.6;
    text-align: center;
  }
</style> 