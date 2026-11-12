/// 条目详情「相关推荐」的**纯判定层**（docs/07 §10.2）。
///
/// 不读库、不调模型：按标签 Jaccard + 标题中文 bigram 重合给候选打分，
/// 输出 top N。密码（kind=6）与 AI 日记（kind=4）永不出现在推荐里，
/// 避免 L0 数据借「相关推荐」泄漏到上下文。
library;

class RelatedCandidate {
  const RelatedCandidate({
    required this.id,
    required this.title,
    required this.kind,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final int kind;
  final List<String> tags;
}

class RelatedHit {
  const RelatedHit({
    required this.id,
    required this.score,
    required this.reason,
  });

  final String id;
  final double score;
  final String reason;
}

/// 不参与推荐的 kind（docs/07：AI 日记默认隔离、密码 L0）。
const Set<int> kNeverRecommendKinds = <int>{4, 6};

List<String> _bigrams(String text) {
  final compact = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  final out = <String>[];
  for (var i = 0; i + 2 <= compact.length; i++) {
    out.add(compact.substring(i, i + 2));
  }
  return out;
}

double _jaccard(Iterable<String> a, Iterable<String> b) {
  final sa = a.toSet();
  final sb = b.toSet();
  if (sa.isEmpty && sb.isEmpty) return 0;
  final intersection = sa.intersection(sb).length;
  return intersection / sa.union(sb).length;
}

/// 标题 bigram 重合率（Dice 系数）。
double _titleSimilarity(String a, String b) {
  final ga = _bigrams(a);
  final gb = _bigrams(b);
  if (ga.isEmpty || gb.isEmpty) return 0;
  final counts = <String, int>{for (final g in gb) g: 0};
  for (final g in gb) {
    counts[g] = counts[g]! + 1;
  }
  var overlap = 0;
  for (final g in ga) {
    final left = counts[g] ?? 0;
    if (left > 0) {
      overlap++;
      counts[g] = left - 1;
    }
  }
  return 2.0 * overlap / (ga.length + gb.length);
}

/// 相关推荐：过滤自身与禁止 kind，按 0.6×标签 + 0.4×标题 打分，
/// 分数为 0 的不推荐（不凑数）。
List<RelatedHit> planRelatedEntries({
  required String currentId,
  required String currentTitle,
  required List<String> currentTags,
  required List<RelatedCandidate> candidates,
  int limit = 3,
}) {
  final scored = <RelatedHit>[];
  for (final candidate in candidates) {
    if (candidate.id == currentId) continue;
    if (kNeverRecommendKinds.contains(candidate.kind)) continue;
    final tagScore = _jaccard(currentTags, candidate.tags);
    final titleScore = _titleSimilarity(currentTitle, candidate.title);
    final score = 0.6 * tagScore + 0.4 * titleScore;
    if (score <= 0) continue;
    final reasons = <String>[
      if (tagScore > 0) '标签重合',
      if (titleScore > 0) '标题相近',
    ];
    scored.add(RelatedHit(
      id: candidate.id,
      score: score,
      reason: reasons.join(' + '),
    ));
  }
  scored.sort((RelatedHit a, RelatedHit b) => b.score.compareTo(a.score));
  return List<RelatedHit>.unmodifiable(
    scored.length > limit ? scored.sublist(0, limit) : scored,
  );
}
