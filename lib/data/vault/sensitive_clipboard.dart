/// 剪贴板自动清除（docs/09 §8 / docs/11 §4.3）。
///
/// 复制敏感值（密码 / TOTP / 恢复码）后 30 秒清除，但**只清除仍是本次
/// 写入的内容**：用户在这 30 秒内复制了别的东西，绝不能误删。
/// 通过注入 [read]/[write]/[sleep] 做确定性测试，不依赖真实平台通道。
library;

import 'dart:async';

abstract interface class ClipboardPort {
  Future<void> write(String text);
  Future<String?> read();
}

class SensitiveClipboard {
  SensitiveClipboard({
    required this.port,
    this.ttl = const Duration(seconds: 30),
    Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? ((Duration d) => Future<void>.delayed(d));

  final ClipboardPort port;
  final Duration ttl;
  final Future<void> Function(Duration) _sleep;

  String? _lastWritten;
  int _generation = 0;

  /// 写入敏感值并排一次自动清除；返回本次的 generation（测试可断言）。
  Future<int> copy(String text) async {
    await port.write(text);
    _lastWritten = text;
    final generation = ++_generation;
    unawaited(_clearLater(generation, text));
    return generation;
  }

  Future<void> _clearLater(int generation, String expected) async {
    await _sleep(ttl);
    // 期间又复制过别的敏感值 / 用户手动取消 / 内容已被替换 → 不动。
    if (generation != _generation || _lastWritten != expected) return;
    final current = await port.read();
    if (current != expected) return;
    await port.write('');
    _lastWritten = null;
  }

  /// 显式取消待清除（例如用户手动点了「已复制」并自行清理）。
  void cancel() => _generation++;
}
