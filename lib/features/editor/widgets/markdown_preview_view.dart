import 'package:flutter/material.dart';

import '../../../app/theme/sketch_metrics.dart';
import '../../../app/theme/sketch_theme.dart';
import '../../../data/editor/markdown_preview.dart';

/// Markdown 实时预览面板（docs/09 §4）。
///
/// 只渲染 [parseMarkdownPreview] 归类的块，不引第三方渲染器；
/// 是「写的是不是 Markdown」的轻量核对，不是完整 CommonMark 实现。
class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({
    super.key,
    required this.source,
  });

  final String source;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final blocks = parseMarkdownPreview(source);
    if (source.trim().isEmpty) {
      return Text(
        '预览：正文为空',
        style: TextStyle(fontSize: 12, color: p.muted),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: SketchSpace.lg),
      itemCount: blocks.length,
      itemBuilder: (BuildContext context, int index) {
        final block = blocks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: SketchSpace.xs),
          child: _BlockView(block: block),
        );
      },
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});

  final PreviewBlock block;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final text = block.text;
    switch (block.kind) {
      case PreviewBlockKind.paragraph:
        if (text.isEmpty) return const SizedBox(height: SketchSpace.sm);
        return Text(text,
            style: TextStyle(fontSize: 13.5, height: 1.8, color: p.ink));
      case PreviewBlockKind.heading1:
        return Text(text,
            style: TextStyle(
                fontSize: 20,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: p.ink));
      case PreviewBlockKind.heading2:
        return Text(text,
            style: TextStyle(
                fontSize: 17,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: p.ink));
      case PreviewBlockKind.heading3:
        return Text(text,
            style: TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: p.ink));
      case PreviewBlockKind.bullet:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('· ',
                style: TextStyle(fontSize: 13.5, color: p.red)),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13.5, height: 1.8, color: p.ink)),
            ),
          ],
        );
      case PreviewBlockKind.task:
        return Row(
          children: <Widget>[
            Icon(
              block.checked
                  ? Icons.check_box_outlined
                  : Icons.check_box_outline_blank,
              size: 15,
              color: block.checked ? p.green : p.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 13.5, color: p.ink)),
            ),
          ],
        );
      case PreviewBlockKind.quote:
        return Container(
          padding: const EdgeInsets.only(left: SketchSpace.sm),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: p.blue, width: 2)),
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.8,
                  color: p.muted,
                  fontStyle: FontStyle.italic)),
        );
      case PreviewBlockKind.codeFence:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(SketchSpace.sm),
          color: p.noteAlt,
          child: Text(
            text.isEmpty ? '（空代码块）' : text,
            style: context.typography.monoStyle(size: 12, color: p.ink),
          ),
        );
      case PreviewBlockKind.image:
        return Text('🖼 $text',
            style: TextStyle(fontSize: 12.5, color: p.blue));
    }
  }
}
