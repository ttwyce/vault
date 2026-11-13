/// 年度回顾页（docs/11 §1.5）。
///
/// 只读聚合真实日记 entry.meta：不生成 AI 文本、不改库、不导出 PDF。
/// 月份分布 / 平均字数 / 心情 / 最长连续段都来自本地数据。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/app_runtime.dart';
import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/diary/diary_meta.dart';
import '../../data/diary/diary_handbook.dart';
import '../../data/diary/diary_review.dart';

class DiaryYearReviewPage extends ConsumerStatefulWidget {
  const DiaryYearReviewPage({
    super.key,
    required this.year,
    this.exportRunner,
  });

  final int year;

  /// 测试可注入导出目录；生产由 AppRuntime.exportRoot 决定。
  final Future<DiaryHandbookResult> Function({
    required DiaryYearReview review,
    required bool confirmed,
  })? exportRunner;

  @override
  ConsumerState<DiaryYearReviewPage> createState() =>
      _DiaryYearReviewPageState();
}

class _DiaryYearReviewPageState extends ConsumerState<DiaryYearReviewPage> {
  DiaryYearReview? _review;
  bool _exportConfirmed = false;
  String _exportHint = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(vaultDatabaseProvider);
    final rows = await (db.select(db.entries)
          ..where((t) => t.kind.equals(EntryKind.diary.code))
          ..where((t) => t.deleted.equals(0)))
        .get();
    final entries = <DiaryReviewEntry>[];
    for (final row in rows) {
      try {
        entries.add(DiaryReviewEntry.fromMeta(DiaryMeta.fromJson(row.meta)));
      } on Object {
        // 坏 meta 不阻断整份回顾。
      }
    }
    if (!mounted) return;
    setState(() => _review = buildDiaryYearReview(
          year: widget.year,
          entries: entries,
        ));
  }

  Future<void> _exportPdf(DiaryYearReview review) async {
    if (!_exportConfirmed) {
      setState(() => _exportHint = '请先勾选导出确认');
      return;
    }
    final injected = widget.exportRunner;
    final root = ref.read(appRuntimeProvider).exportRoot;
    if (injected == null && root == null) {
      setState(() => _exportHint = '未装配导出目录');
      return;
    }
    final result = injected != null
        ? await injected(review: review, confirmed: true)
        : await exportDiaryHandbook(
            review: review,
            root: root!,
            confirmed: true,
          );
    if (!mounted) return;
    setState(() => _exportHint = result.hint);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final review = _review;
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '${widget.year} 年度回顾',
        subtitle: '本地日记聚合 · 只读',
        showSettings: false,
        leading: SketchIconButton(
          glyph: SketchGlyph.close,
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        child: ListView(
          padding: const EdgeInsets.all(SketchSpace.lg),
          children: <Widget>[
            if (review == null)
              const Text('正在读取日记…')
            else ...<Widget>[
              SketchFrame(
                radius: SketchRadii.b,
                fill: p.note,
                borderColor: p.line,
                padding: const EdgeInsets.all(SketchSpace.lg),
                child: Text(review.hint, style: context.texts.titleSmall),
              ),
              const SizedBox(height: SketchSpace.lg),
              SketchFrame(
                radius: SketchRadii.c,
                fill: p.surface,
                borderColor: p.lineSoft,
                padding: const EdgeInsets.all(SketchSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('每月记录', style: context.texts.titleSmall),
                    const SizedBox(height: SketchSpace.sm),
                    for (final month in review.months)
                      Padding(
                        padding: const EdgeInsets.only(bottom: SketchSpace.xs),
                        child: Text(
                          '${month.month.toString().padLeft(2, '0')} 月 · '
                          '${month.entries} 篇 · ${month.words} 字 · '
                          '平均 ${month.averageWords} 字',
                          style: context.texts.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: SketchSpace.lg),
              SketchFrame(
                radius: SketchRadii.d,
                fill: p.noteAlt,
                borderColor: p.lineSoft,
                padding: const EdgeInsets.all(SketchSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('心情分布', style: context.texts.titleSmall),
                    const SizedBox(height: SketchSpace.sm),
                    if (review.moods.isEmpty)
                      Text('今年还没有记录心情', style: context.texts.bodySmall)
                    else
                      for (final entry in review.moods.entries)
                        Text('${entry.key} · ${entry.value} 次',
                            style: context.texts.bodySmall),
                    const SizedBox(height: SketchSpace.md),
                    Text('补写 ${review.backfilled} 篇',
                        style: context.texts.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: SketchSpace.lg),
              SketchFrame(
                radius: SketchRadii.b,
                fill: p.surface,
                borderColor: p.lineSoft,
                padding: const EdgeInsets.all(SketchSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('导出 PDF 手账', style: context.texts.titleSmall),
                    const SizedBox(height: SketchSpace.sm),
                    Text(
                      '只导出聚合统计，不含日记正文；需二次确认。',
                      style: context.texts.bodySmall,
                    ),
                    const SizedBox(height: SketchSpace.sm),
                    GestureDetector(
                      onTap: () => setState(
                          () => _exportConfirmed = !_exportConfirmed),
                      child: SketchTag(
                        _exportConfirmed ? '已确认' : '未确认',
                        tone: _exportConfirmed
                            ? SketchTone.primary
                            : SketchTone.ghost,
                        dense: true,
                      ),
                    ),
                    const SizedBox(height: SketchSpace.sm),
                    SketchButton(
                      label: '导出 PDF',
                      dense: true,
                      onPressed: () => _exportPdf(review),
                    ),
                    if (_exportHint.isNotEmpty) ...<Widget>[
                      const SizedBox(height: SketchSpace.sm),
                      Text(_exportHint, style: context.texts.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
