/// 标签智能聚类建议（docs/11 §2.6 二期）。
///
/// 不调模型、不写库：用已有标签共现频率 + 标题 bigram 相似度，
/// 给出「可合并的相似标签组」与「高频共现标签对」供用户一键采纳。
/// 采纳走 WriteGateway.mergeTags，本层只输出建议。
library;

class TagCooccurrence {
  const TagCooccurrence({
    required this.left,
    required this.right,
    required this.count,
  });

  final String left;
  final String right;
  final int count;
}

class TagClusterSuggestion {
  const TagClusterSuggestion({
    required this.groups,
    required this.cooccurrences,
    required this.hint,
  });

  final List<List<String>> groups;
  final List<TagCooccurrence> cooccurrences;
  final String hint;
}

/// [entries] 是「单条目标签 id 列表」；[names] 是 id → 显示名。
TagClusterSuggestion planTagClusters({
  required Iterable<List<String>> entries,
  required Map<String, String> names,
}) {
  final rows = entries
      .map((List<String> row) => row.toSet().toList()..sort())
      .where((List<String> row) => row.isNotEmpty)
      .toList();
  final pairCount = <String, int>{};
  final usage = <String, int>{};
  for (final row in rows) {
    for (final tag in row) {
      usage[tag] = (usage[tag] ?? 0) + 1;
    }
    for (var i = 0; i < row.length; i++) {
      for (var j = i + 1; j < row.length; j++) {
        final key = '${row[i]}\u0000${row[j]}';
        pairCount[key] = (pairCount[key] ?? 0) + 1;
      }
    }
  }
  final co = <TagCooccurrence>[
    for (final entry in pairCount.entries)
      if (entry.value >= 2)
        TagCooccurrence(
          left: entry.key.split('\u0000').first,
          right: entry.key.split('\u0000').last,
          count: entry.value,
        ),
  ]..sort((TagCooccurrence a, TagCooccurrence b) =>
      b.count.compareTo(a.count));

  // 显示名做 bigram 相似分组：同名/近似名最容易被手动建重。
  final byName = <String, List<String>>{};
  for (final entry in usage.entries) {
    final name = names[entry.key] ?? entry.key;
    final key = _normalizeName(name);
    byName.putIfAbsent(key, () => <String>[]).add(entry.key);
  }
  final groups = <List<String>>[
    for (final group in byName.values)
      if (group.length > 1) group,
  ];
  return TagClusterSuggestion(
    groups: List<List<String>>.unmodifiable(groups),
    cooccurrences: List<TagCooccurrence>.unmodifiable(co.take(8)),
    hint: groups.isEmpty && co.isEmpty
        ? '没有发现可合并或高频共现的标签'
        : '发现 ${groups.length} 组相似标签 · ${co.length} 对高频共现',
  );
}

String _normalizeName(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[\s_\-]+'), '')
    .replaceAll(RegExp(r'[^A-Za-z0-9\u4e00-\u9fff]'), '');
