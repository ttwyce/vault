import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/search/search_suggestions.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/entry/entry_models.dart';
import '../../data/entry/entry_repository_provider.dart';
import '../editor/editor_page.dart';
import 'highlight.dart';

/// 独立搜索页。
///
/// 记录页顶部也有搜索框，但那是「在当前分段里快速过滤」。这一页是
/// **全库检索**：跨所有 kind、带命中高亮、并把搜索词写进活动埋点。
/// 日总结要靠 `activity.query` 做聚类，所以搜索必须埋点（docs/17）。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String _query = '';
  Future<List<EntrySummary>> _results =
      Future<List<EntrySummary>>.value(const <EntrySummary>[]);

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _query = widget.initialQuery;
    if (_query.trim().isNotEmpty) _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _refresh);
  }

  void _refresh() {
    if (!mounted) return;
    final repo = ref.read(entryRepositoryProvider);
    final trimmed = _query.trim();
    // 先算 Future 再 setState：箭头闭包返回 Future 会被 Flutter 断言拦下。
    final next = trimmed.isEmpty
        ? Future<List<EntrySummary>>.value(const <EntrySummary>[])
        : repo.searchHybrid(trimmed, nowMs: DateTime.now().millisecondsSinceEpoch, limit: 50);
    setState(() {
      _results = next;
    });

    if (trimmed.isNotEmpty) {
      // 埋点不阻塞界面；失败也不该让搜索框报错。
      unawaited(_logSearch(trimmed, next));
    }
  }

  Future<void> _logSearch(String query, Future<List<EntrySummary>> results) async {
    try {
      final rows = await results;
      await ref.read(activityLoggerProvider).recordSearch(
            query,
            resultCount: rows.length,
          );
    } on Object {
      // 活动埋点是「有则更好」的数据，绝不因为它失败就打断搜索。
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '搜索',
        showSettings: false,
        leading: SketchIconButton(
          glyph: SketchGlyph.close,
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildSearchField(p),
            Expanded(child: _buildResults(p)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(SketchPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SketchSpace.lg,
        SketchSpace.md,
        SketchSpace.lg,
        SketchSpace.sm,
      ),
      child: SketchFrame(
        radius: SketchRadii.pill,
        fill: p.surface,
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
              size: 14,
              color: p.muted,
              strokeWidth: SketchStroke.icon,
            ),
            const SizedBox(width: SketchSpace.sm),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                style: TextStyle(fontSize: 14, height: 1.4, color: p.ink),
                cursorColor: p.red,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '搜标题、正文或标签',
                  hintStyle: TextStyle(fontSize: 13, color: p.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(SketchPalette p) {
    return FutureBuilder<List<EntrySummary>>(
      future: _results,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<EntrySummary>> snapshot,
      ) {
        final trimmed = _query.trim();
        if (trimmed.isEmpty) {
          return Center(
            child: Text(
              '输入关键词，跨全部内容检索',
              style: TextStyle(fontSize: 12.5, height: 1.6, color: p.muted),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: p.red));
        }
        final rows = snapshot.data ?? const <EntrySummary>[];
        if (rows.isEmpty) {
          // docs/06 §8.2：无结果给 3 个改写建议；本项目尚无向量通道，
          // 因此只显示「关键词匹配」降级提示，不谎称已启用语义检索。
          final hint = planEmptySearchHint(
            rawQuery: trimmed,
            ftsHadResults: false,
            vectorHadResults: false,
          );
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: SketchSpace.lg,
                vertical: SketchSpace.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '没有找到「$trimmed」',
                    style: TextStyle(
                        fontSize: 12.5, height: 1.6, color: p.muted),
                  ),
                  const SizedBox(height: SketchSpace.md),
                  Text(hint.headline,
                      style: TextStyle(fontSize: 12, color: p.ink)),
                  const SizedBox(height: SketchSpace.sm),
                  Wrap(
                    spacing: SketchSpace.sm,
                    runSpacing: SketchSpace.sm,
                    children: <Widget>[
                      for (final suggestion in hint.suggestions)
                        GestureDetector(
                          onTap: () {
                            _controller.text = suggestion;
                            _onChanged(suggestion);
                          },
                          child: SketchTag(suggestion, tone: SketchTone.plain),
                        ),
                    ],
                  ),
                  const SizedBox(height: SketchSpace.md),
                  Text(
                    hint.modelTip,
                    style: TextStyle(fontSize: 10.5, color: p.blue),
                  ),
                ],
              ),
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
          itemBuilder: (BuildContext context, int index) => _SearchTile(
            entry: rows[index],
            query: trimmed,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => EditorPage(entryId: rows[index].id),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchTile extends StatelessWidget {
  const _SearchTile({
    required this.entry,
    required this.query,
    required this.onTap,
  });

  final EntrySummary entry;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final base = TextStyle(fontSize: 12, height: 1.6, color: p.muted);
    final hit = TextStyle(
      fontSize: 12,
      height: 1.6,
      color: p.red,
      fontWeight: FontWeight.w700,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SketchSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: highlightSpans(
                  entry.title,
                  query,
                  base: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: p.ink,
                  ),
                  hit: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: p.red,
                  ),
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.snippet.isNotEmpty) ...<Widget>[
              const SizedBox(height: SketchSpace.xs),
              Text.rich(
                TextSpan(children: highlightSpans(entry.snippet, query,
                    base: base, hit: hit)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: SketchSpace.xs),
            Wrap(
              spacing: SketchSpace.sm,
              children: <Widget>[
                Text(
                  _kindLabel(entry.kind),
                  style: TextStyle(fontSize: 10.5, color: p.muted),
                ),
                Text(
                  '命中：关键词',
                  style: TextStyle(fontSize: 10.5, color: p.blue),
                ),
                if (entry.kind == EntryKind.bookmark)
                  const SketchTag('归档', tone: SketchTone.plain, dense: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


/// 结果卡片的类型标签（docs/06 §8.1）。
String _kindLabel(EntryKind kind) => switch (kind) {
      EntryKind.note => '笔记',
      EntryKind.thought => '想法',
      EntryKind.diary => '日记',
      EntryKind.aiDiary => 'AI 日记',
      EntryKind.bookmark => '书签',
      EntryKind.credential => '密码',
    };
