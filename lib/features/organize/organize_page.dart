import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../data/db/vault_database.dart';
import '../../data/entry/entry_models.dart';
import '../../data/entry/entry_repository.dart';
import '../../data/entry/entry_repository_provider.dart';

/// 分类与标签管理页。
///
/// 本轮**只读**：展示分类树与标签云。增删改在下一轮 ——
/// 写入需要 `WriteGateway` 支持 category / tag 实体，那是独立的工作量。
class OrganizePage extends ConsumerWidget {
  const OrganizePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.sketch;
    final repo = ref.watch(entryRepositoryProvider);

    // 组织页是被 push 出来的独立路由，自带 Scaffold（TextField 等
    // Material 组件需要 Material 祖先；将来加编辑功能时不会踩坑）。
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '分类与标签',
        showSettings: false,
        leading: SketchIconButton(
          glyph: SketchGlyph.close,
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        child: FutureBuilder<({List<CategoryRow> categories, List<TagWithCount> tags})>(
          future: _load(repo),
          builder: (
            BuildContext context,
            AsyncSnapshot<
                ({List<CategoryRow> categories, List<TagWithCount> tags})>
                snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator(color: p.red));
            }
            final data = snapshot.data;
            final categories = data?.categories ?? const <CategoryRow>[];
            final tags = data?.tags ?? const <TagWithCount>[];

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                SketchSpace.lg,
                SketchSpace.lg,
                SketchSpace.lg,
                SketchSpace.xxl,
              ),
              children: <Widget>[
                _buildCategories(context, p, categories),
                const SizedBox(height: SketchSpace.xl),
                _buildTags(p, tags),
                const SizedBox(height: SketchSpace.lg),
                Text(
                  '管理功能将在后续版本开放',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, height: 1.5, color: p.muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<({List<CategoryRow> categories, List<TagWithCount> tags})> _load(
    EntryRepository repo,
  ) async {
    final categories = await repo.categories();
    final tags = await repo.tags();
    return (categories: categories, tags: tags);
  }

  // ---------------------------------------------------------------------------
  // 分类树
  // ---------------------------------------------------------------------------

  Widget _buildCategories(
    BuildContext context,
    SketchPalette p,
    List<CategoryRow> rows,
  ) {
    final tree = buildCategoryTree(rows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '分类',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink),
        ),
        const SizedBox(height: SketchSpace.sm),
        if (tree.isEmpty)
          Text(
            '还没有分类',
            style: TextStyle(fontSize: 12, height: 1.6, color: p.muted),
          )
        else
          ...<Widget>[
            for (final node in tree)
              ..._buildCategoryNode(context, p, node, depth: 0),
          ],
      ],
    );
  }

  List<Widget> _buildCategoryNode(
    BuildContext context,
    SketchPalette p,
    CategoryNode node, {
    required int depth,
  }) {
    return <Widget>[
      Padding(
        padding: EdgeInsets.only(
          left: depth * SketchSpace.lg,
          top: SketchSpace.sm,
          bottom: SketchSpace.sm,
        ),
        child: Row(
          children: <Widget>[
            if (node.children.isNotEmpty)
              SketchIcon(
                SketchGlyph.menu,
                size: 10,
                color: p.muted,
                strokeWidth: SketchStroke.icon,
              ),
            const SizedBox(width: SketchSpace.sm),
            Expanded(
              child: Text(
                node.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      node.children.isNotEmpty ? FontWeight.w700 : FontWeight.w400,
                  color: p.ink,
                ),
              ),
            ),
            Text(
              '${node.entryCount}',
              style: context.typography.monoStyle(
                size: 10.5,
                height: 1.4,
                color: p.muted,
              ),
            ),
          ],
        ),
      ),
      for (final child in node.children)
        ..._buildCategoryNode(context, p, child, depth: depth + 1),
    ];
  }

  // ---------------------------------------------------------------------------
  // 标签云
  // ---------------------------------------------------------------------------

  Widget _buildTags(SketchPalette p, List<TagWithCount> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '标签',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink),
        ),
        const SizedBox(height: SketchSpace.sm),
        if (tags.isEmpty)
          Text(
            '还没有标签',
            style: TextStyle(fontSize: 12, height: 1.6, color: p.muted),
          )
        else
          Wrap(
            spacing: SketchSpace.sm,
            runSpacing: SketchSpace.sm,
            children: <Widget>[
              for (final tag in tags)
                SketchTag(
                  '${tag.name} · ${tag.count}',
                  tone: _toneForIndex(tags.indexOf(tag)),
                ),
            ],
          ),
      ],
    );
  }

  /// 标签云轮换三种色调。不按 count 调大小 ——
  /// 大小映射需要渲染前算比例，本轮只读展示，不值得。
  SketchTone _toneForIndex(int index) {
    const tones = <SketchTone>[
      SketchTone.primary,
      SketchTone.blue,
      SketchTone.ghost,
    ];
    return tones[index % tones.length];
  }
}
