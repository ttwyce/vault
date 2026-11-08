import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';

/// 日记：月历 + 本月列表。
///
/// 月历格子用「简化容器」（实线 + 对称圆角）而不是完整的 SketchFrame：
/// 一屏 42 个格子若都走虚线 CustomPainter，滚动会掉帧（docs/09 R14）。
class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return PageScaffold(
      title: '日记',
      subtitle: '2026 年 11 月 · 8 篇 · 连续 3 天',
      actions: <Widget>[
        SketchButton(
          label: '写今天的',
          tone: SketchTone.primary,
          dense: true,
          onPressed: () {},
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SketchSpace.lg,
          SketchSpace.lg,
          SketchSpace.lg,
          SketchSpace.xxl,
        ),
        children: <Widget>[
          const _MonthGrid(),
          const SizedBox(height: SketchSpace.md),
          Row(
            children: <Widget>[
              _legend(p.note, '有日记', p),
              const SizedBox(width: SketchSpace.md),
              _legend(p.surface, '仅 AI 日记', p),
              const Spacer(),
              Text('点格子预览 · 双击进入',
                  style: TextStyle(fontSize: 10.5, color: p.muted)),
            ],
          ),
          const SizedBox(height: SketchSpace.xl),
          _DiaryTile(
            variant: 0,
            date: '11-08',
            title: '跟限流较劲的一天',
            excerpt: '上午卡在坚果云的限流上，下午想通了应该按分片批量列举。',
            meta: '320 字 · 你写的 · 阴',
          ),
          const SizedBox(height: SketchSpace.md),
          _DiaryTile(
            variant: 1,
            date: '11-07',
            title: '什么都没干',
            excerpt: '睡到中午，下午看了会儿书。',
            meta: '180 字 · 你写的',
          ),
          const SizedBox(height: SketchSpace.md),
          _DiaryTile(
            variant: 2,
            date: '11-06',
            title: 'AI 日记',
            excerpt: '你今天大部分时间在整理旧笔记，把 8 月的三条合并成了一篇。',
            meta: '150 字 · 不是你写的 · 引用 4 条',
            isAi: true,
          ),
        ],
      ),
    );
  }

  Widget _legend(Color fill, String label, SketchPalette palette) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: palette.lineSoft, width: 1),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 10.5, color: palette.muted)),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid();

  static const List<String> _weekdays = <String>['一', '二', '三', '四', '五', '六', '日'];

  /// 2026-11-01 是周日，所以前面留 6 个空位
  static const int _leadingBlanks = 6;
  static const int _daysInMonth = 30;
  static const int _today = 8;
  static const Set<int> _withEntry = <int>{1, 2, 3, 4, 5, 7, 8};
  static const Set<int> _aiOnly = <int>{6};

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final cells = <Widget>[
      for (final w in _weekdays)
        Center(
          child: Text(w,
              style: TextStyle(fontSize: 10.5, color: p.muted, height: 1.4)),
        ),
    ];

    for (var i = 0; i < _leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= _daysInMonth; day++) {
      cells.add(_DayCell(
        day: day,
        isToday: day == _today,
        hasEntry: _withEntry.contains(day),
        aiOnly: _aiOnly.contains(day),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1.25,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.hasEntry,
    required this.aiOnly,
  });

  final int day;
  final bool isToday;
  final bool hasEntry;
  final bool aiOnly;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final marked = hasEntry || aiOnly;

    return Container(
      decoration: BoxDecoration(
        color: isToday ? p.red : (marked ? p.surface : Colors.transparent),
        borderRadius: SketchRadii.pill,
        border: Border.all(
          color: isToday
              ? p.red
              : (marked ? p.lineSoft : p.lineSoft.withValues(alpha: 0.45)),
          width: 1,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 5,
            top: 3,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                color: isToday ? Colors.white : (marked ? p.ink : p.muted),
              ),
            ),
          ),
          if (hasEntry)
            Positioned(
              right: 5,
              bottom: 4,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: p.red, shape: BoxShape.circle),
              ),
            ),
          if (aiOnly)
            Positioned(
              right: 5,
              bottom: 4,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.lineSoft, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiaryTile extends StatelessWidget {
  const _DiaryTile({
    required this.variant,
    required this.date,
    required this.title,
    required this.excerpt,
    required this.meta,
    this.isAi = false,
  });

  final int variant;
  final String date;
  final String title;
  final String excerpt;
  final String meta;
  final bool isAi;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return SketchCard(
      variant: variant,
      fill: isAi ? p.note : null,
      tilt: variant.isEven ? SketchTilt.left : SketchTilt.right,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(date,
                  style: TextStyle(fontSize: 10.5, color: p.muted)),
              const SizedBox(width: SketchSpace.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
              ),
              if (isAi) const SketchTag('不是你写的', dense: true),
            ],
          ),
          const SizedBox(height: SketchSpace.xs),
          Text(
            excerpt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.6, color: p.muted),
          ),
          const SizedBox(height: SketchSpace.sm),
          Text(meta, style: TextStyle(fontSize: 10.5, color: p.muted)),
        ],
      ),
    );
  }
}
