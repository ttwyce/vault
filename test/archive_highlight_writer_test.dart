import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_highlight_writer.dart';
import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// docs/05 §9 阅读器高亮标注写回测试。
void main() {
  late TestApp app;
  late ArchiveHighlightWriter writer;

  setUp(() async {
    app = await TestApp.create();
    writer = ArchiveHighlightWriter(db: app.db, gateway: app.gateway);
  });
  tearDown(() async => app.dispose());

  Future<String> createArchive() async {
    final meta = ArchiveMeta(
      url: 'https://example.com/p',
      site: 'example.com',
      status: ArchiveStatus.text,
      excerpt: '摘要',
    );
    final result = await app.gateway.writeEntry(EntryWrite.create(
      id: 'a1',
      kind: EntryKind.bookmark,
      title: '归档标题',
      body: '正文内容',
      meta: meta.toJsonString(),
    ));
    return result.snapshot.id;
  }

  Future<ArchiveMeta> readMeta(String id) async {
    final row = await app.repo.getRow(id);
    return ArchiveMeta.fromJson(jsonDecode(row!.meta!));
  }

  test('追加高亮写回 meta，保留 title/body，产生新版本与 oplog', () async {
    final id = await createArchive();
    final before = await app.repo.getRow(id);
    final changed = await writer.addHighlight(
      id,
      const ArchiveHighlight(text: '重点', offset: 10),
    );
    expect(changed, isTrue);
    final after = await app.repo.getRow(id);
    expect(after!.rev, greaterThan(before!.rev));
    expect(after.title, '归档标题');
    expect(after.body, '正文内容');
    final meta = await readMeta(id);
    expect(meta.highlights, hasLength(1));
    expect(meta.highlights.single.text, '重点');
    expect(meta.excerpt, '摘要');
    expect(await app.db.select(app.db.oplogs).get(), isNotEmpty);
  });

  test('重复/重叠高亮合并，清空高亮也走唯一写入口', () async {
    final id = await createArchive();
    await writer.addHighlight(
        id, const ArchiveHighlight(text: '甲', offset: 0));
    await writer.addHighlight(
        id, const ArchiveHighlight(text: '乙', offset: 2));
    expect((await readMeta(id)).highlights, hasLength(2));

    final cleared = await writer.clearHighlights(id);
    expect(cleared, isTrue);
    expect((await readMeta(id)).highlights, isEmpty);
    expect(await writer.clearHighlights(id), isFalse, reason: '空操作幂等');
  });

  test('非归档 / 坏 meta / 不存在条目一律拒绝，不覆盖', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'note',
      title: '普通笔记',
      body: '正文',
    ));
    expect(
      () => writer.addHighlight(
          'note', const ArchiveHighlight(text: 'x', offset: 0)),
      throwsA(isA<WriteException>()),
    );
    expect(
      () => writer.addHighlight(
          'missing', const ArchiveHighlight(text: 'x', offset: 0)),
      throwsA(isA<WriteException>()),
    );
  });
}
