import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/model_status.dart';
import 'package:vault/features/chat/chat_page.dart';

import 'support/test_harness.dart';

/// docs/07 C5 无模型 / 无 Key 明确引导测试。
void main() {
  test('端侧未就绪 / 云端无 Key / 两端就绪 / 已授权', () {
    final none = resolveModelStatus(
      availability: const ModelAvailability(
        onDeviceModelReady: false,
        hasCloudKey: false,
      ),
    );
    expect(none.subtitle, contains('未就绪'));
    expect(none.guidance, contains('检索与工具仍可用'));
    expect(none.canAnswer, isFalse);

    final cloudNoKey = resolveModelStatus(
      availability: const ModelAvailability(
        onDeviceModelReady: true,
        hasCloudKey: false,
      ),
      task: 'long_doc_analysis',
      privacyAuthorized: true,
    );
    expect(cloudNoKey.subtitle, contains('未配置 API Key'));
    expect(cloudNoKey.guidance, contains('配置 API Key'));
    expect(cloudNoKey.canAnswer, isFalse);

    final cloudOk = resolveModelStatus(
      availability: const ModelAvailability(
        onDeviceModelReady: true,
        hasCloudKey: true,
        cloudProviderLabel: 'DeepSeek',
      ),
      task: 'long_doc_analysis',
      privacyAuthorized: true,
    );
    expect(cloudOk.subtitle, contains('DeepSeek'));
    expect(cloudOk.canAnswer, isTrue);

    final local = resolveModelStatus(
      availability: const ModelAvailability(
        onDeviceModelReady: true,
        hasCloudKey: false,
      ),
    );
    expect(local.subtitle, '端侧模型 · 就绪');
    expect(local.canAnswer, isTrue);
  });

  testWidgets('聊天页默认显示诚实引导，不假装端侧模型就绪',
      (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: Scaffold(body: ChatPage())),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('端侧模型 · 未就绪'), findsWidgets);
    expect(find.textContaining('检索与工具仍可用'), findsOneWidget);
  });

  testWidgets('当前对话条显示真实模型状态，不写死端侧模型就绪',
      (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: Scaffold(body: ChatPage())),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('端侧模型 · 未就绪'), findsWidgets);
    expect(find.text('端侧模型'), findsNothing,
        reason: '旧版写死的「端侧模型」标签已移除');
  });
}
