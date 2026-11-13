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
    this.showSettings = false,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// 是否显示右上角设置入口。**默认关闭**：五个主 tab 曾被 AppActions
  /// 挂上重复齿轮，设置只保留外壳一个入口；需要该入口的独立页面显式开启。
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

    // 无 AppBar 的 Scaffold 不会替 body 避开状态栏。统一在这里补 top，
    // 所有页面（设置 / 编辑 / 诊断 …）的标题栏都不会再压到系统状态栏。
    // SafeArea 幂等：AppShell 已经处理过的 tab 页不会重复加高。
    return SafeArea(
      top: true,
      bottom: false,
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
      ),
    );
  }
}

