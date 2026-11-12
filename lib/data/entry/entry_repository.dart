import 'package:drift/drift.dart';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import '../search/cjk_segmenter.dart';
import '../search/hybrid_search.dart';
import 'entry_models.dart';
import 'note_meta.dart';

/// 条目的**只读**仓库。
///
/// 写操作一律走 `WriteGateway`（`lib/data/write/write_gateway.dart`），
/// 那是全项目唯一的写入口 —— 这个类不提供任何写方法，从类型层面
/// 保证"读了再改"的流程不会有人在这里偷偷 `insert`。
///
/// ## 为什么标签用一个 `char(31)` 的 group_concat
///
/// 列表页要一次取 200 条的标签。逐条再查一次 `entry_tag` 是 N+1，
/// 在手机上就是 200 次往返。`group_concat` 一次带回，
/// 用单元分隔符（U+001F，几乎不可能出现在标签名里）拼接，Dart 侧再拆。
class EntryRepository {
  EntryRepository(this.db);

  final VaultDatabase db;

  /// 分隔标签名的控制字符。
  static const String _tagSeparator = '\u001f';

  // ---------------------------------------------------------------------------
  // 列表与检索
  // ---------------------------------------------------------------------------

  /// 按更新时间倒序列出条目。
  ///
  /// [kind] 为 null 表示全部类型；[includeDeleted] 给回收站用。
  Future<List<EntrySummary>> list({
    EntryKind? kind,
    bool includeDeleted = false,
    int limit = 200,
  }) async {
    final kindClause = kind == null ? '' : 'AND e.kind = ?';
    final deletedClause = includeDeleted ? 'AND e.deleted = 1' : 'AND e.deleted = 0';

    final rows = await db.customSelect(
      'SELECT e.id, e.kind, e.title, e.body, e.updated_at, e.deleted, '
      '  (SELECT group_concat(t.name, ?) FROM entry_tag et '
      '    JOIN tag t ON t.id = et.tag_id '
      '    WHERE et.entry_id = e.id AND t.deleted = 0) AS tag_names '
      'FROM entry e '
      'WHERE 1 = 1 $kindClause $deletedClause '
      'ORDER BY e.updated_at DESC LIMIT ?;',
      variables: <Variable<Object>>[
        Variable<String>(_tagSeparator),
        if (kind != null) Variable<int>(kind.code),
        Variable<int>(limit),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{db.entries},
    ).get();

    return rows.map(_summaryFromRow).toList(growable: false);
  }

  /// 全文检索。走 FTS5，命中 id 再回表组装摘要（保持相关度顺序）。
  Future<List<EntrySummary>> search(String query, {int limit = 50}) async {
    final matchQuery = CjkSegmenter.matchQuery(query);
    if (!CjkSegmenter.isSearchable(query)) return const <EntrySummary>[];

    final ids = await db.searchEntryIds(matchQuery, limit: limit);
    if (ids.isEmpty) return const <EntrySummary>[];

    final summaries = <EntrySummary>[];
    for (var index = 0; index < ids.length; index++) {
      final id = ids[index];
      final row = await (db.select(db.entries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null || row.deleted != 0) continue;
      summaries.add(await _summaryForRow(row));
    }
    return summaries;
  }

  /// 结构化混合检索（docs/06 §1.2）：在 FTS 前做查询预处理，
  /// 再用时间衰减重排。向量那一路由 M5 接入层补上后走 RRF。
  ///
  /// 硬规则：**默认排除 AI 日记（kind=4）**，避免生成文本污染用户搜索。
  Future<List<EntrySummary>> searchHybrid(
    String rawQuery, {
    required int nowMs,
    int limit = 20,
    bool includeAiDiary = false,
  }) async {
    final parsed = preprocessSearchQuery(rawQuery, nowMs: nowMs);
    if (parsed.ftsPhrase.trim().isEmpty) {
      return const <EntrySummary>[];
    }
    final matchQuery = CjkSegmenter.matchQuery(parsed.ftsPhrase);
    if (!CjkSegmenter.isSearchable(parsed.ftsPhrase)) {
      return const <EntrySummary>[];
    }
    // FTS 多取一些，让结构化过滤与时间衰减重排后仍有足够候选。
    final ids = await db.searchEntryIds(matchQuery, limit: limit * 3);
    if (ids.isEmpty) return const <EntrySummary>[];

    final scored = <({EntrySummary summary, double score})>[];
    for (var index = 0; index < ids.length; index++) {
      final id = ids[index];
      final row = await (db.select(db.entries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null || row.deleted != 0) continue;
      if (!includeAiDiary && row.kind == EntryKind.aiDiary.code) continue;
      if (parsed.kinds.isNotEmpty && !parsed.kinds.contains(row.kind)) {
        continue;
      }
      final from = parsed.fromMs;
      if (from != null && row.updatedAt < from) continue;
      final summary = await _summaryForRow(row);
      // 没有向量分数时 rrfScore 用 FTS 名次近似，仍按时间衰减重排。
      final rank = index + 1;
      final pinned = (row.kind == EntryKind.note.code ||
              row.kind == EntryKind.thought.code) &&
          NoteMeta.fromJson(row.meta).pinned;
      final score = rerankScore(
        rrfScore: 1 / (60 + rank),
        updatedAtMs: row.updatedAt,
        nowMs: nowMs,
        pinned: pinned,
      );
      scored.add((summary: summary, score: score));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.summary.id.compareTo(b.summary.id);
    });
    return List<EntrySummary>.unmodifiable(
      scored.take(limit).map((item) => item.summary),
    );
  }

  /// 单条完整行。编辑页打开时用。
  Future<EntryRow?> getRow(String id) {
    return (db.select(db.entries)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 某条的全部标签名（编辑页展示用）。
  Future<List<String>> tagsForEntry(String entryId) async {
    final rows = await db.customSelect(
      'SELECT t.name FROM tag t '
      'JOIN entry_tag et ON et.tag_id = t.id '
      'WHERE et.entry_id = ? AND t.deleted = 0 ORDER BY t.name;',
      variables: <Variable<Object>>[Variable<String>(entryId)],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{db.tags, db.entryTags},
    ).get();
    return rows
        .map((QueryRow row) => row.read<String>('name'))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // 日记
  // ---------------------------------------------------------------------------

  /// 某个月的日记（含 AI 日记）。
  ///
  /// 用 `meta.date`（显式日期）分月，不用 `created_at` —— 补写的日记
  /// 要落在被补写的那天，而不是落在那天的"现在"。
  ///
  /// 返回以"日"为键的映射，值是该天的日记摘要。
  /// 用映射而不是列表：月历格子和"某天列表"都要按日期随机访问。
  Future<Map<int, List<EntrySummary>>> diaryForMonth(int year, int month) async {
    final rows = await db.customSelect(
      'SELECT e.id, e.kind, e.title, e.body, e.updated_at, e.deleted, '
      '  (SELECT group_concat(t.name, ?) FROM entry_tag et '
      '    JOIN tag t ON t.id = et.tag_id '
      '    WHERE et.entry_id = e.id AND t.deleted = 0) AS tag_names, '
      '  e.meta AS meta '
      'FROM entry e '
      'WHERE e.kind IN (?, ?) AND e.deleted = 0 '
      'ORDER BY e.updated_at DESC;',
      variables: <Variable<Object>>[
        Variable<String>(_tagSeparator),
        Variable<int>(EntryKind.diary.code),
        Variable<int>(EntryKind.aiDiary.code),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{db.entries},
    ).get();

    final byDay = <int, List<EntrySummary>>{};
    for (final row in rows) {
      final meta = row.read<String?>('meta');
      final date = diaryDateOf(meta);
      if (date == null) continue;

      final parts = date.split('-');
      if (parts.length != 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != year || m != month || d == null) continue;

      byDay.putIfAbsent(d, () => <EntrySummary>[]).add(_summaryFromRow(row));
    }
    return byDay;
  }

  // ---------------------------------------------------------------------------
  // 分类与标签
  // ---------------------------------------------------------------------------

  /// 全部未删除的分类（扁平，按 kind + 排序）。
  ///
  /// UI 用 `buildCategoryTree` 拼树。返回扁平行而不是树，是因为
  /// "组织页要树、记录页要按 kind 过滤"两种用法都从同一份数据出发更省事。
  Future<List<CategoryRow>> categories() {
    return (db.select(db.categories)
          ..where((t) => t.deleted.equals(0))
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.asc(t.kind),
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  /// 全部未删除的标签，按使用次数倒序。标签云用。
  Future<List<TagWithCount>> tags() async {
    final rows = await (db.select(db.tags)
          ..where((t) => t.deleted.equals(0))
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.desc(t.usageCount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
    return rows
        .map((TagRow t) => TagWithCount(id: t.id, name: t.name, count: t.usageCount))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // 列表筛选（docs/09 §4：分类 OR / 标签 AND）
  // ---------------------------------------------------------------------------

  /// 命中某个分类的条目 id，**包含它所有子分类**。
  ///
  /// 用户点一级分类「工作」时，期望连「工作 › 周报」一起看到；
  /// 只查 `entry_category` 里精确等于该 id 的行会漏掉一半内容。
  /// 递归 CTE 展开整棵子树（表本身限制两级，不会无限递归），
  /// 同时排掉软删分类和已进回收站的条目。
  Future<Set<String>> entryIdsForCategory(String categoryId) async {
    final rows = await db.customSelect(
      'WITH RECURSIVE subtree(id) AS ('
      '  SELECT id FROM category WHERE id = ? AND deleted = 0 '
      '  UNION ALL '
      '  SELECT c.id FROM category c JOIN subtree s ON c.parent_id = s.id '
      '    WHERE c.deleted = 0'
      ') '
      'SELECT DISTINCT ec.entry_id AS entry_id FROM entry_category ec '
      'JOIN subtree s ON s.id = ec.category_id '
      'JOIN entry e ON e.id = ec.entry_id AND e.deleted = 0;',
      variables: <Variable<Object>>[Variable<String>(categoryId)],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        db.categories,
        db.entryCategories,
        db.entries,
      },
    ).get();
    return rows.map((QueryRow r) => r.read<String>('entry_id')).toSet();
  }

  /// 没有任何有效分类关联的条目 id（「未分类」筛选项）。
  ///
  /// 删除分类后关联行会被清掉；但同步合并可能留下指向软删分类的关联，
  /// 所以这里 JOIN 到 `category` 判断有效性，而不是只看 `NOT EXISTS` 关联行。
  Future<Set<String>> uncategorizedEntryIds() async {
    final rows = await db.customSelect(
      'SELECT e.id AS entry_id FROM entry e '
      'WHERE e.deleted = 0 AND NOT EXISTS ('
      '  SELECT 1 FROM entry_category ec '
      '  JOIN category c ON c.id = ec.category_id AND c.deleted = 0 '
      '  WHERE ec.entry_id = e.id'
      ');',
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        db.categories,
        db.entryCategories,
        db.entries,
      },
    ).get();
    return rows.map((QueryRow r) => r.read<String>('entry_id')).toSet();
  }

  /// 同时带齐所有选中标签的条目 id —— **AND，不是 OR**。
  ///
  /// `IN (...)` 只保证"沾上任意一个"，`HAVING COUNT(DISTINCT) = n`
  /// 才保证每个都命中。多选标签的语义是「越选越窄」，选成并集会让
  /// 用户以为筛选坏了。
  Future<Set<String>> entryIdsWithAllTags(Iterable<String> tagIds) async {
    final ids = tagIds.toSet().toList(growable: false);
    if (ids.isEmpty) return <String>{};

    final marks = List<String>.filled(ids.length, '?').join(', ');
    final rows = await db.customSelect(
      'SELECT et.entry_id AS entry_id FROM entry_tag et '
      'JOIN tag t ON t.id = et.tag_id AND t.deleted = 0 '
      'JOIN entry e ON e.id = et.entry_id AND e.deleted = 0 '
      'WHERE et.tag_id IN ($marks) '
      'GROUP BY et.entry_id HAVING COUNT(DISTINCT et.tag_id) = ?;',
      variables: <Variable<Object>>[
        for (final id in ids) Variable<String>(id),
        Variable<int>(ids.length),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        db.tags,
        db.entryTags,
        db.entries,
      },
    ).get();
    return rows.map((QueryRow r) => r.read<String>('entry_id')).toSet();
  }

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  EntrySummary _summaryFromRow(QueryRow row) {
    final tagNames = row.read<String?>('tag_names');
    return EntrySummary(
      id: row.read<String>('id'),
      kind: EntryKind.fromCode(row.read<int>('kind')) ?? EntryKind.note,
      title: displayTitle(row.read<String?>('title'), row.read<String?>('body')),
      snippet: plainSnippet(row.read<String?>('body')),
      updatedAt: row.read<int>('updated_at'),
      deleted: row.read<int>('deleted') != 0,
      tagNames: _splitTags(tagNames),
    );
  }

  Future<EntrySummary> _summaryForRow(EntryRow row) async {
    final tags = await tagsForEntry(row.id);
    return EntrySummary(
      id: row.id,
      kind: EntryKind.fromCode(row.kind) ?? EntryKind.note,
      title: displayTitle(row.title, row.body),
      snippet: plainSnippet(row.body),
      updatedAt: row.updatedAt,
      deleted: row.deleted != 0,
      tagNames: tags,
    );
  }

  List<String> _splitTags(String? joined) {
    if (joined == null || joined.isEmpty) return const <String>[];
    return joined
        .split(_tagSeparator)
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
  }
}
