import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/embedding_manifest.dart';

/// docs/06 §3.2 / §4 模型 manifest 结构与配置坑测试。
void main() {
  Map<String, Object?> spec([Map<String, Object?>? patch]) =>
      <String, Object?>{
        ...kDefaultModelSpecs.first,
        ...?patch,
      };

  Map<String, Object?> manifest(List<Map<String, Object?>> models) =>
      <String, Object?>{'schema': 1, 'models': models};

  test('默认四套模型可解析，内置恰好一个', () {
    final m = EmbeddingManifest.fromJsonString(
      jsonEncode(manifest(kDefaultModelSpecs)),
    );
    expect(m.schema, 1);
    expect(m.models, hasLength(4));
    expect(m.builtin!.id, 'bge-small-zh-v15-int8');
    expect(m.byId('embeddinggemma-300m-q8')!.dim, 768);
    expect(m.byId('qwen3-embedding-0.6b-q4')!.pooling, Pooling.last);
  });

  test('id 重复 / 多个内置 / schema 非法一律拒绝', () {
    expect(
      () => EmbeddingManifest.fromJsonString(jsonEncode(manifest(
        <Map<String, Object?>>[spec(), spec()],
      ))),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EmbeddingManifest.fromJsonString(jsonEncode(manifest(
        <Map<String, Object?>>[spec(), spec(<String, Object?>{'id': 'x'})],
      ))),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EmbeddingManifest.fromJsonString('{"schema":0,"models":[]}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('非法 pooling / sha256 / 缺模板占位符一律拒绝', () {
    Object? broken(Map<String, Object?> patch) => spec(patch);

    expect(
      () => EmbeddingModelSpec.fromJson(
        broken(<String, Object?>{'pooling': 'wat'}),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EmbeddingModelSpec.fromJson(
        broken(<String, Object?>{'sha256': 'ABC'}),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EmbeddingModelSpec.fromJson(broken(<String, Object?>{
            'prompt': <String, Object?>{
              'query': 'no placeholder',
              'doc': '{text}',
            },
          })),
      throwsA(isA<FormatException>()),
    );
  });

  test('坑 A：EmbeddingGemma query/doc 前缀不同', () {
    final gemma = EmbeddingModelSpec.fromJson(kDefaultModelSpecs[2]);
    expect(auditModelConfig(gemma).ok, isTrue);
    expect(gemma.buildQuery('同步冲突'),
        'task: search result | query: 同步冲突');
    expect(gemma.buildDoc('标题', '正文'), '标题 | 正文');

    final broken = spec(<String, Object?>{
      'id': 'my-gemma',
      'prompt': <String, Object?>{'query': '{text}', 'doc': '{text}'},
    });
    expect(
      auditModelConfig(EmbeddingModelSpec.fromJson(broken)).issues.single,
      contains('前缀必须不同'),
    );
  });

  test('坑 B：Qwen3 必须 last-token pooling', () {
    final qwen = EmbeddingModelSpec.fromJson(kDefaultModelSpecs[3]);
    expect(auditModelConfig(qwen).ok, isTrue);
    final broken = spec(<String, Object?>{
      'id': 'my-qwen',
      'pooling': 'mean',
    });
    expect(
      auditModelConfig(EmbeddingModelSpec.fromJson(broken)).issues.single,
      contains('last-token pooling'),
    );
  });

  test('MRL 维度校验与模型兼容判定（禁止混用不同模型向量）', () {
    final gemma = EmbeddingModelSpec.fromJson(kDefaultModelSpecs[2]);
    final bge = EmbeddingModelSpec.fromJson(kDefaultModelSpecs.first);
    expect(gemma.supportsMrl, isTrue);
    expect(gemma.isCompatibleWith(bge), isFalse);
    expect(gemma.isCompatibleWith(gemma), isTrue);

    final badMrl = spec(<String, Object?>{
      'mrl': <int>[768, 9999],
    });
    expect(
      auditModelConfig(EmbeddingModelSpec.fromJson(badMrl)).issues,
      isNotEmpty,
    );
  });

  test('prompt 模板 JSON 往返保真', () {
    final original = EmbeddingModelSpec.fromJson(kDefaultModelSpecs[2]);
    final decoded = EmbeddingModelSpec.fromJson(original.toJson());
    expect(decoded.queryTemplate, original.queryTemplate);
    expect(decoded.docTemplate, original.docTemplate);
    expect(decoded.mrl, original.mrl);
  });
}
