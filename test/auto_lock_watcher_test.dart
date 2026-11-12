import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/auto_lock_watcher.dart';

/// docs/18 §9 自动锁定观察器测试。
void main() {
  testWidgets('后台未达阈值不锁；超阈值回到前台触发 lock',
      (WidgetTester tester) async {
    var now = 1000;
    var locks = 0;
    await tester.pumpWidget(MaterialApp(
      home: AutoLockWatcher(
        thresholdMs: 5000,
        nowMsProvider: () => now,
        onAutoLock: () => locks++,
        child: const SizedBox.shrink(),
      ),
    ));

    // 模拟进入后台再很快回前台。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = 3000;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(locks, 0);

    // 再次进入后台超过阈值。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = 20000;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(locks, 1);
  });
}
