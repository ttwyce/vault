import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/backup/backup_models.dart';
import 'package:vault/data/backup/markdown_exporter.dart';
import 'package:vault/data/backup/markdown_importer.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// docs/03 §10：Markdown 文件夹无冲突合并导入（临时目录 + 内存库）。
void main() {
  late TestApp source;
  late TestApp target;
  late Directory root;

  setUp(() async {
    source = await TestApp.create();
    target = await TestApp.create();
    root = await Directory.systemTemp.createTemp('vault-md-import-');
  });
  tearDown(() async {
    root.deleteSync(recursive: true);
    await source.dispose();
    await target.dispose();
  });

  Future<void> exportFromSource() async {
    final result = await MarkdownExporter(db: source.db, root: root).export(
      stage: PlaintextExportStage.confirmed,
      knownSecrets: const <String>[],
    );
    expect(result.ok, isTrue);
  }

  MarkdownImporter importer() => MarkdownImporter(
        db: target.db,
        gateway: target.gateway,
        root: root,
      );

  test('导出→导入 round-trip：正文与 meta 完整还原', () async {
    await source.gateway.writeEntry(EntryWrite.create(
      id: 'note-rt',
      kind: EntryKind.note,
      title: '往返笔记',
      body: '正文内容 A B C',
      meta: '{"pinned":true}',
    ));
    await exportFromSource();
    final result = await importer().importFolder();
    expect(result.inserted, <String>['note-rt']);
    final row = await target.repo.getRow('note-rt');
    expect(row!.title, '往返笔记');
    expect(row.body, '正文内容 A B C');
    expect(row.meta, '{"pinned":true}');
    expect(result.conflictCopies, isEmpty);
  });

  test('同 hash 二次导入跳过；本地改写后导入生成冲突副本不覆盖', () async {
    await source.gateway.writeEntry(EntryWrite.create(
      id: 'note-conflict',
      kind: EntryKind.note,
      title: '原始',
      body: '原始正文',
    ));
    await exportFromSource();
    expect((await importer().importFolder()).inserted,
        <String>['note-conflict']);
    final again = await importer().importFolder();
    expect(again.skipped, <String>['note-conflict']);
    expect(again.inserted, isEmpty);

    await target.gateway.writeEntry(EntryWrite.update(
      id: 'note-conflict',
      title: '本地改写',
      body: '本地完全不同的正文',
    ));
    final conflict = await importer().importFolder();
    expect(conflict.conflictCopies, hasLength(1));
    final local = await target.repo.getRow('note-conflict');
    expect(local!.body, '本地完全不同的正文', reason: '绝不覆盖本地');
    final copy = await target.repo.getRow(conflict.conflictCopies.single);
    expect(copy!.title, contains('冲突副本'));
  });

  test('密码占位与坏文件被跳过，不产生条目', () async {
    await source.gateway.writeEntry(EntryWrite.create(
      id: 'cred-x',
      kind: EntryKind.credential,
      title: '密码',
      body: '不应导入',
    ));
    await exportFromSource();
    await Directory('${root.path}/notes').create(recursive: true);
    await File('${root.path}/notes/broken.md').writeAsString('没有 frontmatter');
    final result = await importer().importFolder();
    expect(result.inserted, isEmpty);
    expect(result.failed, isNotEmpty);
    expect(await target.db.select(target.db.entries).get(), isEmpty);
  });

  test('目录不存在明确返回，不抛异常', () async {
    final missing = MarkdownImporter(
      db: target.db,
      gateway: target.gateway,
      root: Directory('${root.path}/nope'),
    );
    final result = await missing.importFolder();
    expect(result.total, 0);
    expect(result.hints.join(), contains('不存在'));
  });
}
