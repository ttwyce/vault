import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../features/archive/archive_page.dart';
import '../../features/chat/chat_page.dart';
import '../../features/diary/diary_page.dart';
import '../../features/quick/quick_capture_page.dart';
import '../../features/records/records_page.dart';
import '../../features/settings/settings_hub_page.dart';
import '../../features/vault/vault_page.dart';
import '../chrome/app_actions.dart';
import '../theme/bottom_nav_fit.dart';
import 'desktop_shortcuts.dart';
import '../theme/sketch_metrics.dart';
import '../theme/sketch_palette.dart';

/// 五个顶层分区。顺序即导航顺序，桌面与移动一致。
enum AppSection { chat, records, diary, archive, vault }

extension AppSectionMeta on AppSection {
  String get label => switch (this) {
        AppSection.chat => '聊天',
        AppSection.records => '记录',
        AppSection.diary => '日记',
        AppSection.archive => '归档',
        AppSection.vault => '密码',
      };

  SketchGlyph get glyph => switch (this) {
        AppSection.chat => SketchGlyph.chat,
        AppSection.records => SketchGlyph.records,
        AppSection.diary => SketchGlyph.diary,
        AppSection.archive => SketchGlyph.archive,
        AppSection.vault => SketchGlyph.vault,
      };
}

/// 应用外壳：桌面用左侧悬浮便签栏，移动用底部悬浮便签条。
///
/// 两者是同一套视觉规则（虚线 + 硬阴影 + 倾斜 + 选中项变便签黄），
/// 见 docs/10 §7.5。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    ChatPage(),
    RecordsPage(),
    DiaryPage(),
    ArchivePage(),
    VaultPage(),
  ];

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  /// 打开设置中心。字体 / 整理 / 搜索 / 回收站都从这一页进。
  void _openSettings() {
    Navigator.of(context).push<void>(_settingsRoute());
  }

  /// 全局快速记录：任何分区都能一键记一条想法。
  void _openQuickCapture() {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => const QuickCapturePage(),
    ));
  }

  Route<void> _settingsRoute() {
    return PageRouteBuilder<void>(
      transitionDuration: SketchMotion.page,
      reverseTransitionDuration: SketchMotion.page,
      pageBuilder: (_, _, _) => const SettingsHubPage(),
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondary, Widget child) {
        // 尊重系统「减少动效」
        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
        final curved = CurvedAnimation(parent: animation, curve: SketchMotion.ease);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SketchPalette.of(context);
    final breakpoint = SketchBreakpoints.of(MediaQuery.sizeOf(context).width);

    final body = IndexedStack(index: _index, children: _pages);

    // docs/08 §7：桌面快捷键。用 CallbackShortcuts 仅在 rail 布局启用，
    // 移动端不抢系统按键；动作表与 desktop_shortcuts.dart 同源。
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
        _invokeShortcut(const _ShortcutIntent('n', ctrl: true));
      },
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
        _invokeShortcut(const _ShortcutIntent('k', ctrl: true));
      },
      const SingleActivator(LogicalKeyboardKey.tab, control: true): () {
        _invokeShortcut(const _ShortcutIntent('tab', ctrl: true));
      },
      const SingleActivator(LogicalKeyboardKey.tab,
          control: true, shift: true): () {
        _invokeShortcut(const _ShortcutIntent('tab', ctrl: true, shift: true));
      },
      const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () {
        _invokeShortcut(const _ShortcutIntent('right', alt: true));
      },
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
        _invokeShortcut(const _ShortcutIntent('left', alt: true));
      },
    };

    return AppActions(
      openSettings: _openSettings,
      child: CallbackShortcuts(
      bindings: breakpoint.useRail ? shortcuts : const <ShortcutActivator, VoidCallback>{},
      child: Focus(autofocus: breakpoint.useRail, child: Scaffold(
        backgroundColor: palette.bg,
        // 快速记录是全局入口，放在内容区右下而不是塞进某个分区 ——
        // 「想到一句话」不该要求用户先切到「记录」页。
        // 抬高一截是为了不压住移动端的底部导航条。
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: SketchSpace.xxl, right: 4),
          child: SketchButton(
            label: '快速记录',
            glyph: SketchGlyph.plus,
            tone: SketchTone.primary,
            dense: true,
            onPressed: _openQuickCapture,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: SafeArea(
          bottom: false,
          child: breakpoint.useRail
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(width: 68, child: _Rail(current: _index, onSelect: _select)),
                    Expanded(child: body),
                  ],
                )
              : Column(
                  children: <Widget>[
                    Expanded(child: body),
                    _BottomNav(current: _index, onSelect: _select),
                  ],
                ),
        ),
      ),
      ),
      ),
    );
  }

  void _invokeShortcut(_ShortcutIntent intent) {
    final action = shortcutFor(
      keyLabel: intent.keyLabel,
      ctrl: intent.ctrl,
      shift: intent.shift,
      alt: intent.alt,
    );
    switch (action) {
      case DesktopShortcutAction.newEntry:
        _openQuickCapture();
      case DesktopShortcutAction.search:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('全库搜索在设置中心 · 搜索页')),
          );
        }
      case DesktopShortcutAction.nextSection:
      case DesktopShortcutAction.previousSection:
        setState(() => _index = nextSectionIndex(
              _index, action, count: AppSection.values.length));
      case DesktopShortcutAction.none:
        break;
    }
  }
}

/// 传给 [shortcutFor] 的按键描述（避免 widget 层直接依赖判定层枚举）。
class _ShortcutIntent {
  const _ShortcutIntent(
    this.keyLabel, {this.ctrl = false, this.shift = false, this.alt = false});

  final String keyLabel;
  final bool ctrl;
  final bool shift;
  final bool alt;
}

// ---------------------------------------------------------------------------
// 桌面：左侧悬浮便签栏
// ---------------------------------------------------------------------------

class _Rail extends StatelessWidget {
  const _Rail({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = SketchPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      child: SketchFrame(
        radius: SketchRadii.c,
        fill: palette.surface,
        padding: const EdgeInsets.symmetric(vertical: SketchSpace.md, horizontal: 6),
        shadowOffset: SketchShadowOffset.button,
        tilt: SketchTilt.left,
        child: Column(
          children: <Widget>[
            _Logo(palette: palette),
            const SizedBox(height: SketchSpace.lg),
            for (var i = 0; i < AppSection.values.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _RailItem(
                  section: AppSection.values[i],
                  selected: i == current,
                  onTap: () => onSelect(i),
                ),
              ),
            const Spacer(),
            _StatusDot(palette: palette),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = SketchPalette.of(context);
    final highlight = widget.selected || _hover;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.section.label,
          child: AnimatedContainer(
            duration: SketchMotion.of(context, SketchMotion.hover),
            width: 38,
            height: 38,
            transform: Matrix4.rotationZ(
              widget.selected ? SketchTilt.selected : SketchTilt.none,
            ),
            decoration: BoxDecoration(
              color: highlight ? palette.note : Colors.transparent,
              borderRadius: SketchRadii.pill,
              border: Border.all(
                color: highlight ? palette.lineSoft : Colors.transparent,
                width: SketchStroke.hair,
              ),
            ),
            child: Center(
              child: SketchIcon(
                widget.section.glyph,
                size: 19,
                color: widget.selected ? palette.red : palette.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.palette});

  final SketchPalette palette;

  @override
  Widget build(BuildContext context) {
    return SketchFrame(
      radius: SketchRadii.d,
      fill: palette.note,
      padding: const EdgeInsets.all(6),
      shadowOffset: SketchShadowOffset.card,
      tilt: SketchTilt.none,
      child: Text(
        '拾',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: palette.ink,
          height: 1.1,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.palette});

  final SketchPalette palette;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '已同步',
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: palette.green, shape: BoxShape.circle),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 移动：底部悬浮便签条
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = SketchPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SketchFrame(
        radius: SketchRadii.a,
        fill: palette.surface,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 7),
        shadowOffset: SketchShadowOffset.button,
        tilt: SketchTilt.left,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < AppSection.values.length; i++)
              Expanded(
                child: _NavItem(
                  section: AppSection.values[i],
                  selected: i == current,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SketchPalette.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: SketchMotion.hover,
        transform: Matrix4.rotationZ(selected ? -0.014 : 0),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: selected ? palette.note : Colors.transparent,
          borderRadius: SketchRadii.pill,
          border: Border.all(
            color: selected ? palette.lineSoft : Colors.transparent,
            width: SketchStroke.hair,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SketchIcon(
              section.glyph,
              size: 19,
              color: selected ? palette.red : palette.muted,
            ),
            const SizedBox(height: 2),
            Builder(
              builder: (BuildContext context) {
                final fit = planBottomNavFit(
                  availableWidth: MediaQuery.sizeOf(context).width,
                  tabCount: AppSection.values.length,
                );
                return Text(
                  fit.needsAbbreviate
                      ? section.label.characters.first
                      : section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fit.suggestedFontSize,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? palette.ink : palette.muted,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
