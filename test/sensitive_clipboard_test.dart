import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/sensitive_clipboard.dart';

/// docs/09 §8 剪贴板 30 秒自动清除测试。
class _FakePort implements ClipboardPort {
  String? value;

  @override
  Future<void> write(String text) async => value = text;

  @override
  Future<String?> read() async => value;
}

void main() {
  test('30 秒后清除，且只清仍是本次写入的内容', () async {
    final port = _FakePort();
    final clipboard = SensitiveClipboard(
      port: port,
      sleep: (Duration d) async {
        expect(d, const Duration(seconds: 30));
      },
    );
    await clipboard.copy('recovery words');
    expect(port.value, 'recovery words');
    // sleep 被替换成立即返回；让挂起的 _clearLater 微任务跑完。
    await Future<void>.delayed(Duration.zero);
    expect(port.value, '', reason: '内容未变 → 清除');
  });

  test('用户 30 秒内复制了别的东西，绝不误删', () async {
    final port = _FakePort();
    final clipboard = SensitiveClipboard(
      port: port,
      sleep: (Duration _) async {},
    );
    await clipboard.copy('secret');
    port.value = '用户后来复制的别的内容';
    await Future<void>.delayed(Duration.zero);
    expect(port.value, '用户后来复制的别的内容');
  });

  test('连续两次复制：只有最后一次生效，旧任务不动手', () async {
    final port = _FakePort();
    final clipboard = SensitiveClipboard(
      port: port,
      sleep: (Duration _) async {},
    );
    final first = await clipboard.copy('first');
    final second = await clipboard.copy('second');
    expect(second, first + 1);
    await Future<void>.delayed(Duration.zero);
    // 旧 generation 跳过；第二次复制自己的清除任务把内容清掉。
    expect(port.value, '', reason: '旧 generation 不会误删第二次的写入');
  });

  test('cancel 后待清除任务不执行', () async {
    final port = _FakePort();
    final clipboard = SensitiveClipboard(
      port: port,
      sleep: (Duration _) async {},
    );
    await clipboard.copy('secret');
    clipboard.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(port.value, 'secret');
  });
}
