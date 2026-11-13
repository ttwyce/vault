/// 云端 LLM Key / 多端点的安全存储（docs/20 §5 A1）。
///
/// **Key 与端点配置都只放系统安全区**：不进 settings.json、不进 LocalSettings、
/// 不进日志 / 异常 / toString / 发布审计的输入文本。
/// 存储抽象可注入，widget 测试不需要平台通道就能覆盖读写路径。
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'openai_compat.dart';

const String kLlmApiKeyStorageKey = 'vault.llm.api_key';
const String kLlmEndpointIdStorageKey = 'vault.llm.endpoint_id';
const String kLlmCustomEndpointStorageKey = 'vault.llm.custom_endpoint';
const String kLlmProfilesStorageKey = 'vault.llm.profiles';

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

/// 一个可切换的端点档案。Key 单独存一份，所有档案共用；
/// 切换档案只改 activeId，不重复保存 Key。
class LlmProfile {
  const LlmProfile({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.model,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String model;

  bool get isPreset =>
      kDefaultEndpoints.any((LlmEndpoint e) => e.id == id);

  LlmEndpoint toEndpoint() => isPreset
      ? kDefaultEndpoints.firstWhere((LlmEndpoint e) => e.id == id)
      : LlmEndpoint(
          id: kCustomLlmEndpointId,
          label: label,
          baseUrl: baseUrl,
          model: model,
          isCustom: true,
        );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'base_url': baseUrl,
        'model': model,
      };

  static LlmProfile? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, Object?>.from(raw);
    final id = map['id'];
    final label = map['label'];
    final baseUrl = map['base_url'];
    final model = map['model'];
    if (id is! String || label is! String || baseUrl is! String ||
        model is! String) {
      return null;
    }
    if (id == kCustomLlmEndpointId) {
      final endpoint = tryCustomLlmEndpoint(
        label: label,
        baseUrl: baseUrl,
        model: model,
      );
      if (endpoint == null) return null;
      return LlmProfile(
        id: id,
        label: endpoint.label,
        baseUrl: endpoint.baseUrl,
        model: endpoint.model,
      );
    }
    if (!kDefaultEndpoints.any((LlmEndpoint e) => e.id == id)) return null;
    return LlmProfile(id: id, label: label, baseUrl: baseUrl, model: model);
  }
}

/// 当前配置：活动档案 + 所有档案 + Key。坏 JSON 按「无档案」处理。
class LlmConfig {
  const LlmConfig({
    required this.endpointId,
    required this.apiKey,
    required this.profiles,
    this.customEndpointRaw,
  });

  final String endpointId;
  final String apiKey;
  final List<LlmProfile> profiles;
  final String? customEndpointRaw;

  bool get isComplete => apiKey.trim().isNotEmpty;

  LlmProfile? get active {
    for (final profile in profiles) {
      if (profile.id == endpointId) return profile;
    }
    return null;
  }
}

class LlmConfigService {
  const LlmConfigService(this.store);

  final LlmConfigStore store;

  Future<List<LlmProfile>> _loadProfiles() async {
    final raw = await store.read(kLlmProfilesStorageKey);
    if (raw == null) return <LlmProfile>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <LlmProfile>[];
      return <LlmProfile>[
        for (final item in decoded)
          if (LlmProfile.fromJson(item) case LlmProfile p) p,
      ];
    } on Object {
      return <LlmProfile>[];
    }
  }

  Future<LlmConfig?> load() async {
    final endpointId = await store.read(kLlmEndpointIdStorageKey);
    final apiKey = await store.read(kLlmApiKeyStorageKey);
    if (endpointId == null || apiKey == null) return null;
    final profiles = await _loadProfiles();
    // 旧版只有两个键：用保存的 id / 自定义 JSON 补出一个档案，平滑迁移。
    if (profiles.isEmpty) {
      final legacy = endpointId == kCustomLlmEndpointId
          ? parseCustomLlmEndpoint(
              await store.read(kLlmCustomEndpointStorageKey) ?? '')
          : resolveLlmEndpoint(endpointId, null);
      if (legacy != null) {
        profiles.add(LlmProfile(
          id: endpointId,
          label: legacy.label,
          baseUrl: legacy.baseUrl,
          model: legacy.model,
        ));
      }
    }
    final customRaw = endpointId == kCustomLlmEndpointId
        ? await store.read(kLlmCustomEndpointStorageKey)
        : null;
    if (endpointId == kCustomLlmEndpointId && customRaw == null &&
        profiles.every((LlmProfile p) => p.id != kCustomLlmEndpointId)) {
      return null;
    }
    if (endpointId == kCustomLlmEndpointId && customRaw != null &&
        parseCustomLlmEndpoint(customRaw) == null) {
      return null;
    }
    return LlmConfig(
      endpointId: endpointId,
      apiKey: apiKey,
      profiles: List<LlmProfile>.unmodifiable(profiles),
      customEndpointRaw: customRaw,
    );
  }

  /// 新增/更新一个档案并设为活动档案；Key 单独保存。
  Future<void> saveProfile({
    required LlmProfile profile,
    required String apiKey,
  }) async {
    final profiles = await _loadProfiles();
    final next = <LlmProfile>[
      for (final item in profiles)
        if (item.id != profile.id) item,
      profile,
    ];
    await store.write(
      kLlmProfilesStorageKey,
      jsonEncode(<Object?>[for (final item in next) item.toJson()]),
    );
    await store.write(kLlmEndpointIdStorageKey, profile.id);
    await store.write(kLlmApiKeyStorageKey, apiKey);
    if (profile.id == kCustomLlmEndpointId) {
      await store.write(
        kLlmCustomEndpointStorageKey,
        jsonEncode(<String, Object?>{
          'label': profile.label,
          'base_url': profile.baseUrl,
          'model': profile.model,
        }),
      );
    }
  }

  /// 兼容旧调用：单端点保存（会替换/新增同名档案）。
  Future<void> save({
    required String endpointId,
    required String apiKey,
    LlmEndpoint? customEndpoint,
  }) async {
    final endpoint = customEndpoint ?? resolveLlmEndpoint(endpointId, null);
    final profile = endpoint == null
        ? null
        : LlmProfile(
            id: endpointId,
            label: endpoint.label,
            baseUrl: endpoint.baseUrl,
            model: endpoint.model,
          );
    if (profile != null) {
      await saveProfile(profile: profile, apiKey: apiKey);
    } else {
      await store.write(kLlmEndpointIdStorageKey, endpointId);
      await store.write(kLlmApiKeyStorageKey, apiKey);
    }
    if (customEndpoint == null) {
      await store.delete(kLlmCustomEndpointStorageKey);
    }
  }

  Future<void> removeProfile(String id) async {
    final profiles = await _loadProfiles();
    final next = <LlmProfile>[
      for (final item in profiles)
        if (item.id != id) item,
    ];
    if (next.isEmpty) {
      await clear();
      return;
    }
    await store.write(
      kLlmProfilesStorageKey,
      jsonEncode(<Object?>[for (final item in next) item.toJson()]),
    );
    final active = await store.read(kLlmEndpointIdStorageKey);
    if (active == id) {
      await store.write(kLlmEndpointIdStorageKey, next.first.id);
      if (id == kCustomLlmEndpointId) {
        await store.delete(kLlmCustomEndpointStorageKey);
      }
    }
  }

  Future<void> clear() async {
    await store.delete(kLlmEndpointIdStorageKey);
    await store.delete(kLlmApiKeyStorageKey);
    await store.delete(kLlmCustomEndpointStorageKey);
    await store.delete(kLlmProfilesStorageKey);
  }
}
