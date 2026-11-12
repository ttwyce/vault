/// 检索结果 5 分钟缓存（docs/07 §7.2）。
///
/// 纯内存、无依赖、不持久化：相同 query 在窗口内复用结果，避免
/// 打字机式刷屏把 FTS 与活动埋点刷爆。真实持久化由平台层决定。
library;


class SearchCacheEntry<T> {
  const SearchCacheEntry({
    required this.value,
    required this.storedAtMs,
  });

  final T value;
  final int storedAtMs;
}

class SearchResultCache<T> {
  SearchResultCache({
    this.ttlMs = 300000,
    this.maxEntries = 32,
  });

  /// 5 分钟（docs/07 §7.2）。
  final int ttlMs;
  final int maxEntries;
  final Map<String, SearchCacheEntry<T>> _entries =
      <String, SearchCacheEntry<T>>{};

  T? read(String query, int nowMs) {
    final key = _key(query);
    final entry = _entries[key];
    if (entry == null) return null;
    if (nowMs - entry.storedAtMs > ttlMs) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  void write(String query, T value, int nowMs) {
    if (_entries.length >= maxEntries) {
      // 简单 FIFO 淘汰：map 保序，删最早写入的一条。
      _entries.remove(_entries.keys.first);
    }
    _entries[_key(query)] =
        SearchCacheEntry<T>(value: value, storedAtMs: nowMs);
  }

  void clear() => _entries.clear();

  /// 只用查询词归一化做 key；TTL 由 [storedAtMs] 独立判定，
  /// 避免「5 分钟分桶」与「5 分钟 TTL」窗口错位导致边界提前失效。
  static String _key(String query) => query.trim().toLowerCase();

  int get length => _entries.length;
}
