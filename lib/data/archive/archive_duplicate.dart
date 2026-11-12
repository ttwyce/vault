/// 归档 URL 去重判定（docs/05 §4 第 1 步）。
///
/// 不联网、不写库：规范化 URL 后与已有条目的 url/finalUrl 比对，
/// 输出「新增 / 已归档（提示是否更新快照）/ 非法」。
/// 真实抓取与快照更新由平台层按计划执行。
library;

enum ArchiveDuplicateAction { create, askUpdate, invalid }

class ArchiveDuplicatePlan {
  const ArchiveDuplicatePlan({
    required this.action,
    required this.normalizedUrl,
    required this.reason,
    this.existingEntryId,
  });

  final ArchiveDuplicateAction action;
  final String normalizedUrl;
  final String reason;
  final String? existingEntryId;

  Map<String, Object?> toJson() => <String, Object?>{
        'action': action.name,
        'url': normalizedUrl,
        'reason': reason,
        'existing_entry_id': existingEntryId,
      };
}

const Set<String> _trackingParams = <String>{
  'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
  'gclid', 'fbclid', 'spm', 'from',
};

/// 规范化：小写 host、去 fragment、去跟踪参数、去尾斜杠与默认端口。
/// 只接受 http/https；坏 URL 返回 null。
String? normalizeArchiveUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  final isDefaultPort =
      (scheme == 'http' && uri.port == 80) ||
      (scheme == 'https' && uri.port == 443);
  final query = <String, String>{
    for (final entry in uri.queryParameters.entries)
      if (!_trackingParams.contains(entry.key.toLowerCase())) entry.key: entry.value,
  };
  var path = uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return Uri(
    scheme: scheme,
    host: host,
    port: uri.hasPort && !isDefaultPort ? uri.port : null,
    path: path.isEmpty ? '/' : path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

/// 与已有归档比对。
ArchiveDuplicatePlan planArchiveDuplicate({
  required String rawUrl,
  required List<({String entryId, String url, String? finalUrl})> existing,
}) {
  final normalized = normalizeArchiveUrl(rawUrl);
  if (normalized == null) {
    return const ArchiveDuplicatePlan(
      action: ArchiveDuplicateAction.invalid,
      normalizedUrl: '',
      reason: 'URL 必须是完整的 http/https 地址',
    );
  }
  for (final item in existing) {
    for (final candidate in <String?>[item.url, item.finalUrl]) {
      if (candidate == null) continue;
      if (normalizeArchiveUrl(candidate) == normalized) {
        return ArchiveDuplicatePlan(
          action: ArchiveDuplicateAction.askUpdate,
          normalizedUrl: normalized,
          reason: '这条 URL 已归档过，是否更新快照？',
          existingEntryId: item.entryId,
        );
      }
    }
  }
  return ArchiveDuplicatePlan(
    action: ArchiveDuplicateAction.create,
    normalizedUrl: normalized,
    reason: '新 URL，进入抓取流水线',
  );
}
