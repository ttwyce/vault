/// 同步设置页（docs/10 第 12 屏）。
///
/// 只做表单校验与状态说明：**不持久化账号/密码、不发起 WebDAV 请求、
/// 不实例化 VaultSyncRuntime**。M0 A5 未确认前明确禁止启动同步。
library;

import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/sync/sync_settings_plan.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_field.dart';
import '../../core/widgets/sketch_frame.dart';

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _user = TextEditingController();
  final TextEditingController _password = TextEditingController();
  SyncSettingsPlan? _plan;

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  void _check() {
    setState(() {
      _plan = planSyncSettings(
        SyncSettingsDraft(
          rootUrl: _url.text,
          username: _user.text,
          password: _password.text,
        ),
        // 硬门槛：A5 未在真实坚果云 / Nextcloud 上确认。
        a5Confirmed: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final plan = _plan;
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '同步设置',
        subtitle: 'WebDAV 配置校验（不存凭据、不启动同步）',
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
                  SketchFieldFrame(
                    child: TextField(
                      controller: _url,
                      decoration: sketchInputDecoration(
                        context,
                        labelText: 'WebDAV 地址（https）',
                      ),
                    ),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  SketchFieldFrame(
                    child: TextField(
                      controller: _user,
                      decoration: sketchInputDecoration(context,
                          labelText: '账号'),
                    ),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  SketchFieldFrame(
                    child: TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: sketchInputDecoration(context,
                          labelText: '应用密码'),
                    ),
                  ),
                  const SizedBox(height: SketchSpace.md),
                  SketchButton(
                    label: '校验配置',
                    tone: SketchTone.primary,
                    dense: true,
                    onPressed: _check,
                  ),
                ],
              ),
            ),
            if (plan != null) ...<Widget>[
              const SizedBox(height: SketchSpace.lg),
              SketchFrame(
                radius: SketchRadii.c,
                fill: plan.canProbe ? p.noteAlt : p.note,
                borderColor: p.lineSoft,
                padding: const EdgeInsets.all(SketchSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      plan.gate.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    if (plan.normalizedRootUrl.isNotEmpty)
                      Text(plan.normalizedRootUrl,
                          style: TextStyle(fontSize: 11, color: p.muted)),
                    const SizedBox(height: SketchSpace.sm),
                    for (final error in plan.errors)
                      Text('· $error',
                          style: TextStyle(fontSize: 11, color: p.red)),
                    Text(plan.hint,
                        style: TextStyle(fontSize: 11.5, color: p.ink)),
                    const SizedBox(height: SketchSpace.xs),
                    Text(
                      '账号密码只在本页内存中用于校验，不会写入本地库或日志；'
                      '真实凭据存储需 flutter_secure_storage（平台层）。',
                      style: TextStyle(fontSize: 10.5, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
