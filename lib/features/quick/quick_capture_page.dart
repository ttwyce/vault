import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/entry/entry_models.dart';
import '../../data/write/write_gateway.dart';

/// 全局「快速记录」：一个输入框，一次点击，存成想法。
///
/// 目标文档写的是「3 秒内完成一条记录」，所以这里**没有标题框、
/// 没有分类、没有标签、没有二次确认**。整理是之后在编辑器里做的事，
/// 不该挡在「先记下来」前面。
class QuickCapturePage extends ConsumerStatefulWidget {
  const QuickCapturePage({super.key});

  @override
  ConsumerState<QuickCapturePage> createState() => _QuickCapturePageState();
}

class _QuickCapturePageState extends ConsumerState<QuickCapturePage> {
  final TextEditingController _body = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _body.text.trim();
    if (text.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final gateway = ref.read(writeGatewayProvider);
      final result = await gateway.writeEntry(
        EntryWrite.create(
          kind: EntryKind.thought,
          title: displayTitle(null, text),
          body: text,
        ),
      );
      // 记一条「创建」活动。失败不影响保存结果。
      try {
        await ref
            .read(activityLoggerProvider)
            .recordCreate(result.snapshot.id);
      } on Object {
        // 埋点是尽力而为，见 SearchPage 的同样处理。
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on WriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '快速记录',
        subtitle: '先记下来，之后再整理',
        showSettings: false,
        leading: SketchIconButton(
          glyph: SketchGlyph.close,
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          SketchButton(
            label: _saving ? '保存中…' : '存为想法',
            tone: SketchTone.primary,
            dense: true,
            onPressed: _saving ? null : _save,
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SketchSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null) ...<Widget>[
                const SizedBox(height: SketchSpace.md),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12, color: p.red),
                ),
              ],
              const SizedBox(height: SketchSpace.sm),
              Expanded(
                child: TextField(
                  controller: _body,
                  autofocus: true,
                  enabled: !_saving,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(fontSize: 16, height: 1.8, color: p.ink),
                  cursorColor: p.red,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '想到什么就写…',
                    hintStyle:
                        TextStyle(fontSize: 16, height: 1.8, color: p.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
