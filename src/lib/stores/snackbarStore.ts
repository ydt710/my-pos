import { writable, get } from 'svelte/store';

interface Snackbar {
  show: boolean;
  message: string;
  duration: number;
}

const queue: Snackbar[] = [];
export const snackbarStore = writable<Snackbar>({ show: false, message: '', duration: 3000 });
let timeout: NodeJS.Timeout | null = null;

function showNext() {
  if (queue.length === 0) {
    snackbarStore.set({ show: false, message: '', duration: 3000 });
    return;
  }
  const next = queue.shift()!;
  snackbarStore.set({ ...next, show: true });
  if (timeout) clearTimeout(timeout);
  timeout = setTimeout(() => {
    showNext();
  }, next.duration);
}

export function showSnackbar(message: string, duration = 3000) {
  queue.push({ show: true, message, duration });
  if (get(snackbarStore).show === false) {
    showNext();
  }
}

export function clearSnackbar() {
  queue.length = 0;
  snackbarStore.set({ show: false, message: '', duration: 3000 });
  if (timeout) clearTimeout(timeout);
} 