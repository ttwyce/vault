import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/features/settings/pending_jobs_page.dart';
import 'package:vault/features/settings/settings_hub_page.dart';

import 'support/test_harness.dart';

/// docs/10 第 20 屏 待处理任务页测试。
void main() {
  testWidgets('空队列显示空状态', (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: PendingJobsPage()),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('待处理'), findsOneWidget);
    expect(find.textContaining('没有待处理任务'), findsOneWidget);
  });

  testWidgets('真实 job_queue 行渲染类型/状态/重试次数',
      (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    await app.gateway.enqueueArchiveJob(
      type: 'archive',
      nextRunAt: 1731052800000,
    );
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: PendingJobsPage()),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('archive 1'), findsOneWidget);
    expect(find.textContaining('archive · 第 0 次重试'), findsOneWidget);
    expect(find.text('待处理'), findsWidgets);
  });

  testWidgets('设置中心有待处理任务入口', (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: SettingsHubPage()),
    ));
    expect(find.text('待处理任务'), findsOneWidget);
  });
}
