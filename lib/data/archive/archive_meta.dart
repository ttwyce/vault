

/// kind=5 网页归档的 `entry.meta` 结构（docs/13 §3 / docs/11 §3.3）。
///
/// 这是归档子系统**唯一的交换格式**：页面、策略引擎、死链检测、按需下载
/// 都读它。所有扩展字段只进 `meta` JSON，不给 `entry` 表加列。
///
/// 「解析即校验」：手写 / 旧版本 / 被篡改的 meta 不会带着非法枚举值流进
/// 业务层，而是在边界上直接抛 [FormatException]，由调用方隔离或降级。

library;

import 'dart:convert';
import '../../core/crypto/canonical.dart';

/// 归档状态。docs/11 §3.3 的七个值，另加 `none`（仅建了空条目）。
enum ArchiveStatus {
  none('none'),
  metadata('metadata'),
  text('text'),
  full('full'),
  blocked('blocked'),
  paywalled('paywalled'),
  dead('dead');

  const ArchiveStatus(this.wire);

  final String wire;

  static ArchiveStatus? fromWire(String? value) {
    if (value == null) return null;
    for (final status in ArchiveStatus.values) {
      if (status.wire == value) return status;
    }
    return null;
  }

  /// 是否已经保存了 L1 正文层（检索与 AI 的唯一输入源）。
  bool get hasText =>
      this == ArchiveStatus.text ||
      this == ArchiveStatus.full ||
      this == ArchiveStatus.blocked ||
      this == ArchiveStatus.paywalled;

  /// 是否持有 L2/L3 快照或原始层（占空间、可降级）。
  bool get hasSnapshot => this == ArchiveStatus.full;

  /// 原站已不可读，阅读器应直接回退快照 / 正文。
  bool get isDeadLink => this == ArchiveStatus.dead;
}

/// 重检查策略。
enum RecheckPolicy {
  weekly('weekly'),
  monthly('monthly'),
  never('never');

  const RecheckPolicy(this.wire);

  final String wire;

  static RecheckPolicy? fromWire(String? value) {
    if (value == null) return null;
    for (final policy in RecheckPolicy.values) {
      if (policy.wire == value) return policy;
    }
    return null;
  }

  Duration? get interval => switch (this) {
        RecheckPolicy.weekly => const Duration(days: 7),
        RecheckPolicy.monthly => const Duration(days: 30),
        RecheckPolicy.never => null,
      };
}

/// 死链检查 / 内容变更检查的结果。
enum LinkCheckResult {
  ok('ok'),
  dead('dead'),
  restricted('restricted'),
  unreachable('unreachable'),
  changed('changed');

  const LinkCheckResult(this.wire);

  final String wire;
}

/// 归档 blob 的层级（与 `blob_ref.kind` 一致）。
enum ArchiveBlobKind {
  text(1),
  pdf(2),
  html(3),
  image(4),
  favicon(5);

  const ArchiveBlobKind(this.code);

  final int code;
}

class ArchiveMeta {
  const ArchiveMeta({
    required this.url,
    required this.site,
    required this.status,
    this.finalUrl,
    this.title,
    this.author,
    this.publishedAt,
    this.httpStatus,
    this.lastCheckedAt,
    this.policy = RecheckPolicy.monthly,
    this.snapshotBytes = 0,
    this.readingTimeMin = 0,
    this.excerpt = '',
    this.changed = false,
    this.waybackUrl,
    this.watchChanges = false,
    this.highlights = const <ArchiveHighlight>[],
  });

  /// 原始 URL。必填且必须是 http/https。
  final String url;

  /// 站点聚合键（去掉 www、端口与路径的主机名）。
  final String site;

  final ArchiveStatus status;
  final String? finalUrl;
  final String? title;
  final String? author;
  final int? publishedAt;
  final int? httpStatus;
  final int? lastCheckedAt;
  final RecheckPolicy policy;
  final int snapshotBytes;
  final int readingTimeMin;
  final String excerpt;
  final bool changed;
  final String? waybackUrl;
  final bool watchChanges;
  final List<ArchiveHighlight> highlights;

  /// docs/05 §10：列表页展示摘要时不能去读 blob，所以归档时就把
  /// 前 200 字存进 meta。
  static const int maxExcerptChars = 200;

  static String siteOf(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException('归档 URL 不合法：$rawUrl');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FormatException('归档 URL 只支持 http/https：$rawUrl');
    }
    final host = uri.host.toLowerCase();
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'url': url,
        'final_url': finalUrl,
        'site': site,
        'title': title,
        'author': author,
        'published_at': publishedAt,
        'archive_status': status.wire,
        'http_status': httpStatus,
        'last_checked_at': lastCheckedAt,
        'recheck_policy': policy.wire,
        'snapshot_bytes': snapshotBytes,
        'reading_time_min': readingTimeMin,
        'excerpt': excerpt,
        'changed': changed,
        'wayback_url': waybackUrl,
        'watch_changes': watchChanges,
        'highlights': <Map<String, Object?>>[
          for (final highlight in highlights) highlight.toJson(),
        ],
      };

  /// 确定性字节：写入 `entry.meta` 用。键序由 Canonical 保证。
  String toJsonString() => Canonical.json(toJson());

  factory ArchiveMeta.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('归档 meta 不是 JSON 对象');
    }
    final map = Map<String, Object?>.from(raw);
    final url = map['url'];
    if (url is! String || url.isEmpty) {
      throw const FormatException('归档 meta 缺少 url');
    }
    // site 缺失时从 url 推；存在时也要与 url 一致，避免列表聚合错乱。
    final derivedSite = siteOf(url);
    final site = map['site'];
    if (site != null && site is! String) {
      throw const FormatException('归档 meta 的 site 必须是字符串');
    }
    final status = ArchiveStatus.fromWire(map['archive_status'] as String?);
    if (status == null) {
      throw FormatException(
        '归档 meta 的 archive_status 非法：${map['archive_status']}',
      );
    }
    final policyRaw = map['recheck_policy'];
    final policy = policyRaw == null
        ? RecheckPolicy.monthly
        : RecheckPolicy.fromWire(policyRaw as String?);
    if (policy == null) {
      throw FormatException('归档 meta 的 recheck_policy 非法：$policyRaw');
    }
    final excerpt = map['excerpt'];
    if (excerpt != null && excerpt is! String) {
      throw const FormatException('归档 meta 的 excerpt 必须是字符串');
    }
    final excerptText = (excerpt as String?) ?? '';
    if (excerptText.length > maxExcerptChars) {
      throw const FormatException('归档 meta 的 excerpt 超过 200 字');
    }

    return ArchiveMeta(
      url: url,
      site: (site as String?) ?? derivedSite,
      status: status,
      finalUrl: _nullableString(map, 'final_url'),
      title: _nullableString(map, 'title'),
      author: _nullableString(map, 'author'),
      publishedAt: _nullableInt(map, 'published_at'),
      httpStatus: _nullableInt(map, 'http_status'),
      lastCheckedAt: _nullableInt(map, 'last_checked_at'),
      policy: policy,
      snapshotBytes: _int(map, 'snapshot_bytes'),
      readingTimeMin: _int(map, 'reading_time_min'),
      excerpt: excerptText,
      changed: map['changed'] == true,
      waybackUrl: _nullableString(map, 'wayback_url'),
      watchChanges: map['watch_changes'] == true,
      highlights: _highlights(map['highlights']),
    );
  }

  /// 从 `entry.meta` 字符串解析。空串按「仅元数据」处理，不抛错。
  factory ArchiveMeta.fromMetaString(
    String? meta, {
    required String fallbackUrl,
  }) {
    if (meta == null || meta.trim().isEmpty) {
      return ArchiveMeta(
        url: fallbackUrl,
        site: siteOf(fallbackUrl),
        status: ArchiveStatus.metadata,
      );
    }
    final decoded = jsonDecode(meta);
    return ArchiveMeta.fromJson(decoded);
  }

  ArchiveMeta copyWith({
    String? url,
    ArchiveStatus? status,
    String? finalUrl,
    String? title,
    String? author,
    int? publishedAt,
    int? httpStatus,
    int? lastCheckedAt,
    RecheckPolicy? policy,
    int? snapshotBytes,
    int? readingTimeMin,
    String? excerpt,
    bool? changed,
    String? waybackUrl,
    bool? watchChanges,
    List<ArchiveHighlight>? highlights,
    bool clearLastCheckedAt = false,
  }) {
    final nextUrl = url ?? this.url;
    return ArchiveMeta(
      url: nextUrl,
      site: siteOf(nextUrl),
      status: status ?? this.status,
      finalUrl: finalUrl ?? this.finalUrl,
      title: title ?? this.title,
      author: author ?? this.author,
      publishedAt: publishedAt ?? this.publishedAt,
      httpStatus: httpStatus ?? this.httpStatus,
      lastCheckedAt: clearLastCheckedAt
          ? null
          : (lastCheckedAt ?? this.lastCheckedAt),
      policy: policy ?? this.policy,
      snapshotBytes: snapshotBytes ?? this.snapshotBytes,
      readingTimeMin: readingTimeMin ?? this.readingTimeMin,
      excerpt: excerpt ?? this.excerpt,
      changed: changed ?? this.changed,
      waybackUrl: waybackUrl ?? this.waybackUrl,
      watchChanges: watchChanges ?? this.watchChanges,
      highlights: highlights ?? this.highlights,
    );
  }

  /// 页面常用便捷判定，避免在 UI 里到处写 `meta.status.xxx`。
  bool get hasText => status.hasText;
  bool get hasSnapshot => status.hasSnapshot;
  bool get isDeadLink => status.isDeadLink;

  /// 下一次该检查的时间戳；`never` 返回 null（不排任务）。
  int? nextCheckAt() {
    final last = lastCheckedAt;
    if (last == null) return null;
    final interval = policy.interval;
    if (interval == null) return null;
    return last + interval.inMilliseconds;
  }

  static String? _nullableString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('归档 meta 的 $key 必须是字符串');
    }
    return value;
  }

  static int? _nullableInt(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('归档 meta 的 $key 必须是整数');
  }

  static int _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('归档 meta 的 $key 必须是整数');
  }

  static List<ArchiveHighlight> _highlights(Object? raw) {
    if (raw == null) return const <ArchiveHighlight>[];
    if (raw is! List) {
      throw const FormatException('归档 meta 的 highlights 必须是数组');
    }
    return <ArchiveHighlight>[
      for (final item in raw)
        ArchiveHighlight.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }
}

/// 阅读器高亮标注（docs/05 §9）。
class ArchiveHighlight {
  const ArchiveHighlight({
    required this.text,
    required this.offset,
    this.note,
  });

  final String text;
  final int offset;
  final String? note;

  Map<String, Object?> toJson() => <String, Object?>{
        'text': text,
        'offset': offset,
        'note': note,
      };

  factory ArchiveHighlight.fromJson(Map<String, Object?> json) {
    final text = json['text'];
    final offset = json['offset'];
    if (text is! String || offset is! int || offset < 0) {
      throw const FormatException('归档高亮字段不合法');
    }
    return ArchiveHighlight(
      text: text,
      offset: offset,
      note: json['note'] as String?,
    );
  }
}
