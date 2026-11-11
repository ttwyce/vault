import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
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
  }) async {
    final meta = ArchiveMeta(
      url: url,
      site: ArchiveMeta.siteOf(url),
      status: status,
      title: title,
      snapshotBytes: snapshotBytes,
      excerpt: excerpt,
      changed: changed,
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
}
