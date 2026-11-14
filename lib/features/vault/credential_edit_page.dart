/// 账号完整编辑页（docs/11 §4）。
///
/// 新增账号确定后直接进入这里：密码 / 用户名 / 网址 / TOTP / 备注 /
/// 自定义字段都可在同一页保存，全部经 [CredentialRepository] 字段级
/// 加密写入。明文只在内存控制器里，不写日志、不进 prompt。
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
import '../../core/widgets/sketch_transitions.dart';
import '../../data/vault/credential_repository_provider.dart';
import '../../data/vault/password_generator.dart';
import '../../data/vault/totp_setup.dart';
import 'credential_fields_page.dart';

class CredentialEditPage extends ConsumerStatefulWidget {
  const CredentialEditPage({
    super.key,
    required this.credentialId,
    required this.title,
  });

  final String credentialId;
  final String title;

  @override
  ConsumerState<CredentialEditPage> createState() => _CredentialEditPageState();
}

class _CredentialEditPageState extends ConsumerState<CredentialEditPage> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _totp = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  bool _obscure = true;
  String _hint = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _totp.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(credentialRepositoryProvider);
    final detail = await repo.detail(widget.credentialId);
    if (detail == null || !mounted) return;
    setState(() {
      _username.text = detail.username ?? '';
      _url.text = detail.url ?? '';
      _notes.text = '';
    });
    _notes.text = await repo.notes(widget.credentialId);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final repo = ref.read(credentialRepositoryProvider);
    final errors = <String>[];
    try {
      await repo.setProfile(
        widget.credentialId,
        username: _username.text.trim(),
        url: _url.text.trim(),
      );
      if (_password.text.isNotEmpty) {
        await repo.setPassword(widget.credentialId, _password.text);
      }
      if (_totp.text.trim().isNotEmpty) {
        final uri = parseOtpauthUri(_totp.text);
        final secret = uri?.secret ?? normalizeTotpSecret(_totp.text);
        if (secret == null) {
          errors.add('TOTP 格式不合法');
        } else {
          await repo.setTotpSecret(widget.credentialId, secret);
        }
      }
      await repo.setNotes(widget.credentialId, _notes.text);
    } on Object catch (e) {
      errors.add('$e');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _hint = errors.isEmpty ? '账号资料已加密保存' : '保存失败：${errors.join('；')}';
    });
  }

  Future<void> _openFields() async {
    await Navigator.of(context).push<void>(sketchPageRoute<void>(
      CredentialFieldsPage(
        credentialId: widget.credentialId,
        title: widget.title,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '编辑账号',
        subtitle: widget.title,
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
                  const _Section('登录信息'),
                  _Field('用户名', _username),
                  const SizedBox(height: SketchSpace.sm),
                  SketchFieldFrame(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _password,
                            obscureText: _obscure,
                            decoration: sketchInputDecoration(context,
                                hintText: '密码（留空表示不修改）'),
                          ),
                        ),
                        SketchIconButton(
                          glyph: _obscure
                              ? SketchGlyph.search
                              : SketchGlyph.close,
                          tooltip: _obscure ? '显示' : '隐藏',
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        SketchButton(
                          label: '生成',
                          dense: true,
                          onPressed: () => setState(() => _password.text =
                              generatePassword(const PasswordPolicy())),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  _Field('网址', _url),
                  const SizedBox(height: SketchSpace.lg),
                  const _Section('两步验证与备注'),
                  _Field('TOTP：otpauth 链接或 Base32 密钥', _totp),
                  const SizedBox(height: SketchSpace.sm),
                  _Field('备注', _notes, maxLines: 3),
                ],
              ),
            ),
            const SizedBox(height: SketchSpace.lg),
            SketchFrame(
              radius: SketchRadii.c,
              fill: p.noteAlt,
              borderColor: p.lineSoft,
              padding: const EdgeInsets.all(SketchSpace.lg),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text('自定义字段（含 secret 项）',
                        style: context.texts.bodySmall),
                  ),
                  SketchButton(
                    label: '编辑字段',
                    dense: true,
                    onPressed: _openFields,
                  ),
                ],
              ),
            ),
            const SizedBox(height: SketchSpace.lg),
            SketchButton(
              label: '保存账号',
              tone: SketchTone.primary,
              dense: true,
              onPressed: _busy ? null : _save,
            ),
            if (_hint.isNotEmpty) ...<Widget>[
              const SizedBox(height: SketchSpace.sm),
              Text(_hint, style: context.texts.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: SketchSpace.sm),
        child: Text(label,
            style: context.texts.titleSmall
                ?.copyWith(color: context.sketch.blue)),
      );
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.controller, {this.maxLines = 1});
  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) => SketchFieldFrame(
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: sketchInputDecoration(context, hintText: label),
        ),
      );
}
