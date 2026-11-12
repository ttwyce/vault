import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/app_runtime.dart';
import 'package:vault/app/session/llm_runtime_provider.dart';
import 'package:vault/data/agent/llm_config_store.dart';
import 'package:vault/features/settings/llm_settings_page.dart';

/// 云端模型设置页：Key 不回填表单，保存 / 清除即时推进 AppRuntime。
void main() {
  testWidgets('保存 Key 后状态变为已配置，清除后回到未配置',
      (WidgetTester tester) async {
    final store = InMemoryLlmConfigStore();
    final container = ProviderContainer(
      overrides: [
        llmConfigStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LlmSettingsPage()),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('状态：未配置'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'sk-from-user');
    await tester.tap(find.text('保存'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await store.read(kLlmApiKeyStorageKey), 'sk-from-user');
    expect(container.read(appRuntimeProvider).llmRuntime, isNotNull);
    expect(find.textContaining('状态：已配置'), findsOneWidget);
    // Key 只存在安全区，不回填到可截图的表单。
    expect(find.text('sk-from-user'), findsNothing);

    await tester.tap(find.text('清除'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await store.read(kLlmApiKeyStorageKey), isNull);
    expect(container.read(appRuntimeProvider).llmRuntime, isNull);
    expect(find.textContaining('状态：未配置'), findsOneWidget);
  });

  testWidgets('已保存的 Key 在页面里不回显', (WidgetTester tester) async {
    final store = InMemoryLlmConfigStore();
    await LlmConfigService(store).save(
      endpointId: 'kimi',
      apiKey: 'sk-existing-secret',
    );
    final container = ProviderContainer(
      overrides: [
        llmConfigStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LlmSettingsPage()),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('已保存云端 Key（未显示）'), findsOneWidget);
    expect(find.text('sk-existing-secret'), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text ?? '', isEmpty);
    expect(field.obscureText, isTrue);
  });
}
