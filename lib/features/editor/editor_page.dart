import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/entry/entry_models.dart';
import '../../data/entry/entry_repository_provider.dart';
import '../../data/write/write_gateway.dart';

/// 条目编辑器。新建（`entryId == null`）与编辑（`entryId != null`）共用。
///
/// 本轮只做纯文本编辑：标题 + 正文。Markdown 渲染、斜杠菜单、附件
/// 是后续轮次的事 —— 先把"写进去再读出来"这条链路跑通。
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({
    super.key,
    this.entryId,
    this.initialKind = EntryKind.note,
  });

  /// 为 null 表示新建；非空表示编辑已有条目。
  final String? entryId;

  /// 新建时的类型。编辑态以数据库里的 `kind` 为准。
  final EntryKind initialKind;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();

  late EntryKind _kind = widget.initialKind;

  /// 编辑态下从数据库读到的旧 `meta`。保存时要原样传回 ——
  /// 日记日期等扩展字段都住在 meta 里，不传回就等于把扩展字段清掉。
  String? _existingMeta;

  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.entryId != null) _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final row = await ref.read(entryRepositoryProvider).getRow(widget.entryId!);
    if (!mounted) return;

    if (row == null) {
      setState(() {
        _loading = false;
        _error = '这条内容不存在，可能已被删除。';
      });
      return;
    }

    _title.text = row.title ?? '';
    _body.text = row.body ?? '';
    _existingMeta = row.meta;
    _kind = EntryKind.fromCode(row.kind) ?? widget.initialKind;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    // 标题为空时用正文首行兜底（读侧 `displayTitle` 也做同样的事，
    // 这里在写侧就规范化，保证存进去的标题不是空串）。
    final String title = displayTitle(_title.text, _body.text);
    final String body = _body.text;

    final gateway = ref.read(writeGatewayProvider);
    try {
      if (widget.entryId == null) {
        // 日记的日期是显式字段（补写需求），新建时落今天。
        String? meta;
        if (_kind == EntryKind.diary) {
          meta = jsonEncode(<String, Object?>{
            'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          });
        }
        await gateway.writeEntry(
          EntryWrite.create(kind: _kind, title: title, body: body, meta: meta),
        );
      } else {
        // update 是整体替换语义：没改的字段（meta）也要原样传回。
        await gateway.writeEntry(
          EntryWrite.update(
            id: widget.entryId!,
            title: title,
            body: body,
            meta: _existingMeta,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on WriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$e';
      });
    }
  }

  String get _kindLabel => switch (_kind) {
        EntryKind.note => '笔记',
        EntryKind.thought => '想法',
        EntryKind.diary => '日记',
        EntryKind.aiDiary => 'AI 日记',
        EntryKind.bookmark => '归档',
        EntryKind.credential => '密码',
      };

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return PageScaffold(
      title: widget.entryId == null ? '新建$_kindLabel' : '编辑$_kindLabel',
      showSettings: false,
      leading: SketchIconButton(
        glyph: SketchGlyph.close,
        tooltip: '返回',
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
      ),
      actions: <Widget>[
        SketchButton(
          label: _saving ? '保存中…' : '保存',
          tone: SketchTone.primary,
          glyph: SketchGlyph.plus,
          onPressed: (_loading || _saving) ? null : _save,
        ),
      ],
      child: _buildBody(p),
    );
  }

  Widget _buildBody(SketchPalette p) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: p.red));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SketchSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_error != null) ...<Widget>[
            const SizedBox(height: SketchSpace.md),
            SketchFrame(
              radius: SketchRadii.cycle(1),
              fill: p.surface,
              borderColor: p.red,
              padding: const EdgeInsets.all(SketchSpace.md),
              tilt: SketchTilt.left,
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, height: 1.7, color: p.ink),
              ),
            ),
          ],
          TextField(
            controller: _title,
            enabled: !_saving,
            autofocus: widget.entryId == null,
            maxLines: null,
            textInputAction: TextInputAction.next,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: p.ink,
            ),
            cursorColor: p.red,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '标题',
              hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.muted),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _body,
              enabled: !_saving,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: TextStyle(fontSize: 14, height: 1.8, color: p.ink),
              cursorColor: p.red,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '开始写…',
                hintStyle: TextStyle(fontSize: 14, height: 1.8, color: p.muted),
              ),
            ),
          ),
          const SizedBox(height: SketchSpace.md),
        ],
      ),
    );
  }
}
