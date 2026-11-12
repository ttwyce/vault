import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_body_meta_writer.dart';
import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// docs/05 §10 派生 meta 懒补齐测试。
void main() {
  late TestApp app;
  late ArchiveBodyMetaWriter writer;

  setUp(() async {
    app = await TestApp.create();
    writer = ArchiveBodyMetaWriter(db: app.db, gateway: app.gateway);
  });
  tearDown(() async => app.dispose());

  Future<void> seed() => app.gateway.writeEntry(EntryWrite.create(
        id: 'arch-derived',
        kind: EntryKind.bookmark,
        title: '归档',
        body: '正文内容 ${'长' * 400}',
        meta: ArchiveMeta(
          url: 'https://example.com/p',
          site: 'example.com',
          status: ArchiveStatus.full,
        ).toJsonString(),
      )).then((_) {});

  Future<ArchiveMeta> readMeta() async {
    final row = await app.repo.getRow('arch-derived');
    return ArchiveMeta.fromJson(jsonDecode(row!.meta!));
  }

  test('缺 excerpt/reading_time 时从正文补齐前 200 字与时长', () async {
    await seed();
    expect(await writer.ensureDerivedMeta('arch-derived'), isTrue);
    final meta = await readMeta();
    expect(meta.excerpt.length, 200);
    expect(meta.excerpt, contains('正文内容'));
    expect(meta.readingTimeMin, 2);
    expect(meta.url, 'https://example.com/p');
  });

  test('再次调用幂等，不制造新版本', () async {
    await seed();
    await writer.ensureDerivedMeta('arch-derived');
    final before = await app.repo.getRow('arch-derived');
    expect(await writer.ensureDerivedMeta('arch-derived'), isFalse);
    final after = await app.repo.getRow('arch-derived');
    expect(after!.rev, before!.rev);
  });

  test('坏 meta / 空正文 / 不存在条目不写入', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'arch-bad',
      kind: EntryKind.bookmark,
      title: '坏',
      body: '正文',
      meta: '{"url":""}',
    ));
    expect(await writer.ensureDerivedMeta('arch-bad'), isFalse);
    expect(await writer.ensureDerivedMeta('missing'), isFalse);
  });
}
