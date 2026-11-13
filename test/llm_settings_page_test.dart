import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/app_runtime.dart';
import 'package:vault/app/session/llm_runtime_provider.dart';
import 'package:vault/data/agent/llm_config_store.dart';
import 'package:vault/data/agent/openai_compat.dart';
import 'package:vault/features/settings/llm_settings_page.dart';

/// 云端模型设置页：Key 不回填表单，保存 / 清除即时推进 AppRuntime。
void main() {
  Finder field(String key) => find.byKey(ValueKey<String>(key));

  Future<void> pumpPage(
    WidgetTester tester,
    InMemoryLlmConfigStore store,
    ProviderContainer container,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LlmSettingsPage()),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('预设端点保存 Key 后状态变为已配置，清除后回到未配置',
      (WidgetTester tester) async {
    final store = InMemoryLlmConfigStore();
    final container = ProviderContainer(
      overrides: [llmConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await pumpPage(tester, store, container);

    expect(find.textContaining('状态：未配置'), findsOneWidget);
    await tester.enterText(field('api-key').evaluate().isEmpty
        ? find.byType(TextField)
        : find.descendant(
            of: field('api-key'), matching: find.byType(TextField)),
        'sk-from-user');
    await tester.tap(find.text('保存'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await store.read(kLlmApiKeyStorageKey), 'sk-from-user');
    expect(await store.read(kLlmEndpointIdStorageKey),
        kDefaultEndpoints.first.id);
    final runtime = container.read(appRuntimeProvider).llmRuntime;
    expect(runtime, isNotNull);
    expect(runtime!.endpoint.isCustom, isFalse);
    expect(find.textContaining('状态：已配置'), findsOneWidget);
    expect(find.text('sk-from-user'), findsNothing);

    await tester.tap(find.text('清除'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await store.read(kLlmApiKeyStorageKey), isNull);
    expect(await store.read(kLlmEndpointIdStorageKey), isNull);
    expect(container.read(appRuntimeProvider).llmRuntime, isNull);
    expect(find.textContaining('状态：未配置'), findsOneWidget);
  });

  testWidgets('自定义端点：名称 / https 地址 / 模型名持久化并注入',
      (WidgetTester tester) async {
    final store = InMemoryLlmConfigStore();
    final container = ProviderContainer(
      overrides: [llmConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await pumpPage(tester, store, container);

    await tester.tap(find.text('自定义端点'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
        find.descendant(
            of: field('custom-label'), matching: find.byType(TextField)),
        '自建网关');
    await tester.enterText(
        find.descendant(
            of: field('custom-base-url'), matching: find.byType(TextField)),
        'https://llm.example.com/v1/');
    await tester.enterText(
        find.descendant(
            of: field('custom-model'), matching: find.byType(TextField)),
        'local-chat');
    await tester.enterText(
        find.descendant(
            of: field('api-key'), matching: find.byType(TextField)),
        'sk-custom');

    await tester.tap(find.text('保存'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await store.read(kLlmEndpointIdStorageKey),
        kCustomLlmEndpointId);
    final raw = await store.read(kLlmCustomEndpointStorageKey);
    expect(raw, isNotNull);
    final endpoint = parseCustomLlmEndpoint(raw!);
    expect(endpoint, isNotNull);
    expect(endpoint!.label, '自建网关');
    expect(endpoint.baseUrl, 'https://llm.example.com/v1');
    expect(endpoint.model, 'local-chat');
    expect(endpoint.isCustom, isTrue);

    final runtime = container.read(appRuntimeProvider).llmRuntime;
    expect(runtime, isNotNull);
    expect(runtime!.endpoint.isCustom, isTrue);
    expect(runtime.endpoint.baseUrl, 'https://llm.example.com/v1');
    expect(runtime.endpoint.model, 'local-chat');
    expect(runtime.apiKey, 'sk-custom');

    // 从安全存储重新装配，仍得到同一个自定义端点。
    final restored = await loadLlmRuntime(
      service: LlmConfigService(store),
      enabled: true,
    );
    expect(restored, isNotNull);
    expect(restored!.endpoint.baseUrl, 'https://llm.example.com/v1');
    restored.client.close();
  });

  testWidgets('自定义端点非法地址不落库、不注入',
      (WidgetTester tester) async {
    final store = InMemoryLlmConfigStore();
    final container = ProviderContainer(
      overrides: [llmConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await pumpPage(tester, store, container);

    await tester.tap(find.text('自定义端点'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
        find.descendant(
            of: field('custom-label'), matching: find.byType(TextField)),
        '坏地址');
    await tester.enterText(
        find.descendant(
            of: field('custom-base-url'), matching: find.byType(TextField)),
        'http://plain.example.com/v1');
    await tester.enterText(
        find.descendant(
            of: field('custom-model'), matching: find.byType(TextField)),
        'm');
    await tester.enterText(
        find.descendant(
            of: field('api-key'), matching: find.byType(TextField)),
        'sk-bad');
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('自定义端点需要'), findsOneWidget);
    expect(await store.read(kLlmApiKeyStorageKey), isNull);
    expect(container.read(appRuntimeProvider).llmRuntime, isNull);
  });

  testWidgets('已保存的 Key 与自定义端点重开后不回显 Key',
      (WidgetTester tester) async {
    final store = InMemoryLlmConfigStore();
    await LlmConfigService(store).save(
      endpointId: kCustomLlmEndpointId,
      apiKey: 'sk-existing-secret',
      customEndpoint: tryCustomLlmEndpoint(
        label: '我的端点',
        baseUrl: 'https://secret.example.com/v1',
        model: 'private-model',
      ),
    );
    final container = ProviderContainer(
      overrides: [llmConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await pumpPage(tester, store, container);

    expect(find.textContaining('已保存云端 Key（未显示）'), findsOneWidget);
    expect(find.text('sk-existing-secret'), findsNothing);
    final keyField = tester.widget<TextField>(find.descendant(
        of: field('api-key'), matching: find.byType(TextField)));
    expect(keyField.controller?.text ?? '', isEmpty);
    expect(keyField.obscureText, isTrue);
    final labelField = tester.widget<TextField>(find.descendant(
        of: field('custom-label'), matching: find.byType(TextField)));
    expect(labelField.controller?.text, '我的端点');
  });
}
