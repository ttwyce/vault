/// 混合检索的纯判定层（docs/06 §1 / §2.1）。
///
/// 不碰 FTS5、不碰向量运行时、不碰模型下载：只做「查询怎么预处理、
/// 两路召回怎么按 RRF 融合、结果怎么重排、长文怎么分块」。
/// 于是 T「中文查询 top3 命中」「短查询降权向量」这些规则能确定性单测。
library;

import 'dart:math' as math;

/// 查询预处理结果。
class SearchQuery {
  const SearchQuery({
    required this.raw,
    required this.normalized,
    required this.ftsPhrase,
    required this.exactPhrase,
    required this.kinds,
    required this.fromMs,
    required this.toMs,
    required this.vectorWeight,
    required this.ftsWeight,
  });

  final String raw;
  final String normalized;

  /// 送进 CjkSegmenter.matchQuery 的短语（精确短语会保留引号语义）。
  final String ftsPhrase;
  final bool exactPhrase;

  /// 类型限定（kind IN ...），空集合表示不限。
  final Set<int> kinds;
  final int? fromMs;
  final int? toMs;

  /// 短查询向量效果差：降权向量、提升 FTS。
  final double vectorWeight;
  final double ftsWeight;
}

const Set<String> _stopWords = <String>{
  '的', '了', '是', '在', '和', '与', '有', '我', '你', '这', '那',
};

/// 时间意图词 → 相对天数。用「请求时刻」由调用方转绝对时间戳。
const Map<String, int> _timeHints = <String, int>{
  '今天': 1,
  '最近': 30,
  '上个月': 60,
  '去年': 365,
};

SearchQuery preprocessSearchQuery(String raw, {required int nowMs}) {
  var text = raw.trim();
  final exact = text.length >= 2 &&
      text.startsWith('"') &&
      text.endsWith('"');
  if (exact) text = text.substring(1, text.length - 1).trim();

  final kinds = <int>{};
  // 类型限定词只用于结构化过滤，必须连同指代词一起从 FTS 短语里剥离，
  // 否则「那篇日记 同步」会变成一个根本匹配不到的长短语。
  const intentWords = <String>[
    '日记', '书签', '归档', '想法', '笔记', '那篇', '这篇', '一篇',
  ];
  if (text.contains('日记')) kinds.addAll(<int>{3, 4});
  if (text.contains('书签') || text.contains('归档')) kinds.add(5);
  if (text.contains('想法')) kinds.add(2);
  if (text.contains('笔记')) kinds.add(1);
  for (final intent in intentWords) {
    text = text.replaceAll(intent, ' ');
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  int? fromMs;
  for (final entry in _timeHints.entries) {
    if (!text.contains(entry.key)) continue;
    fromMs = nowMs - Duration(days: entry.value).inMilliseconds;
    text = text.replaceAll(entry.key, ' ').trim();
    break;
  }

  // 停用词只在 FTS 侧去掉，向量侧保留自然语言语义。
  var normalized = text;
  for (final stop in _stopWords) {
    normalized = normalized.replaceAll(stop, ' ');
  }
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

  final short = normalized.runes.length < 4;
  return SearchQuery(
    raw: raw,
    normalized: normalized.isEmpty ? text : normalized,
    ftsPhrase: normalized.isEmpty ? text : normalized,
    exactPhrase: exact,
    kinds: Set<int>.unmodifiable(kinds),
    fromMs: fromMs,
    toMs: nowMs,
    vectorWeight: short ? 0.35 : 1.0,
    ftsWeight: short ? 1.3 : 1.0,
  );
}

/// 一路召回的排序结果（名次从 1 开始）。
class RankedHit {
  const RankedHit(this.entryId, this.rank);

  final String entryId;
  final int rank;
}

class FusedHit {
  const FusedHit({
    required this.entryId,
    required this.score,
    required this.sources,
  });

  final String entryId;
  final double score;
  final Set<String> sources;
}

/// RRF 融合（docs/06 §1.1）：score(d) = Σ 1/(k + rank_i(d))，k=60。
///
/// 结构化过滤由调用方在传入前完成；这里只做两路（FTS / 向量）融合。
/// 被过滤掉的 id 即使出现在召回里也不会进入结果。
/// 分块命中先聚合到 entry 粒度（docs/06 §2.1）。
///
/// 同一 entry 的多个 chunk 只保留**最佳名次**，避免多篇长文因分块多
/// 在 RRF 里被重复累加、把短笔记挤出 top3。fts / vector 两路都要先过这道。
List<RankedHit> aggregateChunkHits(Iterable<RankedHit> hits) {
  final best = <String, int>{};
  for (final hit in hits) {
    if (hit.rank < 1) continue;
    final current = best[hit.entryId];
    if (current == null || hit.rank < current) {
      best[hit.entryId] = hit.rank;
    }
  }
  // 按名次升序输出，保持与下游 rank 语义一致。
  final out = <RankedHit>[
    for (final entry in best.entries) RankedHit(entry.key, entry.value),
  ]..sort((RankedHit a, RankedHit b) {
      final byRank = a.rank.compareTo(b.rank);
      return byRank != 0 ? byRank : a.entryId.compareTo(b.entryId);
    });
  return List<RankedHit>.unmodifiable(out);
}

List<FusedHit> reciprocalRankFusion({
  required Iterable<RankedHit> ftsHits,
  required Iterable<RankedHit> vectorHits,
  Set<String>? allowedIds,
  double ftsWeight = 1.0,
  double vectorWeight = 1.0,
  int k = 60,
  int limit = 20,
}) {
  final scores = <String, double>{};
  final sources = <String, Set<String>>{};

  void accumulate(Iterable<RankedHit> hits, double weight, String source) {
    for (final hit in hits) {
      if (hit.rank < 1) continue;
      if (allowedIds != null && !allowedIds.contains(hit.entryId)) continue;
      scores[hit.entryId] =
          (scores[hit.entryId] ?? 0.0) + weight / (k + hit.rank);
      sources.putIfAbsent(hit.entryId, () => <String>{}).add(source);
    }
  }

  accumulate(aggregateChunkHits(ftsHits), ftsWeight, 'fts');
  accumulate(aggregateChunkHits(vectorHits), vectorWeight, 'vector');

  final fused = <FusedHit>[
    for (final entry in scores.entries)
      FusedHit(
        entryId: entry.key,
        score: entry.value,
        sources: Set<String>.unmodifiable(sources[entry.key]!),
      ),
  ];
  fused.sort((FusedHit a, FusedHit b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.entryId.compareTo(b.entryId);
  });
  return List<FusedHit>.unmodifiable(fused.take(limit));
}

/// 时间衰减 + 置顶加权（docs/06 §1.1 可选重排）。
double rerankScore({
  required double rrfScore,
  required int updatedAtMs,
  required int nowMs,
  bool pinned = false,
}) {
  final days = ((nowMs - updatedAtMs) / Duration(days: 1).inMilliseconds)
      .clamp(0.0, double.infinity);
  final decay = 1 + 0.3 * math.exp(-days / 180);
  return rrfScore * decay * (pinned ? 1.5 : 1.0);
}

/// 分块计划（docs/06 §2.1）。纯按段落与字符数近似 token，不引入分词库。
class ChunkPlan {
  const ChunkPlan({required this.chunks, required this.truncated});

  /// 每块是 `[start, end)` 的字符区间（含 overlap）。
  final List<({int start, int end})> chunks;
  final bool truncated;
}

/// credential（kind=6）永不向量化：这是代码级硬约束。
bool shouldVectorize(int kind) => kind != 6;

ChunkPlan planChunks({
  required String body,
  required int kind,
  int maxChunks = 20,
}) {
  if (!shouldVectorize(kind) || body.trim().isEmpty) {
    return const ChunkPlan(chunks: <({int start, int end})>[], truncated: false);
  }
  final isBookmark = kind == 5;
  // 文档用 token，纯 Dart 里用「4 字符 ≈ 1 token」近似，够用于分块上限。
  final chunkChars = isBookmark ? 400 * 4 : 512 * 4;
  final overlapChars = isBookmark ? 80 * 4 : 64 * 4;
  final maxTotal = chunkChars * maxChunks;
  final text = body.length > maxTotal ? body.substring(0, maxTotal) : body;
  final truncated = body.length > maxTotal;

  final chunks = <({int start, int end})>[];
  var start = 0;
  while (start < text.length && chunks.length < maxChunks) {
    var end = (start + chunkChars).clamp(0, text.length);
    if (end < text.length) {
      // 尽量落在段落边界，避免把一句话切成两半。
      final boundary = text.lastIndexOf('\n\n', end);
      if (boundary > start + chunkChars ~/ 2) end = boundary + 2;
    }
    chunks.add((start: start, end: end));
    if (end >= text.length) break;
    start = (end - overlapChars).clamp(start + 1, end);
  }
  return ChunkPlan(
    chunks: List<({int start, int end})>.unmodifiable(chunks),
    truncated: truncated,
  );
}


/// docs/06 §8.1：结果卡片上的命中来源标签。
///
/// 真实向量召回未接入前，一律如实标「关键词」并附语义状态，
/// 不写死「两者」骗用户。
String hitSourceLabel({
  required bool keywordHit,
  required bool vectorHit,
  required bool vectorEnabled,
}) {
  if (keywordHit && vectorHit) return '命中：关键词 + 语义';
  if (keywordHit) {
    return vectorEnabled ? '命中：关键词' : '命中：关键词（语义未启用）';
  }
  if (vectorHit) return '命中：语义';
  return '命中：—';
}
