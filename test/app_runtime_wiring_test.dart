import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/app_runtime.dart';
import 'package:vault/app/session/llm_runtime_provider.dart';
import 'package:vault/data/agent/http_llm_client.dart';
import 'package:vault/data/agent/llm_chat_service.dart';
import 'package:vault/data/agent/llm_config_store.dart';
import 'package:vault/data/agent/openai_compat.dart';
import 'package:vault/data/backup/backup_models.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// §5 A1 装配接线验证：安全存储 / runner / 页面工厂都不发真实请求。
void main() {
  test('AppRuntime 默认空装配：没有目录与 Key 时全部诚实降级', () async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    const runtime = AppRuntime.empty;
    expect(runtime.llmRuntime, isNull);
    expect(runtime.modelDownloaderFactory, isNull);
    expect(runtime.blobBaseUrl, isNull);
    final result = await runtime.exportPlaintext(
      db: app.db,
      gateway: app.gateway,
    );
    expect(result.ok, isFalse);
    expect(result.hint, '未装配导出目录');
    final imported = await runtime.importMarkdown(
      db: app.db,
      gateway: app.gateway,
    );
    expect(imported.hints, <String>['未装配导入目录']);
  });

  test('LlmConfigService 只存 endpoint id + Key，清除后读回 null', () async {
    final store = InMemoryLlmConfigStore();
    final service = LlmConfigService(store);
    expect(await service.load(), isNull);
    await service.save(endpointId: 'deepseek', apiKey: 'sk-test-123');
    expect(await store.read(kLlmApiKeyStorageKey), 'sk-test-123');
    final loaded = await service.load();
    expect(loaded!.endpointId, 'deepseek');
    expect(loaded.apiKey, 'sk-test-123');
    expect(loaded.isComplete, isTrue);
    await service.clear();
    expect(await service.load(), isNull);
  });

  test('LlmConfigService 自定义端点往返、切预设与坏 JSON', () async {
    final store = InMemoryLlmConfigStore();
    final service = LlmConfigService(store);
    final custom = tryCustomLlmEndpoint(
      label: '自建网关',
      baseUrl: 'https://llm.example.com/v1',
      model: 'local-chat',
    )!;
    await service.save(
      endpointId: kCustomLlmEndpointId,
      apiKey: 'sk-custom',
      customEndpoint: custom,
    );
    final loaded = await service.load();
    expect(loaded, isNotNull);
    expect(loaded!.customEndpointRaw, isNotNull);
    expect(parseCustomLlmEndpoint(loaded.customEndpointRaw!)!.baseUrl,
        'https://llm.example.com/v1');

    final runtime = await loadLlmRuntime(service: service, enabled: true);
    expect(runtime!.endpoint.isCustom, isTrue);
    expect(runtime.endpoint.model, 'local-chat');
    runtime.client.close();

    await service.save(endpointId: 'deepseek', apiKey: 'sk-preset');
    expect(await store.read(kLlmCustomEndpointStorageKey), isNull);
    expect((await service.load())!.endpointId, 'deepseek');

    await store.write(kLlmCustomEndpointStorageKey, '{bad json');
    await store.write(kLlmEndpointIdStorageKey, kCustomLlmEndpointId);
    expect(await service.load(), isNull);
  });

  test('loadLlmRuntime 从安全存储装配出真实 SSE 客户端', () async {
    final store = InMemoryLlmConfigStore();
    final service = LlmConfigService(store);
    await service.save(endpointId: 'qwen', apiKey: 'sk-qwen');
    final runtime = await loadLlmRuntime(service: service, enabled: true);
    expect(runtime, isNotNull);
    expect(runtime!.endpoint.id, 'qwen');
    expect(runtime.apiKey, 'sk-qwen');
    runtime.client.close();

    final disabled = await loadLlmRuntime(service: service, enabled: false);
    expect(disabled, isNull);
  });

  test('未知厂商 id / 空 Key 不构造 LlmRuntime', () async {
    final store = InMemoryLlmConfigStore();
    final service = LlmConfigService(store);
    await service.save(endpointId: 'unknown-vendor', apiKey: 'k');
    expect(await loadLlmRuntime(service: service, enabled: true), isNull);
    await service.save(endpointId: 'deepseek', apiKey: '   ');
    expect(await loadLlmRuntime(service: service, enabled: true), isNull);
  });

  test('AppRuntime 导出目录装配后跑真实扫描与写盘，导入走同一目录',
      () async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    final root = await Directory.systemTemp.createTemp('vault-runtime-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final runtime = AppRuntime(exportRoot: root);
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'rt-note-1',
      title: '装配测试',
      body: '这是真实写进临时目录的正文',
    ));
    final exported = await runtime.exportPlaintext(
      db: app.db,
      gateway: app.gateway,
    );
    expect(exported.ok, isTrue, reason: exported.hint);
    expect(exported.writtenFiles.any((String p) => p.endsWith('rt-note-1.md')),
        isTrue);
    expect(exported.stage, PlaintextExportStage.done);

    final other = await TestApp.create(seed: 77);
    addTearDown(other.dispose);
    final imported = await runtime.importMarkdown(
      db: other.db,
      gateway: other.gateway,
    );
    expect(imported.inserted, <String>['rt-note-1']);
    expect(imported.failed, isEmpty);
    final row = await (other.db.select(other.db.entries)
          ..where((t) => t.id.equals('rt-note-1')))
        .getSingle();
    expect(row.body, '这是真实写进临时目录的正文');
  });

  test('modelsRoot 装配后工厂每次返回新的真实下载器', () async {
    final root = await Directory.systemTemp.createTemp('vault-models-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final factory = AppRuntime(modelsRoot: root).modelDownloaderFactory;
    expect(factory, isNotNull);
    final first = factory!();
    final second = factory();
    expect(first, isNot(same(second)));
    first.close();
    second.close();
  });

  test('AppRuntimeNotifier 替换 LlmRuntime 会关掉旧客户端', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appRuntimeProvider.notifier);
    final first = LlmRuntime(
      endpoint: kDefaultEndpoints.first,
      apiKey: 'first',
      client: _TrackingClient(),
    );
    final second = LlmRuntime(
      endpoint: kDefaultEndpoints.first,
      apiKey: 'second',
      client: _TrackingClient(),
    );
    notifier.setLlmRuntime(first);
    expect(container.read(appRuntimeProvider).llmRuntime, same(first));
    notifier.setLlmRuntime(second);
    expect(container.read(appRuntimeProvider).llmRuntime, same(second));
    expect((first.client as _TrackingClient).closed, isTrue);
    expect((second.client as _TrackingClient).closed, isFalse);
    second.client.close();
  });
}

class _TrackingClient extends HttpLlmClient {
  _TrackingClient() : super(client: HttpClient());

  bool closed = false;

  @override
  void close({bool force = true}) {
    closed = true;
    super.close(force: force);
  }
}
