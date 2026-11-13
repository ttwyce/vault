/// 自定义端侧模型下载源（docs/06 §5）。
///
/// 内置 manifest 的 sha256 是占位值且 sources 为空；真实下载必须由用户
/// 提供 URL / sha256 / 字节数。配置只放系统安全区，不进 settings.json、
/// 不进日志；不内置模型二进制、不新增依赖。
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String kModelSourcesStorageKey = 'vault.models.custom_sources';

abstract class ModelSourceStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureModelSourceStore implements ModelSourceStore {
  const SecureModelSourceStore({this.storage = const FlutterSecureStorage()});

  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

class InMemoryModelSourceStore implements ModelSourceStore {
  final Map<String, String> _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class ModelDownloadSource {
  const ModelDownloadSource({
    required this.modelId,
    required this.url,
    required this.sha256,
    required this.bytes,
  });

  final String modelId;
  final String url;
  final String sha256;
  final int bytes;

  bool get valid =>
      modelId.trim().isNotEmpty &&
      Uri.tryParse(url)?.hasScheme == true &&
      (Uri.parse(url).scheme == 'https' || Uri.parse(url).scheme == 'http') &&
      RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) &&
      bytes > 0;

  Map<String, Object?> toJson() => <String, Object?>{
        'model_id': modelId,
        'url': url,
        'sha256': sha256,
        'bytes': bytes,
      };

  static ModelDownloadSource? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, Object?>.from(raw);
    final id = map['model_id'];
    final url = map['url'];
    final hash = map['sha256'];
    final size = map['bytes'];
    if (id is! String || url is! String || hash is! String || size is! int) {
      return null;
    }
    final source = ModelDownloadSource(
      modelId: id,
      url: url,
      sha256: hash,
      bytes: size,
    );
    return source.valid ? source : null;
  }
}

class ModelSourceService {
  const ModelSourceService(this.store);

  final ModelSourceStore store;

  Future<Map<String, ModelDownloadSource>> loadAll() async {
    final raw = await store.read(kModelSourcesStorageKey);
    if (raw == null) return <String, ModelDownloadSource>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String, ModelDownloadSource>{};
      final out = <String, ModelDownloadSource>{};
      for (final item in decoded) {
        final source = ModelDownloadSource.fromJson(item);
        if (source != null) out[source.modelId] = source;
      }
      return out;
    } on Object {
      return <String, ModelDownloadSource>{};
    }
  }

  Future<void> save(ModelDownloadSource source) async {
    if (!source.valid) {
      throw const FormatException('模型下载源不合法：需要 http(s) URL、'
          '64 位小写 sha256 与正数 bytes');
    }
    final all = await loadAll();
    all[source.modelId] = source;
    await store.write(
      kModelSourcesStorageKey,
      jsonEncode(<Object?>[
        for (final item in all.values) item.toJson(),
      ]),
    );
  }

  Future<void> remove(String modelId) async {
    final all = await loadAll();
    all.remove(modelId);
    if (all.isEmpty) {
      await store.delete(kModelSourcesStorageKey);
    } else {
      await store.write(
        kModelSourcesStorageKey,
        jsonEncode(<Object?>[
          for (final item in all.values) item.toJson(),
        ]),
      );
    }
  }

  Future<void> clear() => store.delete(kModelSourcesStorageKey);
}
