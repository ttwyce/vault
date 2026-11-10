import 'package:drift/drift.dart';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import '../search/cjk_segmenter.dart';
import 'entry_models.dart';

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
    for (final id in ids) {
      final row = await (db.select(db.entries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null || row.deleted != 0) continue;
      summaries.add(await _summaryForRow(row));
    }
    return summaries;
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
