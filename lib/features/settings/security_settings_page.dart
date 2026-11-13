/// 安全设置：改主密码 / 重置恢复码（docs/18 §9、D95）。
///
/// 两个动作都要求二次确认并说明「DEK 不变 / 旧码立即失效」；
/// 重置恢复码成功后由 VaultGate 依据 recoveryCode 自动跳回引导页展示新码。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_field.dart';
import '../../core/widgets/sketch_frame.dart';

class SecuritySettingsPage extends ConsumerStatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  ConsumerState<SecuritySettingsPage> createState() =>
      _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _recoveryPassphrase = TextEditingController();
  bool _changeConfirmed = false;
  bool _resetConfirmed = false;
  String _hint = '';

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _recoveryPassphrase.dispose();
    super.dispose();
  }

  void _change() {
    if (!_changeConfirmed) {
      setState(() => _hint = '请先勾选二次确认');
      return;
    }
    if (_next.text.length < 8) {
      setState(() => _hint = '新主密码至少 8 个字符');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _hint = '两次输入的新主密码不一致');
      return;
    }
    ref.read(vaultSessionProvider.notifier).changePassphrase(
          currentPassphrase: _current.text,
          newPassphrase: _next.text,
        );
    _current.clear();
    _next.clear();
    _confirm.clear();
    setState(() => _hint = '已提交：正在重新包裹 DEK，数据库密钥不变');
  }

  void _reset() {
    if (!_resetConfirmed) {
      setState(() => _hint = '请先勾选「旧恢复码立即失效」');
      return;
    }
    ref.read(vaultSessionProvider.notifier).regenerateRecoveryCode(
          _recoveryPassphrase.text,
        );
    _recoveryPassphrase.clear();
    setState(() => _hint = '已提交：新恢复码将在确认页展示一次');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '安全设置',
        subtitle: '改主密码 / 重置恢复码 · DEK 不变',
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
                  Text('改主密码', style: context.texts.titleSmall),
                  const SizedBox(height: SketchSpace.sm),
                  _Field('当前主密码', _current, obscureText: true),
                  const SizedBox(height: SketchSpace.sm),
                  _Field('新主密码', _next, obscureText: true),
                  const SizedBox(height: SketchSpace.sm),
                  _Field('再输一次新密码', _confirm, obscureText: true),
                  const SizedBox(height: SketchSpace.sm),
                  _ConfirmTile(
                    label: '我已确认：改密码不会重新加密数据，但忘掉新密码仍会永久丢数据',
                    value: _changeConfirmed,
                    onChanged: (bool v) =>
                        setState(() => _changeConfirmed = v),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  SketchButton(
                    label: '更新主密码',
                    tone: SketchTone.primary,
                    dense: true,
                    onPressed: _change,
                  ),
                ],
              ),
            ),
            const SizedBox(height: SketchSpace.lg),
            SketchFrame(
              radius: SketchRadii.c,
              fill: p.noteAlt,
              borderColor: p.lineSoft,
              padding: const EdgeInsets.all(SketchSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('重置恢复码', style: context.texts.titleSmall),
                  const SizedBox(height: SketchSpace.sm),
                  Text(
                    '需要当前主密码。生成后旧码立即失效，新码只展示一次。',
                    style: context.texts.bodySmall,
                  ),
                  const SizedBox(height: SketchSpace.md),
                  _Field('当前主密码', _recoveryPassphrase, obscureText: true),
                  const SizedBox(height: SketchSpace.sm),
                  _ConfirmTile(
                    label: '我已确认：旧恢复码立即失效，新码必须重新抄写',
                    value: _resetConfirmed,
                    onChanged: (bool v) =>
                        setState(() => _resetConfirmed = v),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  SketchButton(
                    label: '生成新恢复码',
                    tone: SketchTone.primary,
                    dense: true,
                    onPressed: _reset,
                  ),
                ],
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

class _Field extends StatelessWidget {
  const _Field(this.label, this.controller, {required this.obscureText});

  final String label;
  final TextEditingController controller;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => SketchFieldFrame(
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: sketchInputDecoration(context, labelText: label),
        ),
      );
}

class _ConfirmTile extends StatelessWidget {
  const _ConfirmTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!value),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SketchTag(value ? '已确认' : '未确认',
                tone: value ? SketchTone.primary : SketchTone.ghost,
                dense: true),
            const SizedBox(width: SketchSpace.sm),
            Expanded(child: Text(label, style: context.texts.bodySmall)),
          ],
        ),
      );
}
