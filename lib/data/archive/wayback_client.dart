/// Wayback availability 响应的**纯判定层**（docs/05 §6.1 / §6.3）。
///
/// 不联网：只解析 `archive.org/wayback/available` 的 JSON、
/// 生成存档 URL、把 API 时间戳转成年月日，并判定「自动提交存档」
/// 是否默认关闭。真实 GET / Save Page Now 由平台层接。
library;

import 'dart:convert';

class WaybackResult {
  const WaybackResult({
    required this.available,
    required this.archiveUrl,
    required this.hint,
    this.timestamp,
  });

  final bool available;
  final String? archiveUrl;
  final String hint;
  final String? timestamp;

  Map<String, Object?> toJson() => <String, Object?>{
        'available': available,
        'archive_url': archiveUrl,
        'hint': hint,
        'timestamp': timestamp,
      };
}

/// 可用性 API 地址（由平台层发起 GET，这里只构造）。
String waybackAvailabilityUrl(String targetUrl) =>
    Uri.https('archive.org', '/wayback/available', <String, String>{
      'url': targetUrl,
    }).toString();

/// 把 `20190312093015` 转成 `2019-03-12`。
String? formatWaybackTimestamp(String? raw) {
  if (raw == null || raw.length < 8 ||
      !RegExp(r'^\d{8,}').hasMatch(raw)) {
    return null;
  }
  return '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}';
}

/// 解析 availability 响应。坏 JSON / 缺 closest / unavailable 都明确处理，
/// 绝不把「解析失败」当成「有存档」。
WaybackResult parseWaybackAvailability(Object? raw, String targetUrl) {
  Map<String, Object?> body;
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const WaybackResult(
          available: false,
          archiveUrl: null,
          hint: '响应格式不对，建议手动提交到 archive.org',
        );
      }
      body = Map<String, Object?>.from(decoded);
    } on Object {
      return const WaybackResult(
        available: false,
        archiveUrl: null,
        hint: '响应无法解析，建议手动提交到 archive.org',
      );
    }
  } else if (raw is Map) {
    body = Map<String, Object?>.from(raw);
  } else {
    return const WaybackResult(
      available: false,
      archiveUrl: null,
      hint: '没有响应，建议手动提交到 archive.org',
    );
  }
  final snapshots = body['archived_snapshots'];
  final closest = snapshots is Map ? snapshots['closest'] : null;
  if (closest is! Map || closest['available'] != true) {
    return const WaybackResult(
      available: false,
      archiveUrl: null,
      hint: '没有找到存档，建议手动提交到 archive.org',
    );
  }
  final timestamp = closest['timestamp'] as String?;
  final direct = closest['url'];
  final fallback = timestamp == null
      ? null
      : 'https://web.archive.org/web/$timestamp/$targetUrl';
  final url = direct is String ? direct : fallback;
  if (url == null) {
    return const WaybackResult(
      available: false,
      archiveUrl: null,
      hint: '存档缺少 URL / 时间戳，建议手动提交到 archive.org',
    );
  }
  final date = formatWaybackTimestamp(timestamp);
  return WaybackResult(
    available: true,
    archiveUrl: url,
    timestamp: timestamp,
    hint: date == null
        ? '已找到存档版本，可打开 archive.org 链接'
        : '已找到 $date 的存档版本，可打开 archive.org 链接',
  );
}

/// §6.3：自动提交存档默认关闭（把 URL 发给第三方必须逐次勾选）。
bool shouldSubmitToWayback({required bool userOptedIn}) => userOptedIn;
