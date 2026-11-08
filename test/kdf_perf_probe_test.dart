@Timeout(Duration(minutes: 6))
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/argon2_params.dart';
import 'package:vault/core/crypto/kdf.dart';

/// Argon2id 真实代价的实测。
///
/// ## 为什么必须实测
///
/// 设计文档里写的是「低端 Android 约 0.6~1.2s」，那是**推测**。
/// 实际上 `cryptography` 包里的 Argon2id 是**纯 Dart 实现**（虽然会起 isolate
/// 并行，但每个 lane 的计算仍是 Dart 代码）。Dart AOT 下 Argon2 的吞吐
/// 通常只有 C 实现的三到五分之一。
///
/// 如果实测远超预期，只有三个选择：
///   1. 降参数（削弱安全性）
///   2. 换 native 实现（增加三端构建复杂度）
///   3. 接受慢（在解锁页加进度反馈）
///
/// 这个决定不能靠猜。所以这组用例不是"测试"，是**测量**：
/// 它打印真实耗时，并用一个宽松上限兜底（防止某次改动把参数调到不可用）。
void main() {
  test('测量不同参数下的派生耗时', () async {
    final salt = KdfSalt.random(Random(99));

    const candidates = <String, Argon2Params>{
      'OWASP 最低 (m=19MB, t=2, p=1)': Argon2Params(
        memoryKb: 19456,
        iterations: 2,
        parallelism: 1,
      ),
      'm=32MB, t=3, p=4': Argon2Params(memoryKb: 32768, iterations: 3, parallelism: 4),
      'm=64MB, t=3, p=4（当前推荐）': Argon2Params.recommended,
    };

    final timings = <String, int>{};
    for (final entry in candidates.entries) {
      // 预热一次，排除 JIT / isolate 首次启动的固定开销
      await Kdf.fromPassphrase(passphrase: 'warmup', salt: salt, params: entry.value);

      final watch = Stopwatch()..start();
      await Kdf.fromPassphrase(passphrase: 'benchmark-passphrase', salt: salt, params: entry.value);
      watch.stop();
      timings[entry.key] = watch.elapsedMilliseconds;

      // ignore: avoid_print
      print('[Argon2id] ${entry.key} → ${watch.elapsedMilliseconds} ms');
    }

    // 兜底：当前推荐参数在桌面 VM 上不应超过 5 秒。
    // 超过说明参数被误调或实现退化了 —— 这不是"慢一点"，是"用户会以为卡死"。
    expect(
      timings['m=64MB, t=3, p=4（当前推荐）'],
      lessThan(5000),
      reason: 'Argon2id 64MB 耗时异常。若确实变慢，需要重新评估参数或换 native 实现。',
    );
  });
}
