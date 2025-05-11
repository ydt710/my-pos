import { writable } from 'svelte/store';

export const snackbarStore = writable({
  show: false,
  message: '',
  duration: 3000
});

export function showSnackbar(message: string, duration = 3000) {
  snackbarStore.set({ show: true, message, duration });
} 