import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/log_tables.dart';
import 'package:vault/data/db/vault_database.dart' show TagsCompanion;
import 'package:vault/data/entry/entry_models.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// taxonomy 写路径 / 回收站 / 历史版本的测试。
///
/// 这里最要紧的不是「CRUD 能不能跑」，而是三条约束：
///   1. 每一次实体变更都必须留下能解开的加密 oplog（否则同步静默丢数据）
///   2. 删分类不删条目、删标签重建 FTS（否则「打了标签却搜不到」）
///   3. 回滚是新的 rev，不能把版本号倒回去
void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.create();
  });

  tearDown(() async {
    await app.dispose();
  });

  Future<String> newEntry(String title) async {
    final r = await app.gateway.writeEntry(
      EntryWrite.create(title: title, body: '正文 $title'),
    );
    return r.snapshot.id;
  }

  group('分类', () {
    test('创建两级树，拒绝三级', () async {
      final parent = await app.gateway
          .writeCategory(CategoryWrite.create(name: '工作'));
      final child = await app.gateway.writeCategory(
        CategoryWrite.create(name: '项目A', parentId: parent.snapshot.id),
      );
      expect(child.changed, isTrue);

      await expectLater(
        app.gateway.writeCategory(
          CategoryWrite.create(name: '三级', parentId: child.snapshot.id),
        ),
        throwsA(isA<WriteException>()
            .having((WriteException e) => e.code, 'code', 'invalid')),
      );
    });

    test('同级同名拒绝，改名与规范化', () async {
      await app.gateway.writeCategory(CategoryWrite.create(name: ' 工作 '));
      await expectLater(
        app.gateway.writeCategory(CategoryWrite.create(name: '工作')),
        throwsA(isA<WriteException>()
            .having((WriteException e) => e.code, 'code', 'exists')),
      );

      final rows = await app.repo.categories();
      expect(rows.single.name, '工作');
    });

    test('删除分类：条目回未分类，子级提升为一级', () async {
      final parent = await app.gateway
          .writeCategory(CategoryWrite.create(name: '工作'));
      final child = await app.gateway.writeCategory(
        CategoryWrite.create(name: '项目A', parentId: parent.snapshot.id),
      );
      final entryId = await newEntry('待整理');
      await app.gateway.setEntryTaxonomy(
        entryId: entryId,
        categoryId: parent.snapshot.id,
      );
      expect(
        await app.taxonomyRepo.categoryForEntry(entryId),
        parent.snapshot.id,
      );

      final result = await app.gateway
          .writeCategory(CategoryWrite.delete(id: parent.snapshot.id));
      expect(result.changed, isTrue);
      expect(result.relatedOplogSeqs, hasLength(1));
      expect(await app.taxonomyRepo.categoryForEntry(entryId), isNull);

      final rows = await app.repo.categories();
      final childRow = rows.firstWhere((r) => r.id == child.snapshot.id);
      expect(childRow.parentId, isNull);
      expect(rows.any((r) => r.id == parent.snapshot.id), isFalse);

      // 条目本身没被删
      expect(await app.repo.getRow(entryId), isNotNull);
    });

    test('恢复分类，重复删除是空操作', () async {
      final c = await app.gateway
          .writeCategory(CategoryWrite.create(name: '工作'));
      final id = c.snapshot.id;
      await app.gateway.writeCategory(CategoryWrite.delete(id: id));

      final noop = await app.gateway.writeCategory(CategoryWrite.delete(id: id));
      expect(noop.changed, isFalse);
      expect(noop.oplogSeq, -1);

      await app.gateway.writeCategory(CategoryWrite.restore(id: id));
      expect((await app.repo.categories()).any((r) => r.id == id), isTrue);
    });
  });

  group('标签', () {
    test('创建、改名、同名拒绝', () async {
      final tag =
          await app.gateway.writeTag(TagWrite.create(name: ' 同步 '));
      expect(tag.snapshot.name, '同步');

      await expectLater(
        app.gateway.writeTag(TagWrite.create(name: '同步')),
        throwsA(isA<WriteException>()
            .having((WriteException e) => e.code, 'code', 'exists')),
      );

      await app.gateway
          .writeTag(TagWrite.rename(id: tag.snapshot.id, name: '增量同步'));
      final rows = await app.repo.tags();
      expect(rows.single.name, '增量同步');
    });

    test('标签参与 FTS，删除后不再命中', () async {
      final tag = await app.gateway.writeTag(TagWrite.create(name: '同步'));
      final entryId = await newEntry('一篇笔记');
      await app.gateway.setEntryTaxonomy(
        entryId: entryId,
        tagIds: <String>[tag.snapshot.id],
      );

      final before = await app.repo.search('同步');
      expect(before.map((e) => e.id), contains(entryId));

      await app.gateway.writeTag(TagWrite.delete(id: tag.snapshot.id));
      final after = await app.repo.search('同步');
      expect(after.map((e) => e.id), isNot(contains(entryId)));
    });

    test('标签上限 8 个，超出拒绝且不写 oplog', () async {
      final entryId = await newEntry('带标签');
      final ids = <String>[];
      for (var i = 0; i < TaxonomyRules.maxTagsPerEntry + 1; i++) {
        final t =
            await app.gateway.writeTag(TagWrite.create(name: '标签$i'));
        ids.add(t.snapshot.id);
      }
      final before = await app.gateway.pendingCount();

      await expectLater(
        app.gateway.setEntryTaxonomy(entryId: entryId, tagIds: ids),
        throwsA(isA<WriteException>()
            .having((WriteException e) => e.code, 'code', 'invalid')),
      );
      expect(await app.gateway.pendingCount(), before);
    });

    test('同名合并：关联不丢，source 软删，target 计数正确', () async {
      final target =
          await app.gateway.writeTag(TagWrite.create(name: '同步'));
      // 模拟「另一台设备建了同名标签」—— 本地 create 会拒绝同名，
      // 同名只可能来自同步合并，所以这里直接插一行远端数据。
      await app.db.into(app.db.tags).insert(TagsCompanion(
            id: const Value<String>('remote-tag'),
            name: const Value<String>('同步'),
            usageCount: const Value<int>(0),
            hlc: const Value<String>('remote-hlc'),
            deleted: const Value<int>(0),
          ));

      final a = await newEntry('甲');
      final b = await newEntry('乙');
      await app.db.customStatement(
        'INSERT INTO entry_tag(entry_id, tag_id) VALUES (?, ?), (?, ?);',
        <Object?>[a, target.snapshot.id, b, 'remote-tag'],
      );

      final result = await app.gateway.writeTag(TagWrite.merge(
        sourceId: 'remote-tag',
        targetId: target.snapshot.id,
      ));
      expect(result.changed, isTrue);
      expect(result.relatedOplogSeqs, hasLength(1));

      final rows = await app.db
          .customSelect(
            'SELECT usage_count AS c FROM tag WHERE id = ?;',
            variables: <Variable<Object>>[
              Variable<String>(target.snapshot.id),
            ],
          )
          .getSingle();
      expect(rows.read<int>('c'), 2);
      expect(await app.taxonomyRepo.tagIdsForEntry(b),
          contains(target.snapshot.id));
      expect(await app.repo.tags(), hasLength(1));
    });
  });

  group('条目关联', () {
    test('重复设置相同关联是空操作，不写 oplog', () async {
      final entryId = await newEntry('笔记');
      final tag = await app.gateway.writeTag(TagWrite.create(name: '同步'));
      final first = await app.gateway.setEntryTaxonomy(
        entryId: entryId,
        tagIds: <String>[tag.snapshot.id],
      );
      expect(first.changed, isTrue);

      final before = await app.gateway.pendingCount();
      final second = await app.gateway.setEntryTaxonomy(
        entryId: entryId,
        tagIds: <String>[tag.snapshot.id],
      );
      expect(second.changed, isFalse);
      expect(second.oplogSeq, -1);
      expect(await app.gateway.pendingCount(), before);
    });

    test('分类与标签的变更都留下可解开的加密 oplog', () async {
      final entryId = await newEntry('笔记');
      final tag = await app.gateway.writeTag(TagWrite.create(name: '同步'));
      await app.gateway.setEntryTaxonomy(
        entryId: entryId,
        tagIds: <String>[tag.snapshot.id],
      );

      final pending = await app.gateway.pending();
      final taxonomyRow = pending.firstWhere(
        (r) => r.entity == SyncEntity.entryTaxonomy,
      );
      final snap = await app.gateway.readTaxonomySnapshot(taxonomyRow);
      expect(snap.fields['tag_ids'], <Object?>[tag.snapshot.id]);
      expect(taxonomyRow.payload, isNotNull);

      final tagRow = pending.firstWhere((r) => r.entity == SyncEntity.tag);
      expect((await app.gateway.readTaxonomySnapshot(tagRow)).name, '同步');
    });
  });

  group('回收站与历史', () {
    test('删除进回收站，带 30 天到期时间，恢复后清空', () async {
      final entryId = await newEntry('将删除');
      await app.gateway.writeEntry(EntryWrite.delete(id: entryId));

      final items = await app.taxonomyRepo.trash();
      expect(items, hasLength(1));
      expect(items.first.title, '将删除');
      expect(items.first.expireAt, isNotNull);
      expect(
        items.first.expireAt! - items.first.deletedAt,
        Duration(days: WriteGateway.trashRetentionDays).inMilliseconds,
      );

      await app.gateway.writeEntry(EntryWrite.restore(id: entryId));
      expect(await app.taxonomyRepo.trash(), isEmpty);
    });

    test('历史版本可解密，回滚产生新 rev 而不倒退', () async {
      final created =
          await app.gateway.writeEntry(EntryWrite.create(title: 'v1', body: '甲'));
      final id = created.snapshot.id;
      await app.gateway.writeEntry(
        EntryWrite.update(id: id, title: 'v2', body: '乙'),
      );

      final versions = await app.taxonomyRepo.history(id);
      expect(versions, hasLength(1));
      expect(versions.first.rev, 1);
      expect(versions.first.title, 'v1');

      final restored =
          await app.gateway.restoreVersion(entryId: id, rev: 1);
      expect(restored.snapshot.rev, 3);
      expect(restored.snapshot.title, 'v1');
      final row = await app.repo.getRow(id);
      expect(row!.body, '甲');

      // 回滚本身也归档旧版本，历史里现在有 r1 与 r2
      expect(await app.taxonomyRepo.history(id), hasLength(2));
    });

    test('回滚不存在的版本报 not_found', () async {
      final entryId = await newEntry('笔记');
      await expectLater(
        app.gateway.restoreVersion(entryId: entryId, rev: 99),
        throwsA(isA<WriteException>()
            .having((WriteException e) => e.code, 'code', 'not_found')),
      );
    });
  });

  group('纯函数', () {
    test('duplicateTagGroups 按 usage 降序，忽略大小写与空白', () {
      final groups = duplicateTagGroups(<TagWithCount>[
        const TagWithCount(id: 'a', name: 'WebDAV', count: 2),
        const TagWithCount(id: 'b', name: ' webdav ', count: 7),
        const TagWithCount(id: 'c', name: '别的', count: 3),
      ]);
      expect(groups, hasLength(1));
      expect(groups.first.first.id, 'b');
    });

    test('normalizeTaxonomyName 折叠空白并限长', () {
      expect(normalizeTaxonomyName('  工作   项目  '), '工作 项目');
      expect(
        normalizeTaxonomyName('字' * 100).length,
        TaxonomyRules.maxNameLength,
      );
    });
  });
}
