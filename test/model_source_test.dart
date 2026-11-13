
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/model_source_provider.dart';
import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/data/search/model_source_store.dart';
import 'package:vault/features/settings/model_source_page.dart';
import 'package:vault/features/settings/settings_hub_page.dart';

import 'support/test_harness.dart';

/// 自定义模型下载源：配置持久化 + 真实下载写盘。
void main() {
  test('ModelSourceService 校验、保存、读取、移除', () async {
    final store = InMemoryModelSourceStore();
    final service = ModelSourceService(store);
    final hash = 'a' * 64;
    const good = ModelDownloadSource(
      modelId: 'm1',
      url: 'https://example.com/m.gguf',
      sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      bytes: 1024,
    );
    expect(good.valid, isTrue);
    await service.save(good);
    expect((await service.loadAll())['m1']!.url, 'https://example.com/m.gguf');
    expect(
      () => service.save(const ModelDownloadSource(
        modelId: 'bad',
        url: 'ftp://x',
        sha256: 'nope',
        bytes: 0,
      )),
      throwsA(isA<FormatException>()),
    );
    await service.remove('m1');
    expect(await service.loadAll(), isEmpty);
    expect(hash.length, 64);
  });

  testWidgets('设置中心与模型页有下载源入口', (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(theme: SketchTheme.light, home: const SettingsHubPage()),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('模型下载源'), findsOneWidget);
  });

  testWidgets('模型下载源页可打开且显示表单', (WidgetTester tester) async {
    final store = InMemoryModelSourceStore();
    final container = ProviderContainer(
      overrides: [modelSourceStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ModelSourcePage()),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('保存下载源'), findsOneWidget);
    expect(find.text('下载并校验'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
  });
}
