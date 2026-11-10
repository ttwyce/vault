import 'package:drift/drift.dart';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import '../entry/entry_models.dart';
import '../write/write_gateway.dart';
import 'taxonomy_models.dart';

/// 回收站里的一条。
class TrashItem {
  const TrashItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.snippet,
    required this.deletedAt,
    this.expireAt,
  });

  final String id;
  final EntryKind kind;
  final String title;
  final String snippet;
  final int deletedAt;

  /// 30 天后过期。为 null 说明 trash 行缺失（老数据 / 异常），
  /// UI 要当成「无到期信息」而不是「永不过期」。
  final int? expireAt;
}

/// 一个历史版本。
class HistoryVersion {
  const HistoryVersion({
    required this.rev,
    required this.hlc,
    required this.createdAt,
    required this.title,
    required this.snippet,
    required this.body,
  });

  final int rev;
  final String hlc;
  final int createdAt;
  final String title;
  final String snippet;
  final String body;
}

/// 回收站 / 历史 / 分类标签的**只读**仓库。
///
/// 写操作全在 `WriteGateway`：分类标签走 `writeCategory` / `writeTag` /
/// `setEntryTaxonomy`，恢复走 `EntryWrite.restore`，回滚走 `restoreVersion`。
/// 这里一个写方法都不给，从类型层面杜绝绕过 oplog。
///
/// 解密历史 payload 需要密钥，但**密钥不进 Repository** —— 它借用
/// `WriteGateway.readEntryPayload()`（写入层内部持有 VaultKeys）。
/// 这样 `VaultKeys` 不会被迫暴露成公开 provider，测试也只需 override
/// 已有的两个 provider。
class TaxonomyRepository {
  const TaxonomyRepository({required this.db, required this.gateway});

  final VaultDatabase db;
  final WriteGateway gateway;

  /// 回收站列表，按删除时间倒序。
  Future<List<TrashItem>> trash() async {
    final rows = await db.customSelect(
      'SELECT e.id, e.kind, e.title, e.body, e.deleted_at, t.expire_at '
      'FROM entry e LEFT JOIN trash t ON t.entry_id = e.id '
      'WHERE e.deleted = 1 '
      'ORDER BY e.deleted_at DESC;',
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        db.entries,
        db.trashRows,
      },
    ).get();

    return <TrashItem>[
      for (final row in rows)
        TrashItem(
          id: row.read<String>('id'),
          kind: EntryKind.fromCode(row.read<int>('kind')) ?? EntryKind.note,
          title: displayTitle(
            row.read<String?>('title'),
            row.read<String?>('body'),
          ),
          snippet: plainSnippet(row.read<String?>('body')),
          deletedAt: row.read<int?>('deleted_at') ?? 0,
          expireAt: row.read<int?>('expire_at'),
        ),
    ];
  }

  /// 某条条目的历史版本，新的在前。
  ///
  /// `entry_history` 里存的是**加密信封**，不是明文 JSON —— 直接
  /// `jsonDecode(payload)` 只会得到一串乱码。这里统一交给写入层解。
  Future<List<HistoryVersion>> history(String entryId) async {
    final rows = await (db.select(db.entryHistory)
          ..where((t) => t.entryId.equals(entryId))
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.desc(t.rev),
          ]))
        .get();

    final versions = <HistoryVersion>[];
    for (final row in rows) {
      final snapshot = await gateway.readEntryPayload(
        row.payload,
        expectedId: entryId,
      );
      versions.add(HistoryVersion(
        rev: row.rev,
        hlc: row.hlc,
        createdAt: row.createdAt,
        title: displayTitle(snapshot.title, snapshot.body),
        snippet: plainSnippet(snapshot.body),
        body: snapshot.body ?? '',
      ));
    }
    return versions;
  }

  /// 条目当前所属的分类 id（null = 未分类）。
  Future<String?> categoryForEntry(String entryId) async {
    final rows = await (db.select(db.entryCategories)
          ..where((t) => t.entryId.equals(entryId))
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first.categoryId;
  }

  /// 条目当前挂的标签 id。
  Future<List<String>> tagIdsForEntry(String entryId) async {
    final rows = await (db.select(db.entryTags)
          ..where((t) => t.entryId.equals(entryId)))
        .get();
    return <String>[for (final row in rows) row.tagId];
  }

  /// 同名标签分组，供合并向导用。组内按 usage 降序。
  Future<List<List<TagWithCount>>> duplicateTags() async {
    final rows = await (db.select(db.tags)
          ..where((t) => t.deleted.equals(0)))
        .get();
    return duplicateTagGroups(<TagWithCount>[
      for (final row in rows)
        TagWithCount(id: row.id, name: row.name, count: row.usageCount),
    ]);
  }
}
