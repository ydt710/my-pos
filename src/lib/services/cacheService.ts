import { writable, derived, get } from 'svelte/store';

// --- Cache Durations ---
const PROFILE_CACHE_DURATION = 30 * 60 * 1000; // 30 minutes
const CREDIT_LEDGER_CACHE_DURATION = 5 * 60 * 1000; // 5 minutes
const SETTINGS_CACHE_DURATION = 24 * 60 * 60 * 1000; // 24 hours

interface CacheEntry<T> {
  data: T;
  timestamp: number;
}

// --- Persistent Store Utility ---
// A helper to create a Svelte store that syncs with localStorage.
function createPersistentStore<T>(key: string, startValue: T) {
  const isBrowser = typeof window !== 'undefined';
  let initialValue = startValue;

  if (isBrowser) {
    const storedValue = localStorage.getItem(key);
    if (storedValue) {
      try {
        initialValue = JSON.parse(storedValue);
      } catch (e) {
        console.error(`Error parsing localStorage key "${key}", clearing it.`, e);
        localStorage.removeItem(key);
      }
    }
  }

  const store = writable<T>(initialValue);

  if (isBrowser) {
    store.subscribe(value => {
      localStorage.setItem(key, JSON.stringify(value));
    });
  }

  return store;
}


// --- Cache Stores ---
const profileCache = createPersistentStore<Record<string, CacheEntry<any>>>('profileCache', {});
const creditLedgerCache = createPersistentStore<Record<string, CacheEntry<any>>>('creditLedgerCache', {});
const settingsCache = createPersistentStore<CacheEntry<any> | null>('settingsCache', null);


// --- Cache Validation & Cleanup ---
function isCacheValid(timestamp: number, duration: number): boolean {
  return Date.now() - timestamp < duration;
}

function cleanExpiredCache(cache: Record<string, CacheEntry<any>>, duration: number): Record<string, CacheEntry<any>> {
  return Object.entries(cache).reduce((acc, [key, entry]) => {
    if (isCacheValid(entry.timestamp, duration)) {
      acc[key] = entry;
    }
    return acc;
  }, {} as Record<string, CacheEntry<any>>);
}


// --- Profile Cache ---
export function cacheProfile(id: string, data: any) {
  profileCache.update(cache => ({ ...cache, [id]: { data, timestamp: Date.now() } }));
}

export function getCachedProfile(id: string) {
  const cache = get(profileCache);
  const entry = cache[id];
  if (entry && isCacheValid(entry.timestamp, PROFILE_CACHE_DURATION)) {
    return entry.data;
  }
  return null;
}

// --- Credit Ledger Cache ---
export function cacheCreditLedger(type: string, data: any) {
  creditLedgerCache.update(cache => ({ ...cache, [type]: { data, timestamp: Date.now() } }));
}

export function getCachedCreditLedger(type: string) {
  const cache = get(creditLedgerCache);
  const entry = cache[type];
  if (entry && isCacheValid(entry.timestamp, CREDIT_LEDGER_CACHE_DURATION)) {
    return entry.data;
  }
  return null;
}

// --- Settings Cache ---
export function cacheSettings(data: any) {
    settingsCache.set({ data, timestamp: Date.now() });
}
  
export function getCachedSettings() {
    const entry = get(settingsCache);
    if (entry && isCacheValid(entry.timestamp, SETTINGS_CACHE_DURATION)) {
        return entry.data;
    }
    return null;
}


// --- Periodic Cleanup ---
setInterval(() => {
  profileCache.update(cache => cleanExpiredCache(cache, PROFILE_CACHE_DURATION));
  creditLedgerCache.update(cache => cleanExpiredCache(cache, CREDIT_LEDGER_CACHE_DURATION));

  const settings = get(settingsCache);
  if (settings && !isCacheValid(settings.timestamp, SETTINGS_CACHE_DURATION)) {
    settingsCache.set(null);
  }
}, 5 * 60 * 1000);

// --- Derived Stores ---
export const cachedProfiles = derived(profileCache, $cache =>
  Object.entries($cache)
    .filter(([_, entry]) => isCacheValid(entry.timestamp, PROFILE_CACHE_DURATION))
    .reduce((acc, [key, entry]) => ({ ...acc, [key]: entry.data }), {})
);

export const cachedCreditLedger = derived(creditLedgerCache, $cache =>
  Object.entries($cache)
    .filter(([_, entry]) => isCacheValid(entry.timestamp, CREDIT_LEDGER_CACHE_DURATION))
    .reduce((acc, [key, entry]) => ({ ...acc, [key]: entry.data }), {})
); 