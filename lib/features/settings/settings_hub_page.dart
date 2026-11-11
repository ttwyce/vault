import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../organize/organize_page.dart';
import '../quick/quick_capture_page.dart';
import '../search/search_page.dart';
import '../settings/diagnostics_page.dart';
import '../settings/fonts_page.dart';
import '../trash/trash_page.dart';

/// 设置中心。
///
/// 之前右上角的齿轮直接跳字体页。加了回收站 / 搜索 / 整理之后，
/// 一个齿轮只对应一个页面会变成猜谜，所以收敛成一个入口列表。
class SettingsHubPage extends ConsumerWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.sketch;

    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '设置',
        showSettings: false,
        leading: SketchIconButton(
          glyph: SketchGlyph.close,
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SketchSpace.lg,
            SketchSpace.md,
            SketchSpace.lg,
            SketchSpace.xxl,
          ),
          children: <Widget>[
            _SettingsTile(
              glyph: SketchGlyph.type,
              title: '字体',
              subtitle: '三角色排版、预设与导入字体',
              onTap: () => _push(context, const FontsPage()),
            ),
            _SettingsTile(
              glyph: SketchGlyph.menu,
              title: '分类与标签',
              subtitle: '两级分类树、标签云与同名合并',
              onTap: () => _push(context, const OrganizePage()),
            ),
            _SettingsTile(
              glyph: SketchGlyph.search,
              title: '全库搜索',
              subtitle: '跨类型检索标题、正文与标签',
              onTap: () => _push(context, const SearchPage()),
            ),
            _SettingsTile(
              glyph: SketchGlyph.archive,
              title: '回收站',
              subtitle: '删除的内容保留 30 天，可恢复、可看历史版本',
              onTap: () => _push(context, const TrashPage()),
            ),
            _SettingsTile(
              glyph: SketchGlyph.plus,
              title: '快速记录',
              subtitle: '一句话存成想法',
              onTap: () => _push(context, const QuickCapturePage()),
            ),
            _SettingsTile(
              glyph: SketchGlyph.settings,
              title: '诊断与备份',
              subtitle: '六项发布前自检、加密备份包与 /backup/ 排期',
              onTap: () => _push(context, const DiagnosticsPage()),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final SketchGlyph glyph;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Column(
      children: <Widget>[
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SketchSpace.sm,
            vertical: SketchSpace.xs,
          ),
          leading: SketchIcon(glyph, size: 18, color: p.blue),
          title: Text(
            title,
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 11.5, height: 1.5, color: p.muted),
          ),
          onTap: onTap,
        ),
        const SketchDivider(),
      ],
    );
  }
}
