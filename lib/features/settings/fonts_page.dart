import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../app/theme/sketch_typography.dart';
import '../../core/fonts/font_catalog.dart';
import '../../core/fonts/font_face.dart';
import '../../core/fonts/font_providers.dart';
import '../../core/fonts/font_role.dart';
import '../../core/fonts/font_service.dart';
import '../../core/fonts/font_state.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_field.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../core/widgets/sketch_transitions.dart';

/// 字体设置页。结构见 docs/15 §7：
/// 预设 → 分角色指定 → 导入 → 已导入 → 说明。
class FontsPage extends ConsumerStatefulWidget {
  const FontsPage({super.key});

  @override
  ConsumerState<FontsPage> createState() => _FontsPageState();
}

class _FontsPageState extends ConsumerState<FontsPage> {
  bool _busy = false;

  FontService get _service => ref.read(fontServiceProvider);

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final state = _service.state;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: PageScaffold(
          title: '字体',
          subtitle: '本机生效 · 不参与同步',
          showSettings: false,
          leading: SketchIconButton(
            glyph: SketchGlyph.close,
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SketchSpace.lg,
              6,
              SketchSpace.lg,
              SketchSpace.xxl,
            ),
            children: <Widget>[
              if (_service.bootErrors.isNotEmpty) ...<Widget>[
                _BootWarning(errors: _service.bootErrors),
                const SizedBox(height: SketchSpace.md),
              ],
              _SectionLabel('预设方案'),
              const SizedBox(height: 6),
              _PresetGrid(
                current: state.presetId,
                onPick: (FontPreset preset) => _run(() => _service.applyPreset(preset)),
              ),
              const SizedBox(height: SketchSpace.xl),
              _SectionLabel('分别指定'),
              const SizedBox(height: 2),
              for (final role in FontRole.values) ...<Widget>[
                _RoleSection(
                  role: role,
                  state: state,
                  onPick: (String fontId) =>
                      _run(() => _service.setRoleFont(role, fontId)),
                ),
                const SizedBox(height: SketchSpace.lg),
              ],
              const SizedBox(height: SketchSpace.xs),
              _SectionLabel('导入字体'),
              const SizedBox(height: 6),
              _ImportCard(busy: _busy, onImport: _import),
              if (state.imported.isNotEmpty) ...<Widget>[
                const SizedBox(height: SketchSpace.md),
                for (var i = 0; i < state.imported.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SketchSpace.sm),
                    child: _ImportedRow(
                      face: state.imported[i],
                      index: i,
                      inUse: FontRole.values
                          .any((FontRole r) => state.roles[r] == state.imported[i].id),
                      onRename: () => _rename(state.imported[i]),
                      onDelete: () => _confirmDelete(state.imported[i]),
                    ),
                  ),
              ],
              const SizedBox(height: SketchSpace.xl),
              const _NotesCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 动作
  // ---------------------------------------------------------------------------

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // file_picker 13 的 pickFiles 默认就是多选，返回 List<PlatformFile>。
      // 不用 FileType.custom：各端 MIME 映射不一致，Android 上常直接返回空。
      // 一律按字节校验文件头，比扩展名可靠。
      final picked = await FilePicker.pickFiles();
      if (picked.isEmpty) return;

      // 不依赖 path：Android 的 content:// 没有本地路径，
      // 但 PlatformFile.readAsBytes() 在所有端都可用。
      final sources = <FontImportSource>[
        for (final file in picked)
          FontImportSource(name: file.name, read: file.readAsBytes),
      ];

      final report = await _service.importSources(sources);
      if (!mounted) return;
      await _showReport(report);
    } on Object catch (e) {
      if (mounted) _toast('导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(FontFace face) async {
    final controller = TextEditingController(text: face.displayName);
    final name = await showSketchDialog<String>(
      context: context,
      builder: (BuildContext ctx) => _SketchDialog(
        title: '重命名字体',
        body: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: ctx.sketch.ink, fontSize: 14),
          decoration: sketchInputDecoration(ctx, hintText: '显示名称'),
        ),
        actions: <Widget>[
          SketchButton(
            label: '取消',
            tone: SketchTone.ghost,
            dense: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          SketchButton(
            label: '保存',
            tone: SketchTone.primary,
            dense: true,
            onPressed: () => Navigator.of(ctx).pop(controller.text),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await _run(() => _service.renameImported(face.id, name));
    }
  }

  Future<void> _confirmDelete(FontFace face) async {
    final ok = await showSketchDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => _SketchDialog(
        title: '删除「${face.displayName}」？',
        body: Text(
          '字体文件会从本机删除。如果它正被某个角色使用，该角色会退回系统默认字体。',
          style: TextStyle(fontSize: 12.5, height: 1.6, color: ctx.sketch.muted),
        ),
        actions: <Widget>[
          SketchButton(
            label: '取消',
            tone: SketchTone.ghost,
            dense: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          SketchButton(
            label: '删除',
            tone: SketchTone.primary,
            dense: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => _service.removeImported(face.id));
    }
  }

  Future<void> _showReport(FontImportReport report) async {
    if (report.added.isEmpty && report.errors.isEmpty && report.skipped.isEmpty) {
      return;
    }
    await showSketchDialog<void>(
      context: context,
      builder: (BuildContext ctx) => _SketchDialog(
        title: report.summary,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final face in report.added)
              _ReportLine(
                icon: SketchGlyph.type,
                text: '${face.displayName} · ${face.sizeLabel}',
                tone: ctx.sketch.ink,
              ),
            for (final name in report.skipped)
              _ReportLine(
                icon: SketchGlyph.close,
                text: name,
                tone: ctx.sketch.muted,
              ),
            for (final err in report.errors)
              _ReportLine(
                icon: SketchGlyph.close,
                text: err,
                tone: ctx.sketch.red,
              ),
          ],
        ),
        actions: <Widget>[
          SketchButton(
            label: '知道了',
            tone: SketchTone.plain,
            dense: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 小组件
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.type.monoStyle(
        size: 10.5,
        weight: FontWeight.w700,
        color: context.sketch.muted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _PresetGrid extends StatelessWidget {
  const _PresetGrid({required this.current, required this.onPick});

  final String current;
  final ValueChanged<FontPreset> onPick;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (var i = 0; i < FontPresets.all.length; i++)
              SizedBox(
                width: width,
                child: _PresetCard(
                  preset: FontPresets.all[i],
                  index: i,
                  selected: current == FontPresets.all[i].id,
                  onTap: () => onPick(FontPresets.all[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final FontPreset preset;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final uiFace = FontCatalog.byId(preset.roles[FontRole.ui]!) ?? FontCatalog.systemUi;
    final monoFace = FontCatalog.byId(preset.roles[FontRole.mono]!) ?? FontCatalog.systemMono;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SketchFrame(
        radius: SketchRadii.cycle(index),
        fill: selected ? p.note : p.surface,
        borderColor: selected ? p.red : p.lineSoft,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        shadowOffset: selected ? SketchShadowOffset.card : Offset.zero,
        tilt: selected ? SketchTilt.selected : SketchTilt.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  preset.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 6),
                if (selected) const _Dot(color: null),
                const Spacer(),
                Text(
                  uiFace.displayName,
                  style: TextStyle(
                    fontFamily: monoFace.family,
                    fontFamilyFallback: monoFace.fallback,
                    fontSize: 9.5,
                    color: p.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '拾遗 · Aa 14:02',
              style: TextStyle(
                fontFamily: uiFace.family,
                fontFamilyFallback: uiFace.fallback,
                fontSize: 17,
                height: 1.3,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              preset.desc,
              style: TextStyle(fontSize: 11, height: 1.5, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color ?? context.sketch.red,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RoleSection extends StatelessWidget {
  const _RoleSection({
    required this.role,
    required this.state,
    required this.onPick,
  });

  final FontRole role;
  final FontState state;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final active = state.faceFor(role);
    final options = state.optionsFor(role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              role.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '正在用：${active.displayName}',
                style: context.type.monoStyle(size: 10, color: p.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          role.hint,
          style: TextStyle(fontSize: 11, height: 1.5, color: p.muted),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int i) {
              final face = options[i];
              return _FontChip(
                face: face,
                index: i,
                role: role,
                selected: face.id == active.id,
                onTap: () => onPick(face.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FontChip extends StatelessWidget {
  const _FontChip({
    required this.face,
    required this.index,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final FontFace face;
  final int index;
  final FontRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SketchFrame(
        radius: SketchRadii.cycle(index + 1),
        fill: selected ? p.note : p.surface,
        borderColor: selected ? p.red : p.lineSoft,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        shadowOffset: selected ? SketchShadowOffset.card : Offset.zero,
        tilt: selected ? SketchTilt.selected : SketchTilt.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              face.displayName,
              style: TextStyle(
                fontFamily: face.family,
                fontFamilyFallback: face.fallback,
                fontSize: 14,
                height: 1.25,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              face.isSystem ? '系统' : face.sizeLabel,
              style: context.type.monoStyle(size: 9.5, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  const _ImportCard({required this.busy, required this.onImport});

  final bool busy;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return SketchFrame(
      radius: SketchRadii.a,
      fill: p.surface,
      borderColor: p.lineSoft,
      padding: const EdgeInsets.all(SketchSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SketchIcon(SketchGlyph.upload, size: 18, color: p.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '支持 TTF / OTF / TTC，单个不超过 40 MB',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '导入的字体只存在本机，不参与同步、不上传。WOFF / WOFF2 需要先转成 TTF。',
                  style: TextStyle(fontSize: 11, height: 1.55, color: p.muted),
                ),
                const SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    SketchButton(
                      label: busy ? '处理中…' : '选择字体文件',
                      glyph: SketchGlyph.plus,
                      tone: SketchTone.blue,
                      dense: true,
                      onPressed: busy ? null : onImport,
                    ),
                    const SizedBox(width: 10),
                    if (busy)
                      SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: p.blue,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportedRow extends StatelessWidget {
  const _ImportedRow({
    required this.face,
    required this.index,
    required this.inUse,
    required this.onRename,
    required this.onDelete,
  });

  final FontFace face;
  final int index;
  final bool inUse;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return SketchFrame(
      radius: SketchRadii.cycle(index),
      fill: p.surface,
      borderColor: p.lineSoft,
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        face.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: face.family,
                          fontFamilyFallback: face.fallback,
                          fontSize: 14,
                          color: p.ink,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (inUse) ...<Widget>[
                      const SizedBox(width: 7),
                      SketchTag('使用中', tone: SketchTone.blue, dense: true),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${face.sizeLabel} · ${face.originName ?? face.id}',
                  overflow: TextOverflow.ellipsis,
                  style: context.type.monoStyle(size: 9.5, color: p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SketchIconButton(
            glyph: SketchGlyph.type,
            tooltip: '重命名',
            size: 27,
            onPressed: onRename,
          ),
          SketchIconButton(
            glyph: SketchGlyph.close,
            tooltip: '删除',
            size: 27,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard();

  static const List<(String, String)> _items = <(String, String)>[
    ('字体不参与同步', '每台设备各自设置。换设备需要重新选一次，内置字体不需要重装。'),
    ('运行时字体没有真粗体', '导入的字体由引擎合成粗体，观感会略糊。内置的三套已在包里声明，表现更好。'),
    ('加载后常驻内存', '中文字体约 13 MB，切换过的导入字体会留在内存里。导入多了建议重启一次应用。'),
    ('许可请自行确认', '用户导入的字体不会外发，但商用授权由你负责。内置三套均为 SIL OFL 1.1。'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return SketchFrame(
      radius: SketchRadii.c,
      fill: p.noteAlt,
      borderColor: p.lineSoft,
      padding: const EdgeInsets.all(SketchSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '关于字体',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 8),
          for (final (String title, String body) in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 7),
                    child: _Dot(color: p.blue),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 11, height: 1.6, color: p.ink),
                        children: <InlineSpan>[
                          TextSpan(
                            text: '$title　',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: body,
                            style: TextStyle(color: p.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BootWarning extends StatelessWidget {
  const _BootWarning({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return SketchFrame(
      radius: SketchRadii.b,
      fill: p.surface,
      borderColor: p.red,
      padding: const EdgeInsets.all(SketchSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '有 ${errors.length} 个字体没能加载',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: p.red,
            ),
          ),
          const SizedBox(height: 4),
          for (final e in errors)
            Text(
              e,
              style: TextStyle(fontSize: 10.5, height: 1.5, color: p.muted),
            ),
          const SizedBox(height: 4),
          Text(
            '相关角色已自动退回系统字体，功能不受影响。',
            style: TextStyle(fontSize: 10.5, height: 1.5, color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({required this.icon, required this.text, required this.tone});

  final SketchGlyph icon;
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 7),
            child: SketchIcon(icon, size: 12, color: tone),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, height: 1.55, color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

/// 手绘风弹窗。不用 `AlertDialog`：它的圆角和阴影与全站规则冲突。
class _SketchDialog extends StatelessWidget {
  const _SketchDialog({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SketchFrame(
          radius: SketchRadii.b,
          fill: p.surface,
          borderColor: p.line,
          padding: const EdgeInsets.all(SketchSpace.lg),
          shadowOffset: SketchShadowOffset.panel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: SketchSpace.md),
              body,
              const SizedBox(height: SketchSpace.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  for (var i = 0; i < actions.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
