/// 端侧向量模型 manifest（docs/06 §3 / §4）。
///
/// 只定义结构与「解析即校验」：不下载、不加载 GGUF / ONNX、不碰文件路径。
/// 两个最容易踩的坑在这里被钉死：
/// - EmbeddingGemma 的 query/doc 任务前缀必须不同
/// - Qwen3-Embedding 必须 last-token pooling（不是 mean）
///
/// 文档明确：manifest 打包进 App、不依赖后端；换模型时旧向量必须全部作废
/// （工程红线 3：禁止混合不同 embedding 模型的向量）。
library;

import 'dart:convert';

/// pooling 方式。Qwen3 用 last，其余多为 mean / cls。
enum Pooling { cls, mean, last }

class EmbeddingModelSpec {
  const EmbeddingModelSpec({
    required this.id,
    required this.name,
    required this.dim,
    required this.mrl,
    required this.ctx,
    required this.quant,
    required this.runtime,
    required this.diskBytes,
    required this.ramMb,
    required this.sha256,
    required this.license,
    required this.builtin,
    required this.pooling,
    required this.queryTemplate,
    required this.docTemplate,
    required this.sources,
  });

  final String id;
  final String name;
  final int dim;

  /// 可裁剪维度（MRL）；null 表示不支持。
  final List<int>? mrl;
  final int ctx;
  final String quant;
  final String runtime;
  final int diskBytes;
  final int ramMb;
  final String sha256;
  final String license;
  final bool builtin;
  final Pooling pooling;

  /// 查询侧 prompt 模板，`{text}` 是占位符。
  final String queryTemplate;

  /// 文档侧 prompt 模板。
  final String docTemplate;
  final List<String> sources;

  bool get supportsMrl => mrl != null && mrl!.isNotEmpty;

  /// 是否允许把该模型生成的向量与另一模型混用（永远不允许）。
  bool isCompatibleWith(EmbeddingModelSpec other) =>
      id == other.id && dim == other.dim;

  String buildQuery(String text) => _apply(queryTemplate, text);
  /// `{text}` 是「标题 + 正文」合成后的文档文本；模板只需一个占位符，
  /// 避免各模型自己发明 `{title}` 造成解析与拼接不一致。
  String buildDoc(String title, String text) =>
      _apply(docTemplate, title.isEmpty ? text : '$title | $text');

  static String _apply(String template, String text) =>
      template.replaceAll('{text}', text);

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'dim': dim,
        'mrl': mrl,
        'ctx': ctx,
        'quant': quant,
        'runtime': runtime,
        'disk_bytes': diskBytes,
        'ram_mb': ramMb,
        'sha256': sha256,
        'license': license,
        'builtin': builtin,
        'pooling': pooling.name,
        'prompt': <String, Object?>{
          'query': queryTemplate,
          'doc': docTemplate,
        },
        'sources': sources,
      };

  factory EmbeddingModelSpec.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('模型 spec 不是 JSON 对象');
    }
    final map = Map<String, Object?>.from(raw);
    final id = _string(map, 'id');
    final dim = _int(map, 'dim');
    if (dim <= 0) {
      throw const FormatException('模型 dim 必须为正');
    }
    final poolingRaw = _string(map, 'pooling');
    final pooling = Pooling.values
        .where((Pooling p) => p.name == poolingRaw)
        .firstOrNull;
    if (pooling == null) {
      throw FormatException('模型 pooling 非法：$poolingRaw');
    }
    final prompt = map['prompt'];
    if (prompt is! Map) {
      throw const FormatException('模型缺少 prompt 模板');
    }
    final query = _string(Map<String, Object?>.from(prompt), 'query');
    final doc = _string(Map<String, Object?>.from(prompt), 'doc');
    if (!query.contains('{text}') || !doc.contains('{text}')) {
      throw const FormatException('模型 prompt 模板必须含 {text} 占位符');
    }
    final sha = _string(map, 'sha256');
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      throw const FormatException('模型 sha256 必须是 64 位小写十六进制');
    }
    final mrlRaw = map['mrl'];
    final mrl = mrlRaw == null
        ? null
        : (mrlRaw as List)
            .map((Object? v) => (v! as num).toInt())
            .toList(growable: false);

    return EmbeddingModelSpec(
      id: id,
      name: _string(map, 'name'),
      dim: dim,
      mrl: mrl,
      ctx: _int(map, 'ctx'),
      quant: _string(map, 'quant'),
      runtime: _string(map, 'runtime'),
      diskBytes: _int(map, 'disk_bytes'),
      ramMb: _int(map, 'ram_mb'),
      sha256: sha,
      license: _string(map, 'license'),
      builtin: map['builtin'] == true,
      pooling: pooling,
      queryTemplate: query,
      docTemplate: doc,
      sources: (map['sources'] as List? ?? const <Object?>[])
          .map((Object? v) => v.toString())
          .toList(growable: false),
    );
  }

  static String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('模型 $key 缺失或不是字符串');
    }
    return value;
  }

  static int _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('模型 $key 必须是整数');
  }
}

class EmbeddingManifest {
  const EmbeddingManifest({
    required this.schema,
    required this.models,
  });

  final int schema;
  final List<EmbeddingModelSpec> models;

  EmbeddingModelSpec? byId(String id) =>
      models.where((EmbeddingModelSpec m) => m.id == id).firstOrNull;

  /// 内置模型必须恰好一个：没下载任何东西前语义搜索也要可用。
  EmbeddingModelSpec? get builtin =>
      models.where((EmbeddingModelSpec m) => m.builtin).firstOrNull;

  factory EmbeddingManifest.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('manifest 不是 JSON 对象');
    }
    final map = Map<String, Object?>.from(decoded);
    final schema = map['schema'];
    if (schema is! int || schema < 1) {
      throw const FormatException('manifest schema 非法');
    }
    final modelsRaw = map['models'];
    if (modelsRaw is! List) {
      throw const FormatException('manifest 缺少 models 数组');
    }
    final models = <EmbeddingModelSpec>[
      for (final item in modelsRaw) EmbeddingModelSpec.fromJson(item),
    ];
    final ids = <String>{};
    for (final model in models) {
      if (!ids.add(model.id)) {
        throw FormatException('manifest 里模型 id 重复：${model.id}');
      }
    }
    if (models.where((EmbeddingModelSpec m) => m.builtin).length > 1) {
      throw const FormatException('manifest 只能有一个内置模型');
    }
    return EmbeddingManifest(schema: schema, models: models);
  }
}

/// 校验文档 §3.2 的两个坑：模型特定配置必须写进 manifest。
class ModelConfigAudit {
  const ModelConfigAudit(this.issues);

  final List<String> issues;

  bool get ok => issues.isEmpty;
}

ModelConfigAudit auditModelConfig(EmbeddingModelSpec model) {
  final issues = <String>[];
  if (model.id.contains('gemma') &&
      model.queryTemplate == model.docTemplate) {
    issues.add('EmbeddingGemma 的 query/doc 前缀必须不同，否则召回率下降');
  }
  if (model.id.contains('qwen') && model.pooling != Pooling.last) {
    issues.add('Qwen3-Embedding 必须 last-token pooling，用 mean 会静默失效');
  }
  if (model.supportsMrl &&
      model.mrl!.any((int d) => d <= 0 || d > model.dim)) {
    issues.add('MRL 维度必须在 1..dim 之间');
  }
  if (model.diskBytes <= 0 || model.ramMb <= 0) {
    issues.add('磁盘 / 内存预算必须为正');
  }
  return ModelConfigAudit(List<String>.unmodifiable(issues));
}

/// 内置四套模型的默认 manifest（与 docs/06 §4 一致，无下载源）。
const List<Map<String, Object?>> kDefaultModelSpecs = <Map<String, Object?>>[
  <String, Object?>{
    'id': 'bge-small-zh-v15-int8',
    'name': 'BGE Small 中文',
    'dim': 512,
    'mrl': null,
    'ctx': 512,
    'quant': 'int8',
    'runtime': 'onnx',
    'disk_bytes': 26214400,
    'ram_mb': 80,
    'sha256': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'license': 'MIT',
    'builtin': true,
    'pooling': 'cls',
    'prompt': <String, Object?>{'query': '{text}', 'doc': '{text}'},
    'sources': <String>[],
  },
  <String, Object?>{
    'id': 'multilingual-e5-small-int8',
    'name': 'E5 Small 多语言',
    'dim': 384,
    'mrl': null,
    'ctx': 512,
    'quant': 'int8',
    'runtime': 'onnx',
    'disk_bytes': 125829120,
    'ram_mb': 180,
    'sha256': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    'license': 'MIT',
    'builtin': false,
    'pooling': 'mean',
    'prompt': <String, Object?>{
      'query': 'query: {text}',
      'doc': 'passage: {text}',
    },
    'sources': <String>[],
  },
  <String, Object?>{
    'id': 'embeddinggemma-300m-q8',
    'name': 'EmbeddingGemma 300M',
    'dim': 768,
    'mrl': <int>[768, 512, 256, 128],
    'ctx': 2048,
    'quant': 'Q8_0',
    'runtime': 'gguf',
    'disk_bytes': 330000000,
    'ram_mb': 200,
    'sha256': 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    'license': 'Gemma Terms of Use',
    'builtin': false,
    'pooling': 'mean',
    'prompt': <String, Object?>{
      'query': 'task: search result | query: {text}',
      'doc': '{text}',
    },
    'sources': <String>[],
  },
  <String, Object?>{
    'id': 'qwen3-embedding-0.6b-q4',
    'name': 'Qwen3-Embedding 0.6B',
    'dim': 1024,
    'mrl': <int>[1024, 512, 256],
    'ctx': 32768,
    'quant': 'Q4_K_M',
    'runtime': 'gguf',
    'disk_bytes': 396500000,
    'ram_mb': 700,
    'sha256': 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
    'license': 'Apache 2.0',
    'builtin': false,
    'pooling': 'last',
    'prompt': <String, Object?>{
      'query':
          'Instruct: Given a note search query, retrieve relevant notes\nQuery: {text}',
      'doc': '{text}',
    },
    'sources': <String>[],
  },
];
