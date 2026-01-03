import 'dart:collection';
import 'cache_entry.dart';

/// LRU in-memory cache
class MemoryCache<T> {
  final int maxSize;
  final LinkedHashMap<String, CacheEntry<T>> _cache;

  MemoryCache({required this.maxSize})
      : _cache = LinkedHashMap<String, CacheEntry<T>>();

  CacheEntry<T>? get(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      // Move to end (most recently used)
      _cache[key] = entry;
    }
    return entry;
  }

  void put(CacheEntry<T> entry) {
    _cache.remove(entry.key);
    _cache[entry.key] = entry;

    // Evict oldest if over capacity
    if (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  void remove(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }

  bool contains(String key) => _cache.containsKey(key);

  int get size => _cache.length;

  List<CacheEntry<T>> get allEntries => _cache.values.toList();
}
