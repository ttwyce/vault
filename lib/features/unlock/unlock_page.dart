import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/biometric_session_policy.dart';
import '../../app/session/biometric_unlock.dart';
import '../../app/session/unlock_policy.dart';
import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';

/// 秒数读数的刷新节奏。
///
/// 刻意不复用 `SketchMotion`：那几个常量描述的是"动效时长"，
/// 这里是"读数刷新频率"，语义不同 —— 混在一起的话，将来调慢动效
/// 会顺手把计时也调慢，而这种错误在代码评审里几乎看不出来。
const Duration _tickInterval = Duration(seconds: 1);

/// 内容列最大宽度。与致命错误页、字体页弹窗用同一把尺子（420），
/// 保证"窄屏撑满、宽屏不散"的手感一致。
const double _contentMaxWidth = 420;

/// 解锁方式。两种模式共用一张卡，切换时不换页 —— 换页会丢掉输入焦点，
/// 而用户在这两种模式之间来回试是常态。
enum _UnlockMode { passphrase, recovery }

/// 解锁页：本机已有 vault，等用户给主密码（或 24 词恢复码）。
///
/// 这一页**不做任何跳转** —— 解锁成功后由 [VaultGate] 依据会话状态切走。
/// 页面唯一的职责是把 `VaultSessionState` 翻译成"能看懂 + 敢按"的界面。
///
/// ## 写 widget 测试时的三个坑
///
/// - 派生期间有循环转圈动画，`pumpAndSettle()` 会一直等到超时。忙态请用定长
///   `pump(Duration(seconds: n))`：秒数计时器是 1 秒一拍，推到 3 秒就能读到
///   「已用 3 秒」。
/// - 成功后本页不做任何导航（由 gate 换页），**不要断言 `Navigator`**。
/// - 主密码框带 `autofocus`，`WidgetTester` 里会有焦点副作用；恢复码模式没有。
class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  final TextEditingController _passphrase = TextEditingController();
  final TextEditingController _recovery = TextEditingController();

  _UnlockMode _mode = _UnlockMode.passphrase;
  bool _obscure = true;
  UnlockPolicyState _policy = const UnlockPolicyState();
  String? _lastError;
  bool _biometricAvailable = false;
  bool _biometricEnrolled = false;
  final BiometricVaultUnlock _biometric = const BiometricVaultUnlock();

  /// 只用于"每秒重建一次"以刷新已用秒数，本身不存任何进度。
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // gate 在 `unlocking` 状态下也返回本页，所以首帧可能已经处于派生中
    // （例如热重启时）。这里补一次同步，避免计时器晚一秒才起来。
    _syncTicker(ref.read(vaultSessionProvider).isBusy);
    _probeBiometric();
  }

  Future<void> _probeBiometric() async {
    final available = await _biometric.isAvailable();
    final enrolled = await _biometric.hasEnrollment();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnrolled = enrolled;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _passphrase.dispose();
    _recovery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final state = ref.watch(vaultSessionProvider);
    final busy = state.isBusy;

    // 派生开始/结束时开关计时器。用 `listen` 而不是在 build 里直接开关：
    // build 可能因为主题、字体、键盘弹起而重跑，副作用不能写在那里。
    ref.listen<bool>(
      vaultSessionProvider.select((VaultSessionState s) => s.isBusy),
      (bool? _, bool next) => _syncTicker(next),
    );
    // docs/08 §6：失败计数只在「新的错误文本」出现时推进一次，
    // 避免 build 重跑把一次失败算成十次。
    ref.listen<String?>(
      vaultSessionProvider.select((VaultSessionState s) => s.error),
      (String? previous, String? next) {
        if (next == null || next == _lastError) return;
        _lastError = next;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _policy = expireLockIfNeeded(_policy, nowMs: nowMs);
          _policy = recordUnlockFailure(
            _policy,
            method: _mode == _UnlockMode.passphrase
                ? UnlockMethod.passphrase
                : UnlockMethod.recovery,
            nowMs: nowMs,
          );
        });
      },
    );
    // 成功解锁（错误清空）后重置计数。
    if (state.error == null && _lastError != null) {
      _lastError = null;
      _policy = recordUnlockSuccess();
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SketchSpace.xl,
              vertical: SketchSpace.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _Wordmark(),
                  const SizedBox(height: SketchSpace.xl),
                  _buildFormCard(p, state, busy, _policy),
                  const SizedBox(height: SketchSpace.lg),
                  const _FooterNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 表单
  // ---------------------------------------------------------------------------

  Widget _buildFormCard(
    SketchPalette p,
    VaultSessionState state,
    bool busy,
    UnlockPolicyState policy,
  ) {
    final passphraseMode = _mode == _UnlockMode.passphrase;
    final error = state.error;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final gate = decideUnlockGate(
      policy,
      method: passphraseMode
          ? UnlockMethod.passphrase
          : UnlockMethod.recovery,
      nowMs: nowMs,
    );
    final locked = !gate.allowed;

    return SketchFrame(
      radius: SketchRadii.b,
      fill: p.surface,
      borderColor: p.line,
      padding: const EdgeInsets.all(SketchSpace.lg),
      shadowOffset: SketchShadowOffset.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (passphraseMode)
            _PassphraseField(
              controller: _passphrase,
              enabled: !busy,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onSubmitted: _unlockWithPassphrase,
            )
          else
            _RecoveryField(controller: _recovery, enabled: !busy),
          if (locked) ...<Widget>[
            const SizedBox(height: SketchSpace.md),
            _ErrorNote(message: gate.hint),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: SketchSpace.md),
            // 文案原样显示：控制器里的措辞明确说了"无法区分密码错与文件损坏"，
            // 这里任何"友好化"改写都会把这句关键信息抹掉。
            _ErrorNote(message: error),
          ],
          if (busy) ...<Widget>[
            const SizedBox(height: SketchSpace.md),
            _BusyNote(elapsed: state.elapsed),
          ],
          const SizedBox(height: SketchSpace.md),
          Align(
            alignment: Alignment.centerLeft,
            child: SketchButton(
              label: passphraseMode
                  ? (busy ? '解锁中…' : '解锁')
                  : (busy ? '解锁中…' : '用恢复码解锁'),
              glyph: SketchGlyph.vault,
              tone: SketchTone.primary,
              onPressed: busy || locked
                  ? null
                  : (passphraseMode ? _unlockWithPassphrase : _unlockWithRecovery),
            ),
          ),
          if (state.hasRecoveryCode) ...<Widget>[
            const SizedBox(height: SketchSpace.md),
            const SketchDivider(),
            const SizedBox(height: SketchSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: SketchButton(
                label: passphraseMode ? '用恢复码解锁' : '返回主密码',
                tone: SketchTone.ghost,
                dense: true,
                onPressed: busy ? null : _toggleMode,
              ),
            ),
          ],
          const SizedBox(height: SketchSpace.sm),
          _biometricAction(policy, nowMs, busy),
        ],
      ),
    );
  }

  Widget _biometricAction(
    UnlockPolicyState policy,
    int nowMs,
    bool busy,
  ) {
    final decision = decideBiometricGate(
      platformAvailable: _biometricAvailable,
      enrolled: _biometricEnrolled,
      policy: policy,
      nowMs: nowMs,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SketchButton(
          label: decision.gate == BiometricGate.notEnrolled
              ? '启用生物识别（先输入主密码解锁）'
              : '用指纹 / 面容解锁',
          glyph: SketchGlyph.vault,
          tone: SketchTone.ghost,
          dense: true,
          onPressed: busy || decision.gate != BiometricGate.available
              ? null
              : _unlockWithBiometric,
        ),
        const SizedBox(height: SketchSpace.xs),
        Text(decision.hint,
            style: TextStyle(fontSize: 10.5, color: context.sketch.muted)),
      ],
    );
  }

  void _unlockWithBiometric() {
    ref
        .read(vaultSessionProvider.notifier)
        .unlockWithBiometric(unlock: _biometric);
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _UnlockMode.passphrase
          ? _UnlockMode.recovery
          : _UnlockMode.passphrase;
    });
  }

  void _unlockWithPassphrase() {
    final value = _passphrase.text;
    if (value.isEmpty) return;
    // 主密码成功解锁后注册生物识别：DEK 只在 _activate 前这一刻可取。
    unawaited(_enrollAfterPassphrase());
    ref.read(vaultSessionProvider.notifier).unlock(value);
  }

  Future<void> _enrollAfterPassphrase() async {
    // 等 unlock 完成后会话里才有 dekForEnrollment；轮询改为一次
    // Future.delayed 仅作 UI 侧等待，不写任何凭据。
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // 真实 Argon2 派生约 2 秒：由会话状态变为 unlocked 后再注册。
    for (var i = 0; i < 40; i++) {
      if (!mounted) return;
      final session = ref.read(vaultSessionProvider);
      if (session.isUnlocked) {
        await ref.read(vaultSessionProvider.notifier).enrollBiometric(
              unlock: _biometric,
              enabled: _biometricAvailable,
            );
        await _probeBiometric();
        return;
      }
      if (session.status == VaultStatus.locked && session.error != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void _unlockWithRecovery() {
    final value = _recovery.text.trim();
    if (value.isEmpty) return;
    ref.read(vaultSessionProvider.notifier).unlockWithRecoveryCode(value);
  }

  void _syncTicker(bool busy) {
    if (busy) {
      _ticker ??= Timer.periodic(_tickInterval, (Timer _) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }
}

// ---------------------------------------------------------------------------
// 小组件
// ---------------------------------------------------------------------------

/// 字标 + 副标题。字标用 display 字体（手写体），并轻微歪一点 ——
/// 正对齐的标题会立刻暴露"这是模板"。
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Transform.rotate(
          angle: SketchTilt.left,
          child: Text(
            '拾遗',
            textAlign: TextAlign.center,
            style: context.typography.display.apply(
              TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                height: 1.05,
                color: p.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: SketchSpace.xs),
        // 手画的底线：用虚线分隔线裁到字标宽度，比实线下划线更像笔迹。
        const SizedBox(width: 46, child: SketchDivider()),
        const SizedBox(height: SketchSpace.md),
        Text(
          '输入主密码，打开你的库',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.6, color: p.muted),
        ),
      ],
    );
  }
}

/// 主密码输入框。显示/隐藏做成按钮而不是 `suffixIcon`：
/// 这套手绘控件里没有眼睛图标，硬塞一个 Material 图标会破坏一致性。
class _PassphraseField extends StatelessWidget {
  const _PassphraseField({
    required this.controller,
    required this.enabled,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return _FieldBox(
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              obscureText: obscure,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (String _) {
                if (enabled) onSubmitted();
              },
              cursorColor: p.red,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: p.ink,
                // 密文点之间留点空，否则看起来像一串方块
                letterSpacing: obscure ? 2 : 0,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '输入主密码',
                hintStyle: TextStyle(fontSize: 13, color: p.muted),
              ),
            ),
          ),
          const SizedBox(width: SketchSpace.sm),
          SketchButton(
            label: obscure ? '显示' : '隐藏',
            tone: SketchTone.ghost,
            dense: true,
            onPressed: enabled ? onToggleObscure : null,
          ),
        ],
      ),
    );
  }
}

/// 恢复码输入框。用等宽体：24 个英文词逐词核对时，
/// 等宽能让人一眼看出"第 7 个词短了一截"。
class _RecoveryField extends StatelessWidget {
  const _RecoveryField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return _FieldBox(
      padding: const EdgeInsets.symmetric(
        horizontal: SketchSpace.md,
        vertical: SketchSpace.sm,
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        minLines: 4,
        maxLines: 4,
        keyboardType: TextInputType.multiline,
        cursorColor: p.red,
        style: context.typography.monoStyle(size: 12.5, height: 1.7, color: p.ink),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: '粘贴或输入 24 个词，空格或换行分隔',
          hintStyle: TextStyle(fontSize: 12, height: 1.7, color: p.muted),
        ),
      ),
    );
  }
}

/// 输入框的外壳：底色取页面纸色，让它在卡片上看起来像"挖出来的一格"。
class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return SketchFrame(
      radius: SketchRadii.c,
      fill: p.bg,
      borderColor: p.lineSoft,
      strokeWidth: SketchStroke.hair,
      shadowOffset: Offset.zero,
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: SketchSpace.md,
            vertical: SketchSpace.xs,
          ),
      child: child,
    );
  }
}

/// 错误提示卡。红只描边不填充 —— 满屏红会让人以为"库已经坏了"，
/// 而这里多数情况只是密码打错。
class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return SketchFrame(
      radius: SketchRadii.cycle(3),
      fill: p.surface,
      borderColor: p.red,
      padding: const EdgeInsets.all(SketchSpace.md),
      tilt: SketchTilt.left,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SketchIcon(
              SketchGlyph.close,
              size: 12,
              color: p.red,
              strokeWidth: SketchStroke.icon,
            ),
          ),
          const SizedBox(width: SketchSpace.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, height: 1.7, color: p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// 派生中的提示。
///
/// **只有不确定的转圈 + 真实秒数，没有进度条**：Argon2id 没有进度回调，
/// 画一个百分比就是拿假数据骗用户 —— 而且这个"进度条"会在 1% 卡两秒，
/// 比没有更让人焦虑。
class _BusyNote extends StatelessWidget {
  const _BusyNote({required this.elapsed});

  final Duration? elapsed;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final seconds = elapsed?.inSeconds ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: p.red),
          ),
        ),
        const SizedBox(width: SketchSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '已用 $seconds 秒',
                style: context.typography.monoStyle(
                  size: 12,
                  weight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '正在派生密钥，通常需要 2 秒左右',
                style: TextStyle(fontSize: 11, height: 1.5, color: p.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 底部说明。放"没有人能帮你找回密码"这句，是这一页唯一需要建立的心理预期：
/// 输错不会被锁死，但忘记也没有后门。
class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      '连续输错不会锁死设备，但没有人能帮你找回密码。',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, height: 1.6, color: context.sketch.muted),
    );
  }
}
