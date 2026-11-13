/// 密码条目的自定义字段编辑（docs/11 §4.4 / docs/09 §8）。
///
/// 真实读写 `CredentialRepository.customFields / setCustomFields`：
/// 整组字段以 K_item 字段级加密后落库；secret 字段默认掩码，
/// 可切换显示但绝不写日志。支持套用字段模板、增删、上移/下移。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/identity/uuid_v7.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_field.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/vault/credential_models.dart';
import '../../data/vault/credential_repository.dart';
import '../../data/vault/credential_repository_provider.dart';
import '../../data/vault/credential_template.dart';

class CredentialFieldsPage extends ConsumerStatefulWidget {
  const CredentialFieldsPage({
    super.key,
    required this.credentialId,
    required this.title,
  });

  final String credentialId;
  final String title;

  @override
  ConsumerState<CredentialFieldsPage> createState() =>
      _CredentialFieldsPageState();
}

class _CredentialFieldsPageState extends ConsumerState<CredentialFieldsPage> {
  CustomFields _fields = const CustomFields(<CredentialField>[]);
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Set<String> _revealed = <String>{};
  String _hint = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  CredentialRepository get _repo =>
      ref.read(credentialRepositoryProvider);

  Future<void> _load() async {
    final loaded = await _repo.customFields(widget.credentialId);
    if (!mounted) return;
    setState(() {
      _fields = loaded;
      _syncControllers();
      _hint = '共 ${_fields.fields.length} 个字段';
    });
  }

  void _syncControllers() {
    final alive = <String>{};
    for (final field in _fields.fields) {
      alive.add(field.id);
      final controller = _controllers.putIfAbsent(
        field.id,
        () => TextEditingController(text: field.value),
      );
      if (controller.text != field.value) controller.text = field.value;
    }
    for (final entry in _controllers.entries.toList()) {
      if (!alive.contains(entry.key)) {
        entry.value.dispose();
        _controllers.remove(entry.key);
        _revealed.remove(entry.key);
      }
    }
  }

  void _applyTemplate(FieldTemplate template) {
    final instant = template.instantiate();
    final merged = <CredentialField>[..._fields.fields];
    var sort = merged.length;
    for (final item in instant.fields) {
      if (merged.any((CredentialField f) => f.label == item.label)) continue;
      if (merged.length >= CustomFields.maxFields) break;
      merged.add(item.copyWith(
        id: '${item.id}-${UuidV7().next()}',
        sort: sort++,
      ));
    }
    setState(() {
      _fields = CustomFields(merged);
      _syncControllers();
      _hint = '已套用「${template.label}」模板，保存后生效';
    });
  }

  void _addField() {
    if (_fields.fields.length >= CustomFields.maxFields) {
      setState(() => _hint = '自定义字段最多 20 个');
      return;
    }
    final id = 'field-${UuidV7().next()}';
    setState(() {
      _fields = _fields.add(CredentialField(
        id: id,
        label: '新字段',
        value: '',
        type: CustomFieldType.text,
        secret: false,
        sort: _fields.fields.length,
      ));
      _syncControllers();
      _hint = '已新增字段，编辑后保存';
    });
  }

  void _remove(String id) {
    setState(() {
      _fields = _fields.remove(id);
      _syncControllers();
      _hint = '已移除字段，保存后生效';
    });
  }

  void _move(String id, int delta) {
    final ordered = _fields.fields.toList()
      ..sort((CredentialField a, CredentialField b) =>
          a.sort.compareTo(b.sort));
    final index = ordered.indexWhere((CredentialField f) => f.id == id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= ordered.length) return;
    setState(() {
      _fields = _fields.reorder(id, target);
      _syncControllers();
    });
  }

  CustomFields _collect() => CustomFields(<CredentialField>[
        for (final field in _fields.fields)
          field.copyWith(value: _controllers[field.id]?.text ?? field.value),
      ]);

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final collected = _collect();
      await _repo.setCustomFields(widget.credentialId, collected);
      if (!mounted) return;
      setState(() {
        _fields = collected;
        _syncControllers();
        _hint = '自定义字段已整体加密保存';
      });
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
        title: '自定义字段',
        subtitle: '${widget.title} · 字段级加密 · secret 默认掩码',
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
                  Text('套用模板', style: context.texts.bodySmall),
                  const SizedBox(height: SketchSpace.sm),
                  Wrap(
                    spacing: SketchSpace.sm,
                    runSpacing: SketchSpace.sm,
                    children: <Widget>[
                      for (final template in kDefaultFieldTemplates)
                        GestureDetector(
                          onTap: () => _applyTemplate(template),
                          child: SketchTag(template.label, dense: true),
                        ),
                    ],
                  ),
                  const SizedBox(height: SketchSpace.md),
                  SketchButton(
                    label: '新增字段',
                    glyph: SketchGlyph.plus,
                    dense: true,
                    onPressed: _busy ? null : _addField,
                  ),
                ],
              ),
            ),
            const SizedBox(height: SketchSpace.lg),
            for (final field in _fields.fields) ...<Widget>[
              _FieldCard(
                field: field,
                labelController: _labelController(field),
                valueController: _controllers[field.id]!,
                revealed: _revealed.contains(field.id),
                onToggleReveal: () => setState(() {
                  if (!_revealed.remove(field.id)) _revealed.add(field.id);
                }),
                onToggleSecret: (bool value) => setState(() {
                  _fields = _replace(field, field.copyWith(secret: value));
                }),
                onLabelChanged: (String value) => setState(() {
                  _fields = _replace(field, field.copyWith(label: value));
                }),
                onRemove: () => _remove(field.id),
                onUp: () => _move(field.id, -1),
                onDown: () => _move(field.id, 1),
              ),
              const SizedBox(height: SketchSpace.md),
            ],
            SketchButton(
              label: '保存全部字段',
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

  TextEditingController _labelController(CredentialField field) {
    // label 输入不走 _controllers（那只管值），避免清理值控制器时误删。
    return _labelControllers.putIfAbsent(
      field.id,
      () => TextEditingController(text: field.label),
    );
  }

  final Map<String, TextEditingController> _labelControllers =
      <String, TextEditingController>{};

  CustomFields _replace(CredentialField old, CredentialField next) =>
      CustomFields(<CredentialField>[
        for (final field in _fields.fields)
          if (field.id == old.id) next else field,
      ]);
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.field,
    required this.labelController,
    required this.valueController,
    required this.revealed,
    required this.onToggleReveal,
    required this.onToggleSecret,
    required this.onLabelChanged,
    required this.onRemove,
    required this.onUp,
    required this.onDown,
  });

  final CredentialField field;
  final TextEditingController labelController;
  final TextEditingController valueController;
  final bool revealed;
  final VoidCallback onToggleReveal;
  final ValueChanged<bool> onToggleSecret;
  final ValueChanged<String> onLabelChanged;
  final VoidCallback onRemove;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return SketchFrame(
      radius: SketchRadii.c,
      fill: p.noteAlt,
      borderColor: p.lineSoft,
      padding: const EdgeInsets.all(SketchSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SketchFieldFrame(
                  child: TextField(
                    controller: labelController,
                    onChanged: onLabelChanged,
                    decoration: sketchInputDecoration(context,
                        hintText: '字段名'),
                  ),
                ),
              ),
              const SizedBox(width: SketchSpace.sm),
              SketchTag(field.type.name, dense: true),
            ],
          ),
          const SizedBox(height: SketchSpace.sm),
          SketchFieldFrame(
            child: TextField(
              controller: valueController,
              obscureText: field.secret && !revealed,
              maxLines: field.type == CustomFieldType.multiline ? 3 : 1,
              decoration: sketchInputDecoration(context, hintText: '字段值'),
            ),
          ),
          const SizedBox(height: SketchSpace.sm),
          Wrap(
            spacing: SketchSpace.sm,
            runSpacing: SketchSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SketchButton(
                label: field.secret ? '秘密字段' : '普通字段',
                tone: field.secret ? SketchTone.primary : SketchTone.ghost,
                dense: true,
                onPressed: () => onToggleSecret(!field.secret),
              ),
              if (field.secret)
                SketchButton(
                  label: revealed ? '隐藏' : '显示',
                  dense: true,
                  onPressed: onToggleReveal,
                ),
              SketchButton(
                label: '上移',
                dense: true,
                onPressed: onUp,
              ),
              SketchButton(
                label: '下移',
                dense: true,
                onPressed: onDown,
              ),
              SketchButton(
                label: '删除',
                dense: true,
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
