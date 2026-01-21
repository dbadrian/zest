class CacheEntry<T> {
  final String key;
  final DateTime cachedAt;
  final DateTime? itemTimestamp;
  final T data; //

  const CacheEntry({
    required this.key,
    required this.data,
    required this.cachedAt,
    required this.itemTimestamp,
  });

  bool isExpired(Duration? ttl) {
    if (ttl == null) return false;
    return DateTime.now().difference(cachedAt) > ttl;
  }

  Duration get age => DateTime.now().difference(cachedAt);

  Map<String, dynamic> toJson(dynamic Function(T) dataEncoder) {
    return {
      'key': key,
      'data': dataEncoder(data),
      'cachedAt': cachedAt.toIso8601String(),
      'itemTimestamp': itemTimestamp?.toIso8601String(),
    };
  }

  factory CacheEntry.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) dataDecoder,
  ) {
    return CacheEntry(
      key: json['key'],
      data: dataDecoder(json['data']),
      cachedAt: DateTime.parse(json['cachedAt']),
      itemTimestamp: json.containsKey("itemTimestamp")
          ? DateTime.tryParse(json['itemTimestamp'])
          : null,
    );
  }

  CacheEntry<T> copyWith({
    String? key,
    T? data,
    DateTime? cachedAt,
    DateTime? updatedAt,
  }) {
    return CacheEntry(
      key: key ?? this.key,
      data: data ?? this.data,
      cachedAt: cachedAt ?? this.cachedAt,
      itemTimestamp: itemTimestamp,
    );
  }
}
