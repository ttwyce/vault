import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/audit/daily_calibration.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart' show CategoryWrite, TagWrite;
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// 每日一致性校准：真实重算派生索引 / 计数 / 清孤儿关联。
void main() {
  test('校准重算分类与标签计数并清掉指向已删条目的关联', () async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    final category = await app.gateway.writeCategory(
        CategoryWrite.create(name: '工作'));
    final tag = await app.gateway.writeTag(TagWrite.create(name: '重要'));
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cal-1',
      title: '校准笔记',
      body: '正文',
    ));
    await app.gateway.setEntryTaxonomy(
      entryId: 'cal-1',
      categoryId: category.snapshot.id,
      tagIds: <String>[tag.snapshot.id],
    );

    // 人为制造脏数据：计数改成 99，并给不存在的条目插关联。
    await app.db.customStatement(
      'UPDATE category SET entry_count = 99 WHERE id = ?;',
      <Object?>[category.snapshot.id],
    );
    await app.db.customStatement(
      'UPDATE tag SET usage_count = 99 WHERE id = ?;',
      <Object?>[tag.snapshot.id],
    );
    await app.db.into(app.db.entryCategories).insert(
          EntryCategoriesCompanion.insert(
            entryId: 'ghost',
            categoryId: category.snapshot.id,
          ),
        );
    await app.db.into(app.db.entryTags).insert(
          EntryTagsCompanion.insert(
            entryId: 'ghost',
            tagId: tag.snapshot.id,
          ),
        );

    final report = await DailyCalibration(
      db: app.db,
      gateway: app.gateway,
    ).run();
    expect(report.entriesReindexed, 1);
    expect(report.orphanLinksRemoved, 2);
    expect(report.hint, contains('校准完成'));

    final cat = (await app.db.select(app.db.categories).get())
        .where((CategoryRow r) => r.id == category.snapshot.id)
        .single;
    final tagRow = (await app.db.select(app.db.tags).get())
        .where((TagRow r) => r.id == tag.snapshot.id)
        .single;
    expect(cat.entryCount, 1);
    expect(tagRow.usageCount, 1);
    expect(
      (await app.db.select(app.db.entryCategories).get())
          .any((EntryCategoryRow r) => r.entryId == 'ghost'),
      isFalse,
    );
    expect(
      (await app.db.select(app.db.entryTags).get())
          .any((EntryTagRow r) => r.entryId == 'ghost'),
      isFalse,
    );
  });
}
