import { writable, derived } from 'svelte/store';

// Cache duration in milliseconds (5 minutes)
const CACHE_DURATION = 5 * 60 * 1000;

interface CacheEntry<T> {
  data: T;
  timestamp: number;
}

// Create stores for different types of cached data
const productCache = writable<Record<string, CacheEntry<any>>>({});
const profileCache = writable<Record<string, CacheEntry<any>>>({});
const creditLedgerCache = writable<Record<string, CacheEntry<any>>>({});

// Helper function to check if cache is valid
function isCacheValid(timestamp: number): boolean {
  return Date.now() - timestamp < CACHE_DURATION;
}

// Helper function to clean expired cache entries
function cleanExpiredCache(cache: Record<string, CacheEntry<any>>): Record<string, CacheEntry<any>> {
  return Object.entries(cache).reduce((acc, [key, entry]) => {
    if (isCacheValid(entry.timestamp)) {
      acc[key] = entry;
    }
    return acc;
  }, {} as Record<string, CacheEntry<any>>);
}

// Product cache functions
export function cacheProduct(id: string, data: any) {
  productCache.update(cache => ({
    ...cache,
    [id]: { data, timestamp: Date.now() }
  }));
}

export function getCachedProduct(id: string) {
  let result: any = null;
  productCache.subscribe(cache => {
    const entry = cache[id];
    if (entry && isCacheValid(entry.timestamp)) {
      result = entry.data;
    }
  })();
  return result;
}

// Profile cache functions
export function cacheProfile(id: string, data: any) {
  profileCache.update(cache => ({
    ...cache,
    [id]: { data, timestamp: Date.now() }
  }));
}

export function getCachedProfile(id: string) {
  let result: any = null;
  profileCache.subscribe(cache => {
    const entry = cache[id];
    if (entry && isCacheValid(entry.timestamp)) {
      result = entry.data;
    }
  })();
  return result;
}

// Credit ledger cache functions
export function cacheCreditLedger(type: string, data: any) {
  creditLedgerCache.update(cache => ({
    ...cache,
    [type]: { data, timestamp: Date.now() }
  }));
}

export function getCachedCreditLedger(type: string) {
  let result: any = null;
  creditLedgerCache.subscribe(cache => {
    const entry = cache[type];
    if (entry && isCacheValid(entry.timestamp)) {
      result = entry.data;
    }
  })();
  return result;
}

// Clean expired cache entries periodically
setInterval(() => {
  productCache.update(cleanExpiredCache);
  profileCache.update(cleanExpiredCache);
  creditLedgerCache.update(cleanExpiredCache);
}, CACHE_DURATION);

// Export derived stores for reactive cache access
export const cachedProducts = derived(productCache, $cache => 
  Object.entries($cache)
    .filter(([_, entry]) => isCacheValid(entry.timestamp))
    .reduce((acc, [key, entry]) => ({ ...acc, [key]: entry.data }), {})
);

export const cachedProfiles = derived(profileCache, $cache =>
  Object.entries($cache)
    .filter(([_, entry]) => isCacheValid(entry.timestamp))
    .reduce((acc, [key, entry]) => ({ ...acc, [key]: entry.data }), {})
);

export const cachedCreditLedger = derived(creditLedgerCache, $cache =>
  Object.entries($cache)
    .filter(([_, entry]) => isCacheValid(entry.timestamp))
    .reduce((acc, [key, entry]) => ({ ...acc, [key]: entry.data }), {})
); 