import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/embedding_manifest.dart';
import 'package:vault/data/search/vector_sync_policy.dart';

/// docs/06 §7 向量同步判定层测试。
void main() {
  const expected = VectorExpectation(
    modelId: 'bge-small',
    dim: 512,
    dtype: 'int8',
  );

  VectorEnvelope envelope({
    String modelId = 'bge-small',
    int dim = 512,
    String dtype = 'int8',
    String bytes = 'AQID',
  }) =>
      VectorEnvelope(
        modelId: modelId,
        dim: dim,
        dtype: dtype,
        bytesBase64: bytes,
      );

  test('规格完全匹配才接受，且不要求重算', () {
    final result = checkVectorEnvelope(envelope(), expected);
    expect(result.accepted, isTrue);
    expect(result.needsRecompute, isFalse);
    expect(result.reasons, isEmpty);
  });

  test('model_id / dim / dtype / 空 bytes 一律丢弃并标记重算', () {
    for (final bad in <VectorEnvelope>[
      envelope(modelId: 'qwen3'),
      envelope(dim: 768),
      envelope(dtype: 'float32'),
      envelope(bytes: ''),
    ]) {
      final result = checkVectorEnvelope(bad, expected);
      expect(result.decision, VectorDecision.discard);
      expect(result.needsRecompute, isTrue);
      expect(result.reasons, isNotEmpty);
    }
  });

  test('坏结构 tryParse 返回 null，不抛异常', () {
    expect(VectorEnvelope.tryParse('not a map'), isNull);
    expect(VectorEnvelope.tryParse(<String, Object?>{'model_id': 'x'}),
        isNull);
    final parsed = VectorEnvelope.tryParse(envelope().toJson());
    expect(parsed, isNotNull);
    expect(parsed!.modelId, 'bge-small');
  });

  test('批量重算计划只列不匹配的 entry', () {
    final raw = <String, Object?>{
      'ok': envelope().toJson(),
      'stale-model': envelope(modelId: 'old').toJson(),
      'bad-dim': envelope(dim: 768).toJson(),
      'broken': 'oops',
    };
    final plan = planVectorRecompute(raw, expected);
    expect(plan, <String>['stale-model', 'bad-dim', 'broken']);
    expect(plan, isNot(contains('ok')));
  });

  test('期望规格来自 manifest，不硬编码', () {
    final spec = EmbeddingModelSpec.fromJson(kDefaultModelSpecs.first);
    final fromSpec = expectationFromSpec(spec);
    expect(fromSpec.modelId, spec.id);
    expect(fromSpec.dim, spec.dim);
    expect(fromSpec.dtype, spec.quant);
  });
}
