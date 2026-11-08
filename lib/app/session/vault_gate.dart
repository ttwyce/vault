import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../features/unlock/onboarding_page.dart';
import '../../features/unlock/unlock_page.dart';
import '../shell/app_shell.dart';
import '../theme/sketch_metrics.dart';
import '../theme/sketch_theme.dart';
import 'vault_session.dart';

/// 闸门决定显示哪一屏。
///
/// 抽成纯函数而不是写在 `build` 里，是为了让它能被单元测试直接覆盖 ——
/// 「恢复码阶段优先」这条规则如果只存在于 widget 里，就只能靠搭
/// 完整的 widget 环境去验证，而这类测试既慢又容易因为无关改动而碎。
enum GateScreen {
  /// 首次创建 + 恢复码（也用于"创建成功但还没确认恢复码"）。
  onboarding,

  /// 输密码 / 输恢复码。
  unlock,

  /// 主界面。
  shell,

  /// 致命错误：重试没有意义。
  fatal,
}

/// **全 App 唯一的路由判断。**
///
/// 顺序有硬性要求：
///
/// 1. **未确认的恢复码优先于一切。** 创建 vault 成功后状态已经是 `unlocked`，
///    但用户还没抄下那 24 个词。按状态直接进主界面的话，那 24 个词
///    就永远看不到了（系统只存被包裹的 DEK，不存词本身）。
/// 2. 其次才是状态机。
GateScreen resolveGateScreen(VaultSessionState state) {
  if (state.recoveryCode != null) return GateScreen.onboarding;

  switch (state.status) {
    case VaultStatus.failed:
      return GateScreen.fatal;
    case VaultStatus.needsSetup:
      return GateScreen.onboarding;
    case VaultStatus.locked:
      return GateScreen.unlock;
    case VaultStatus.unlocking:
      // **创建中与解锁中都是 `unlocking`**，只能靠 `meta` 区分：
      //   · 创建阶段 meta 还没写盘（为 null）→ 留在创建页
      //   · 解锁阶段必然已有 meta → 留在解锁页
      //
      // 不区分的话，首次创建的那 2 秒派生里闸门会切到解锁页，
      // 用户会看到「刚设完密码，界面突然变成了另一个页面」。
      return state.meta == null ? GateScreen.onboarding : GateScreen.unlock;
    case VaultStatus.unlocked:
      return GateScreen.shell;
  }
}

/// 根路由闸门。**整个 App 只有这一处决定"现在该显示什么"。**
///
/// 为什么收敛到一处：如果把「有没有 vault」「有没有解锁」这些判断散落到
/// 各个页面里，迟早会出现「解锁页和主界面同时可见」或者「两个页面各自
/// 尝试打开数据库」这类竞态。这里一次判断，页面自己不用管。
class VaultGate extends ConsumerWidget {
  const VaultGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vaultSessionProvider);

    switch (resolveGateScreen(state)) {
      case GateScreen.onboarding:
        return const OnboardingPage();
      case GateScreen.unlock:
        // 解锁中仍然显示解锁页：它自己会根据 `isBusy` 切换成转圈状态，
        // 这样页面不会在派生的 2 秒里被整个替换掉（那会闪一下）。
        return const UnlockPage();
      case GateScreen.shell:
        return const AppShell();
      case GateScreen.fatal:
        return _FatalErrorPage(message: state.error ?? '未知错误');
    }
  }
}

/// 致命错误页。
///
/// 「致命」的定义：**重试没有意义**。典型是 `meta.enc` 损坏 ——
/// 没有它就无法派生出 KEK，任何密码都打不开。
///
/// 所以这一页**不提供"重试"按钮**，那是在骗用户。它只做三件事：
/// 说清发生了什么、给出可执行的下一步、让用户能把错误信息带走求助。
class _FatalErrorPage extends StatelessWidget {
  const _FatalErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;

    return Scaffold(
      backgroundColor: palette.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SketchSpace.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '打不开这个库',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: SketchSpace.sm),
                Text(
                  '本机的 vault 元数据读取失败。没有它就无法派生出解密密钥，'
                  '换任何密码都打不开。',
                  style: TextStyle(fontSize: 13, height: 1.7, color: palette.muted),
                ),
                const SizedBox(height: SketchSpace.lg),
                SketchCard(
                  fill: palette.note,
                  child: Text(
                    message,
                    // 错误信息用等宽体：里面有路径、PRAGMA 名、文件头这类
                    // 需要逐字核对的内容，等宽才看得清。
                    style: context.typography.monoStyle(
                      size: 12,
                      height: 1.7,
                      color: palette.ink,
                    ),
                  ),
                ),
                const SizedBox(height: SketchSpace.lg),
                Text(
                  '可以做的事',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: SketchSpace.xs),
                Text(
                  '· 如果你有备份，把 meta.enc 恢复回去再重新打开\n'
                  '· 如果刚从别的设备同步过，先不要继续，避免覆盖云端\n'
                  '· 把下面的错误信息复制给开发者，不要自己删文件',
                  style: TextStyle(fontSize: 12, height: 1.9, color: palette.muted),
                ),
                const SizedBox(height: SketchSpace.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SketchButton(
                    label: '复制错误信息',
                    glyph: null,
                    tone: SketchTone.plain,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: message));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
