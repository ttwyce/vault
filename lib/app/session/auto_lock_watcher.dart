/// 前后台自动锁定观察器（docs/18 §9）。
///
/// 进入后台记时间戳，回到前台按 [decideAutoLock] 判定；
/// 达阈值才调 `VaultSession.lock()`，未达阈值什么都不做。
/// 不改闸门状态机，不接平台 channel。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auto_lock_policy.dart';
import 'vault_session.dart';

class AutoLockWatcher extends ConsumerStatefulWidget {
  const AutoLockWatcher({
    super.key,
    required this.child,
    this.thresholdMs = kDefaultAutoLockMs,
    this.nowMsProvider,
    this.onAutoLock,
  });

  final Widget child;
  final int thresholdMs;

  /// 可注入时钟，便于 widget 测试模拟后台时长。
  final int Function()? nowMsProvider;

  /// 可注入锁定动作；为空时走真实的 [VaultSession.lock]。
  final VoidCallback? onAutoLock;

  @override
  ConsumerState<AutoLockWatcher> createState() => _AutoLockWatcherState();
}

class _AutoLockWatcherState extends ConsumerState<AutoLockWatcher>
    with WidgetsBindingObserver {
  int? _backgroundAtMs;

  int get _nowMs =>
      widget.nowMsProvider?.call() ?? DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundAtMs ??= _nowMs;
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final background = _backgroundAtMs;
    _backgroundAtMs = null;
    if (background == null) return;
    final decision = decideAutoLock(
      backgroundAtMs: background,
      resumedAtMs: _nowMs,
      thresholdMs: widget.thresholdMs,
    );
    if (decision.shouldLock) {
      final injected = widget.onAutoLock;
      if (injected != null) {
        injected();
      } else {
        // 只有已解锁会话才需要 lock；未解锁时 lock() 本身也是幂等空操作。
        ref.read(vaultSessionProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
