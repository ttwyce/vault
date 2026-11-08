import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';

/// 归档网站总览（docs/11 §3）。
///
/// 这里只展示「事实」：字数、快照大小、HTTP 状态、下次检查时间。
/// 死链条目明确标注可回退快照，而不是只报错。
class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  int _filter = 0;

  static const List<String> _filters = <String>['全部', '存活', '失效', '待重抓'];

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return PageScaffold(
      title: '归档',
      subtitle: '88 个 · 1.2 GB',
      actions: <Widget>[
        SketchButton(
          label: '归档网址',
          glyph: SketchGlyph.plus,
          tone: SketchTone.primary,
          dense: true,
          onPressed: () {},
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SketchSpace.lg,
          SketchSpace.md,
          SketchSpace.lg,
          SketchSpace.xxl,
        ),
        children: <Widget>[
          Wrap(
            spacing: SketchSpace.sm,
            runSpacing: SketchSpace.sm,
            children: <Widget>[
              for (var i = 0; i < _filters.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _filter = i),
                  child: SketchTag(
                    _filters[i],
                    tone: _filter == i ? SketchTone.primary : SketchTone.plain,
                  ),
                ),
            ],
          ),
          const SizedBox(height: SketchSpace.lg),
          _ArchiveTile(
            variant: 0,
            letter: 'R',
            title: 'RFC 6578：WebDAV 的增量同步机制',
            meta: 'example.com · 08-11 · 4,182 字 · 412 KB',
            badges: const <(String, SketchTone)>[
              ('快照', SketchTone.primary),
              ('已读', SketchTone.plain),
            ],
            trailing: '下次检查 12-01',
          ),
          const SizedBox(height: SketchSpace.md),
          _ArchiveTile(
            variant: 1,
            letter: 'C',
            title: '一篇讲 CRDT 的长文',
            meta: 'blog.example.org · 08-12 · 已失效',
            badges: const <(String, SketchTone)>[
              ('原站已失效', SketchTone.primary),
              ('已回退快照', SketchTone.plain),
            ],
            trailing: '试 Wayback',
          ),
          const SizedBox(height: SketchSpace.md),
          _ArchiveTile(
            variant: 2,
            letter: 'G',
            title: 'GitHub Actions 缓存策略',
            meta: 'github.com · 08-09 · 3,010 字 · 286 KB',
            badges: const <(String, SketchTone)>[
              ('快照', SketchTone.plain),
              ('内容有变更', SketchTone.blue),
            ],
            trailing: '对比',
          ),
          const SizedBox(height: SketchSpace.xl),
          SketchCard(
            variant: 3,
            fill: p.noteAlt,
            tilt: SketchTilt.none,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '云端用了 68%，快照占 1.0 GB。超过 80% 会自动把最老的快照降级为纯正文。',
                    style: TextStyle(fontSize: 11.5, height: 1.6, color: p.blue),
                  ),
                ),
                const SizedBox(width: SketchSpace.md),
                SketchButton(label: '清理', dense: true, onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({
    required this.variant,
    required this.letter,
    required this.title,
    required this.meta,
    required this.badges,
    required this.trailing,
  });

  final int variant;
  final String letter;
  final String title;
  final String meta;
  final List<(String, SketchTone)> badges;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return SketchCard(
      variant: variant,
      tilt: variant.isEven ? SketchTilt.left : SketchTilt.right,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SketchFrame(
            radius: SketchRadii.d,
            fill: p.note,
            padding: const EdgeInsets.all(6),
            shadowOffset: SketchShadowOffset.card,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.ink,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: SketchSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(meta,
                    style: TextStyle(fontSize: 10.5, color: p.muted)),
                const SizedBox(height: SketchSpace.sm),
                Wrap(
                  spacing: SketchSpace.xs,
                  runSpacing: SketchSpace.xs,
                  children: <Widget>[
                    for (final (label, tone) in badges)
                      SketchTag(label, tone: tone, dense: true),
                    Text(trailing,
                        style: TextStyle(fontSize: 10.5, color: p.muted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
