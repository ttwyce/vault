/// TOTP 绑定页（docs/09 §8）。
///
/// 相机扫码需平台通道，本页先支持粘贴 otpauth:// 链接（等价于扫码结果）
/// 与手动 Base32 密钥；写入走 CredentialRepository.setTotpSecret，
/// 经 K_item 字段级加密，并同步 kind=6 meta 的 has_totp 标记。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_field.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/vault/credential_repository_provider.dart';
import '../../data/vault/totp.dart';
import '../../data/vault/totp_setup.dart';

class TotpSetupPage extends ConsumerStatefulWidget {
  const TotpSetupPage({
    super.key,
    required this.credentialId,
    required this.title,
  });

  final String credentialId;
  final String title;

  @override
  ConsumerState<TotpSetupPage> createState() => _TotpSetupPageState();
}

class _TotpSetupPageState extends ConsumerState<TotpSetupPage> {
  final TextEditingController _input = TextEditingController();
  String _hint = '';
  String? _previewCode;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  ({String secret, String label})? _parse() {
    final raw = _input.text.trim();
    final uri = parseOtpauthUri(raw);
    if (uri != null) return (secret: uri.secret, label: uri.label);
    final secret = normalizeTotpSecret(raw);
    if (secret == null) return null;
    return (secret: secret, label: widget.title);
  }

  void _preview() {
    final parsed = _parse();
    if (parsed == null) {
      setState(() => _hint = '请输入 otpauth:// 链接或合法 Base32 密钥');
      return;
    }
    try {
      final code = generateTotp(
        base32Secret: parsed.secret,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      setState(() {
        _previewCode = code;
        _hint = '已识别「${parsed.label}」，预览验证码 $code';
      });
    } on Object {
      setState(() => _hint = '密钥无法生成验证码，请重新核对');
    }
  }

  Future<void> _save() async {
    final parsed = _parse();
    if (parsed == null) {
      setState(() => _hint = '请输入 otpauth:// 链接或合法 Base32 密钥');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(credentialRepositoryProvider)
          .setTotpSecret(widget.credentialId, parsed.secret);
      if (!mounted) return;
      setState(() => _hint = 'TOTP 已加密保存，30 秒轮换');
    } on Object catch (error) {
      if (mounted) setState(() => _hint = '保存失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '绑定 TOTP',
        subtitle: '${widget.title} · 支持 otpauth 链接 / Base32 密钥',
        showSettings: false,
        leading: SketchIconButton(
          glyph: SketchGlyph.close,
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        child: ListView(
          padding: const EdgeInsets.all(SketchSpace.lg),
          children: <Widget>[
            SketchFrame(
              radius: SketchRadii.b,
              fill: p.surface,
              borderColor: p.line,
              padding: const EdgeInsets.all(SketchSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    '粘贴验证器扫码得到的内容',
                    style: context.texts.bodySmall,
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  SketchFieldFrame(
                    child: TextField(
                      controller: _input,
                      maxLines: 3,
                      decoration: sketchInputDecoration(
                        context,
                        hintText: 'otpauth://totp/... 或 JBSWY3DPEHPK3PXP',
                      ),
                    ),
                  ),
                  const SizedBox(height: SketchSpace.md),
                  Wrap(
                    spacing: SketchSpace.sm,
                    runSpacing: SketchSpace.sm,
                    children: <Widget>[
                      SketchButton(
                        label: '校验并预览',
                        dense: true,
                        onPressed: _busy ? null : _preview,
                      ),
                      SketchButton(
                        label: '保存密钥',
                        tone: SketchTone.primary,
                        dense: true,
                        onPressed: _busy ? null : _save,
                      ),
                    ],
                  ),
                  if (_previewCode != null) ...<Widget>[
                    const SizedBox(height: SketchSpace.md),
                    Text('当前验证码 $_previewCode',
                        style: context.texts.titleSmall),
                  ],
                ],
              ),
            ),
            const SizedBox(height: SketchSpace.lg),
            SketchFrame(
              radius: SketchRadii.c,
              fill: p.noteAlt,
              borderColor: p.lineSoft,
              padding: const EdgeInsets.all(SketchSpace.lg),
              child: Text(
                '相机扫码需要在 Android / iOS 平台层接入图像识别；'
                '本页已支持粘贴扫码结果，密钥经字段级加密后写入本地库，'
                '验证码只在内存生成，不写日志。',
                style: context.texts.bodySmall,
              ),
            ),
            if (_hint.isNotEmpty) ...<Widget>[
              const SizedBox(height: SketchSpace.md),
              Text(_hint, style: context.texts.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
