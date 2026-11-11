import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/settings/local_settings_provider.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/db/vault_database.dart' show CategoryRow;
import '../../data/entry/entry_models.dart';
import '../../data/entry/entry_repository_provider.dart';
import '../editor/editor_page.dart';
import '../organize/organize_page.dart';

/// 记录页：笔记 / 想法两个分段 + 分类/标签筛选 + 搜索。
///
/// 筛选规则（docs/09 §4）：分类取 OR（选一级分类连带子级），
/// 标签取 AND（越选越窄）。两者同时存在时取交集，搜索结果同样适用。
class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  /// 「未分类」是一个筛选项，不是「没筛选」，所以不能用 null 表示。
  /// 用一个不可能和 UUID 撞上的哨兵值区分这两种状态。
  static const String _uncategorized = '\u0000uncategorized';

  EntryKind _kind = EntryKind.note;
  String _query = '';

  /// null = 不按分类筛；[_uncategorized] = 只看未分类；其余 = 分类 id。
  String? _categoryFilter;
  final Set<String> _selectedTagIds = <String>{};

  List<CategoryRow> _categories = const <CategoryRow>[];
  List<TagWithCount> _tags = const <TagWithCount>[];
  Future<List<EntrySummary>> _results = Future<List<EntrySummary>>.value(
    const <EntrySummary>[],
  );
  Timer? _debounce;

  bool get _hasFilter =>
      _categoryFilter != null || _selectedTagIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final repo = ref.read(entryRepositoryProvider);
    final categories = await repo.categories();
    final tags = await repo.tags();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _tags = tags;
    });
  }

  /// 重算列表数据源。
  ///
  /// 搜索词非空走 FTS；否则按分段拉全量。筛选统一在读侧按 id 求集合，
  /// 这样「搜索结果 + 分类 + 多标签」三种条件能干净地取交集，
  /// 也避免把 tag 名字塞进摘要模型做内存比对（同名标签合并后会误判）。
  Future<List<EntrySummary>> _compute() async {
    final repo = ref.read(entryRepositoryProvider);
    final List<EntrySummary> rows = _query.trim().isNotEmpty
        ? await repo.searchHybrid(_query, nowMs: DateTime.now().millisecondsSinceEpoch,
        includeAiDiary: ref.read(localSettingsProvider).includeAiDiaryInSearch,
        limit: 50)
        : await repo.list(kind: _kind);

    Set<String>? allowed;
    final category = _categoryFilter;
    if (category != null) {
      allowed = category == _uncategorized
          ? await repo.uncategorizedEntryIds()
          : await repo.entryIdsForCategory(category);
    }
    if (_selectedTagIds.isNotEmpty) {
      final tagged = await repo.entryIdsWithAllTags(_selectedTagIds);
      allowed = allowed == null ? tagged : allowed.intersection(tagged);
    }

    final visible = allowed;
    if (visible == null) return rows;
    return rows
        .where((EntrySummary s) => visible.contains(s.id))
        .toList(growable: false);
  }

  void _refresh() {
    // 防抖回调可能在页面销毁后触发，setState 前必须确认还活着。
    if (!mounted) return;
    // 先算 Future 再 setState：setState 的闭包不能返回 Future，
    // 否则 Flutter 会直接抛「callback argument returned a Future」。
    // 写成 `setState(() => _results = _compute())` 看着省事，
    // 但那个箭头闭包的返回值恰好就是 Future，页面会在首帧崩掉。
    final Future<List<EntrySummary>> next = _compute();
    setState(() {
      _results = next;
    });
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _refresh);
  }

  void _openEditor({String? entryId, EntryKind? kind}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => entryId == null
          ? EditorPage(initialKind: kind ?? _kind)
          : EditorPage(entryId: entryId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return PageScaffold(
      title: '记录',
      actions: <Widget>[
        SketchButton(
          label: '整理',
          tone: SketchTone.ghost,
          dense: true,
          glyph: SketchGlyph.menu,
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const OrganizePage(),
            ));
          },
        ),
        SketchIconButton(
          glyph: SketchGlyph.plus,
          tooltip: '新建',
          onPressed: () => _openEditor(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildSearchField(p),
          _buildSegments(),
          if (_categories.isNotEmpty) _buildCategoryChips(),
          if (_tags.isNotEmpty) _buildTagChips(),
          if (_hasFilter) _buildClearRow(),
          const SizedBox(height: SketchSpace.xs),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 搜索 / 分段 / 标签
  // ---------------------------------------------------------------------------

  Widget _buildSearchField(SketchPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SketchSpace.lg,
        SketchSpace.md,
        SketchSpace.lg,
        0,
      ),
      child: SketchFrame(
        radius: SketchRadii.pill,
        fill: p.bg,
        borderColor: p.lineSoft,
        strokeWidth: SketchStroke.hair,
        shadowOffset: Offset.zero,
        padding: const EdgeInsets.symmetric(
          horizontal: SketchSpace.md,
          vertical: SketchSpace.xs,
        ),
        child: Row(
          children: <Widget>[
            SketchIcon(
              SketchGlyph.search,
              size: 13,
              color: p.muted,
              strokeWidth: SketchStroke.icon,
            ),
            const SizedBox(width: SketchSpace.sm),
            Expanded(
              child: TextField(
                onChanged: _onQueryChanged,
                style: TextStyle(fontSize: 13, height: 1.4, color: p.ink),
                cursorColor: p.red,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '搜索你的记录',
                  hintStyle: TextStyle(fontSize: 13, color: p.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegments() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SketchSpace.lg,
        SketchSpace.md,
        SketchSpace.lg,
        0,
      ),
      child: Row(
        children: <Widget>[
          _SegmentButton(
            label: '笔记',
            selected: _kind == EntryKind.note,
            onTap: () {
              if (_kind == EntryKind.note) return;
              setState(() => _kind = EntryKind.note);
              _refresh();
            },
          ),
          const SizedBox(width: SketchSpace.sm),
          _SegmentButton(
            label: '想法',
            selected: _kind == EntryKind.thought,
            onTap: () {
              if (_kind == EntryKind.thought) return;
              setState(() => _kind = EntryKind.thought);
              _refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    // 只列一级：点父分类时读侧的递归 CTE 会把子分类内容一起带出来，
    // 再列一遍子级只会让 chip 行变成重复噪音。
    final topLevel = _categories
        .where((CategoryRow c) => c.parentId == null)
        .toList(growable: false);
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          SketchSpace.lg,
          SketchSpace.sm,
          SketchSpace.lg,
          0,
        ),
        children: <Widget>[
          _TagChip(
            name: '全部',
            selected: _categoryFilter == null,
            onTap: () => _setCategoryFilter(null),
          ),
          const SizedBox(width: SketchSpace.sm),
          _TagChip(
            name: '未分类',
            selected: _categoryFilter == _uncategorized,
            onTap: () => _setCategoryFilter(_uncategorized),
          ),
          for (final c in topLevel) ...<Widget>[
            const SizedBox(width: SketchSpace.sm),
            _TagChip(
              name: c.name,
              selected: _categoryFilter == c.id,
              onTap: () => _setCategoryFilter(c.id),
            ),
          ],
        ],
      ),
    );
  }

  void _setCategoryFilter(String? value) {
    setState(() => _categoryFilter = value);
    _refresh();
  }

  Widget _buildClearRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SketchSpace.lg,
        SketchSpace.xs,
        SketchSpace.lg,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SketchButton(
          label: '清除筛选',
          tone: SketchTone.ghost,
          dense: true,
          onPressed: () {
            setState(() {
              _categoryFilter = null;
              _selectedTagIds.clear();
            });
            _refresh();
          },
        ),
      ),
    );
  }

  Widget _buildTagChips() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          SketchSpace.lg,
          SketchSpace.sm,
          SketchSpace.lg,
          0,
        ),
        children: <Widget>[
          for (final tag in _tags) ...<Widget>[
            _TagChip(
              name: tag.name,
              selected: _selectedTagIds.contains(tag.id),
              onTap: () {
                setState(() {
                  // 多选：AND 语义，选得越多结果越少。
                  if (!_selectedTagIds.remove(tag.id)) {
                    _selectedTagIds.add(tag.id);
                  }
                });
                _refresh();
              },
            ),
            const SizedBox(width: SketchSpace.sm),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 列表
  // ---------------------------------------------------------------------------

  Widget _buildList() {
    final p = context.sketch;

    return FutureBuilder<List<EntrySummary>>(
      future: _results,
      builder: (BuildContext context, AsyncSnapshot<List<EntrySummary>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: p.red));
        }
        final rows = snapshot.data ?? const <EntrySummary>[];
        if (rows.isEmpty) {
          return Center(
            child: Text(
              '还没有内容，点右上角新建',
              style: TextStyle(fontSize: 12.5, height: 1.6, color: p.muted),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            SketchSpace.lg,
            SketchSpace.sm,
            SketchSpace.lg,
            SketchSpace.xxl,
          ),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SketchDivider(),
          itemBuilder: (BuildContext context, int index) {
            final EntrySummary entry = rows[index];
            return _RecordTile(
              entry: entry,
              onTap: () => _openEditor(entryId: entry.id),
            );
          },
        );
      },
    );
  }
}

/// 「笔记 / 想法」分段按钮。`SketchTag` 本身不可点，这里包一层手势。
class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SketchTag(
        label,
        tone: selected ? SketchTone.primary : SketchTone.ghost,
      ),
    );
  }
}

/// 标签筛选 chip，同样包一层手势。
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SketchTag(
        name,
        tone: selected ? SketchTone.primary : SketchTone.ghost,
        dense: true,
      ),
    );
  }
}

/// 列表里的一条记录。标题 + 两行片段 + 时间/标签脚注。
class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.entry, required this.onTap});

  final EntrySummary entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final String time = DateFormat('yyyy-MM-dd HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(entry.updatedAt),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SketchSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: p.ink,
              ),
            ),
            if (entry.snippet.isNotEmpty) ...<Widget>[
              const SizedBox(height: SketchSpace.xs),
              Text(
                entry.snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.6, color: p.muted),
              ),
            ],
            const SizedBox(height: SketchSpace.sm),
            Row(
              children: <Widget>[
                Text(
                  time,
                  style: context.typography.monoStyle(
                    size: 10,
                    height: 1.4,
                    color: p.muted,
                  ),
                ),
                if (entry.tagNames.isNotEmpty) ...<Widget>[
                  const SizedBox(width: SketchSpace.sm),
                  Expanded(
                    child: Text(
                      entry.tagNames.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, height: 1.4, color: p.muted),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
