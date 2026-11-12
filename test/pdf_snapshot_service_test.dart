import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/archive/pdf_pagination.dart';
import 'package:vault/data/archive/pdf_snapshot_service.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// docs/05 §8：L2 PDF 真实生成 → blob_ref → meta 回写端到端。
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> seed(String id, String body) => app.gateway
      .writeEntry(EntryWrite.create(
        id: id,
        kind: EntryKind.bookmark,
        title: '归档',
        body: body,
        meta: ArchiveMeta(
          url: 'https://example.com/$id',
          site: 'example.com',
          status: ArchiveStatus.text,
        ).toJsonString(),
      ))
      .then((_) {});

  test('正文生成 PDF 并登记 blob_ref(kind=2, local=1)、meta 标 full', () async {
    await seed('snap-ok', '第一段正文 A B C\n第二段正文 D E F');
    final svc = PdfSnapshotService(db: app.db, gateway: app.gateway);
    final result = await svc.generate(entryId: 'snap-ok');
    expect(result.ok, isTrue);
    expect(result.stage, PdfFallbackStage.dartPdf);
    expect(result.pageCount, 1);
    expect(result.blobHash, isNotNull);
    expect(result.blobHash!.length, 64);

    final blobs = await app.db.select(app.db.blobRefs).get();
    expect(blobs, hasLength(1));
    expect(blobs.single.kind, 2);
    expect(blobs.single.local, 1);
    expect(blobs.single.bytes, result.bytes);

    final row = await app.repo.getRow('snap-ok');
    final meta = ArchiveMeta.fromJson(jsonDecode(row!.meta!));
    expect(meta.status, ArchiveStatus.full);
    expect(meta.snapshotBytes, result.bytes);
    expect(meta.hasSnapshot, isTrue);
  });

  test('空正文走 textOnly 降级，不写 blob 也不标 full', () async {
    await seed('snap-empty', '   ');
    final svc = PdfSnapshotService(db: app.db, gateway: app.gateway);
    final result = await svc.generate(entryId: 'snap-empty');
    expect(result.ok, isFalse);
    expect(result.stage, PdfFallbackStage.textOnly);
    expect(await app.db.select(app.db.blobRefs).get(), isEmpty);
    final row = await app.repo.getRow('snap-empty');
    final meta = ArchiveMeta.fromJson(jsonDecode(row!.meta!));
    expect(meta.status, ArchiveStatus.text);
  });

  test('nativeOk 时明确交回平台层，不假装 Dart 生成', () async {
    await seed('snap-native', '正文');
    final svc = PdfSnapshotService(db: app.db, gateway: app.gateway);
    final result = await svc.generate(entryId: 'snap-native', nativeOk: true);
    expect(result.ok, isFalse);
    expect(result.stage, PdfFallbackStage.native);
    expect(result.hint, contains('平台层'));
  });
}
