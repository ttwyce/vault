import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/db/vault_database.dart' show BlobRefsCompanion;
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/archive/archive_page.dart';

import 'support/test_harness.dart';

/// 归档总览页：必须显示真实 kind=5 数据，而不是写死的假条目。
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> pumpArchive(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(
        home: Scaffold(body: ArchivePage()),
      ),
    ));
    // FutureBuilder 两帧足够；不用 pumpAndSettle（页面里有进度圈）。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> addArchive({
    required String id,
    required String url,
    required ArchiveStatus status,
    String? title,
    int snapshotBytes = 0,
    String excerpt = '',
    bool changed = false,
    String? waybackUrl,
  }) async {
    final meta = ArchiveMeta(
      url: url,
      site: ArchiveMeta.siteOf(url),
      status: status,
      title: title,
      snapshotBytes: snapshotBytes,
      excerpt: excerpt,
      changed: changed,
      waybackUrl: waybackUrl,
      lastCheckedAt: 1731052800000,
    );
    await app.gateway.writeEntry(EntryWrite.create(
      id: id,
      kind: EntryKind.bookmark,
      title: title,
      meta: meta.toJsonString(),
    ));
  }

  testWidgets('空库显示空状态，不出现写死的假条目', (WidgetTester tester) async {
    await pumpArchive(tester);
    expect(find.textContaining('这个筛选下还没有归档'), findsOneWidget);
    expect(find.text('RFC 6578：WebDAV 的增量同步机制'), findsNothing);
    expect(find.textContaining('0 个'), findsWidgets);
  });

  testWidgets('真实 kind=5 条目渲染标题 / 站点 / 摘要 / 状态徽章',
      (WidgetTester tester) async {
    await addArchive(
      id: 'a1',
      url: 'https://example.com/post/1',
      status: ArchiveStatus.full,
      title: 'RFC 6578 归档',
      snapshotBytes: 412000,
      excerpt: 'sync-collection 报告允许客户端…',
    );
    await pumpArchive(tester);

    expect(find.text('RFC 6578 归档'), findsOneWidget);
    expect(find.textContaining('example.com'), findsWidgets);
    expect(find.text('sync-collection 报告允许客户端…'), findsOneWidget);
    expect(find.text('快照'), findsOneWidget);
    expect(find.textContaining('1 个'), findsWidgets);
  });

  testWidgets('状态筛选与站点筛选按真实 meta 生效',
      (WidgetTester tester) async {
    await addArchive(
      id: 'a1',
      url: 'https://example.com/p1',
      status: ArchiveStatus.full,
      title: '存活条目',
    );
    await addArchive(
      id: 'a2',
      url: 'https://github.com/p2',
      status: ArchiveStatus.dead,
      title: '失效条目',
    );
    await addArchive(
      id: 'a3',
      url: 'https://blog.example.org/p3',
      status: ArchiveStatus.metadata,
      title: '仅元数据条目',
    );
    await pumpArchive(tester);

    expect(find.text('存活条目'), findsOneWidget);
    expect(find.text('失效条目'), findsOneWidget);
    expect(find.text('仅元数据条目'), findsOneWidget);

    await tester.tap(find.text('失效'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('失效条目'), findsOneWidget);
    expect(find.text('存活条目'), findsNothing);
    expect(find.text('仅元数据条目'), findsNothing);

    await tester.tap(find.text('仅元数据'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('仅元数据条目'), findsOneWidget);
    expect(find.text('失效条目'), findsNothing);
  });

  testWidgets('坏 meta 条目被隔离跳过，不让整页崩', (WidgetTester tester) async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'broken',
      kind: EntryKind.bookmark,
      title: '坏数据',
      meta: '{"archive_status":"wat","url":"ftp://x"}',
    ));
    await addArchive(
      id: 'good',
      url: 'https://example.com/ok',
      status: ArchiveStatus.text,
      title: '正常条目',
    );
    await pumpArchive(tester);

    expect(find.text('正常条目'), findsOneWidget);
    expect(find.text('坏数据'), findsNothing);
    expect(find.textContaining('1 个'), findsWidgets);
  });

  testWidgets('存储面板汇总快照体积', (WidgetTester tester) async {
    await addArchive(
      id: 'a1',
      url: 'https://example.com/p1',
      status: ArchiveStatus.full,
      title: '带快照',
      snapshotBytes: 1024 * 1024,
    );
    await pumpArchive(tester);
    expect(find.textContaining('快照 1.0 MB'), findsOneWidget);
  });

  testWidgets('搜索框按站点/标题/摘要过滤真实归档', (WidgetTester tester) async {
    await addArchive(
      id: 'a1',
      url: 'https://example.com/p1',
      status: ArchiveStatus.text,
      title: 'RFC 6578',
      excerpt: '增量同步报告',
    );
    await addArchive(
      id: 'a2',
      url: 'https://github.com/p2',
      status: ArchiveStatus.text,
      title: 'GitHub Actions',
    );
    await pumpArchive(tester);

    expect(find.text('RFC 6578'), findsOneWidget);
    expect(find.text('GitHub Actions'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'github');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('GitHub Actions'), findsOneWidget);
    expect(find.text('RFC 6578'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '增量同步');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('RFC 6578'), findsOneWidget);
    expect(find.text('GitHub Actions'), findsNothing);
  });

  testWidgets('归档网址按钮：合法 URL 落 kind=5 条目，非法 URL 不落库',
      (WidgetTester tester) async {
    await pumpArchive(tester);

    await tester.tap(find.text('归档网址'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byType(TextField).last,
      'https://www.Example.com/post/1',
    );
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final rows = await (app.db.select(app.db.entries)
          ..where((t) => t.kind.equals(EntryKind.bookmark.code)))
        .get();
    expect(rows, hasLength(1));
    final meta = ArchiveMeta.fromMetaString(rows.single.meta,
        fallbackUrl: 'https://www.Example.com/post/1');
    expect(meta.site, 'example.com');
    expect(meta.status, ArchiveStatus.metadata);
    expect(find.textContaining('1 个'), findsWidgets);

    // 非法 URL 被 ArchiveMeta.siteOf 拒绝，不产生第二条。
    await tester.tap(find.text('归档网址'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).last, 'ftp://x/y');
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      await (app.db.select(app.db.entries)
            ..where((t) => t.kind.equals(EntryKind.bookmark.code)))
          .get(),
      hasLength(1),
    );
  });

  testWidgets('死链带 Wayback 存档 URL 时显示年份徽章', (WidgetTester tester) async {
    await addArchive(
      id: 'a-dead',
      url: 'https://example.com/gone',
      status: ArchiveStatus.dead,
      title: '失效文章',
      waybackUrl: 'https://web.archive.org/web/2019/https://example.com/gone',
    );
    await pumpArchive(tester);
    expect(find.text('查看 2019 存档'), findsOneWidget);
    expect(find.text('试 Wayback'), findsNothing);
  });

  testWidgets('重复 URL 弹「已归档过」且不插入第二条',
      (WidgetTester tester) async {
    await addArchive(
      id: 'dup',
      url: 'https://example.com/post?utm_source=rss',
      status: ArchiveStatus.metadata,
      title: '已有条目',
    );
    await pumpArchive(tester);
    await tester.tap(find.text('归档网址'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byType(TextField).last,
      'https://example.com/post/#x',
    );
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('已归档过'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump(const Duration(milliseconds: 200));

    final rows = await (app.db.select(app.db.entries)
          ..where((t) => t.kind.equals(EntryKind.bookmark.code)))
        .get();
    expect(rows, hasLength(1));
  });

  testWidgets('点开归档时把真实 L1 正文与 PDF 本地状态传给阅读器',
      (WidgetTester tester) async {
    final meta = ArchiveMeta(
      url: 'https://example.com/full',
      site: 'example.com',
      status: ArchiveStatus.full,
      title: '有正文的归档',
    );
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'arch-body',
      kind: EntryKind.bookmark,
      title: '有正文的归档',
      body: '这是真实 L1 正文',
      meta: meta.toJsonString(),
    ));
    await app.db.into(app.db.blobRefs).insert(
          BlobRefsCompanion.insert(
            entryId: 'arch-body',
            blobHash: 'pdf-hash',
            kind: 2,
            bytes: 1024,
            createdAt: 1731052800000,
            local: const Value<int>(1),
          ),
        );
    await pumpArchive(tester);
    await tester.tap(find.text('有正文的归档'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('这是真实 L1 正文'), findsOneWidget);
    // 原貌模式可点（pdfLocal=true），说明 blob_ref 已接线。
    expect(find.text('原貌'), findsOneWidget);
  });

  testWidgets('点开归档时解密 entry_history 上一版并启用真实对比模式',
      (WidgetTester tester) async {
    final meta = ArchiveMeta(
      url: 'https://example.com/history',
      site: 'example.com',
      status: ArchiveStatus.full,
      title: '改过的归档',
      changed: true,
    );
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'arch-history',
      kind: EntryKind.bookmark,
      title: '改过的归档',
      body: '新的正文内容\n保留行',
      meta: meta.toJsonString(),
    ));
    // 一次 update 会把 rev=1 的旧快照写进 entry_history（加密信封）。
    await app.gateway.writeEntry(EntryWrite.update(
      id: 'arch-history',
      title: '改过的归档',
      body: '新新正文内容\n保留行',
      meta: meta.toJsonString(),
    ));
    await pumpArchive(tester);
    await tester.tap(find.text('改过的归档'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('对比'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('新旧正文差异'), findsOneWidget);
    expect(find.textContaining('+'), findsWidgets);
  });

  testWidgets('点开归档时懒补齐 excerpt 与 reading_time_min',
      (WidgetTester tester) async {
    final meta = ArchiveMeta(
      url: 'https://example.com/derived',
      site: 'example.com',
      status: ArchiveStatus.full,
      title: '派生摘要归档',
    );
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'arch-derived-ui',
      kind: EntryKind.bookmark,
      title: '派生摘要归档',
      body: '这是一段归档正文内容，${'长' * 350}',
      meta: meta.toJsonString(),
    ));
    await pumpArchive(tester);
    await tester.tap(find.text('派生摘要归档'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final row = await app.repo.getRow('arch-derived-ui');
    final written = ArchiveMeta.fromJson(jsonDecode(row!.meta!));
    expect(written.excerpt.length, 200);
    expect(written.readingTimeMin, greaterThan(0));
  });

  testWidgets('L1 正文仅存云端时阅读器显示按需下载骨架屏',
      (WidgetTester tester) async {
    final meta = ArchiveMeta(
      url: 'https://example.com/cloud-text',
      site: 'example.com',
      status: ArchiveStatus.text,
      title: '仅云端正文',
    );
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'arch-cloud-text',
      kind: EntryKind.bookmark,
      title: '仅云端正文',
      meta: meta.toJsonString(),
    ));
    await app.db.into(app.db.blobRefs).insert(
          BlobRefsCompanion.insert(
            entryId: 'arch-cloud-text',
            blobHash: 'text-hash',
            kind: 1,
            bytes: 4096,
            createdAt: 1731052800000,
          ),
        );
    await pumpArchive(tester);
    await tester.tap(find.text('仅云端正文'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.textContaining('骨架屏并自动下载'), findsOneWidget);
  });

  testWidgets('归档 tile 显示按 recheck_policy 算出的下次检查日期',
      (WidgetTester tester) async {
    await addArchive(
      id: 'a-next',
      url: 'https://example.com/next',
      status: ArchiveStatus.full,
      title: '带检查日期',
    );
    await pumpArchive(tester);
    // lastCheckedAt=1731052800000（2024-11-08）+ monthly 30 天 → 12-08
    expect(find.textContaining('下次检查 12-08'), findsOneWidget);
  });

  testWidgets('recheck_policy=never 的归档显示不自动重检查',
      (WidgetTester tester) async {
    final meta = ArchiveMeta(
      url: 'https://example.com/never',
      site: 'example.com',
      status: ArchiveStatus.full,
      policy: RecheckPolicy.never,
      lastCheckedAt: 1731052800000,
    );
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'a-never',
      kind: EntryKind.bookmark,
      title: '不重检查',
      meta: meta.toJsonString(),
    ));
    await pumpArchive(tester);
    expect(find.textContaining('不自动重检查'), findsOneWidget);
  });
}
