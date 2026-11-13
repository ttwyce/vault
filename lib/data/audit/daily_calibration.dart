/// 每日一致性校准（docs/11 §5 兼容性检查）。
///
/// 不新增表、不接后台定时器（平台层前台补偿已有排期层）：一次调用
/// 真实重算分类计数、标签用量、全文索引文档，并清掉指向不存在条目的
/// 派生关联。所有实体写入仍走 [WriteGateway]；校准只修正派生表，
/// 不改写用户正文 / 历史 / oplog。
library;

import 'package:drift/drift.dart';

import '../db/vault_database.dart';
import '../write/write_gateway.dart';

class DailyCalibrationReport {
  const DailyCalibrationReport({
    required this.entriesReindexed,
    required this.categoriesRecounted,
    required this.tagsRecounted,
    required this.orphanLinksRemoved,
    required this.hint,
  });

  final int entriesReindexed;
  final int categoriesRecounted;
  final int tagsRecounted;
  final int orphanLinksRemoved;
  final String hint;
}

class DailyCalibration {
  const DailyCalibration({
    required this.db,
    required this.gateway,
  });

  final VaultDatabase db;
  final WriteGateway gateway;

  Future<DailyCalibrationReport> run() async {
    var indexed = 0;
    var categories = 0;
    var tags = 0;
    var orphans = 0;

    await db.transaction(() async {
      // ① 孤儿关联：entry 已删 / 不存在时，entry_category / entry_tag
      //    仍留行会让筛选和计数虚高。只删派生关联，不动 taxonomy 实体。
      final badCategoryLinks = await db.customSelect(
        'SELECT ec.entry_id, ec.category_id FROM entry_category ec '
        'LEFT JOIN entry e ON e.id = ec.entry_id '
        'WHERE e.id IS NULL OR e.deleted != 0;',
      ).get();
      for (final row in badCategoryLinks) {
        await (db.delete(db.entryCategories)
              ..where((t) =>
                  t.entryId.equals(row.read<String>('entry_id')) &
                  t.categoryId.equals(row.read<String>('category_id'))))
            .go();
        orphans++;
      }
      final badTagLinks = await db.customSelect(
        'SELECT et.entry_id, et.tag_id FROM entry_tag et '
        'LEFT JOIN entry e ON e.id = et.entry_id '
        'WHERE e.id IS NULL OR e.deleted != 0;',
      ).get();
      for (final row in badTagLinks) {
        await (db.delete(db.entryTags)
              ..where((t) =>
                  t.entryId.equals(row.read<String>('entry_id')) &
                  t.tagId.equals(row.read<String>('tag_id'))))
            .go();
        orphans++;
      }

      // ② 全部未删条目重建 FTS 文档；已删条目移除文档。
      final entries = await db.select(db.entries).get();
      for (final row in entries) {
        if (row.deleted != 0) {
          await db.removeSearchDocument(row.id);
          continue;
        }
        await gateway.rebuildEntrySearchDocument(row.id);
        indexed++;
      }

      // ③ 分类计数与标签 usage_count 一次性重算。
      final categoryRows = await db.select(db.categories).get();
      for (final row in categoryRows) {
        await db.customStatement(
          'UPDATE category SET entry_count = ('
          '  SELECT count(*) FROM entry_category ec '
          '  JOIN entry e ON e.id = ec.entry_id '
          '  WHERE ec.category_id = ? AND e.deleted = 0'
          ') WHERE id = ?;',
          <Object?>[row.id, row.id],
        );
        categories++;
      }
      final tagRows = await db.select(db.tags).get();
      for (final row in tagRows) {
        await db.customStatement(
          'UPDATE tag SET usage_count = ('
          '  SELECT count(*) FROM entry_tag et '
          '  JOIN entry e ON e.id = et.entry_id '
          '  WHERE et.tag_id = ? AND e.deleted = 0'
          ') WHERE id = ?;',
          <Object?>[row.id, row.id],
        );
        tags++;
      }
    });

    return DailyCalibrationReport(
      entriesReindexed: indexed,
      categoriesRecounted: categories,
      tagsRecounted: tags,
      orphanLinksRemoved: orphans,
      hint: '校准完成：重建 $indexed 篇索引 · '
          '$categories 个分类 · $tags 个标签 · 清理 $orphans 条孤儿关联',
    );
  }
}
