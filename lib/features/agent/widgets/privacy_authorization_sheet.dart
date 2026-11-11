import 'package:flutter/material.dart';

import '../../../app/theme/sketch_metrics.dart';
import '../../../app/theme/sketch_theme.dart';
import '../../../core/widgets/sketch_controls.dart';
import '../../../core/widgets/sketch_frame.dart';

/// L2 / L1 离设备数据的**逐次授权**弹窗（docs/07 §4.2）。
///
/// 授权结果只返回给本次调用方，**不写设置、不落库、不缓存**；
/// 下次调用必须重新弹。关闭对话框按拒绝处理。
class PrivacyAuthorizationSheet extends StatelessWidget {
  const PrivacyAuthorizationSheet({
    super.key,
    required this.level,
    required this.modelName,
    required this.entryCount,
    required this.outgoingChars,
    required this.onApprove,
    required this.onDeny,
  });

  final String level;
  final String modelName;
  final int entryCount;
  final int outgoingChars;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

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
            '本次授权 · $level',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: SketchSpace.md),
          SketchFrame(
            radius: SketchRadii.b,
            fill: p.red.withValues(alpha: 0.10),
            padding: const EdgeInsets.all(SketchSpace.md),
            child: Text(
              '将向 $modelName 发送 $entryCount 条内容的 '
              '$outgoingChars 字片段，数据会离开设备。',
              style: TextStyle(fontSize: 13, height: 1.6, color: p.ink),
            ),
          ),
          const SizedBox(height: SketchSpace.md),
          Text(
            '仅授权这一次；下次调用会重新询问。密码 / TOTP / 日记正文'
            '永远不会出现在这类请求里。',
            style: TextStyle(fontSize: 11, height: 1.6, color: p.muted),
          ),
          const SizedBox(height: SketchSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              SketchButton(label: '拒绝', dense: true, onPressed: onDeny),
              const SizedBox(width: SketchSpace.sm),
              SketchButton(
                label: '仅本次允许',
                dense: true,
                tone: SketchTone.primary,
                onPressed: onApprove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 返回是否批准；调用方把结果只用于本次 [ToolCallContext]。
Future<bool> requestPrivacyAuthorization({
  required BuildContext context,
  required String level,
  required String modelName,
  required int entryCount,
  required int outgoingChars,
}) async {
  final approved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => Dialog(
      child: SingleChildScrollView(
        child: PrivacyAuthorizationSheet(
          level: level,
          modelName: modelName,
          entryCount: entryCount,
          outgoingChars: outgoingChars,
          onApprove: () => Navigator.of(dialogContext).pop(true),
          onDeny: () => Navigator.of(dialogContext).pop(false),
        ),
      ),
    ),
  );
  return approved ?? false;
}

/// 授权说明纯文本，便于日志/测试断言（不含任何内容本体）。
String authorizationSummary({
  required String level,
  required String modelName,
  required int entryCount,
  required int outgoingChars,
}) =>
    '$level → $modelName：$entryCount 条 / $outgoingChars 字（仅本次）';
