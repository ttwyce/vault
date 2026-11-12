import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/auto_lock_policy.dart';

/// docs/18 §9 自动锁定判定测试。
void main() {
  test('默认 5 分钟；未达阈值不锁并给剩余宽限', () {
    expect(kDefaultAutoLockMs, 300000);
    final short = decideAutoLock(
      backgroundAtMs: 1000,
      resumedAtMs: 1000 + 60000,
    );
    expect(short.shouldLock, isFalse);
    expect(short.remainingMs, 240000);
    expect(short.reason, contains('不锁定'));
  });

  test('达到/超过阈值锁定；边界当天仍有效', () {
    final exact = decideAutoLock(
      backgroundAtMs: 0,
      resumedAtMs: kDefaultAutoLockMs,
    );
    expect(exact.shouldLock, isTrue);
    expect(exact.remainingMs, 0);
    final over = decideAutoLock(
      backgroundAtMs: 0,
      resumedAtMs: kDefaultAutoLockMs * 3,
    );
    expect(over.backgroundMs, kDefaultAutoLockMs * 3);
    expect(over.reason, contains('5 分钟'));
  });

  test('时间戳倒退保守不锁；阈值可配置', () {
    expect(
      decideAutoLock(backgroundAtMs: 500, resumedAtMs: 100).shouldLock,
      isFalse,
    );
    expect(
      decideAutoLock(
        backgroundAtMs: 0,
        resumedAtMs: 2000,
        thresholdMs: 1000,
      ).shouldLock,
      isTrue,
    );
  });
}
