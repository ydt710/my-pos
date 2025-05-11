<script lang="ts">
  export let message = 'Are you sure?';
  export let onConfirm: () => void;
  export let onCancel: () => void;
</script>

<div class="modal-backdrop">
  <div class="modal">
    <p>{message}</p>
    <div class="modal-actions">
      <button class="confirm-btn" on:click={onConfirm}>Yes</button>
      <button class="cancel-btn" on:click={onCancel}>No</button>
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
  border-radius: 10px;
  padding: 2rem;
  min-width: 300px;
  box-shadow: 0 2px 16px rgba(0,0,0,0.2);
  text-align: center;
}
.modal-actions {
  margin-top: 1.5rem;
  display: flex;
  gap: 1rem;
  justify-content: center;
}
.confirm-btn {
  background: #dc3545;
  color: white;
  border: none;
  border-radius: 6px;
  padding: 0.5rem 1.5rem;
  font-size: 1rem;
  cursor: pointer;
}
.cancel-btn {
  background: #6c757d;
  color: white;
  border: none;
  border-radius: 6px;
  padding: 0.5rem 1.5rem;
  font-size: 1rem;
  cursor: pointer;
}
.confirm-btn:hover { background: #b52a37; }
.cancel-btn:hover { background: #495057; }
</style> 