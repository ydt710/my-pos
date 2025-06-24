import { writable } from 'svelte/store';
import { browser } from '$app/environment';

// Starry background toggle store
function createStarryBackgroundStore() {
  // Default to true (enabled) but check localStorage
  let initial = true;
  if (browser) {
    const stored = localStorage.getItem('starryBackground');
    if (stored !== null) {
      initial = JSON.parse(stored);
    }
  }

  const { subscribe, set, update } = writable(initial);

  return {
    subscribe,
    set: (value: boolean) => {
      if (browser) {
        localStorage.setItem('starryBackground', JSON.stringify(value));
      }
      set(value);
    },
    update,
    toggle: () => {
      update(value => {
        const newValue = !value;
        if (browser) {
          localStorage.setItem('starryBackground', JSON.stringify(newValue));
        }
        return newValue;
      });
    }
  };
}

export const starryBackground = createStarryBackgroundStore(); 