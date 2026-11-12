/// Windows / 桌面快捷键判定（docs/08 §7「新建 / 搜索 / 切换」）。
///
/// 不绑焦点、不读平台：只把「按键 + 是否 Ctrl/Alt」映射到动作，
/// 让 `CallbackShortcuts` 与测试共用同一张表。
library;

enum DesktopShortcutAction { none, newEntry, search, nextSection, previousSection }

class ShortcutBinding {
  const ShortcutBinding(this.key, this.action);

  final String key;
  final DesktopShortcutAction action;
}

/// key 用字符串而不是 LogicalKeyboardKey，保持纯 Dart 无 Flutter 依赖。
const Map<String, DesktopShortcutAction> kDesktopShortcuts =
    <String, DesktopShortcutAction>{
  'ctrl+n': DesktopShortcutAction.newEntry,
  'ctrl+k': DesktopShortcutAction.search,
  'ctrl+tab': DesktopShortcutAction.nextSection,
  'ctrl+shift+tab': DesktopShortcutAction.previousSection,
  'alt+right': DesktopShortcutAction.nextSection,
  'alt+left': DesktopShortcutAction.previousSection,
};

DesktopShortcutAction shortcutFor({
  required String keyLabel,
  bool ctrl = false,
  bool shift = false,
  bool alt = false,
}) {
  final parts = <String>[
    if (ctrl) 'ctrl',
    if (shift) 'shift',
    if (alt) 'alt',
    keyLabel.toLowerCase(),
  ];
  return kDesktopShortcuts[parts.join('+')] ?? DesktopShortcutAction.none;
}

/// Ctrl+Tab / Alt+Right 在 5 个分区间循环切换。
int nextSectionIndex(int current, DesktopShortcutAction action, {int count = 5}) {
  if (count <= 0) return 0;
  return switch (action) {
    DesktopShortcutAction.nextSection => (current + 1) % count,
    DesktopShortcutAction.previousSection => (current - 1 + count) % count,
    _ => current,
  };
}
