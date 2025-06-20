<script lang="ts">
  export let message = 'Are you sure?';
  export let onConfirm: () => void;
  export let onCancel: () => void;
</script>

<div class="modal-backdrop" role="dialog" aria-modal="true" aria-labelledby="modal-title">
  <div class="modal" role="document">
    <div class="modal-header">
      <h2 id="modal-title" tabindex="-1">Confirm</h2>
      <button class="close-btn" on:click={onCancel} aria-label="Close">×</button>
    </div>
    <div class="modal-body">
      <p>{message}</p>
      <div class="modal-actions">
        <button class="confirm-btn" on:click={onConfirm}>Yes</button>
        <button class="cancel-btn" on:click={onCancel}>No</button>
      </div>
    </div>
  </div>
</div>

<style>
.modal-backdrop {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2000;
}
.modal {
  background: white;
  border-radius: 12px;
  box-shadow: 0 5px 15px rgba(0,0,0,0.3);
  width: 90vw;
  max-width: 400px;
  text-align: center;
  overflow: hidden;
}
.modal-header {
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #e9ecef;
}
.modal-header h2 {
  margin: 0;
  font-size: 1.25rem;
  color: #343a40;
}
.close-btn {
  display: none; /* Can be enabled if needed */
}
.modal-body {
  padding: 1.5rem;
}
.modal-body p {
  margin: 0 0 1.5rem;
  font-size: 1.1rem;
  color: #495057;
}
.modal-actions {
  display: flex;
  gap: 1rem;
  justify-content: center;
}
.confirm-btn, .cancel-btn {
  border: none;
  border-radius: 8px;
  padding: 0.75rem 1.5rem;
  font-size: 1rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  min-width: 100px;
}
.confirm-btn {
  background: #dc3545;
  color: white;
}
.confirm-btn:hover { background: #c82333; }
.cancel-btn {
  background: #e9ecef;
  color: #343a40;
  border: 1px solid #ced4da;
}
.cancel-btn:hover { background: #dee2e6; }
</style> 