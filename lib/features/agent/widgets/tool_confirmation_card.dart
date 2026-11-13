import 'package:flutter/material.dart';

import '../../../app/theme/sketch_metrics.dart';
import '../../../app/theme/sketch_palette.dart';
import '../../../app/theme/sketch_theme.dart';
import '../../../core/widgets/sketch_controls.dart';
import '../../../core/widgets/sketch_frame.dart';
import '../../../data/agent/agent_policy.dart';
import '../../../core/widgets/sketch_transitions.dart';

/// 工具确认卡片（docs/07 §4.1）。
///
/// 三件事必须同时可见：人话操作（不是 JSON）、**完整**内容预览、
/// 数据是否离开设备。dangerous 级还要二次确认：用户必须显式勾住
/// 「我已了解数据流向」才能点确认。
///
/// 返回 true 表示用户批准，false / 关闭表示拒绝；调用方据此决定是否
/// 真的执行工具。这里不执行任何工具，也不改数据。
class ToolConfirmationCard extends StatefulWidget {
  const ToolConfirmationCard({
    super.key,
    required this.toolName,
    required this.decision,
    required this.humanAction,
    required this.contentPreview,
    required this.dataLeavesDevice,
    required this.modelName,
    required this.onConfirm,
    required this.onCancel,
  });

  final String toolName;
  final PolicyDecision decision;
  final String humanAction;
  final String contentPreview;
  final bool dataLeavesDevice;
  final String modelName;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  State<ToolConfirmationCard> createState() => _ToolConfirmationCardState();
}

class _ToolConfirmationCardState extends State<ToolConfirmationCard> {
  bool _acknowledged = false;

  bool get _isDangerous => widget.decision.preview.contains('危险') ||
      widget.toolName.startsWith('mcp/') ||
      widget.dataLeavesDevice;

  bool get _canConfirm => !_isDangerous || _acknowledged;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Padding(
      padding: const EdgeInsets.all(SketchSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '确认操作 · ${widget.toolName}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: SketchSpace.md),
          _SectionLabel('将要执行', p),
          Text(widget.humanAction,
              style: TextStyle(fontSize: 13, color: p.ink)),
          const SizedBox(height: SketchSpace.md),
          _SectionLabel('完整内容预览', p),
          SketchFrame(
            radius: SketchRadii.b,
            fill: p.surface,
            padding: const EdgeInsets.all(SketchSpace.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.contentPreview.isEmpty
                      ? '（无内容）'
                      : widget.contentPreview,
                  style: TextStyle(fontSize: 12, color: p.ink),
                ),
              ),
            ),
          ),
          const SizedBox(height: SketchSpace.md),
          _SectionLabel('数据流向', p),
          SketchCard(
            variant: 0,
            fill: widget.dataLeavesDevice ? p.red.withValues(alpha: 0.12) : p.noteAlt,
            tilt: SketchTilt.none,
            padding: const EdgeInsets.all(SketchSpace.sm),
            child: Text(
              widget.dataLeavesDevice
                  ? '数据将离开设备，发送给 ${widget.modelName}'
                  : '数据仅在本设备内处理',
              style: TextStyle(
                fontSize: 12,
                color: widget.dataLeavesDevice ? p.red : p.blue,
              ),
            ),
          ),
          if (_isDangerous) ...<Widget>[
            const SizedBox(height: SketchSpace.sm),
            CheckboxListTile(
              value: _acknowledged,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '我已了解数据流向，确认继续（二次确认）',
                style: TextStyle(fontSize: 11.5, color: p.ink),
              ),
              onChanged: (bool? value) =>
                  setState(() => _acknowledged = value ?? false),
            ),
          ],
          if (widget.decision.reasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: SketchSpace.xs),
              child: Text(
                widget.decision.reasons.join('；'),
                style: TextStyle(fontSize: 10.5, color: p.muted),
              ),
            ),
          const SizedBox(height: SketchSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              SketchButton(label: '取消', dense: true, onPressed: widget.onCancel),
              const SizedBox(width: SketchSpace.sm),
              SketchButton(
                label: '确认执行',
                dense: true,
                tone: SketchTone.primary,
                onPressed: _canConfirm ? widget.onConfirm : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.p);

  final String text;
  final SketchPalette p;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: SketchSpace.xs),
        child: Text(
          text,
          style: TextStyle(fontSize: 10.5, color: p.muted),
        ),
      );
}

/// 弹出确认卡片并返回用户是否批准。关闭对话框按拒绝处理。
Future<bool> showToolConfirmation({
  required BuildContext context,
  required String toolName,
  required PolicyDecision decision,
  required String humanAction,
  required String contentPreview,
  required bool dataLeavesDevice,
  required String modelName,
}) async {
  final approved = await showSketchDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => Dialog(
      child: SingleChildScrollView(
        child: ToolConfirmationCard(
          toolName: toolName,
          decision: decision,
          humanAction: humanAction,
          contentPreview: contentPreview,
          dataLeavesDevice: dataLeavesDevice,
          modelName: modelName,
          onConfirm: () => Navigator.of(dialogContext).pop(true),
          onCancel: () => Navigator.of(dialogContext).pop(false),
        ),
      ),
    ),
  );
  return approved ?? false;
}
