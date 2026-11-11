import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/archive/archive_meta.dart';
import '../../data/archive/archive_reader.dart';

/// 归档阅读器（docs/05 §9）。
///
/// 用 `resolveReaderModes` 决定哪些模式可点：纯净（L1 正文）/ 原貌（L2 PDF）/
/// 对比（新旧正文）。PDF 渲染与并排 diff 属于平台层，这里只给出明确的
/// 「需要先下载 / 没有快照 / 无上一版」提示，绝不假装能显示。
class ArchiveReaderPage extends StatefulWidget {
  const ArchiveReaderPage({
    super.key,
    required this.title,
    required this.meta,
    required this.archivedAtMs,
    required this.pdfLocal,
    required this.hasPreviousTextVersion,
    this.body,
  });

  final String title;
  final ArchiveMeta meta;
  final int archivedAtMs;
  final bool pdfLocal;
  final bool hasPreviousTextVersion;
  final String? body;

  @override
  State<ArchiveReaderPage> createState() => _ArchiveReaderPageState();
}

class _ArchiveReaderPageState extends State<ArchiveReaderPage> {
  ReaderMode _mode = ReaderMode.clean;

  static String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final availability = resolveReaderModes(
      meta: widget.meta,
      pdfLocal: widget.pdfLocal,
      hasPreviousTextVersion: widget.hasPreviousTextVersion,
    );
    if (!availability.can(_mode)) {
      _mode = fallbackReaderMode(availability);
    }
    final status = readerStatusLine(
      meta: widget.meta,
      archivedAtMs: widget.archivedAtMs,
      formatDate: _formatDate,
    );

    return PageScaffold(
      title: '归档阅读',
      subtitle: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: SketchSpace.sm,
            children: <Widget>[
              for (final mode in ReaderMode.values)
                GestureDetector(
                  onTap: availability.can(mode)
                      ? () => setState(() => _mode = mode)
                      : null,
                  child: SketchTag(
                    _label(mode),
                    tone: _mode == mode ? SketchTone.primary : SketchTone.plain,
                  ),
                ),
            ],
          ),
          const SizedBox(height: SketchSpace.md),
          Expanded(
            child: SketchCard(
              variant: 1,
              fill: p.surface,
              tilt: SketchTilt.none,
              child: SingleChildScrollView(
                child: _bodyFor(p, availability),
              ),
            ),
          ),
          const SizedBox(height: SketchSpace.sm),
          Text(status, style: TextStyle(fontSize: 10.5, color: p.muted)),
          for (final reason in availability.reasons)
            Text(reason,
                style: TextStyle(fontSize: 10.5, color: p.blue)),
        ],
      ),
    );
  }

  Widget _bodyFor(SketchPalette p, ReaderAvailability availability) {
    switch (_mode) {
      case ReaderMode.clean:
        final body = widget.body;
        if (body == null || body.trim().isEmpty) {
          return Text(
            widget.meta.hasText
                ? 'L1 正文层尚未按需下载。'
                : '这条归档目前只有元数据，还没有正文层。',
            style: TextStyle(fontSize: 13, color: p.muted),
          );
        }
        return Text(body,
            style: TextStyle(fontSize: 14.5, height: 1.9, color: p.ink));
      case ReaderMode.original:
        return Text(
          '原貌模式需要 L2 PDF 快照。当前标记为${widget.pdfLocal ? '已本地缓存' : '仅云端'}，'
          'PDF 渲染由平台层提供。',
          style: TextStyle(fontSize: 13, color: p.muted),
        );
      case ReaderMode.compare:
        return Text(
          '对比模式用于查看新旧两版 L1 正文的并排差异。'
          '当前已检测到内容变更：${widget.meta.changed ? '是' : '否'}。',
          style: TextStyle(fontSize: 13, color: p.muted),
        );
    }
  }

  String _label(ReaderMode mode) => switch (mode) {
        ReaderMode.clean => '纯净',
        ReaderMode.original => '原貌',
        ReaderMode.compare => '对比',
      };
}
