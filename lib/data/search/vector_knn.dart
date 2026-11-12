/// A2 退路：Dart 内 int8 量化向量暴力余弦 KNN（docs/02 §8）。
///
/// 不加载 sqlite_vector、不加依赖：5 万条 × 768 维在预算内可接受。
/// 维度不匹配 / 零向量一律跳过，绝不把坏数据混进结果。
library;

import 'dart:math' as math;

class VectorHit {
  const VectorHit({required this.entryId, required this.score});

  final String entryId;
  final double score;
}

/// int8 值域；量化向量用 `List<int>` 承载（-128~127）。
double cosineSimilarity(List<int> a, List<int> b) {
  if (a.length != b.length || a.isEmpty) {
    throw const FormatException('向量维度不一致或为空');
  }
  var dot = 0;
  var normA = 0;
  var normB = 0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0;
  return dot / (math.sqrt(normA) * math.sqrt(normB));
}

/// 暴力 KNN：返回 cosine 降序 topK；同分按 entryId 升序保证稳定。
List<VectorHit> bruteForceKnn({
  required List<int> query,
  required Map<String, List<int>> vectors,
  int topK = 50,
  double minScore = -1.0,
}) {
  if (topK <= 0) return const <VectorHit>[];
  final hits = <VectorHit>[];
  for (final entry in vectors.entries) {
    if (entry.value.length != query.length) continue;
    final score = cosineSimilarity(query, entry.value);
    if (score < minScore) continue;
    hits.add(VectorHit(entryId: entry.key, score: score));
  }
  hits.sort((VectorHit a, VectorHit b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.entryId.compareTo(b.entryId);
  });
  return List<VectorHit>.unmodifiable(
    hits.length > topK ? hits.sublist(0, topK) : hits,
  );
}
