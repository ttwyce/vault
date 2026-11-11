/// 向量同步封包的**纯判定层**（docs/06 §7）。
///
/// 不联网、不解密、不写 entry_vec：只判断「拉下来的向量能不能用」。
/// 核心红线：model_id / dim 不匹配一律丢弃并标记需重算，
/// **绝不混用不同模型的向量**（混用会让语义空间彻底失真）。
library;

import 'embedding_manifest.dart';

/// 本地期望的向量规格。
class VectorExpectation {
  const VectorExpectation({
    required this.modelId,
    required this.dim,
    required this.dtype,
  });

  final String modelId;
  final int dim;
  final String dtype;
}

enum VectorDecision { accept, discard }

class VectorCheckResult {
  const VectorCheckResult({
    required this.decision,
    required this.reasons,
  });

  final VectorDecision decision;
  final List<String> reasons;

  bool get accepted => decision == VectorDecision.accept;

  /// 丢弃时必须写回「需重算」标记，不能静默跳过。
  bool get needsRecompute => !accepted;
}

/// 解码后的向量封包（明文结构，真实密文由同步层处理）。
class VectorEnvelope {
  const VectorEnvelope({
    required this.modelId,
    required this.dim,
    required this.dtype,
    required this.bytesBase64,
  });

  final String modelId;
  final int dim;
  final String dtype;
  final String bytesBase64;

  /// 从 JSON 解析；坏结构返回 null 而不是抛异常，便于逐条隔离。
  static VectorEnvelope? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, Object?>.from(raw);
    final modelId = map['model_id'];
    final dim = map['dim'];
    final dtype = map['dtype'];
    final bytes = map['bytes'];
    if (modelId is! String || dim is! num || dtype is! String ||
        bytes is! String) {
      return null;
    }
    return VectorEnvelope(
      modelId: modelId,
      dim: dim.toInt(),
      dtype: dtype,
      bytesBase64: bytes,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'model_id': modelId,
        'dim': dim,
        'dtype': dtype,
        'bytes': bytesBase64,
      };
}

/// 判定一个封包能否写入本地 entry_vec。
VectorCheckResult checkVectorEnvelope(
  VectorEnvelope? envelope,
  VectorExpectation expected,
) {
  if (envelope == null) {
    return const VectorCheckResult(
      decision: VectorDecision.discard,
      reasons: <String>['封包结构非法，需重算'],
    );
  }
  final reasons = <String>[];
  if (envelope.modelId != expected.modelId) {
    reasons.add('model_id 不匹配（${envelope.modelId} ≠ ${expected.modelId}）');
  }
  if (envelope.dim != expected.dim) {
    reasons.add('dim 不匹配（${envelope.dim} ≠ ${expected.dim}）');
  }
  if (envelope.dtype != expected.dtype) {
    reasons.add('dtype 不匹配（${envelope.dtype} ≠ ${expected.dtype}）');
  }
  if (envelope.bytesBase64.isEmpty) {
    reasons.add('向量 bytes 为空');
  }
  return reasons.isEmpty
      ? const VectorCheckResult(
          decision: VectorDecision.accept,
          reasons: <String>[],
        )
      : VectorCheckResult(
          decision: VectorDecision.discard,
          reasons: List<String>.unmodifiable(reasons),
        );
}

/// 按 manifest 构造期望规格（dim / dtype 必须来自 manifest，不硬编码）。
VectorExpectation expectationFromSpec(EmbeddingModelSpec spec) =>
    VectorExpectation(
      modelId: spec.id,
      dim: spec.dim,
      dtype: spec.quant,
    );

/// 批量判定：返回每个 entry 是否需要重算，供 job_queue 排任务。
List<String> planVectorRecompute(
  Map<String, Object?> envelopes,
  VectorExpectation expected,
) =>
    <String>[
      for (final entry in envelopes.entries)
        if (checkVectorEnvelope(
          VectorEnvelope.tryParse(entry.value),
          expected,
        ).needsRecompute)
          entry.key,
    ];
