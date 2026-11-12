/// Windows 全局热键判定（docs/08 §4.3，默认 Ctrl+Shift+V）。
///
/// 不注册系统热键、不加依赖：只做规范化、冲突检测与回退候选，
/// 真实 `hotkey_manager` 注册仍属平台层。
library;

/// 默认：Ctrl+Shift+V 呼出快速搜索 → 回车复制。
const String kDefaultGlobalHotkey = 'ctrl+shift+v';

/// 不允许占用的系统 / 常用组合。
const Set<String> kReservedHotkeys = <String>{
  'ctrl+alt+delete',
  'alt+f4',
  'ctrl+shift+esc',
  'win+l',
};

String normalizeHotkey(String raw) {
  final parts = raw
      .trim()
      .toLowerCase()
      .split('+')
      .map((String p) => p.trim())
      .where((String p) => p.isNotEmpty)
      .toList();
  final modifiers = <String>{};
  final keys = <String>[];
  for (final part in parts) {
    if (<String>{'ctrl', 'control', 'shift', 'alt', 'win', 'meta'}.contains(part)) {
      modifiers.add(part == 'control' ? 'ctrl' : part == 'meta' ? 'win' : part);
      continue;
    }
    keys.add(part);
  }
  final order = <String>['ctrl', 'shift', 'alt', 'win'];
  return <String>[
    for (final m in order)
      if (modifiers.contains(m)) m,
    ...keys,
  ].join('+');
}

enum HotkeyCheck { ok, reserved, conflict }

class HotkeyPlan {
  const HotkeyPlan({
    required this.check,
    required this.normalized,
    required this.hint,
    required this.fallback,
  });

  final HotkeyCheck check;
  final String normalized;
  final String hint;
  final String? fallback;
}

/// [registered] 是已注册的全局热键（规范化前字符串即可）。
HotkeyPlan planGlobalHotkey(
  String candidate, {
  Iterable<String> registered = const <String>[],
}) {
  final normalized = normalizeHotkey(candidate);
  if (kReservedHotkeys.contains(normalized)) {
    return HotkeyPlan(
      check: HotkeyCheck.reserved,
      normalized: normalized,
      hint: '该组合是系统保留键，不能注册',
      fallback: null,
    );
  }
  final taken = registered.map(normalizeHotkey).toSet();
  if (taken.contains(normalized)) {
    final fallback = _nextFallback(normalized, taken);
    return HotkeyPlan(
      check: HotkeyCheck.conflict,
      normalized: normalized,
      hint: '全局热键冲突，建议改用 $fallback',
      fallback: fallback,
    );
  }
  return HotkeyPlan(
    check: HotkeyCheck.ok,
    normalized: normalized,
    hint: '可注册（真实注册与冲突处理由平台层执行）',
    fallback: null,
  );
}

String _nextFallback(String normalized, Set<String> taken) {
  for (final prefix in <String>['ctrl+shift+alt+', 'ctrl+alt+', 'ctrl+shift+']) {
    final keys = normalized.split('+').last;
    final candidate = '$prefix$keys';
    if (!taken.contains(candidate) && candidate != normalized) {
      return candidate;
    }
  }
  return kDefaultGlobalHotkey;
}
