import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../app/session/flutter_clipboard_port.dart';
import '../../data/vault/sensitive_clipboard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/crypto/recovery_code.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';

// ---------------------------------------------------------------------------
// 页面级常量
//
// 全部集中在这里，避免把数字散落进 build 里。凡是 `SketchSpace` /
// `SketchRadii` / `SketchShadowOffset` 已经有的档位，一律用那套 token。
// ---------------------------------------------------------------------------

/// 内容区最大宽度。
///
/// 再宽的话一组 6 个词会横向散开，抄写时视线要来回跳，反而容易漏词；
/// 520 刚好让「序号 + 词」两列贴得足够近。
const double _contentMaxWidth = 520;

/// 小屏左右留白 24。`SketchSpace` 里没有 24 这一档，用 `md * 2` 表达，
/// 而不是直接写一个裸的 24。
const double _sideInset = SketchSpace.md * 2;

/// 超过这个宽度就把 4 组词排成两列。
///
/// 窄屏一列（每组占满一行）比两列更好抄：两列在手机上每组只剩 ~120px，
/// 词会被截断。
const double _twoColumnMinWidth = 420;

/// 主密码最短长度。
const int _minPassphraseLength = 8;

/// 抽查几个词。
const int _checkCount = 3;

/// 测试阶段专用：debug 构建允许显式跳过抽查。
///
/// release 构建里这个常量为 false，编译器会把按钮与确认分支一起裁掉；
/// 生产用户仍然必须完成抄写校验。跳过不是"没抄也安全"：
/// 恢复码只显示这一屏，跳过就等于接受"以后再也拿不回来"的风险。
const bool _allowSkipRecoveryCheck = kDebugMode;

/// 「已复制」文案保留时长。
const Duration _copiedHold = Duration(seconds: 2);

/// 派生期间刷新「已用秒数」的间隔。
const Duration _tickInterval = Duration(seconds: 1);

/// 首次创建 vault 的引导页。
///
/// 这个页面内部有**两个阶段**，靠 [VaultSessionState.recoveryCode] 自动切换：
///
/// 1. `recoveryCode == null` —— 设主密码，点「创建并生成恢复码」；
/// 2. `recoveryCode != null` —— 展示 24 词 + 抽查抄写。
///
/// 测试阶段的 debug 构建额外提供「跳过抽查」入口（带二次确认）；
/// release 构建不渲染该入口，正式用户仍必须完成抄写校验。
///
/// 为什么第二阶段必须自洽：父级 [VaultGate] 在 `recoveryCode != null` 时
/// 也会渲染本页（见 `vault_gate.dart` ①），这时候页面是「重新构建」出来的，
/// 拿不到任何跳转参数。所以阶段判断只能来自 provider，不能来自构造函数。
///
/// ## 创建入口只在 `needsSetup` 下开放
///
/// [VaultSession.createVault] 不检查 `state.hasVault`：在一台已有库的设备上
/// 调用它会覆盖 `meta.enc`，让老数据永久打不开（新密钥开旧 db 必然失败，
/// 状态却退回 `needsSetup`，看起来像"创建失败，请重试"）。所以本页把创建
/// 入口钉死在 `status == needsSetup`：表单可编辑性、按钮可点性、以及
/// [_OnboardingPageState._create] 内部的早退判断，三处都是同一个条件。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  // ── 阶段一 ────────────────────────────────────────────────────────────
  final TextEditingController _passphrase = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  bool _revealPassphrase = false;
  bool _revealConfirmation = false;

  /// 本地校验的错误文案。与 `state.error`（建库失败）分开存：
  /// 前者是用户还没提交就该看到的，后者只能由后端返回。
  String? _localError;

  /// 派生期间的秒表。Argon2id 没有进度回调，只能按秒数告诉用户"还在跑"。
  Timer? _ticker;

  // ── 阶段二 ────────────────────────────────────────────────────────────

  /// 抽查位置（1 起、升序）。
  ///
  /// **只抽一次**：位置只跟 1..24 这几个下标有关，跟词内容无关，
  /// 所以在 initState 阶段抽好即可。放到 build 里抽会每帧变一次，
  /// 用户刚看清「第 7 个词」就被换成「第 19 个词」。
  final List<int> _checkPositions = RecoveryCode.pickPositions(
    _checkCount,
    Random.secure(),
  );

  final List<TextEditingController> _answers = <TextEditingController>[
    for (var i = 0; i < _checkCount; i++) TextEditingController(),
  ];

  bool _checking = false;

  /// 抽查期间是否重新展开词表。
  ///
  /// 默认收起 —— 24 个词还在屏幕上时，"验证抄写"这件事就是自欺欺人。
  /// 但允许主动展开（有人抄到一半发现漏了行），所以不做硬锁定。
  bool _revealWordsWhileChecking = false;

  String? _checkError;

  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _ticker?.cancel();
    _copiedTimer?.cancel();
    _passphrase.dispose();
    _confirmation.dispose();
    for (final controller in _answers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 构建
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;
    final state = ref.watch(vaultSessionProvider);
    final recoveryCode = state.recoveryCode;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: _sideInset,
              vertical: SketchSpace.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _Wordmark(),
                  const SizedBox(height: SketchSpace.xl),
                  if (recoveryCode != null)
                    ..._buildRecoveryStage(recoveryCode)
                  else if (state.status == VaultStatus.needsSetup || state.isBusy)
                    // `isBusy` 也算「阶段一」：那是本页自己发起的 createVault
                    // 正在派生密钥，表单必须留在原地变成 loading，
                    // 否则整页会被换掉、闪一下。
                    ..._buildPassphraseStage(state)
                  else
                    // 兜底：`recoveryCode == null` 但状态不是 needsSetup。
                    // 正常路由下走不到这里（`VaultGate` 只在这两种状态渲染本页），
                    // 但**绝不能**在这一支里渲染创建表单 —— 见 [_buildBlockedStage]。
                    ..._buildBlockedStage(state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 阶段一：设主密码
  // ---------------------------------------------------------------------------

  List<Widget> _buildPassphraseStage(VaultSessionState state) {
    final palette = context.sketch;
    final busy = state.isBusy;

    // **创建入口的唯一闸门**。
    //
    // `VaultSession.createVault()` 不检查 `state.hasVault`：在一台已经有库的
    // 设备上调用它会生成新 DEK / 新盐并**覆盖磁盘上的 meta.enc**，接着拿新
    // 密钥去开旧 vault.db 必然失败，状态退回 `needsSetup`（看起来像"创建失败，
    // 请重试"），但 meta.enc 已经被换掉 —— 重启后老数据永久打不开，恢复码
    // 也救不了。所以这个按钮只在 `needsSetup` 下可点。
    final editable = !busy && state.status == VaultStatus.needsSetup;

    // 本地校验优先：用户改了输入之后，上一次的建库错误已经不代表当前状态了。
    final error = _localError ?? state.error;

    return <Widget>[
      const _SectionLabel('第一步 · 主密码'),
      const SizedBox(height: SketchSpace.sm),
      _SketchField(
        controller: _passphrase,
        label: '主密码',
        hintText: '至少 $_minPassphraseLength 个字符',
        obscure: !_revealPassphrase,
        enabled: editable,
        autofocus: true,
        textInputAction: TextInputAction.next,
        onChanged: _onPassphraseChanged,
        onToggleObscure: editable
            ? () => setState(() => _revealPassphrase = !_revealPassphrase)
            : null,
      ),
      const SizedBox(height: SketchSpace.md),
      _SketchField(
        controller: _confirmation,
        label: '再输一次',
        hintText: '两次要一致',
        obscure: !_revealConfirmation,
        enabled: editable,
        textInputAction: TextInputAction.done,
        onChanged: _onPassphraseChanged,
        onSubmitted: editable ? (_) => _create() : null,
        onToggleObscure: editable
            ? () => setState(() => _revealConfirmation = !_revealConfirmation)
            : null,
      ),
      const SizedBox(height: SketchSpace.sm),
      _StrengthLine(passphrase: _passphrase.text),
      const SizedBox(height: SketchSpace.lg),
      const _NoRecoveryWarning(),
      if (error != null) ...<Widget>[
        const SizedBox(height: SketchSpace.md),
        _ErrorCard(message: error),
      ],
      const SizedBox(height: SketchSpace.lg),
      Align(
        alignment: Alignment.centerLeft,
        child: SketchButton(
          label: '创建并生成恢复码',
          tone: SketchTone.primary,
          onPressed: editable ? _create : null,
        ),
      ),
      if (busy) ...<Widget>[
        const SizedBox(height: SketchSpace.md),
        _DerivingIndicator(elapsed: state.elapsed),
      ],
      const SizedBox(height: SketchSpace.md),
      Text(
        '主密码只在本机参与密钥派生，不上传、不写日志。',
        style: TextStyle(fontSize: 11, height: 1.5, color: palette.muted),
      ),
    ];
  }

  /// `recoveryCode == null` 但状态不是 `needsSetup` 时的兜底页。
  ///
  /// 这里**故意不提供任何创建 / 重建入口**：在这种状态下再建一次库，
  /// 就是把磁盘上仅存的 `meta.enc` 覆盖掉（见 [_buildPassphraseStage] 的注释）。
  /// `failed` 的正式出路在 `VaultGate._FatalErrorPage`，这一支只是防御性兜底，
  /// 保证即使路由改了也不会从本页触发覆盖。
  List<Widget> _buildBlockedStage(VaultSessionState state) {
    final palette = context.sketch;
    final fatal = state.status == VaultStatus.failed;

    return <Widget>[
      SketchFrame(
        radius: SketchRadii.cycle(1),
        fill: palette.surface,
        borderColor: palette.red,
        shadowOffset: SketchShadowOffset.card,
        tilt: SketchTilt.right,
        padding: const EdgeInsets.all(SketchSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              fatal ? '这个库打不开了' : '这台设备上已经有库',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.red,
              ),
            ),
            const SizedBox(height: SketchSpace.xs),
            Text(
              fatal
                  ? '本机的库元数据读取失败，创建入口已关闭。不要删除任何文件，'
                      '把错误信息交给开发者。'
                  : '创建入口已关闭。请用主密码打开它，不要在这里重新创建 —— '
                      '那会覆盖掉现有的库。',
              style: TextStyle(fontSize: 11.5, height: 1.6, color: palette.muted),
            ),
          ],
        ),
      ),
    ];
  }

  void _onPassphraseChanged(String _) {
    setState(() {
      if (_localError != null) _localError = null;
    });
  }

  String? _validatePassphrase() {
    if (_passphrase.text.length < _minPassphraseLength) {
      return '主密码至少 $_minPassphraseLength 个字符';
    }
    if (_passphrase.text != _confirmation.text) {
      return '两次输入不一致';
    }
    return null;
  }

  Future<void> _create() async {
    final state = ref.read(vaultSessionProvider);

    // 最后一道闸门（不依赖按钮是否可点）。
    //
    // `createVault()` 自己**不检查** `hasVault`，在已有库的设备上调用会覆盖
    // `meta.enc` 并让老数据永久打不开。所以除了「按钮只在 needsSetup 下可点」
    // 之外，这里再按状态挡一次：任何非 needsSetup 的状态都不发起创建。
    // 唯一的例外是 `unlocking` —— 那是本页上一次提交还没返回，交给下面的
    // `isBusy` 早退处理。
    if (state.isBusy || state.status != VaultStatus.needsSetup) return;

    final problem = _validatePassphrase();
    if (problem != null) {
      setState(() => _localError = problem);
      return;
    }

    setState(() => _localError = null);
    _startTicker();
    try {
      await ref.read(vaultSessionProvider.notifier).createVault(_passphrase.text);
    } finally {
      _stopTicker();
    }

    if (!mounted) return;
    // 建库成功后密码就没用了：立刻从输入框（进而从内存里的 TextEditingValue）
    // 清掉，别让它停在内存里等着被 dump。
    if (ref.read(vaultSessionProvider).recoveryCode != null) {
      _passphrase.clear();
      _confirmation.clear();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (Timer _) {
      // 每秒重建一次，只为了让 `state.elapsed` 重新读一遍系统时间。
      if (mounted) setState(() {});
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  // ---------------------------------------------------------------------------
  // 阶段二：展示并确认 24 词
  // ---------------------------------------------------------------------------

  List<Widget> _buildRecoveryStage(RecoveryCode code) {
    final palette = context.sketch;

    return <Widget>[
      const _SectionLabel('第二步 · 恢复码'),
      const SizedBox(height: SketchSpace.sm),
      Text('把这 24 个词抄下来', style: context.texts.titleLarge),
      const SizedBox(height: SketchSpace.xs),
      Text(
        '这是唯一能救回数据的凭证。我们不会保存它，也不会再显示第二次。',
        style: context.texts.bodySmall,
      ),
      const SizedBox(height: SketchSpace.lg),
      if (!_checking || _revealWordsWhileChecking) ...<Widget>[
        _CodeGrid(code: code),
        const SizedBox(height: SketchSpace.lg),
      ],
      if (_checking)
        _CheckPanel(
          positions: _checkPositions,
          controllers: _answers,
          error: _checkError,
          revealing: _revealWordsWhileChecking,
          onVerify: () => _verify(code),
          onToggleReveal: () =>
              setState(() => _revealWordsWhileChecking = !_revealWordsWhileChecking),
          onSkip: _allowSkipRecoveryCheck ? () => _skipCheck(code) : null,
        )
      else
        Wrap(
          spacing: SketchSpace.sm,
          runSpacing: SketchSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SketchButton(
              label: _copied ? '已复制' : '复制全部',
              glyph: SketchGlyph.records,
              tone: SketchTone.plain,
              onPressed: () => _copy(code),
            ),
            SketchButton(
              label: '我已抄好，开始验证',
              tone: SketchTone.primary,
              onPressed: _beginCheck,
            ),
            if (_allowSkipRecoveryCheck)
              SketchButton(
                label: '测试阶段：跳过抽查',
                tone: SketchTone.ghost,
                dense: true,
                onPressed: () => _skipCheck(code),
              ),
          ],
        ),
      const SizedBox(height: SketchSpace.md),
      Text(
        '不要截图，不要存云相册。纸和密码管理器都行。',
        style: TextStyle(fontSize: 11, height: 1.5, color: palette.muted),
      ),
    ];
  }

  /// 复制的是**纯空格分隔的 24 个词**，不带序号。
  ///
  /// `RecoveryCode.parse` 虽然能吃掉 `1. abandon` 这种序号前缀，但纯词最稳 ——
  /// 用户可能把它粘进任何地方（密码管理器备注、文本文件），
  /// 少一层格式就少一个出错机会。
  final SensitiveClipboard _sensitiveClipboard = SensitiveClipboard(
    port: const FlutterClipboardPort(),
  );

  Future<void> _copy(RecoveryCode code) async {
    // 恢复码是库的备份钥匙：30 秒后自动清剪贴板，但只清仍是本次写入的内容。
    await _sensitiveClipboard.copy(code.words.join(' '));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(_copiedHold, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _beginCheck() {
    setState(() {
      _checking = true;
      _revealWordsWhileChecking = false;
      _checkError = null;
    });
  }

  /// 测试阶段跳过抽查：必须再确认一次「恢复码不再显示」。
  ///
  /// 走的是和正常校验成功完全相同的 [VaultSession.acknowledgeRecoveryCode]；
  /// 不改写状态机、不绕过闸门，也不会把恢复码留到下一屏。
  Future<void> _skipCheck(RecoveryCode code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('跳过恢复码抽查？'),
        content: Text(
          '仅用于测试阶段。恢复码只显示这一屏，跳过并继续后'
          '将无法再次查看这 ${code.words.length} 个词；'
          '忘记主密码时数据会永久无法解密。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续抽查'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认跳过'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(vaultSessionProvider.notifier).acknowledgeRecoveryCode();
  }

  /// 逐个校验抽查的词。
  ///
  /// 错了**只提示不锁定**：这是用户第一次接触恢复码，拦着他重试只会让他
  /// 更慌。错误信息必须点明是第几个词 —— 他手上有一张纸，需要知道看哪一行。
  void _verify(RecoveryCode code) {
    for (var i = 0; i < _checkPositions.length; i++) {
      final position = _checkPositions[i];
      if (!code.matches(position, _answers[i].text)) {
        setState(() => _checkError = '第 $position 个词不对，请对着纸再核对一次');
        return;
      }
    }

    setState(() => _checkError = null);
    ref.read(vaultSessionProvider.notifier).acknowledgeRecoveryCode();
  }
}

// ---------------------------------------------------------------------------
// 阶段一的小组件
// ---------------------------------------------------------------------------

/// 顶部字标。
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 用 Align 让便签条按内容收缩，否则在 stretch 的 Column 里会被拉满整行，
        // 倾斜时两端溢出容器。
        Align(
          alignment: Alignment.centerLeft,
          child: SketchFrame(
            radius: SketchRadii.pill,
            fill: palette.note,
            borderColor: palette.lineSoft,
            shadowOffset: SketchShadowOffset.card,
            tilt: SketchTilt.left,
            padding: const EdgeInsets.symmetric(
              horizontal: SketchSpace.md,
              vertical: SketchSpace.xs,
            ),
            child: Text('拾遗', style: context.texts.displaySmall),
          ),
        ),
        const SizedBox(height: SketchSpace.md),
        Text('第一次使用，先建一个属于你的库', style: context.texts.bodySmall),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.typography.monoStyle(
        size: 10.5,
        weight: FontWeight.w700,
        color: context.sketch.muted,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// 手绘风输入框。
///
/// 不用 `TextField` 自带的 `OutlineInputBorder`：它只有实线，而全站输入框
/// 是 1.5px 虚线 + 聚焦时变便签黄（docs/10 §7.4）。所以边框交给
/// [SketchFrame] 画，`TextField` 只负责文字。
class _SketchField extends StatefulWidget {
  const _SketchField({
    required this.controller,
    required this.label,
    this.hintText,
    this.obscure = false,
    this.enabled = true,
    this.mono = false,
    this.autofocus = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onToggleObscure,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool obscure;
  final bool enabled;

  /// 恢复码的词是「要逐字核对的数据」，走等宽体；主密码走正文字体。
  final bool mono;

  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// 非空时在右侧显示「显示 / 隐藏」切换。
  final VoidCallback? onToggleObscure;

  @override
  State<_SketchField> createState() => _SketchFieldState();
}

class _SketchFieldState extends State<_SketchField> {
  final FocusNode _node = FocusNode();

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChanged);
    _node.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;
    final focused = _node.hasFocus && widget.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.label,
          style: context.typography.monoStyle(
            size: 10,
            weight: FontWeight.w700,
            color: palette.muted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: SketchSpace.xs),
        SketchFrame(
          radius: SketchRadii.pill,
          fill: focused ? palette.note : palette.surface,
          borderColor: focused ? palette.line : palette.lineSoft,
          shadowOffset: SketchShadowOffset.none,
          strokeWidth: SketchStroke.hair,
          padding: const EdgeInsets.symmetric(
            horizontal: SketchSpace.md,
            vertical: SketchSpace.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _node,
                  enabled: widget.enabled,
                  obscureText: widget.obscure,
                  autofocus: widget.autofocus,
                  textInputAction: widget.textInputAction,
                  // 密码框不让输入法记词、不做联想。
                  autocorrect: !widget.obscure,
                  enableSuggestions: !widget.obscure,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: palette.red,
                  cursorWidth: SketchStroke.hair,
                  style: widget.mono
                      ? context.typography.monoStyle(
                          size: 14,
                          color: palette.ink,
                          height: 1.5,
                          letterSpacing: 0.6,
                        )
                      : TextStyle(fontSize: 14, height: 1.5, color: palette.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.hintText,
                    hintStyle: TextStyle(fontSize: 12.5, color: palette.muted),
                  ),
                ),
              ),
              if (widget.onToggleObscure != null) ...<Widget>[
                const SizedBox(width: SketchSpace.xs),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onToggleObscure,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SketchSpace.xs,
                      vertical: SketchSpace.xs,
                    ),
                    child: Text(
                      widget.obscure ? '显示' : '隐藏',
                      style: context.typography.monoStyle(
                        size: 10.5,
                        weight: FontWeight.w600,
                        color: widget.enabled ? palette.blue : palette.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 强度提示的档位。刻意只有三档 —— 五档、进度条、百分比都是自我安慰，
/// 用户真正需要知道的只有「够不够」和「还能加什么」。
enum _Strength {
  weak('偏弱', SketchTone.primary),
  fair('一般', SketchTone.ghost),
  good('较好', SketchTone.blue);

  const _Strength(this.label, this.tone);

  final String label;
  final SketchTone tone;
}

_Strength _strengthOf(String value) {
  var score = 0;
  if (value.length >= _minPassphraseLength) score++;
  if (value.length >= 12) score++;
  if (value.length >= 16) score++;
  if (RegExp(r'\d').hasMatch(value)) score++;
  if (RegExp(r'[a-z]').hasMatch(value) && RegExp(r'[A-Z]').hasMatch(value)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
  // 非 ASCII（中文、日文、Emoji）单个字符的信息量远高于一个英文字母，
  // 不额外计分会让「一句中文短语」被误判成偏弱。
  if (RegExp(r'[^\x00-\x7F]').hasMatch(value)) score++;

  if (score <= 2) return _Strength.weak;
  if (score <= 4) return _Strength.fair;
  return _Strength.good;
}

/// 告诉用户「还差什么」，而不是只给一个笼统的评级。
String _strengthHint(String value) {
  final missing = <String>[];
  if (value.length < 12) missing.add('再长一点');
  if (!RegExp(r'\d').hasMatch(value)) missing.add('加个数字');
  // 纯小写才提示大小写混用；中文密码没有大小写之分，不该被说成缺点。
  if (RegExp(r'[a-z]').hasMatch(value) && !RegExp(r'[A-Z]').hasMatch(value)) {
    missing.add('大小写混用');
  }
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) missing.add('加个符号');

  if (missing.isEmpty) return '长度和构成都到位了。记住它比什么都重要。';
  return '还可以：${missing.join('、')}。';
}

class _StrengthLine extends StatelessWidget {
  const _StrengthLine({required this.passphrase});

  final String passphrase;

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;

    if (passphrase.isEmpty) {
      return Text(
        '长短比花样更重要。至少 $_minPassphraseLength 个字符。',
        style: TextStyle(fontSize: 11, height: 1.5, color: palette.muted),
      );
    }

    final level = _strengthOf(passphrase);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SketchTag(level.label, tone: level.tone, dense: true),
        const SizedBox(width: SketchSpace.sm),
        Expanded(
          child: Text(
            _strengthHint(passphrase),
            style: TextStyle(fontSize: 11, height: 1.5, color: palette.muted),
          ),
        ),
      ],
    );
  }
}

/// 全流程最不能省的一段文案。
///
/// 用红框而不是红底：红底会让整页看起来像报错，而这里不是报错，
/// 是一个**必须被读到**的约定。
class _NoRecoveryWarning extends StatelessWidget {
  const _NoRecoveryWarning();

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;

    return SketchFrame(
      radius: SketchRadii.cycle(1),
      fill: palette.surface,
      borderColor: palette.red,
      shadowOffset: SketchShadowOffset.card,
      tilt: SketchTilt.right,
      padding: const EdgeInsets.all(SketchSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SketchIcon(SketchGlyph.vault, size: 17, color: palette.red),
          ),
          const SizedBox(width: SketchSpace.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12.5, height: 1.65, color: palette.red),
                children: <InlineSpan>[
                  const TextSpan(
                    text: '没有恢复码，忘记主密码 = 数据永久无法解密。',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '我们帮不了你。'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 建库失败提示。原样显示 `state.error`，不做任何包装或改写 ——
/// 错误文案里可能带路径、PRAGMA 名，需要用户逐字复制给开发者。
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;

    return SketchFrame(
      radius: SketchRadii.cycle(3),
      fill: palette.surface,
      borderColor: palette.red,
      shadowOffset: SketchShadowOffset.none,
      strokeWidth: SketchStroke.hair,
      padding: const EdgeInsets.all(SketchSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '没能创建这个库',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: palette.red,
            ),
          ),
          const SizedBox(height: SketchSpace.xs),
          Text(
            message,
            style: context.typography.monoStyle(
              size: 11.5,
              height: 1.6,
              color: palette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// 派生中的状态。
///
/// 只有转圈 + 已用秒数，**没有百分比** —— Argon2id 不提供进度回调，
/// 任何"37%"都是编的，而编出来的进度一旦卡住，用户会以为程序死了。
class _DerivingIndicator extends StatelessWidget {
  const _DerivingIndicator({required this.elapsed});

  final Duration? elapsed;

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;
    final seconds = elapsed?.inSeconds ?? 0;

    return Row(
      children: <Widget>[
        SizedBox(
          width: SketchSpace.md,
          height: SketchSpace.md,
          child: CircularProgressIndicator(
            strokeWidth: SketchStroke.hair,
            color: palette.red,
          ),
        ),
        const SizedBox(width: SketchSpace.sm),
        Expanded(
          child: Text(
            '正在派生密钥，通常需要 2~3 秒。已用 $seconds 秒。',
            style: TextStyle(fontSize: 11.5, height: 1.5, color: palette.muted),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 阶段二的小组件
// ---------------------------------------------------------------------------

/// 24 个词：4 组 × 6 个，每个词前面带**全局序号**。
///
/// 序号不从每组重新开始，是刻意的：用户抄错行时会说"第 13 个词"，
/// 而不是"第 3 组第 1 个"，全局序号让「纸上的位置」和「页面上的位置」
/// 一一对应。
class _CodeGrid extends StatelessWidget {
  const _CodeGrid({required this.code});

  final RecoveryCode code;

  @override
  Widget build(BuildContext context) {
    // 分组规则由 `RecoveryCode.grouped` 决定（每 6 个词一组），
    // 这里不再自己切分，避免两处规则漂移。
    final groups = code.grouped;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final columns = constraints.maxWidth >= _twoColumnMinWidth ? 2 : 1;
        final width =
            (constraints.maxWidth - SketchSpace.md * (columns - 1)) / columns;

        var next = 1;
        final cards = <Widget>[];
        for (var g = 0; g < groups.length; g++) {
          final words = groups[g].split(' ');
          cards.add(
            SizedBox(
              width: width,
              child: _WordGroupCard(index: g, start: next, words: words),
            ),
          );
          next += words.length;
        }

        return Wrap(
          spacing: SketchSpace.md,
          runSpacing: SketchSpace.md,
          children: cards,
        );
      },
    );
  }
}

class _WordGroupCard extends StatelessWidget {
  const _WordGroupCard({
    required this.index,
    required this.start,
    required this.words,
  });

  /// 组序号，用来轮换圆角与倾斜方向。
  final int index;

  /// 本组第一个词的全局序号（1 起）。
  final int start;

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;

    return SketchFrame(
      radius: SketchRadii.cycle(index),
      fill: palette.surface,
      borderColor: palette.lineSoft,
      shadowOffset: SketchShadowOffset.card,
      tilt: index.isEven ? SketchTilt.left : SketchTilt.right,
      padding: const EdgeInsets.symmetric(
        horizontal: SketchSpace.md,
        vertical: SketchSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < words.length; i++)
            _WordRow(position: start + i, word: words[i]),
        ],
      ),
    );
  }
}

/// 一行 = 一个词。
///
/// 一个词独占一行（而不是把 6 个词挤在一行里用空格分开）：抄写时眼睛要
/// 在「屏幕」和「纸」之间来回跳，行数固定、每行只有一个词，才不会跳错行。
class _WordRow extends StatelessWidget {
  const _WordRow({required this.position, required this.word});

  final int position;
  final String word;

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SketchSpace.xs / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          // 固定宽度的序号列：4 组卡片的词首能在竖直方向对齐。
          SizedBox(
            width: SketchSpace.xl,
            child: Text(
              '$position',
              textAlign: TextAlign.right,
              style: context.typography.monoStyle(
                size: 10.5,
                color: palette.muted,
              ),
            ),
          ),
          const SizedBox(width: SketchSpace.sm),
          Expanded(
            child: Text(
              word,
              style: context.typography.monoStyle(
                size: 14,
                weight: FontWeight.w600,
                color: palette.ink,
                height: 1.4,
                // 等宽体自带对齐，再加一点字距让 l / 1 / I 这类字符更好分辨。
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 抽查面板：替换掉按钮区。
class _CheckPanel extends StatelessWidget {
  const _CheckPanel({
    required this.positions,
    required this.controllers,
    required this.error,
    required this.revealing,
    required this.onVerify,
    required this.onToggleReveal,
    this.onSkip,
  });

  final List<int> positions;
  final List<TextEditingController> controllers;
  final String? error;
  final bool revealing;
  final VoidCallback onVerify;
  final VoidCallback onToggleReveal;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;
    final message = error;

    return SketchFrame(
      radius: SketchRadii.cycle(2),
      fill: palette.noteAlt,
      borderColor: palette.lineSoft,
      shadowOffset: SketchShadowOffset.card,
      tilt: SketchTilt.left,
      padding: const EdgeInsets.all(SketchSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('抽 3 个词对一下', style: context.texts.titleMedium),
          const SizedBox(height: SketchSpace.xs),
          Text(
            '照着纸填。填错可以重来，不限次数。',
            style: TextStyle(fontSize: 11, height: 1.5, color: palette.muted),
          ),
          const SizedBox(height: SketchSpace.md),
          for (var i = 0; i < positions.length; i++) ...<Widget>[
            _SketchField(
              controller: controllers[i],
              label: '第 ${positions[i]} 个词',
              hintText: '按纸上抄的填',
              mono: true,
              autofocus: i == 0,
              textInputAction: i == positions.length - 1
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmitted: i == positions.length - 1 ? (_) => onVerify() : null,
            ),
            if (i != positions.length - 1) const SizedBox(height: SketchSpace.sm),
          ],
          if (message != null) ...<Widget>[
            const SizedBox(height: SketchSpace.sm),
            Text(
              message,
              style: TextStyle(fontSize: 11.5, height: 1.5, color: palette.red),
            ),
          ],
          const SizedBox(height: SketchSpace.md),
          Wrap(
            spacing: SketchSpace.sm,
            runSpacing: SketchSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SketchButton(
                label: '确认',
                tone: SketchTone.primary,
                onPressed: onVerify,
              ),
              SketchButton(
                label: revealing ? '收起词表' : '再看一遍',
                tone: SketchTone.ghost,
                dense: true,
                onPressed: onToggleReveal,
              ),
              if (onSkip != null)
                SketchButton(
                  label: '测试阶段：跳过抽查',
                  tone: SketchTone.ghost,
                  dense: true,
                  onPressed: onSkip,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
