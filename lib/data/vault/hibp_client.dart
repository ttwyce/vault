/// HIBP k-anonymity 的**纯判定层**（docs/09 §8 / docs/11 §4.4）。
///
/// 不联网：只负责「SHA1 怎么切成前 5 位 + 后缀、响应怎么解析、
/// 命中怎么判定、结果怎么缓存」。真实 HTTPS 请求由平台层按这里给出的
/// [HibpRequest] 执行；完整哈希**永远不出设备**（连日志都不写）。
library;

import 'package:crypto/crypto.dart';

import 'credential_models.dart' show hibpHit, hibpPrefix;

/// 一次 k-anonymity 请求的不可变描述。只含前 5 位。
class HibpRequest {
  const HibpRequest({required this.prefix, required this.suffix});

  /// 5 位大写十六进制。
  final String prefix;
  final String suffix;

  /// 平台层用它发 GET，绝不把 [suffix] 拼进 URL。
  String get path => '/range/$prefix';

  static const String endpoint = 'https://api.pwnedpasswords.com/range';
}

/// 缓存项：前缀 → 后缀集合 + 取回时刻。
class HibpCacheEntry {
  const HibpCacheEntry(this.suffixes, this.fetchedAtMs);

  final Set<String> suffixes;
  final int fetchedAtMs;
}

/// 本地判定器。
class HibpChecker {
  HibpChecker({this._cacheTtlMs = sevenDaysMs});

  /// 7 天 = 7 × 24 × 3600 × 1000；写成字面量以保留 const 默认值。
  static const int sevenDaysMs = 604800000;

  final int _cacheTtlMs;
  final Map<String, HibpCacheEntry> _cache = <String, HibpCacheEntry>{};

  /// 从密码明文构造请求。明文只在内存里，调用完即离开作用域。
  HibpRequest requestFor(String password) {
    final hex = sha1.convert(password.codeUnits).toString().toUpperCase();
    return HibpRequest(prefix: hibpPrefix(hex), suffix: hex.substring(5));
  }

  /// 响应体形如 `SUFFIX:COUNT\r\n...`；大小写、多余空白都容错。
  Set<String> parseResponse(String body) {
    final out = <String>{};
    for (final line in body.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final suffix = trimmed.split(':').first.trim().toUpperCase();
      if (suffix.length == 35 && RegExp(r'^[0-9A-F]{35}$').hasMatch(suffix)) {
        out.add(suffix);
      }
    }
    return out;
  }

  /// 缓存新鲜度；过期后平台层应重新取该前缀。
  bool isFresh(String prefix, int nowMs) {
    final entry = _cache[prefix];
    if (entry == null) return false;
    return nowMs - entry.fetchedAtMs < _cacheTtlMs;
  }

  void store(String prefix, Set<String> suffixes, int nowMs) {
    _cache[prefix] = HibpCacheEntry(
      Set<String>.unmodifiable(suffixes),
      nowMs,
    );
  }

  /// 本地判定：只比对后缀，不上传完整哈希。
  bool isBreached(HibpRequest request, int nowMs) {
    final entry = _cache[request.prefix];
    if (entry == null || !isFresh(request.prefix, nowMs)) {
      throw const FormatException('该前缀的响应尚未取回或已过期，不能判定');
    }
    final hex = '${request.prefix}${request.suffix}';
    return hibpHit(hex, entry.suffixes);
  }

  int get cacheSize => _cache.length;

  void clear() => _cache.clear();
}
