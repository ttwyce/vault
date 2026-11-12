/// 阅读器高亮标注写回 `entry(kind=5).meta`（docs/05 §9）。
///
/// 走唯写入口 [WriteGateway.writeEntry]：读旧快照 → 合并/去重高亮 →
/// 整体替换 meta（保留 title/body）→ 生成新版本与 oplog。
/// 不直接 UPDATE，避免绕过信封加密 / FTS / 活动埋点。
library;

import 'dart:convert';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import 'archive_meta.dart';
import 'archive_reader.dart' show mergeHighlights;
import '../write/write_gateway.dart';

class ArchiveHighlightWriter {
  const ArchiveHighlightWriter({
    required this.db,
    required this.gateway,
  });

  final VaultDatabase db;
  final WriteGateway gateway;

  /// 追加一段高亮；重叠区间由 [mergeHighlights] 合并。
  /// 返回是否真的产生了变更（完全相同的高亮是幂等空操作）。
  Future<bool> addHighlight(String entryId, ArchiveHighlight highlight) async {
    final row = await (db.select(db.entries)
          ..where((t) => t.id.equals(entryId)))
        .getSingleOrNull();
    if (row == null || row.deleted != 0 ||
        row.kind != EntryKind.bookmark.code) {
      throw const WriteException('not_found', '归档条目不存在或已删除');
    }
    final ArchiveMeta meta;
    try {
      meta = ArchiveMeta.fromJson(
        row.meta == null ? null : jsonDecode(row.meta!),
      );
    } on Object {
      throw const WriteException('invalid', '归档 meta 无法解析，拒绝覆盖');
    }
    final merged = mergeHighlights(<ArchiveHighlight>[
      ...meta.highlights,
      highlight,
    ]);
    final next = meta.copyWith(highlights: merged);
    final result = await gateway.writeEntry(EntryWrite.update(
      id: entryId,
      title: row.title,
      body: row.body,
      meta: next.toJsonString(),
    ));
    return result.changed;
  }

  /// 清空全部高亮（同样走唯一写入口）。
  Future<bool> clearHighlights(String entryId) async {
    final row = await (db.select(db.entries)
          ..where((t) => t.id.equals(entryId)))
        .getSingleOrNull();
    if (row == null || row.deleted != 0 ||
        row.kind != EntryKind.bookmark.code) {
      throw const WriteException('not_found', '归档条目不存在或已删除');
    }
    final ArchiveMeta meta;
    try {
      meta = ArchiveMeta.fromJson(
        row.meta == null ? null : jsonDecode(row.meta!),
      );
    } on Object {
      throw const WriteException('invalid', '归档 meta 无法解析，拒绝覆盖');
    }
    if (meta.highlights.isEmpty) return false;
    final result = await gateway.writeEntry(EntryWrite.update(
      id: entryId,
      title: row.title,
      body: row.body,
      meta: meta.copyWith(highlights: const <ArchiveHighlight>[]).toJsonString(),
    ));
    return result.changed;
  }
}
