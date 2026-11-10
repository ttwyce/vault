import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/entry/entry_models.dart';
import '../../data/entry/entry_repository_provider.dart';
import '../editor/editor_page.dart';
import '../organize/organize_page.dart';

/// 记录页：笔记 / 想法两个分段 + 标签筛选 + 搜索。
///
/// 这是"三视图"里最常用的一屏，所以它不做花哨的东西 ——
/// 一条列表、一个搜索框、几个筛选 chip，没了。
class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  EntryKind _kind = EntryKind.note;
  String _query = '';
  String? _selectedTag;

  List<TagWithCount> _tags = const <TagWithCount>[];
  Future<List<EntrySummary>> _results = Future<List<EntrySummary>>.value(
    const <EntrySummary>[],
  );
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadTags();
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final tags = await ref.read(entryRepositoryProvider).tags();
    if (!mounted) return;
    setState(() => _tags = tags);
  }

  /// 重算列表数据源。
  ///
  /// 搜索词非空走 FTS；否则按分段拉全量、在内存里按标签过滤。
  Future<List<EntrySummary>> _compute() {
    final repo = ref.read(entryRepositoryProvider);
    if (_query.trim().isNotEmpty) {
      return repo.search(_query);
    }
    return repo.list(kind: _kind).then((List<EntrySummary> rows) {
      final tag = _selectedTag;
      if (tag == null) return rows;
      return rows
          .where((EntrySummary s) => s.tagNames.contains(tag))
          .toList(growable: false);
    });
  }

  void _refresh() {
    // 防抖回调可能在页面销毁后触发，setState 前必须确认还活着。
    if (!mounted) return;
    setState(() => _results = _compute());
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
          if (_tags.isNotEmpty) _buildTagChips(),
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
              setState(() {
                _kind = EntryKind.note;
                _selectedTag = null;
              });
              _refresh();
            },
          ),
          const SizedBox(width: SketchSpace.sm),
          _SegmentButton(
            label: '想法',
            selected: _kind == EntryKind.thought,
            onTap: () {
              if (_kind == EntryKind.thought) return;
              setState(() {
                _kind = EntryKind.thought;
                _selectedTag = null;
              });
              _refresh();
            },
          ),
        ],
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
              selected: _selectedTag == tag.name,
              onTap: () {
                setState(() {
                  _selectedTag = _selectedTag == tag.name ? null : tag.name;
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
