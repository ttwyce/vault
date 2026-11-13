/// OpenAI 兼容 `/models` 的真实读取（docs/07 §7）。
///
/// 只发 GET `<baseUrl>/models`，Authorization 头带 Key；不缓存、
/// 不写日志、不把 Key 放进 URL。响应只取 `data[].id`，坏 JSON /
/// 非 200 / 超时都返回明确失败，不假装模型列表可用。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ModelListResult {
  const ModelListResult({
    required this.ok,
    required this.models,
    required this.hint,
  });

  final bool ok;
  final List<String> models;
  final String hint;
}

class HttpModelCatalog {
  HttpModelCatalog({HttpClient? client})
      : _client = client ?? HttpClient();

  final HttpClient _client;

  void close({bool force = true}) => _client.close(force: force);

  Uri _uri(String baseUrl) {
    final base = Uri.parse(baseUrl);
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$prefix/models');
  }

  Future<ModelListResult> listModels({
    required String baseUrl,
    required String apiKey,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final request = await _client.getUrl(_uri(baseUrl)).timeout(timeout);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        return ModelListResult(
          ok: false,
          models: const <String>[],
          hint: '模型列表返回 HTTP ${response.statusCode}',
        );
      }
      final raw = await response
          .transform(utf8.decoder)
          .timeout(timeout)
          .join();
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['data'] is! List) {
        return const ModelListResult(
          ok: false,
          models: <String>[],
          hint: '模型列表格式不符合 OpenAI 兼容接口',
        );
      }
      final models = <String>{
        for (final item in decoded['data'] as List)
          if (item is Map && item['id'] is String) item['id'] as String,
      }.toList()
        ..sort();
      return ModelListResult(
        ok: true,
        models: List<String>.unmodifiable(models),
        hint: models.isEmpty ? '服务端未返回可用模型' : '获取到 ${models.length} 个模型',
      );
    } on TimeoutException {
      return const ModelListResult(
        ok: false,
        models: <String>[],
        hint: '获取模型列表超时',
      );
    } on SocketException {
      return const ModelListResult(
        ok: false,
        models: <String>[],
        hint: '网络不可达，无法获取模型列表',
      );
    } on Object {
      return const ModelListResult(
        ok: false,
        models: <String>[],
        hint: '模型列表读取失败',
      );
    }
  }
}
