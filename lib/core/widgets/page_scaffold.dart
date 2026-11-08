import 'package:flutter/material.dart';

import '../../app/chrome/app_actions.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../icons/sketch_icons.dart';
import 'sketch_controls.dart';
import 'sketch_frame.dart';

/// 页面骨架：标题栏（可带左侧图标与右侧操作）+ 虚线分隔 + 内容区。
///
/// 所有页面都用它，保证 43 屏的头部节奏一致（docs/10 §7）。
/// 右侧默认带一个设置入口（由 [AppActions] 注入，见 docs/15 §5.3）。
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.showSettings = true,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// 是否显示右上角设置入口。单独测试页面时通常关掉。
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;
    final appActions = showSettings ? AppActions.maybeOf(context) : null;
    final trailing = <Widget>[
      ...actions,
      if (appActions != null)
        SketchIconButton(
          glyph: SketchGlyph.settings,
          tooltip: '设置 · 字体',
          onPressed: appActions.openSettings,
        ),
    ];

    return Column(
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: SketchSpace.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: palette.ink,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing.isNotEmpty)
                Wrap(
                  spacing: SketchSpace.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: trailing,
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: SketchSpace.lg),
          child: SketchDivider(),
        ),
        Expanded(child: child),
      ],
    );
  }
}

