import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../icons/sketch_icons.dart';
import 'sketch_frame.dart';

enum SketchTone { primary, blue, ghost, plain }

/// 手绘按钮。
///
/// 悬停/按下不用缩放（会导致布局抖动），而是「位移 + 阴影变浅」，
/// 模拟把纸片按进桌面。
class SketchButton extends StatefulWidget {
  const SketchButton({
    super.key,
    required this.label,
    this.onPressed,
    this.tone = SketchTone.plain,
    this.glyph,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final SketchTone tone;
  final SketchGlyph? glyph;
  final bool dense;

  @override
  State<SketchButton> createState() => _SketchButtonState();
}

class _SketchButtonState extends State<SketchButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = SketchPalette.of(context);
    final enabled = widget.onPressed != null;

    final (Color bg, Color fg, Color border) = switch (widget.tone) {
      SketchTone.primary => (p.red, Colors.white, p.red),
      SketchTone.blue => (p.blue, Colors.white, p.blue),
      SketchTone.ghost => (Colors.transparent, p.muted, p.lineSoft),
      SketchTone.plain => (p.surface, p.ink, p.line),
    };

    final base = widget.dense ? SketchShadowOffset.card : SketchShadowOffset.button;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!.call();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: _down ? 1 : 0),
          duration: SketchMotion.press,
          curve: Curves.easeOut,
          builder: (context, t, _) {
            return Transform.translate(
              offset: Offset(base.dx * t, base.dy * t),
              child: SketchFrame(
                radius: SketchRadii.c,
                fill: bg,
                borderColor: border,
                shadowColor: p.shadow,
                shadowOffset: Offset(base.dx * (1 - t), base.dy * (1 - t)),
                strokeWidth: widget.tone == SketchTone.ghost
                    ? SketchStroke.hair
                    : SketchStroke.normal,
                tilt: SketchTilt.none,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.dense ? 10 : 14,
                  vertical: widget.dense ? 5 : 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.glyph != null) ...[
                      SketchIcon(widget.glyph!, size: 13, color: fg, strokeWidth: 2),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: widget.dense ? 11.5 : 12.5,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 图标按钮（三横杠、关闭等）。
class SketchIconButton extends StatefulWidget {
  const SketchIconButton({
    super.key,
    required this.glyph,
    this.onPressed,
    this.tooltip,
    this.size = 31,
  });

  final SketchGlyph glyph;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  State<SketchIconButton> createState() => _SketchIconButtonState();
}

class _SketchIconButtonState extends State<SketchIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = SketchPalette.of(context);
    final button = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: SketchMotion.hover,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _hover ? p.note : Colors.transparent,
            borderRadius: SketchRadii.pill,
            border: Border.all(
              color: _hover ? p.lineSoft : Colors.transparent,
              width: SketchStroke.hair,
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: SketchIcon(
              widget.glyph,
              size: widget.size * 0.6,
              color: _hover ? p.ink : p.muted,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

/// 药丸标签。颜色分工见 docs/10 §3。
class SketchTag extends StatelessWidget {
  const SketchTag(
    this.label, {
    super.key,
    this.tone = SketchTone.plain,
    this.dense = false,
  });

  final String label;
  final SketchTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = SketchPalette.of(context);

    final (Color bg, Color fg, Color border) = switch (tone) {
      SketchTone.primary => (p.red, Colors.white, p.red),
      SketchTone.blue => (p.noteAlt, p.blue, p.blue),
      SketchTone.ghost => (Colors.transparent, p.muted, p.lineSoft),
      SketchTone.plain => (p.surface, p.muted, p.lineSoft),
    };

    return SketchFrame(
      radius: SketchRadii.pill,
      fill: bg,
      borderColor: border,
      shadowColor: Colors.transparent,
      shadowOffset: Offset.zero,
      strokeWidth: SketchStroke.hair,
      tilt: SketchTilt.none,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 9,
        vertical: dense ? 2 : 3,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: dense ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }
}
