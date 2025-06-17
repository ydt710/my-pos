export function debounce<T extends (...args: any[]) => void>(fn: T, delay = 300) {
  let timeout: NodeJS.Timeout;
  return (...args: Parameters<T>) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => fn(...args), delay);
  };
}

export function getBalanceColor(balance: number | null) {
  if (balance === null) return '#666';
  if (balance > 0) return '#28a745';
  if (balance < 0) return '#dc3545';
  return '#666';
} 