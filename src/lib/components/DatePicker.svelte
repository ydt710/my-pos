<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  
  export let value: string = '';
  export let placeholder: string = 'Select date';
  export let id: string = '';
  export let disabled: boolean = false;
  export let required: boolean = false;
  export let min: string = '';
  export let max: string = '';
  export let showCalendarIcon: boolean = true;
  
  const dispatch = createEventDispatcher();
  
  let inputElement: HTMLInputElement;
  let supportsDatePicker = true;
  
  onMount(() => {
    // Check if browser supports date picker
    const testInput = document.createElement('input');
    testInput.type = 'date';
    testInput.value = 'invalid';
    supportsDatePicker = testInput.value !== 'invalid';
  });
  
  function handleChange(event: Event) {
    const target = event.target as HTMLInputElement;
    value = target.value;
    dispatch('change', { value });
  }
  
  function openPicker() {
    if (inputElement && supportsDatePicker) {
      inputElement.showPicker?.();
    }
  }
  
  function handleKeyDown(event: KeyboardEvent) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      openPicker();
    }
  }
  
  // Format the display value for better UX
  $: displayValue = value ? new Date(value).toLocaleDateString() : '';
</script>

<div class="date-picker-wrapper" class:disabled>
  <div class="date-input-container">
    <!-- Hidden native date input for functionality -->
    <input
      bind:this={inputElement}
      type="date"
      {value}
      {id}
      {disabled}
      {required}
      {min}
      {max}
      class="native-date-input"
      on:change={handleChange}
      aria-label={placeholder}
    />
    
    <!-- Custom styled input display -->
    <div
      class="custom-date-display"
      class:has-value={!!value}
      role="button"
      tabindex={disabled ? -1 : 0}
      aria-label={placeholder}
      on:click={openPicker}
      on:keydown={handleKeyDown}
    >
      <span class="date-text">
        {displayValue || placeholder}
      </span>
      
      {#if showCalendarIcon && supportsDatePicker}
        <svg class="calendar-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
          <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
          <line x1="16" y1="2" x2="16" y2="6"/>
          <line x1="8" y1="2" x2="8" y2="6"/>
          <line x1="3" y1="10" x2="21" y2="10"/>
        </svg>
      {/if}
    </div>
  </div>
</div>

<style>
  .date-picker-wrapper {
    position: relative;
    display: inline-block;
    width: 100%;
  }
  
  .date-picker-wrapper.disabled {
    opacity: 0.6;
    pointer-events: none;
  }
  
  .date-input-container {
    position: relative;
    width: 100%;
  }
  
  .native-date-input {
    position: absolute;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    opacity: 0;
    cursor: pointer;
    z-index: 2;
  }
  
  .native-date-input::-webkit-calendar-picker-indicator {
    position: absolute;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    margin: 0;
    padding: 0;
    cursor: pointer;
    background: transparent;
  }
  
  .custom-date-display {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.75rem 1rem;
    background: var(--bg-secondary);
    border: 2px solid var(--border-primary);
    border-radius: 8px;
    color: var(--text-secondary);
    font-size: 1rem;
    cursor: pointer;
    transition: all 0.3s ease;
    position: relative;
    z-index: 1;
    min-height: 48px;
  }
  
  .custom-date-display:hover {
    border-color: var(--neon-cyan);
    box-shadow: 0 0 10px rgba(0, 242, 254, 0.3);
  }
  
  .custom-date-display:focus {
    outline: none;
    border-color: var(--neon-cyan);
    box-shadow: 0 0 15px rgba(0, 242, 254, 0.5);
  }
  
  .custom-date-display.has-value {
    color: var(--text-primary);
  }
  
  .date-text {
    flex: 1;
    text-align: left;
    user-select: none;
  }
  
  .calendar-icon {
    width: 20px;
    height: 20px;
    color: var(--neon-cyan);
    opacity: 0.8;
    transition: all 0.3s ease;
    flex-shrink: 0;
    margin-left: 0.5rem;
  }
  
  .custom-date-display:hover .calendar-icon {
    opacity: 1;
    transform: scale(1.1);
  }
  
  /* Responsive adjustments */
  @media (max-width: 768px) {
    .custom-date-display {
      padding: 0.625rem 0.875rem;
      font-size: 0.95rem;
    }
    
    .calendar-icon {
      width: 18px;
      height: 18px;
    }
  }
  
  /* Dark theme enhancements */
  .custom-date-display {
    background: linear-gradient(135deg, var(--bg-secondary) 0%, rgba(30, 41, 59, 0.8) 100%);
    backdrop-filter: blur(10px);
  }
  
  .custom-date-display:hover {
    background: linear-gradient(135deg, var(--bg-secondary) 0%, rgba(30, 41, 59, 0.9) 100%);
    transform: translateY(-1px);
  }
  
  /* Animation for value changes */
  .date-text {
    transition: color 0.3s ease;
  }
  
  /* Focus ring for accessibility */
  .custom-date-display:focus-visible {
    outline: 2px solid var(--neon-cyan);
    outline-offset: 2px;
  }
</style> 