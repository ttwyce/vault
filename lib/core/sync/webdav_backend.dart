/// WebDAV 后端抽象与能力探测（docs/04 §1 / §3.2）。
///
/// 这一层刻意**不 import 任何 WebDAV 包**：真实 HTTP 实现以后再注入，
/// 现在先把「同步引擎允许后端做什么、什么请求绝对不能发」写成类型约束。
/// 尤其是条件写：接口层就不存在无条件 PUT / DELETE 的调用形态。
library;

import 'change_diff.dart';
import 'cloud_layout.dart';
import 'sync_state_machine.dart';

/// 能力探测结果缓存 24 小时（docs/04 §3.2）。
const Duration kWebDavCapabilityCacheTtl = Duration(hours: 24);

/// 全局最多 3 个并发 HTTP 请求（docs/04 §10）。
const int kWebDavMaxConcurrentRequests = 3;

/// L2 的两条发现路径。
enum WebDavDiscoveryStrategy {
  /// RFC 6578 `REPORT sync-collection`：1 个请求拿到增量与删除列表。
  syncCollection,

  /// 不支持 REPORT 时，16 个分片各做一次 PROPFIND Depth:1。
  shardedPropfind,
}

/// 条件写。**必须二选一**：`If-Match: <etag>` 或 `If-None-Match: *`。
///
/// 把条件做成类型，而不是两个可空参数，是为了让「忘了带条件」
/// 在编译期就不可能表达。工程红线 1：禁止无条件 PUT。
class WebDavCondition {
  const WebDavCondition.ifMatch(String etag)
      : ifMatchEtag = etag,
        isCreateOnly = false;

  const WebDavCondition.createOnly()
      : ifMatchEtag = null,
        isCreateOnly = true;

  final String? ifMatchEtag;
  final bool isCreateOnly;

  bool get isValid =>
      (ifMatchEtag != null && ifMatchEtag!.isNotEmpty && !isCreateOnly) ||
      (ifMatchEtag == null && isCreateOnly);

  String get headerValue => isCreateOnly ? '*' : ifMatchEtag!;

  String get headerName => isCreateOnly ? 'If-None-Match' : 'If-Match';

  @override
  String toString() => '$headerName: $headerValue';
}

/// PROPFIND 返回的一项。**判据是 etag，不是 mtime**。
class WebDavListing {
  const WebDavListing({
    required this.path,
    required this.etag,
    this.size,
    this.isCollection = false,
  });

  final String path;
  final String? etag;
  final int? size;
  final bool isCollection;
}

class WebDavGetResult {
  const WebDavGetResult({required this.bytes, required this.etag});

  final List<int> bytes;
  final String etag;
}

class WebDavPutResult {
  const WebDavPutResult({required this.etag, required this.statusCode});

  final String etag;
  final int statusCode;
}

/// `REPORT sync-collection` 的增量结果。
class SyncCollectionDelta {
  const SyncCollectionDelta({
    required this.changed,
    required this.deleted,
    required this.syncToken,
  });

  /// path → 最新 etag。
  final Map<String, String?> changed;

  /// 服务器明确给出的删除列表，不从目录缺失里猜。
  final Set<String> deleted;
  final String syncToken;
}

class WebDavException implements Exception {
  const WebDavException({
    required this.statusCode,
    required this.method,
    required this.path,
    this.message,
  });

  final int statusCode;
  final String method;
  final String path;
  final String? message;

  bool get isPreconditionFailed => statusCode == 412;

  SyncErrorCode get syncErrorCode => syncErrorCodeForStatus(statusCode);

  @override
  String toString() => 'WebDavException($method $path → $statusCode'
      '${message == null ? '' : ': $message'})';
}

class WebDavPreconditionFailed extends WebDavException {
  const WebDavPreconditionFailed({
    required super.method,
    required super.path,
    super.message,
  }) : super(statusCode: 412);
}

/// OPTIONS 探测出的服务器能力。
class WebDavCapabilities {
  const WebDavCapabilities({
    required this.davTokens,
    required this.syncCollection,
    required this.conditionalPut,
    required this.depthOnePropfind,
    this.maxConcurrentRequests = kWebDavMaxConcurrentRequests,
  });

  final List<String> davTokens;
  final bool syncCollection;
  final bool conditionalPut;
  final bool depthOnePropfind;
  final int maxConcurrentRequests;

  WebDavDiscoveryStrategy get discoveryStrategy => syncCollection
      ? WebDavDiscoveryStrategy.syncCollection
      : WebDavDiscoveryStrategy.shardedPropfind;

  Duration get cacheTtl => kWebDavCapabilityCacheTtl;

  /// 能力探测缓存是否过期。边界当天仍有效。
  bool isCacheExpired(int lastCheckedMs, int nowMs) =>
      nowMs - lastCheckedMs > kWebDavCapabilityCacheTtl.inMilliseconds;
}

/// 从 OPTIONS 响应头解析能力。
///
/// `DAV: 1, 3, sync-collection` 支持 RFC 6578；只有 `DAV: 1` 时降级到
/// 16 分片 PROPFIND。HTTP 头大小写不敏感，所以这里统一转小写查表。
WebDavCapabilities detectWebDavCapabilities(Map<String, String> headers) {
  final davTokens = _davTokens(_header(headers, 'DAV'));
  final allow = (_header(headers, 'Allow') ?? '').toUpperCase();
  final etag = _header(headers, 'ETag');
  final hasDavClass = davTokens.any(
    (String token) => token == '1' || token == '2' || token == '3',
  );

  return WebDavCapabilities(
    davTokens: davTokens,
    syncCollection: davTokens.contains('sync-collection'),
    conditionalPut:
        (etag != null && etag.trim().isNotEmpty) || hasDavClass || allow.contains('PUT'),
    depthOnePropfind: hasDavClass || allow.contains('PROPFIND'),
  );
}

/// HTTP/WebDAV 状态码 → 项目统一错误码（docs/04 §7）。
SyncErrorCode syncErrorCodeForStatus(int statusCode) {
  if (statusCode == 401 || statusCode == 403) return SyncErrorCode.auth;
  if (statusCode == 412) return SyncErrorCode.conflict;
  if (statusCode == 429 || statusCode == 503) return SyncErrorCode.rate;
  if (statusCode == 507) return SyncErrorCode.quota;
  if (statusCode == 404 || statusCode == 409) return SyncErrorCode.path;
  if (statusCode >= 500) return SyncErrorCode.net;
  return SyncErrorCode.path;
}

String? _header(Map<String, String> headers, String name) {
  final lower = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return null;
}

List<String> _davTokens(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <String>[];
  return <String>[
    for (final part in raw.split(','))
      if (part.trim().isNotEmpty) part.trim().toLowerCase(),
  ];
}

/// PROPFIND 列表 → `path → etag`，集合目录本身不参与 diff。
Map<String, String?> listingsToEtags(Iterable<WebDavListing> listings) =>
    <String, String?>{
      for (final listing in listings)
        if (!listing.isCollection) listing.path: listing.etag,
    };

/// 把 `sync-collection` 的增量结果转成 L2 diff。
///
/// 服务器给了明确删除列表，所以本地映射里"没出现在 changed"的路径
/// 不能算删除；只有 delta.deleted 才是删除。
SyncDiff diffSyncCollection({
  required SyncCollectionDelta delta,
  required Map<String, String?> local,
}) {
  final partial = diffListings(
    remote: delta.changed,
    local: local,
    includeDeletes: false,
  );
  return withServerDeletes(partial, delta.deleted);
}

/// 16 个分片**全部**列举完才能推断删除。
///
/// 少一个分片就调用这里，会把没扫到的文件误判成远端删除，
/// 进而删掉本地数据 —— 这是 M3 最危险的静默数据丢失路径之一。
SyncDiff diffAllShards({
  required Map<String, List<WebDavListing>> shards,
  required Map<String, String?> local,
}) {
  if (shards.length != CloudLayout.shardCount) {
    throw ArgumentError.value(
      shards.length,
      'shards.length',
      '必须完整扫描 ${CloudLayout.shardCount} 个分片',
    );
  }
  for (final shard in shards.keys) {
    final value = shard.length == 1 ? int.tryParse(shard, radix: 16) : null;
    if (value == null || value >= CloudLayout.shardCount) {
      throw ArgumentError.value(shard, 'shards.key', '分片名必须是 0~f');
    }
  }

  final all = <WebDavListing>[
    for (final listings in shards.values) ...listings,
  ];
  return diffListings(remote: listingsToEtags(all), local: local);
}

/// 同步引擎看到的后端边界。
///
/// 真实实现可以是 `webdav_plus` / `dart_webdav` / 平台通道；
/// 测试实现是内存 Map。引擎只依赖这组方法，不依赖任何 HTTP 客户端类型。
abstract interface class WebDavBackend {
  /// `OPTIONS /vault/`：能力探测，结果缓存 24 小时。
  Future<Map<String, String>> options(String path);

  /// `PROPFIND`：目录清单。只读 etag / size，不读 mtime 作为判据。
  Future<List<WebDavListing>> propfind(String path, {int depth = 1});

  /// `REPORT sync-collection`：支持 RFC 6578 时的 1 请求增量发现。
  Future<SyncCollectionDelta> reportSyncCollection(
    String path, {
    String? syncToken,
  });

  /// `GET`：返回字节与当前 ETag，后续 PUT 用它做 If-Match。
  Future<WebDavGetResult> get(String path);

  /// 条件写。接口强制要求 [WebDavCondition]，不存在无条件 PUT。
  Future<WebDavPutResult> put(
    String path,
    List<int> bytes, {
    required WebDavCondition condition,
  });

  /// 条件删。删除条目文件前必须已经写过墓碑，且必须带 ETag。
  Future<void> delete(String path, {required String ifMatch});

  /// 目录不存在时自动重建；实现必须幂等。
  Future<void> mkcol(String path);
}
