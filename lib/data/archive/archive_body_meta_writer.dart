/// 归档正文派生 meta 的懒补齐（docs/05 §10）。
///
/// 走唯一写入口 [WriteGateway.writeEntry]：只在 `excerpt` /
/// `reading_time_min` 缺失时从当前 L1 正文算一次，已存在则幂等不动，
/// 避免每次打开阅读器都制造新版本与 oplog。
library;

import 'dart:convert';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import '../write/write_gateway.dart';
import 'archive_body_meta.dart';
import 'archive_meta.dart';

class ArchiveBodyMetaWriter {
  const ArchiveBodyMetaWriter({
    required this.db,
    required this.gateway,
  });

  final VaultDatabase db;
  final WriteGateway gateway;

  Future<bool> ensureDerivedMeta(String entryId) async {
    final row = await (db.select(db.entries)
          ..where((t) => t.id.equals(entryId)))
        .getSingleOrNull();
    if (row == null ||
        row.deleted != 0 ||
        row.kind != EntryKind.bookmark.code) {
      return false;
    }
    final ArchiveMeta meta;
    try {
      meta = ArchiveMeta.fromJson(
        row.meta == null ? null : jsonDecode(row.meta!),
      );
    } on Object {
      return false; // 坏 meta 不猜测、不覆盖，交给读侧隔离。
    }
    final body = row.body ?? '';
    if (body.trim().isEmpty) return false;
    final derived = planArchiveBodyMeta(body);
    if (meta.excerpt.isNotEmpty && meta.readingTimeMin > 0) {
      return false; // 已经算过，幂等。
    }
    final next = meta.copyWith(
      excerpt: derived.excerpt,
      readingTimeMin: derived.readingTimeMin,
    );
    final result = await gateway.writeEntry(EntryWrite.update(
      id: entryId,
      title: row.title,
      body: row.body,
      meta: next.toJsonString(),
    ));
    return result.changed;
  }
}
