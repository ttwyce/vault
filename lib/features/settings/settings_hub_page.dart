import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings/local_settings_provider.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../organize/organize_page.dart';
import '../quick/quick_capture_page.dart';
import '../search/search_page.dart';
import '../settings/about_page.dart';
import '../settings/diagnostics_page.dart';
import '../settings/export_backup_page.dart';
import '../settings/fonts_page.dart';
import '../settings/models_page.dart';
import '../settings/pending_jobs_page.dart';
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
            _AiDiarySearchTile(),
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
              glyph: SketchGlyph.type,
              title: '关于与隐私',
              subtitle: '端侧加密、零遥测、开源许可与恢复码说明',
              onTap: () => _push(context, const AboutPage()),
            ),
            _SettingsTile(
              glyph: SketchGlyph.archive,
              title: '导出与备份',
              subtitle: '明文导出二次确认、导入合并判定、/backup/ 隔离与排期',
              onTap: () => _push(context, const ExportBackupPage()),
            ),
            _SettingsTile(
              glyph: SketchGlyph.archive,
              title: '待处理任务',
              subtitle: '前台补偿队列、失败重试与状态聚合',
              onTap: () => _push(context, const PendingJobsPage()),
            ),
            _SettingsTile(
              glyph: SketchGlyph.type,
              title: '模型管理',
              subtitle: '端侧模型清单、下载源优先级与检索降级四态',
              onTap: () => _push(context, const ModelsPage()),
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


/// docs/07 §6.1：AI 日记默认排除检索，这里提供用户显式开关。
class _AiDiarySearchTile extends ConsumerWidget {
  const _AiDiarySearchTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.sketch;
    final settings = ref.watch(localSettingsProvider);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SketchSpace.sm,
        vertical: SketchSpace.xs,
      ),
      leading: SketchIcon(SketchGlyph.search, size: 18, color: p.ink),
      title: Text(
        '在搜索中包含 AI 日记',
        style: TextStyle(fontSize: 13, color: p.ink),
      ),
      subtitle: Text(
        settings.includeAiDiaryInSearch
            ? '已开启：AI 生成的时间线也会出现在搜索结果里'
            : '默认关闭，避免生成文本占据语义空间与搜索结果',
        style: TextStyle(fontSize: 10.5, color: p.muted),
      ),
      trailing: Switch(
        value: settings.includeAiDiaryInSearch,
        onChanged: (bool value) => ref
            .read(localSettingsProvider.notifier)
            .setIncludeAiDiaryInSearch(value),
      ),
    );
  }
}
