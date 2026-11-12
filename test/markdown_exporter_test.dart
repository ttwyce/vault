import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/backup/backup_models.dart';
import 'package:vault/data/backup/markdown_exporter.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// docs/03 §10：明文 Markdown 导出真实写盘（临时目录）。
void main() {
  late TestApp app;
  late Directory root;

  setUp(() async {
    app = await TestApp.create();
    root = await Directory.systemTemp.createTemp('vault-md-export-');
  });
  tearDown(() async {
    root.deleteSync(recursive: true);
    await app.dispose();
  });

  MarkdownExporter exporter() =>
      MarkdownExporter(db: app.db, root: root);

  test('未到 confirmed 阶段拒绝写盘', () async {
    final result = await exporter().export(
      stage: PlaintextExportStage.warned,
      knownSecrets: const <String>[],
    );
    expect(result.ok, isFalse);
    expect(root.listSync(), isEmpty);
  });

  test('confirmed 后按 kind 写出正文、密码仅占位说明', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'note-1',
      kind: EntryKind.note,
      title: '同步笔记',
      body: '增量同步正文',
    ));
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-1',
      kind: EntryKind.credential,
      title: '某账号',
      body: '密码不该出现',
    ));
    final result = await exporter().export(
      stage: PlaintextExportStage.confirmed,
      knownSecrets: const <String>[],
    );
    expect(result.ok, isTrue);
    expect(result.stage, PlaintextExportStage.done);
    final note = File('${root.path}/notes/note-1.md');
    expect(await note.exists(), isTrue);
    final text = await note.readAsString();
    expect(text, contains('# 同步笔记'));
    expect(text, contains('增量同步正文'));
    expect(text, contains('id: note-1'));
    // 密码正文与字段都不落盘。
    expect(Directory('${root.path}/credentials/cred-1.md').existsSync(), isFalse);
    final readme = await File('${root.path}/credentials/README.md').readAsString();
    expect(readme, contains('未导出'));
    expect(readme, isNot(contains('密码不该出现')));
    final all = root
        .listSync(recursive: true)
        .whereType<File>()
        .map((File f) => f.readAsStringSync())
        .join();
    expect(all, isNot(contains('密码不该出现')));
  });

  test('已知密码明文出现在待导出文本中 → 整批拒绝、零文件', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'note-leak',
      kind: EntryKind.note,
      title: '夹带',
      body: '我的口令是 Hunter2Secret 请记住',
    ));
    final result = await exporter().export(
      stage: PlaintextExportStage.confirmed,
      knownSecrets: const <String>['Hunter2Secret'],
    );
    expect(result.ok, isFalse);
    expect(result.leaks, isNotEmpty);
    expect(result.hint, contains('拒绝导出'));
    expect(root.listSync(), isEmpty);
  });

  test('已删除条目不导出；id 中的路径字符被净化', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'a/b..c',
      kind: EntryKind.note,
      title: '特殊 id',
      body: '正文',
    ));
    await app.gateway.writeEntry(EntryWrite.delete(id: 'a/b..c'));
    final result = await exporter().export(
      stage: PlaintextExportStage.done,
      knownSecrets: const <String>[],
    );
    expect(result.ok, isTrue);
    final files = root.listSync(recursive: true).whereType<File>();
    expect(files.any((File f) => f.path.contains('a_b__c')), isFalse);
  });
}
