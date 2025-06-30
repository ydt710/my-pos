<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  export let value: string = '';
  export let placeholder: string = 'Select date';
  export let id: string = '';
  export let disabled: boolean = false;
  export let required: boolean = false;
  export let min: string = '';
  export let max: string = '';
  
  const dispatch = createEventDispatcher();
  
  function handleChange(event: Event) {
    const target = event.target as HTMLInputElement;
    value = target.value;
    dispatch('change', { value });
  }
</script>

<div class="date-picker-container">
  <input
    type="date"
    bind:value
    {id}
    {disabled}
    {required}
    {min}
    {max}
    {placeholder}
    class="form-control date-picker-input"
    on:change={handleChange}
    on:input={handleChange}
  />
</div>

<style>
  .date-picker-container {
    position: relative;
    width: 100%;
  }
  
  .date-picker-input {
    width: 100%;
    transition: var(--transition-fast);
  }
  
  .date-picker-input:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
  
  /* Enhanced neon glow effects for date inputs */
  .date-picker-input:hover:not(:disabled) {
    box-shadow: 
      0 0 0 2px rgba(0, 242, 254, 0.2), 
      inset 0 0 20px rgba(0, 242, 254, 0.05),
      0 0 15px rgba(0, 240, 255, 0.3);
    border-color: var(--neon-cyan);
  }
  
  .date-picker-input:focus:not(:disabled) {
    box-shadow: 
      0 0 0 2px rgba(0, 242, 254, 0.3), 
      inset 0 0 25px rgba(0, 242, 254, 0.08),
      0 0 20px rgba(0, 240, 255, 0.5);
    border-color: var(--neon-cyan);
    transform: translateY(-1px);
  }
  
  /* Mobile optimizations */
  @media (max-width: 768px) {
    .date-picker-input {
      font-size: 16px; /* Prevents zoom on iOS */
    }
  }
</style> 