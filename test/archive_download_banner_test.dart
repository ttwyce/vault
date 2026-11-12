import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/data/archive/archive_cache_policy.dart';
import 'package:vault/features/archive/widgets/archive_download_banner.dart';

/// docs/05 §7 按需下载 UI 测试。
DownloadRequest _request(OnDemandLayer layer) => planOnDemandRequest(
      entryId: 'e1',
      blobHash: 'h1',
      layer: layer,
      local: false,
    )!;

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      theme: SketchTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('L1 正文仅云端时显示骨架屏与自动下载说明',
      (WidgetTester tester) async {
    await pump(tester, ArchiveDownloadBanner(request: _request(OnDemandLayer.text)));
    expect(find.textContaining('骨架屏并自动下载'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('L2 PDF 需用户点按，显示进度条与百分比',
      (WidgetTester tester) async {
    await pump(tester, ArchiveDownloadBanner(
      request: _request(OnDemandLayer.pdf),
      receivedBytes: 256 * 1024,
      totalBytes: 1024 * 1024,
    ));
    expect(find.textContaining('查看原貌'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('25%'), findsOneWidget);
    expect(find.textContaining('256/1024 KB'), findsOneWidget);
  });

  testWidgets('完成态提示 local=1 且云端副本保留',
      (WidgetTester tester) async {
    await pump(tester, ArchiveDownloadBanner(
      request: _request(OnDemandLayer.text),
      completed: true,
    ));
    expect(find.textContaining('local=1'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
