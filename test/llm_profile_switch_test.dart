import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/app_runtime.dart';
import 'package:vault/app/session/llm_runtime_provider.dart';
import 'package:vault/data/agent/llm_config_store.dart';
import 'package:vault/data/agent/openai_compat.dart';
import 'package:vault/features/settings/llm_settings_page.dart';

/// 多端点切换必须真的写活动档案并更新 AppRuntime。
void main() {
  testWidgets('保存两个档案后点选切换会持久化 activeId 并重建 runtime',
      (WidgetTester tester) async {
    final store = InMemoryLlmConfigStore();
    final service = LlmConfigService(store);
    await service.saveProfile(
      profile: LlmProfile(
        id: 'deepseek',
        label: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-chat',
      ),
      apiKey: 'k1',
    );
    await service.saveProfile(
      profile: LlmProfile(
        id: 'qwen',
        label: '通义千问',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        model: 'qwen-plus',
      ),
      apiKey: 'k2',
    );
    final container = ProviderContainer(
      overrides: [llmConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LlmSettingsPage()),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('已保存 2 个端点（Key 未显示）'), findsOneWidget);
    await tester.tap(find.text('DeepSeek').first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((await service.load())!.endpointId, 'deepseek');
    final runtime = container.read(appRuntimeProvider).llmRuntime;
    expect(runtime, isNotNull);
    expect(runtime!.endpoint.id, 'deepseek');
    expect(runtime.endpoint.model, 'deepseek-chat');
    expect(find.textContaining('已切换到'), findsOneWidget);
  });

  test('LlmProfile 预设档案保留用户保存的 model/baseUrl', () {
    final profile = LlmProfile(
      id: 'deepseek',
      label: '自建兼容',
      baseUrl: 'https://proxy.example.com/v1',
      model: 'my-deepseek',
    );
    final endpoint = profile.toEndpoint();
    expect(endpoint.id, 'deepseek');
    expect(endpoint.label, '自建兼容');
    expect(endpoint.baseUrl, 'https://proxy.example.com/v1');
    expect(endpoint.model, 'my-deepseek');
    expect(endpoint.isCustom, isFalse);
    expect(resolveLlmEndpoint('unknown', null), isNull);
  });
}
