import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';

/// 记录：笔记与想法共用一页，顶部切换。
///
/// 两者本质都是条目，只是形态不同（笔记有标题、想法是一句话），
/// 所以不拆成两个 tab，用分段切换（docs/11 §2）。
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  bool _showThoughts = false;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '记录',
      subtitle: _showThoughts ? '34 条想法' : '12 条笔记',
      actions: <Widget>[
        SketchButton(
          label: '新建',
          glyph: null,
          dense: true,
          onPressed: () {},
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SketchSpace.lg,
              SketchSpace.md,
              SketchSpace.lg,
              SketchSpace.sm,
            ),
            child: Row(
              children: <Widget>[
                GestureDetector(
                  onTap: () => setState(() => _showThoughts = false),
                  child: SketchTag(
                    '笔记 12',
                    tone: _showThoughts ? SketchTone.plain : SketchTone.primary,
                  ),
                ),
                const SizedBox(width: SketchSpace.sm),
                GestureDetector(
                  onTap: () => setState(() => _showThoughts = true),
                  child: SketchTag(
                    '想法 34',
                    tone: _showThoughts ? SketchTone.primary : SketchTone.plain,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SketchSpace.lg,
                SketchSpace.sm,
                SketchSpace.lg,
                SketchSpace.xxl,
              ),
              children: <Widget>[
                _RecordTile(
                  variant: 0,
                  title: '多端同步的冲突处理方案',
                  excerpt: 'base / local / remote 三份数据缺一不可。没有 base 就无法判断谁改了哪一段…',
                  meta: '08-12 · 笔记 · 1,240 字',
                  tags: const <String>['#同步', '#冲突'],
                ),
                const SizedBox(height: SketchSpace.md),
                _RecordTile(
                  variant: 1,
                  title: 'RFC 6578 增量同步',
                  excerpt: 'sync-collection 一次拿到全部增量和删除列表，但坚果云不支持。',
                  meta: '08-11 · 归档 · 4,182 字',
                  tags: const <String>['#webdav'],
                  highlight: true,
                ),
                const SizedBox(height: SketchSpace.md),
                _RecordTile(
                  variant: 2,
                  title: 'CRDT 的取舍',
                  excerpt: '移动端维护成本太高，先用行级三方合并 + 冲突副本。',
                  meta: '08-10 · 想法',
                  tags: const <String>['#架构'],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.variant,
    required this.title,
    required this.excerpt,
    required this.meta,
    required this.tags,
    this.highlight = false,
  });

  final int variant;
  final String title;
  final String excerpt;
  final String meta;
  final List<String> tags;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return SketchCard(
      variant: variant,
      fill: highlight ? p.note : null,
      tilt: variant.isEven ? SketchTilt.left : SketchTilt.right,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: p.ink,
            ),
          ),
          const SizedBox(height: SketchSpace.xs),
          Text(
            excerpt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.6, color: p.muted),
          ),
          const SizedBox(height: SketchSpace.sm),
          Row(
            children: <Widget>[
              for (final t in tags) ...<Widget>[
                SketchTag(t, dense: true),
                const SizedBox(width: SketchSpace.xs),
              ],
              const Spacer(),
              Text(meta, style: TextStyle(fontSize: 10.5, color: p.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
