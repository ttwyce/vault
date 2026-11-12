import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/shell/desktop_shortcuts.dart';

/// docs/08 §7 桌面快捷键测试。
void main() {
  test('Ctrl+N / Ctrl+K 映射到新建 / 搜索', () {
    expect(
      shortcutFor(keyLabel: 'n', ctrl: true),
      DesktopShortcutAction.newEntry,
    );
    expect(
      shortcutFor(keyLabel: 'K', ctrl: true),
      DesktopShortcutAction.search,
    );
    expect(shortcutFor(keyLabel: 'n'), DesktopShortcutAction.none);
  });

  test('Ctrl+Tab / Ctrl+Shift+Tab / Alt+方向切换分区', () {
    expect(
      shortcutFor(keyLabel: 'tab', ctrl: true),
      DesktopShortcutAction.nextSection,
    );
    expect(
      shortcutFor(keyLabel: 'tab', ctrl: true, shift: true),
      DesktopShortcutAction.previousSection,
    );
    expect(
      shortcutFor(keyLabel: 'right', alt: true),
      DesktopShortcutAction.nextSection,
    );
  });

  test('分区索引循环；非切换动作保持原值', () {
    expect(
      nextSectionIndex(4, DesktopShortcutAction.nextSection),
      0,
    );
    expect(
      nextSectionIndex(0, DesktopShortcutAction.previousSection),
      4,
    );
    expect(
      nextSectionIndex(2, DesktopShortcutAction.newEntry),
      2,
    );
    expect(nextSectionIndex(2, DesktopShortcutAction.nextSection, count: 0), 0);
  });
}
