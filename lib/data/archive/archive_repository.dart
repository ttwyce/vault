import 'package:drift/drift.dart';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import 'archive_meta.dart';

/// 归档条目的只读仓库。
///
/// 只做一件事：把 `entry(kind=5)` 的 `meta` 解析成 [ArchiveMeta] 供总览页
/// 使用。**坏 meta 隔离跳过**，不让一条手写/旧版本数据把整页搞崩。
class ArchiveRepository {
  ArchiveRepository(this.db);

  final VaultDatabase db;

  /// 列出归档条目（含 id / 标题 / 更新时间，供列表渲染）。
  Future<List<ArchiveEntry>> list({int limit = 200}) async {
    final rows = await (db.select(db.entries)
          ..where((t) =>
              t.kind.equals(EntryKind.bookmark.code) & t.deleted.equals(0))
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.desc(t.updatedAt),
          ])
          ..limit(limit))
        .get();
    final out = <ArchiveEntry>[];
    for (final row in rows) {
      final meta = _parse(row);
      if (meta == null) continue;
      out.add(ArchiveEntry(
        id: row.id,
        title: row.title,
        updatedAt: row.updatedAt,
        meta: meta,
      ));
    }
    return out;
  }

  /// 站点聚合（docs/11 §3.2 左栏）。
  Future<List<ArchiveSiteGroupCount>> sites() async {
    final entries = await list(limit: 100000);
    final counts = <String, int>{};
    for (final entry in entries) {
      counts[entry.meta.site] = (counts[entry.meta.site] ?? 0) + 1;
    }
    final groups = <ArchiveSiteGroupCount>[
      for (final item in counts.entries)
        ArchiveSiteGroupCount(item.key, item.value),
    ];
    groups.sort((ArchiveSiteGroupCount a, ArchiveSiteGroupCount b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.site.compareTo(b.site);
    });
    return groups;
  }

  static ArchiveMeta? _parse(EntryRow row) {
    try {
      return ArchiveMeta.fromMetaString(row.meta, fallbackUrl: '');
    } on FormatException {
      return null;
    } on Object {
      return null;
    }
  }
}

class ArchiveEntry {
  const ArchiveEntry({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.meta,
  });

  final String id;
  final String? title;
  final int updatedAt;
  final ArchiveMeta meta;
}

class ArchiveSiteGroupCount {
  const ArchiveSiteGroupCount(this.site, this.count);

  final String site;
  final int count;
}
