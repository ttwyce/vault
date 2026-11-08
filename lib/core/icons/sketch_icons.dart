import 'package:flutter/material.dart';

/// 自制手绘图标。
///
/// 不用任何图标库 —— 图标库的绝对直线和完美圆角会瞬间暴露"这是模板"。
/// 这里所有图形都只用 `M / L / C / Z`，控制点刻意不对称，
/// 与 `design/vault-sketch.html` 里的 SVG path 完全同源（24×24 坐标系）。
enum SketchGlyph {
  /// 聊天：歪的气泡 + 四角星
  chat,

  /// 记录：两张错位的纸 + 三条横线
  records,

  /// 日记：书 + 书脊 + 飘出的书签
  diary,

  /// 归档：箱盖一条弧 + 箱身 + 提手
  archive,

  /// 密码：钥匙头 + 钥匙孔 + 带齿的柄
  vault,

  /// 三横杠（三条长度不一的曲线）
  menu,

  /// 加号（两笔不等长）
  plus,

  /// 搜索（歪圆 + 短柄）
  search,

  /// 设置（歪齿轮：圆 + 八根不等长齿）
  settings,

  /// 字体（一个手画的「字格」）
  type,

  /// 导入（托盘 + 向上箭头）
  upload,

  /// 关闭（两笔不交叉的叉）
  close,
}

const Map<SketchGlyph, List<String>> _glyphPaths = {
  SketchGlyph.chat: [
    'M4.6 5.6C10.9 5.2 15.9 5.3 19.4 5.6C19.7 9.4 19.6 13 19.3 16.2'
        'C15.5 16.5 11.4 16.5 8.6 16.2L5.3 19.4C5.1 18.2 5.2 17.1 5.2 16.2'
        'C4.6 12.7 4.5 9 4.6 5.6Z',
    'M12.1 7.9L12.95 10.2L15.25 11.05L12.95 11.9L12.1 14.2'
        'L11.25 11.9L8.95 11.05L11.25 10.2Z',
  ],
  SketchGlyph.records: [
    'M6.4 4.7C9.8 4.4 12.8 4.5 15.4 4.7',
    'M7.6 6.4C10.7 6.1 14 6.2 16.5 6.4C16.8 10.1 16.7 14 16.5 17.5'
        'C13.5 17.8 10.4 17.7 7.6 17.5C7.3 14 7.4 9.9 7.6 6.4Z',
    'M9.5 9.5C11 9.3 12.9 9.4 14.4 9.5',
    'M9.5 12.3C11 12.1 12.9 12.2 14.4 12.3',
    'M9.5 15.1C10.4 15 11.5 15 12.4 15.1',
  ],
  SketchGlyph.diary: [
    'M6.4 4.8C10.4 4.4 14.3 4.5 17.6 4.8C17.9 9 17.8 13.4 17.5 17.6'
        'C13.5 18 9.6 17.9 6.3 17.6C6 13.4 6.1 9 6.4 4.8Z',
    'M9.3 4.9C9.1 9 9.2 13.4 9.3 17.5',
    'M12.7 4.7L12.6 9.3L14.3 8L15.9 9.4L16 4.7',
  ],
  SketchGlyph.archive: [
    'M4.7 8.3C9.6 7.9 14.4 8 19.3 8.3',
    'M5.7 8.5C5.5 11.7 5.6 15 5.8 17.4C9.6 17.8 14.2 17.7 18.1 17.4'
        'C18.3 15 18.4 11.7 18.2 8.5',
    'M9.7 8.4C9.6 6.7 9.8 5.3 10.1 4.7C12 4.5 13.5 4.5 15.1 4.7'
        'C15.4 5.3 15.5 6.7 15.4 8.4',
  ],
  SketchGlyph.vault: [
    'M9.1 6.2C11.1 6 12.9 7.4 13 9.4C13.1 11.4 11.6 13 9.6 13.1'
        'C7.6 13.2 6 11.7 5.9 9.7C5.8 7.8 7.2 6.3 9.1 6.2Z',
    'M9.3 8.7C10 8.6 10.5 9.1 10.4 9.8C10.3 10.5 9.8 10.8 9.1 10.7'
        'C8.5 10.6 8.1 10.1 8.2 9.4C8.3 8.9 8.7 8.7 9.3 8.7Z',
    'M11.9 12.2L18.3 18.2',
    'M16.3 16.3L18.1 14.6',
    'M14.6 14.7L16.3 13',
  ],
  SketchGlyph.menu: [
    'M4.4 6.3C10 5.9 14.8 6 19.6 6.3',
    'M4.4 11.8C9.4 11.5 13.6 11.5 19.6 11.8',
    'M4.4 17.3C8.2 17 11.4 17.1 16.2 17.4',
  ],
  SketchGlyph.plus: [
    'M12 5.6C11.9 10 12 14 12.1 18.4',
    'M5.6 12.1C9.8 11.9 14.2 12 18.4 12.1',
  ],
  SketchGlyph.search: [
    'M11 5.1C14.3 4.9 16.9 7.2 17 10.4C17.1 13.6 14.6 16 11.4 16.1'
        'C8.2 16.2 5.7 13.8 5.6 10.6C5.5 7.6 7.8 5.3 11 5.1Z',
    'M15.4 15.4L19.5 19.6',
  ],
  SketchGlyph.settings: [
    'M12 7.4C14.6 7.3 16.6 9.3 16.5 11.9C16.4 14.5 14.4 16.5 11.8 16.4'
        'C9.2 16.3 7.3 14.3 7.4 11.7C7.5 9.2 9.4 7.5 12 7.4Z',
    'M12 4.2C12.05 4.9 12.06 5.7 12.1 6.5',
    'M12.05 17.5C12.1 18.2 12.11 19 12.15 19.8',
    'M4.3 12.1C5 12.05 5.8 12.05 6.6 12',
    'M17.4 12.05C18.1 12 18.9 12 19.7 12.05',
    'M6.6 6.7C7.2 7.2 7.7 7.8 8.3 8.4',
    'M15.7 15.8C16.3 16.3 16.8 16.9 17.4 17.5',
    'M17.3 6.8C16.7 7.3 16.2 7.9 15.6 8.5',
    'M8.4 15.9C7.8 16.4 7.3 17 6.7 17.6',
  ],
  SketchGlyph.type: [
    'M5.6 5.8C10 5.5 14.2 5.6 18.4 5.9C18.7 10.1 18.6 14.3 18.3 18.2'
        'C14 18.5 9.8 18.4 5.5 18.1C5.2 13.9 5.3 9.8 5.6 5.8Z',
    'M5.8 9.4C9.8 9.1 14.2 9.2 18.2 9.5',
    'M11.9 9.6C11.8 13 11.9 15.6 12 18',
  ],
  SketchGlyph.upload: [
    'M12 5.4C11.9 9 12 12 12.1 15.3',
    'M8.4 8.8C9.6 7.6 10.8 6.5 12 5.4',
    'M12 5.4C13.3 6.6 14.5 7.8 15.7 9',
    'M5.6 14.6C5.5 16.2 5.6 17.4 5.9 18.3C9.8 18.6 14.2 18.5 18.1 18.2'
        'C18.4 17.3 18.5 16.1 18.4 14.5',
  ],
  SketchGlyph.close: [
    'M6.6 6.8C9.2 9.4 11.6 11.8 14.2 14.4',
    'M14.4 6.6C11.8 9.2 9.4 11.6 6.8 14.2',
  ],
};

/// 极简 SVG path 解析器：只支持 `M / L / C / Z`，够画这套图标了。
///
/// 之所以自己解析而不是引第三方包：图标是"设计资产"，
/// 用字符串维护能和设计稿保持一字不差，改一个数字就能微调弧度。
Path parseSketchPath(String d, {double scale = 1.0}) {
  final tokens = RegExp(r'[MLCZ]|-?\d*\.?\d+')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList(growable: false);

  final path = Path();
  var i = 0;
  double next() => double.parse(tokens[i++]) * scale;

  while (i < tokens.length) {
    final cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        path.moveTo(next(), next());
      case 'L':
        path.lineTo(next(), next());
      case 'C':
        final x1 = next();
        final y1 = next();
        final x2 = next();
        final y2 = next();
        final x = next();
        final y = next();
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'Z':
        path.close();
      default:
        break;
    }
  }
  return path;
}

/// 手绘图标组件。颜色走 `color`，未指定时取 `IconTheme`。
class SketchIcon extends StatelessWidget {
  const SketchIcon(
    this.glyph, {
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth = 1.8,
  });

  final SketchGlyph glyph;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final resolved = color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF2D2D2D);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SketchIconPainter(
          paths: _glyphPaths[glyph] ?? const [],
          color: resolved,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SketchIconPainter extends CustomPainter {
  _SketchIconPainter({
    required this.paths,
    required this.color,
    required this.strokeWidth,
  });

  final List<String> paths;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final d in paths) {
      canvas.drawPath(parseSketchPath(d, scale: scale), paint);
    }
  }

  @override
  bool shouldRepaint(_SketchIconPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      !identical(old.paths, paths);
}
