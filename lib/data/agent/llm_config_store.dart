/// 云端 LLM Key / 端点的安全存储（docs/20 §5 A1）。
///
/// **Key 与自定义端点都只放系统安全区**：不进 settings.json、不进 LocalSettings、
/// 不进日志 / 异常 / toString / 发布审计的输入文本。
/// 存储抽象可注入，widget 测试不需要平台通道就能覆盖读写路径。
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'openai_compat.dart';

const String kLlmApiKeyStorageKey = 'vault.llm.api_key';
const String kLlmEndpointIdStorageKey = 'vault.llm.endpoint_id';
const String kLlmCustomEndpointStorageKey = 'vault.llm.custom_endpoint';

/// 可替换的键值存储接口；生产用 [SecureLlmConfigStore]。
abstract class LlmConfigStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureLlmConfigStore implements LlmConfigStore {
  const SecureLlmConfigStore({this.storage = const FlutterSecureStorage()});

  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

class InMemoryLlmConfigStore implements LlmConfigStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// 保存的配置。预设端点只记 id（baseUrl / model 来自代码常量）；
/// 自定义端点另存一条 JSON，坏值按「未配置」处理。
class LlmConfig {
  const LlmConfig({
    required this.endpointId,
    required this.apiKey,
    this.customEndpointRaw,
  });

  final String endpointId;
  final String apiKey;
  final String? customEndpointRaw;

  bool get isComplete => apiKey.trim().isNotEmpty;
}

class LlmConfigService {
  const LlmConfigService(this.store);

  final LlmConfigStore store;

  Future<LlmConfig?> load() async {
    final endpointId = await store.read(kLlmEndpointIdStorageKey);
    final apiKey = await store.read(kLlmApiKeyStorageKey);
    if (endpointId == null || apiKey == null) return null;
    final customRaw = endpointId == kCustomLlmEndpointId
        ? await store.read(kLlmCustomEndpointStorageKey)
        : null;
    if (endpointId == kCustomLlmEndpointId &&
        parseCustomLlmEndpoint(customRaw ?? '') == null) {
      return null;
    }
    return LlmConfig(
      endpointId: endpointId,
      apiKey: apiKey,
      customEndpointRaw: customRaw,
    );
  }

  /// [customEndpoint] 非空时写自定义端点 JSON；选预设时删掉旧配置，
  /// 避免把用户私有 baseUrl 残留在设备上。
  Future<void> save({
    required String endpointId,
    required String apiKey,
    LlmEndpoint? customEndpoint,
  }) async {
    if (customEndpoint != null) {
      await store.write(
        kLlmCustomEndpointStorageKey,
        jsonEncode(<String, Object?>{
          'label': customEndpoint.label,
          'base_url': customEndpoint.baseUrl,
          'model': customEndpoint.model,
        }),
      );
    } else {
      await store.delete(kLlmCustomEndpointStorageKey);
    }
    await store.write(kLlmEndpointIdStorageKey, endpointId);
    await store.write(kLlmApiKeyStorageKey, apiKey);
  }

  Future<void> clear() async {
    await store.delete(kLlmEndpointIdStorageKey);
    await store.delete(kLlmApiKeyStorageKey);
    await store.delete(kLlmCustomEndpointStorageKey);
  }
}
