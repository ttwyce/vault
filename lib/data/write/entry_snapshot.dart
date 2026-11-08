import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../core/crypto/canonical.dart';
import '../db/vault_database.dart';

/// 一条条目的完整快照。
///
/// 这是**同步与合并的唯一交换格式**：oplog payload 是它的密文，
/// 云端 item 文件是它的密文，将来三方合并的 base / local / remote 也是它。
///
/// 为什么不直接用 drift 生成的 `EntryRow`：
///
/// - `EntryRow` 带 `Value<T>` 包装和 drift 的列元数据，序列化出来不稳定
/// - 快照需要**确定性**（同一条内容永远序列化成同样的字节），
///   否则 `content_hash` 会在不同设备上算出不同值，同步会误判成"内容变了"
///
/// 字段名用 snake_case，与 `meta.enc` 和云端格式保持一致 ——
/// 三处格式统一，看日志时不用来回切换心智。
class EntrySnapshot {
  const EntrySnapshot({
    required this.id,
    required this.kind,
    this.title,
    this.body,
    this.meta,
    required this.createdAt,
    required this.updatedAt,
    required this.hlc,
    required this.rev,
    required this.contentHash,
    this.deleted = false,
    this.deletedAt,
  });

  final String id;

  /// `EntryKind.code`
  final int kind;

  final String? title;
  final String? body;

  /// 按 kind 区分的扩展字段 JSON 字符串。写入前会校验是合法 JSON。
  final String? meta;

  final int createdAt;
  final int updatedAt;

  /// 混合逻辑时钟，格式 `0000018F2A3B4C5D:0003:devA`
  final String hlc;

  final int rev;

  /// `sha256(canonical({kind, title, body, meta}))`
  final String contentHash;

  final bool deleted;
  final int? deletedAt;

  /// 计算内容哈希。
  ///
  /// **`meta` 必须先解码再参与哈希**：直接哈希 JSON 字符串的话，
  /// `{"a":1,"b":2}` 和 `{"b":2,"a":1}` 会算出两个不同的哈希，
  /// 而它们在语义上完全一样。`Canonical` 会把键排序，这里只需解码。
  ///
  /// 为什么不含 `updatedAt` / `hlc` / `rev`：这些是"变更的元数据"，
  /// 不是"内容"。把它们算进哈希会让"内容没变但只是被同步了一次"
  /// 也被判定为内容变化，从而制造出无穷的假冲突。
  static String computeContentHash({
    required int kind,
    String? title,
    String? body,
    String? meta,
  }) {
    return Canonical.contentHash(<String, Object?>{
      'kind': kind,
      'title': title ?? '',
      'body': body ?? '',
      'meta': _decodeMeta(meta),
    });
  }

  static Object? _decodeMeta(String? meta) {
    if (meta == null || meta.trim().isEmpty) return null;
    try {
      return jsonDecode(meta);
    } on FormatException catch (e) {
      throw ArgumentError.value(meta, 'meta', 'meta 不是合法 JSON：${e.message}');
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': kind,
        'title': title,
        'body': body,
        'meta': meta,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'hlc': hlc,
        'rev': rev,
        'content_hash': contentHash,
        'deleted': deleted ? 1 : 0,
        'deleted_at': deletedAt,
      };

  /// 确定性字节：喂给加密层与哈希。
  List<int> toCanonicalBytes() => utf8.encode(Canonical.json(toJson()));

  factory EntrySnapshot.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('快照缺少 id');
    }
    final kind = json['kind'];
    if (kind is! int) throw const FormatException('快照缺少 kind');
    final rev = json['rev'];
    if (rev is! int || rev < 1) throw FormatException('快照 rev 非法：$rev');
    final hlc = json['hlc'];
    if (hlc is! String || hlc.isEmpty) throw const FormatException('快照缺少 hlc');

    return EntrySnapshot(
      id: id,
      kind: kind,
      title: json['title'] as String?,
      body: json['body'] as String?,
      meta: json['meta'] as String?,
      createdAt: _int(json, 'created_at'),
      updatedAt: _int(json, 'updated_at'),
      hlc: hlc,
      rev: rev,
      contentHash: json['content_hash'] as String? ?? '',
      deleted: (json['deleted'] as int? ?? 0) != 0,
      deletedAt: json['deleted_at'] as int?,
    );
  }

  factory EntrySnapshot.fromRow(EntryRow row) => EntrySnapshot(
        id: row.id,
        kind: row.kind,
        title: row.title,
        body: row.body,
        meta: row.meta,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        hlc: row.hlc,
        rev: row.rev,
        contentHash: row.contentHash,
        deleted: row.deleted != 0,
        deletedAt: row.deletedAt,
      );

  /// 转成 drift 的插入/更新 companion。`id` 单独传，因为它可能是主键。
  EntriesCompanion toCompanion() => EntriesCompanion(
        id: Value<String>(id),
        kind: Value<int>(kind),
        title: Value<String?>(title),
        body: Value<String?>(body),
        meta: Value<String?>(meta),
        createdAt: Value<int>(createdAt),
        updatedAt: Value<int>(updatedAt),
        hlc: Value<String>(hlc),
        rev: Value<int>(rev),
        contentHash: Value<String>(contentHash),
        deleted: Value<int>(deleted ? 1 : 0),
        deletedAt: Value<int?>(deletedAt),
      );

  EntrySnapshot copyWith({
    String? title,
    String? body,
    String? meta,
    int? updatedAt,
    String? hlc,
    int? rev,
    String? contentHash,
    bool? deleted,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return EntrySnapshot(
      id: id,
      kind: kind,
      title: title ?? this.title,
      body: body ?? this.body,
      meta: meta ?? this.meta,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hlc: hlc ?? this.hlc,
      rev: rev ?? this.rev,
      contentHash: contentHash ?? this.contentHash,
      deleted: deleted ?? this.deleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  static int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  @override
  String toString() => 'EntrySnapshot($id rev=$rev kind=$kind '
      '${deleted ? 'deleted ' : ''}${title ?? '(无标题)'})';
}
