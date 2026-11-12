import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/shell/global_hotkey_policy.dart';

/// docs/08 §4.3 全局热键判定测试。
void main() {
  test('默认 Ctrl+Shift+V；规范化忽略大小写与修饰键顺序', () {
    expect(kDefaultGlobalHotkey, 'ctrl+shift+v');
    expect(normalizeHotkey('Shift + Control + V'), 'ctrl+shift+v');
    expect(normalizeHotkey('ALT+F4'), 'alt+f4');
  });

  test('系统保留键拒绝；无冲突可注册', () {
    expect(
      planGlobalHotkey('Ctrl+Alt+Delete').check,
      HotkeyCheck.reserved,
    );
    final ok = planGlobalHotkey('Ctrl+Shift+V');
    expect(ok.check, HotkeyCheck.ok);
    expect(ok.normalized, kDefaultGlobalHotkey);
  });

  test('与已注册冲突时给不冲突候选', () {
    final plan = planGlobalHotkey(
      'V+Ctrl+Shift',
      registered: const <String>['Ctrl+Shift+V', 'Ctrl+Shift+Alt+V'],
    );
    expect(plan.check, HotkeyCheck.conflict);
    expect(plan.fallback, isNotNull);
    expect(plan.fallback, isNot(plan.normalized));
    expect(plan.hint, contains('冲突'));
  });
}
