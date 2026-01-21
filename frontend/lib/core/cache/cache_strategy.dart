/// Cache strategy for different resource types
enum CacheStrategy {
  /// No caching - always fetch from network
  noCache,

  /// Cache first, network if missing
  cacheFirst,

  /// Network first, cache as fallback (for offline)
  networkFirst,

  /// Show cache immediately, refresh in background
  staleWhileRevalidate,
}

/// Cache configuration for a resource type
class CacheConfig {
  /// Cache strategy to use
  final CacheStrategy strategy;

  /// Time-to-live for cached data (null = never expire)
  final Duration? ttl;

  /// Whether to pre-cache this resource on startup
  final bool preCache;

  /// Maximum number of items to keep in memory cache
  final int? maxMemoryItems;

  const CacheConfig({
    required this.strategy,
    this.ttl,
    this.preCache = false,
    this.maxMemoryItems,
  });

  /// Static resources that rarely change (units, categories)
  static const staticResource = CacheConfig(
    strategy: CacheStrategy.cacheFirst,
    ttl: Duration(days: 7),
    preCache: true,
    maxMemoryItems: 1000,
  );

  /// Dynamic resources with background refresh (recipes, foods)
  static const dynamicResource = CacheConfig(
    strategy: CacheStrategy.staleWhileRevalidate,
    ttl: Duration(hours: 24),
    preCache: false,
    maxMemoryItems: 500,
  );

  /// User-generated content (user's recipes)
  static const userContent = CacheConfig(
    strategy: CacheStrategy.networkFirst,
    ttl: Duration(minutes: 30),
    preCache: false,
    maxMemoryItems: 100,
  );
}
