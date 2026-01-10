import 'dart:async';

import 'cache_entry.dart';
import 'cache_strategy.dart';
import 'memory_cache.dart';
import 'persistent_cache.dart';

/// Result of a cache operation
sealed class CacheResult<T> {
  const CacheResult();
}

class CacheHit<T> extends CacheResult<T> {
  final CacheEntry<T> entry;
  final CacheSource source;

  const CacheHit(this.entry, this.source);
}

class CacheMiss<T> extends CacheResult<T> {
  const CacheMiss();
}

enum CacheSource { memory, persistent }

/// Unified cache manager with memory + persistent storage
class CacheManager<T> {
  final String tableName;
  final CacheConfig config;
  final T Function(dynamic) decoder;
  final dynamic Function(T) encoder;

  late final MemoryCache<T> _memoryCache;
  final PersistentCache _persistentCache;

  // Track in-flight network requests to prevent duplicate fetches
  final Map<String, Future<T>> _inFlightRequests = {};

  CacheManager({
    required this.tableName,
    required this.config,
    required this.decoder,
    required this.encoder,
    required PersistentCache persistentCache,
  }) : _persistentCache = persistentCache {
    _memoryCache = MemoryCache<T>(maxSize: config.maxMemoryItems ?? 100);
  }

  /// Get item from cache (memory first, then persistent)
  Future<CacheResult<T>> get(String key) async {
    // Try memory cache first
    final memoryEntry = _memoryCache.get(key);
    if (memoryEntry != null) {
      if (!memoryEntry.isExpired(config.ttl)) {
        return CacheHit(memoryEntry, CacheSource.memory);
      } else {
        // Expired in memory, remove it
        _memoryCache.remove(key);
      }
    }

    // Try persistent cache
    final persistentEntry = await _persistentCache.get(tableName, key, decoder);
    if (persistentEntry != null) {
      if (!persistentEntry.isExpired(config.ttl)) {
        // Promote to memory cache
        _memoryCache.put(persistentEntry);
        return CacheHit(persistentEntry, CacheSource.persistent);
      } else {
        // Expired, remove from persistent
        await _persistentCache.remove(tableName, key);
      }
    }

    return const CacheMiss();
  }

  /// Put item in cache (both memory and persistent)
  Future<void> put(CacheEntry<T> entry) async {
    _memoryCache.put(entry);
    await _persistentCache.put(tableName, entry, encoder);
  }

  /// Get all cached items
  Future<List<CacheEntry<T>>> getAll() async {
    final entries = await _persistentCache.getAll(tableName, decoder);

    // Filter out expired entries
    final validEntries =
        entries.where((e) => !e.isExpired(config.ttl)).toList();

    // Promote frequently accessed items to memory
    for (final entry in validEntries.take(config.maxMemoryItems ?? 100)) {
      if (!_memoryCache.contains(entry.key)) {
        _memoryCache.put(entry);
      }
    }

    return validEntries;
  }

  /// Remove item from cache
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    await _persistentCache.remove(tableName, key);
  }

  /// Clear all cached items for this table
  Future<void> clear() async {
    _memoryCache.clear();
    await _persistentCache.removeTable(tableName);
  }

  /// Remove expired entries
  Future<void> removeExpired() async {
    if (config.ttl != null) {
      await _persistentCache.removeExpired(tableName, config.ttl!);
    }
  }

  /// Get cached item count
  Future<int> getCount() async {
    return await _persistentCache.getCount(tableName);
  }

  /// Fetch with cache strategy
  ///
  /// This is the main method that implements the caching logic
  /// SAFE: Never deletes cache before successful fetch
  Future<T> fetch({
    required String key,
    required Future<T> Function() fetcher,
    bool forceRefresh = false,
  }) async {
    // Deduplicate concurrent requests for the same key
    if (_inFlightRequests.containsKey(key)) {
      return _inFlightRequests[key]!;
    }

    final request = _fetchInternal(
      key: key,
      fetcher: fetcher,
      forceRefresh: forceRefresh,
    );

    _inFlightRequests[key] = request;

    try {
      return await request;
    } finally {
      _inFlightRequests.remove(key);
    }
  }

  Future<T> _fetchInternal({
    required String key,
    required Future<T> Function() fetcher,
    required bool forceRefresh,
  }) async {
    if (forceRefresh) {
      // Force refresh - fetch new data but DON'T delete cache first
      return _fetchAndCache(key, fetcher);
    }

    switch (config.strategy) {
      case CacheStrategy.noCache:
        return fetcher();

      case CacheStrategy.cacheFirst:
        return _cacheFirst(key, fetcher);

      case CacheStrategy.networkFirst:
        return _networkFirst(key, fetcher);

      case CacheStrategy.staleWhileRevalidate:
        return _staleWhileRevalidate(key, fetcher);
    }
  }

  Future<T> _cacheFirst(String key, Future<T> Function() fetcher) async {
    final cached = await get(key);

    if (cached is CacheHit<T>) {
      return cached.entry.data;
    }

    return _fetchAndCache(key, fetcher);
  }

  Future<T> _networkFirst(String key, Future<T> Function() fetcher) async {
    try {
      return await _fetchAndCache(key, fetcher);
    } catch (e) {
      // Network failed, try cache as fallback
      final cached = await get(key);
      if (cached is CacheHit<T>) {
        return cached.entry.data;
      }
      rethrow;
    }
  }

  Future<T> _staleWhileRevalidate(
    String key,
    Future<T> Function() fetcher,
  ) async {
    final cached = await get(key);

    if (cached is CacheHit<T>) {
      // Return cached data immediately
      final data = cached.entry.data;

      // Refresh in background (fire and forget)
      // If refresh fails, cache remains unchanged
      unawaited(
        _fetchAndCache(key, fetcher).catchError((_) {
          // Silently ignore background refresh errors
          // Cache remains valid
        }),
      );

      return data;
    }

    // No cache, fetch from network
    return _fetchAndCache(key, fetcher);
  }

  Future<T> _fetchAndCache(String key, Future<T> Function() fetcher) async {
    // Fetch new data first
    final data = await fetcher();

    // SUCCESS: Only now update cache
    var itemTimestamp = DateTime.now();
    try {
      final obj = data as dynamic;
      itemTimestamp = obj.updatedAt;
    } catch (e) {
      // pass
    }
    final entry = CacheEntry<T>(
      key: key,
      data: data,
      cachedAt: DateTime.now(),
      itemTimestamp: itemTimestamp,
    );

    await put(entry);

    return data;
  }

  /// Batch fetch multiple items
  Future<List<T>> fetchBatch({
    required List<String> keys,
    required Future<List<T>> Function(List<String> missingKeys) fetcher,
    String Function(T)? keyExtractor,
  }) async {
    final results = <String, T>{};
    final missingKeys = <String>[];

    // Check cache for each key
    for (final key in keys) {
      final cached = await get(key);
      if (cached is CacheHit<T>) {
        results[key] = cached.entry.data;
      } else {
        missingKeys.add(key);
      }
    }

    // Fetch missing items
    if (missingKeys.isNotEmpty) {
      final fetchedItems = await fetcher(missingKeys);

      // Cache fetched items
      for (final item in fetchedItems) {
        final key =
            keyExtractor?.call(item) ?? missingKeys[fetchedItems.indexOf(item)];

        var itemTimestamp = DateTime.now();
        try {
          final obj = item as dynamic;
          itemTimestamp = obj.updatedAt;
        } catch (e) {
          // pass
        }

        final entry = CacheEntry<T>(
          key: key,
          data: item,
          cachedAt: DateTime.now(),
          itemTimestamp: itemTimestamp,
        );

        await put(entry);
        results[key] = item;
      }
    }

    // Return in original order
    return keys.map((key) => results[key]!).toList();
  }
}

// Helper to not await futures
void unawaited(Future<void> future) {
  // Ignore
}
