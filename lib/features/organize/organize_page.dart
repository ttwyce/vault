import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/db/vault_database.dart';
import '../../data/entry/entry_models.dart';
import '../../data/entry/entry_repository_provider.dart';
import '../../data/taxonomy/category_reorder.dart';
import '../../data/taxonomy/taxonomy_models.dart';
import '../../data/taxonomy/taxonomy_repository_provider.dart';
import '../../data/write/write_gateway.dart';

/// 组织页一次加载的内容。
typedef OrganizeData = ({
  List<CategoryRow> categories,
  List<TagWithCount> tags,
  List<List<TagWithCount>> duplicateGroups,
});

/// bottom sheet 里选中的动作。
///
/// 不在 ListTile.onTap 里直接调 showDialog：那时 sheet 还在 pop 动画中，
/// 新 push 的 dialog 会和一个正在退场的路由抢 Navigator，容易整个消失。
/// 让 sheet 返回动作、等它的 Future 完成（已彻底退场）再执行，时序才干净。
enum _CategoryAction { rename, addChild, delete }

enum _TagAction { rename, delete }

/// 分类与标签管理页。
///
/// 所有写操作都走 `WriteGateway` —— 分类、标签、条目关联是**独立同步实体**，
/// 直接 `db.insert` 会静默丢掉另一台设备上的改动。
///
/// 硬规则（docs/11 §2）：分类最多两级、一条内容最多一个分类最多 8 个标签。
/// 这两条在写入口里已经挡住，UI 这里不重复实现，只负责把错误说清楚。
class OrganizePage extends ConsumerStatefulWidget {
  const OrganizePage({super.key});

  @override
  ConsumerState<OrganizePage> createState() => _OrganizePageState();
}

class _OrganizePageState extends ConsumerState<OrganizePage> {
  late Future<OrganizeData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<OrganizeData> _load() async {
    final entryRepo = ref.read(entryRepositoryProvider);
    final taxonomyRepo = ref.read(taxonomyRepositoryProvider);
    return (
      categories: await entryRepo.categories(),
      tags: await entryRepo.tags(),
      duplicateGroups: await taxonomyRepo.duplicateTags(),
    );
  }

  void _refresh() {
    if (!mounted) return;
    // 先取 Future 再 setState：箭头闭包返回 Future 会被 Flutter 断言拦下。
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  Future<void> _run(Future<TaxonomyWriteResult> Function() action) async {
    try {
      await action();
      _refresh();
    } on WriteException catch (e) {
      _notify(e.message);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------------------------------------------------------------------------
  // 输入与确认
  // ---------------------------------------------------------------------------

  Future<String?> _promptName({
    required String title,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: TaxonomyRules.maxNameLength,
          decoration: const InputDecoration(hintText: '名称'),
          onSubmitted: (String value) =>
              Navigator.of(dialogContext).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(String title, String detail) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 分类写操作
  // ---------------------------------------------------------------------------

  Future<void> _addCategory() async {
    final name = await _promptName(title: '新建分类');
    if (name == null || name.trim().isEmpty) return;
    await _run(() => ref.read(writeGatewayProvider).writeCategory(
          CategoryWrite.create(name: name),
        ));
  }

  Future<void> _addChildCategory(CategoryRow parent) async {
    final name = await _promptName(title: '在「${parent.name}」下新建子分类');
    if (name == null || name.trim().isEmpty) return;
    await _run(() => ref.read(writeGatewayProvider).writeCategory(
          CategoryWrite.create(
            name: name,
            parentId: parent.id,
            // 子分类继承父分类的归属类型（账号分组用 kind=6），
            // 统一写 note 会让它下次筛选时凭空消失。
            kind: EntryKind.fromCode(parent.kind) ?? EntryKind.note,
          ),
        ));
  }

  Future<void> _renameCategory(CategoryRow row) async {
    final name = await _promptName(title: '重命名分类', initial: row.name);
    if (name == null || name.trim().isEmpty) return;
    await _run(() => ref.read(writeGatewayProvider).writeCategory(
          CategoryWrite.update(
            id: row.id,
            name: name,
            parentId: row.parentId,
            sortOrder: row.sortOrder,
            // kind 在 update 里保持不变（写入口读旧行）
          ),
        ));
  }

  /// 同级拖拽排序：先算差异，再逐条走唯一写入口。
  ///
  /// 只允许同 parentId 内重排，不允许把二级拖成一级或跨父级换组 ——
  /// 那会改变归属语义，必须走明确的「改层级」操作。
  Future<void> _reorderSiblings(
    List<CategoryRow> rows,
    String? parentId,
    int oldIndex,
    int newIndex,
  ) async {
    final siblings = sortedSiblings(rows, parentId);
    final changes = reorderCategorySiblings(
      siblings: siblings,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    if (changes.isEmpty) return;
    try {
      final gateway = ref.read(writeGatewayProvider);
      for (final change in changes) {
        await gateway.writeCategory(CategoryWrite.update(
          id: change.categoryId,
          name: change.name,
          parentId: change.parentId,
          sortOrder: change.sortOrder,
        ));
      }
      _refresh();
    } on WriteException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _deleteCategory(CategoryRow row) async {
    // docs/11 §2：确认文案必须给出受影响的条目数，且不删条目。
    // entryIdsForCategory 已包含子分类下的条目。
    final affected =
        await ref.read(entryRepositoryProvider).entryIdsForCategory(row.id);
    final ok = await _confirm(
      '删除「${row.name}」？',
      '${affected.length} 条笔记会移到「未分类」，不会被删除；'
      '它下面的子分类会提升为一级分类。',
    );
    if (ok != true) return;
    await _run(() => ref.read(writeGatewayProvider).writeCategory(
          CategoryWrite.delete(id: row.id),
        ));
  }

  Future<void> _categoryActions(CategoryRow row, bool canAddChild) async {
    final action = await showModalBottomSheet<_CategoryAction>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: const Text('重命名'),
              onTap: () => Navigator.of(sheetContext)
                  .pop(_CategoryAction.rename),
            ),
            if (canAddChild)
              ListTile(
                title: const Text('新建子分类'),
                onTap: () => Navigator.of(sheetContext)
                    .pop(_CategoryAction.addChild),
              ),
            ListTile(
              title: Text('删除', style: TextStyle(color: sheetContext.sketch.red)),
              onTap: () => Navigator.of(sheetContext)
                  .pop(_CategoryAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _CategoryAction.rename) {
      await _renameCategory(row);
    } else if (action == _CategoryAction.addChild) {
      await _addChildCategory(row);
    } else {
      await _deleteCategory(row);
    }
  }

  // ---------------------------------------------------------------------------
  // 标签写操作
  // ---------------------------------------------------------------------------

  Future<void> _addTag() async {
    final name = await _promptName(title: '新建标签');
    if (name == null || name.trim().isEmpty) return;
    await _run(() => ref.read(writeGatewayProvider).writeTag(
          TagWrite.create(name: name),
        ));
  }

  Future<void> _renameTag(TagWithCount tag) async {
    final name = await _promptName(title: '重命名标签', initial: tag.name);
    if (name == null || name.trim().isEmpty) return;
    await _run(() => ref.read(writeGatewayProvider).writeTag(
          TagWrite.rename(id: tag.id, name: name),
        ));
  }

  Future<void> _deleteTag(TagWithCount tag) async {
    final ok = await _confirm(
      '删除标签「${tag.name}」？',
      '只会解除关联，条目本身不会被删除。',
    );
    if (ok != true) return;
    await _run(() => ref.read(writeGatewayProvider).writeTag(
          TagWrite.delete(id: tag.id),
        ));
  }

  Future<void> _tagActions(TagWithCount tag) async {
    final action = await showModalBottomSheet<_TagAction>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: const Text('重命名'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_TagAction.rename),
            ),
            ListTile(
              title: Text('删除', style: TextStyle(color: sheetContext.sketch.red)),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_TagAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _TagAction.rename) {
      await _renameTag(tag);
    } else {
      await _deleteTag(tag);
    }
  }

  /// 同名合并：每组保留 usage 最大的那个，其余全部并进去。
  ///
  /// 同名标签只可能来自「两台设备各建了一个」的同步合并，本地创建时
  /// 写入口会拒绝同名。所以这里不是纠错，是同步后的收尾动作。
  Future<void> _mergeDuplicates(List<List<TagWithCount>> groups) async {
    final ok = await _confirm(
      '合并 ${groups.length} 组同名标签？',
      '每组保留使用次数最多的标签，其余标签的关联会全部改指过去，内容不会丢。',
    );
    if (ok != true) return;

    final gateway = ref.read(writeGatewayProvider);
    for (final group in groups) {
      final target = group.first;
      for (final source in group.skip(1)) {
        try {
          await gateway.writeTag(TagWrite.merge(
            sourceId: source.id,
            targetId: target.id,
          ));
        } on WriteException catch (e) {
          _notify(e.message);
          return;
        }
      }
    }
    _refresh();
  }

  // ---------------------------------------------------------------------------
  // 构建
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

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
        actions: <Widget>[
          SketchButton(
            label: '＋ 分类',
            tone: SketchTone.ghost,
            dense: true,
            onPressed: _addCategory,
          ),
          SketchButton(
            label: '＋ 标签',
            tone: SketchTone.ghost,
            dense: true,
            onPressed: _addTag,
          ),
        ],
        child: FutureBuilder<OrganizeData>(
          future: _data,
          builder: (
            BuildContext context,
            AsyncSnapshot<OrganizeData> snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator(color: p.red));
            }
            final categories =
                snapshot.data?.categories ?? const <CategoryRow>[];
            final tags = snapshot.data?.tags ?? const <TagWithCount>[];
            final dupes = snapshot.data?.duplicateGroups ??
                const <List<TagWithCount>>[];

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
                if (dupes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: SketchSpace.xl),
                  _buildDuplicateNotice(p, dupes),
                ],
                const SizedBox(height: SketchSpace.xl),
                Text(
                  '分类最多两级，一条内容最多 1 个分类、'
                  '${TaxonomyRules.maxTagsPerEntry} 个标签',
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

  Widget _buildCategories(
    BuildContext context,
    SketchPalette p,
    List<CategoryRow> rows,
  ) {
    final roots = sortedSiblings(rows, null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '分类（长按拖动可同级排序）',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: p.ink),
        ),
        const SizedBox(height: SketchSpace.sm),
        if (roots.isEmpty)
          Text(
            '还没有分类',
            style: TextStyle(fontSize: 12, height: 1.6, color: p.muted),
          )
        else
          // 扁平展开两级树，但每个 item 自带拖拽手柄；跨父级 / 跨层级
          // 的落点由 _reorderFlat 拒绝，只允许同一 parentId 内重排。
          ReorderableListView.builder(
            key: const ValueKey<String>('category-roots'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _flatCategories(rows).length,
            onReorderItem: (int oldIndex, int newIndex) => _reorderFlat(
              rows,
              oldIndex,
              newIndex,
            ),
            itemBuilder: (BuildContext context, int index) {
              final flat = _flatCategories(rows)[index];
              return KeyedSubtree(
                key: ValueKey<String>('category-${flat.row.id}'),
                child: _categoryTile(
                  context,
                  p,
                  flat.row,
                  depth: flat.depth,
                  canAddChild: flat.depth == 0,
                ),
              );
            },
          ),
      ],
    );
  }

  /// 同一 parentId 内按 sortOrder 稳定展开；父节点紧跟着它的子节点。
  List<({CategoryRow row, int depth})> _flatCategories(List<CategoryRow> rows) {
    final out = <({CategoryRow row, int depth})>[];
    for (final root in sortedSiblings(rows, null)) {
      out.add((row: root, depth: 0));
      for (final child in sortedSiblings(rows, root.id)) {
        out.add((row: child, depth: 1));
      }
    }
    return out;
  }

  /// 扁平列表的拖拽落点若跨越了 parentId 或层级，一律忽略：
  /// 改变归属必须走明确的「改层级」操作，不能靠一次拖拽悄悄完成。
  Future<void> _reorderFlat(
    List<CategoryRow> rows,
    int oldIndex,
    int newIndex,
  ) async {
    final flat = _flatCategories(rows);
    if (oldIndex < 0 ||
        oldIndex >= flat.length ||
        newIndex < 0 ||
        newIndex >= flat.length) {
      return;
    }
    final moved = flat[oldIndex];
    final target = flat[newIndex];
    if (moved.row.parentId != target.row.parentId) return;
    final siblings = sortedSiblings(rows, moved.row.parentId);
    final from = siblings.indexWhere((CategoryRow r) => r.id == moved.row.id);
    final to = siblings.indexWhere((CategoryRow r) => r.id == target.row.id);
    if (from < 0 || to < 0) return;
    await _reorderSiblings(rows, moved.row.parentId, from, to);
  }

  Widget _categoryTile(
    BuildContext context,
    SketchPalette p,
    CategoryRow row, {
    required int depth,
    required bool canAddChild,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: depth * SketchSpace.lg + SketchSpace.lg,
        top: SketchSpace.sm,
        bottom: SketchSpace.sm,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _categoryActions(row, canAddChild),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      depth == 0 ? FontWeight.w700 : FontWeight.w400,
                  color: p.ink,
                ),
              ),
            ),
            Text(
              '${row.entryCount}',
              style: context.typography.monoStyle(
                size: 10.5,
                height: 1.4,
                color: p.muted,
              ),
            ),
            const SizedBox(width: SketchSpace.sm),
            Icon(Icons.drag_indicator, size: 14, color: p.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildTags(SketchPalette p, List<TagWithCount> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '标签',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: p.ink),
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
              for (var i = 0; i < tags.length; i++)
                GestureDetector(
                  onTap: () {
                    _tagActions(tags[i]);
                  },
                  child: SketchTag(
                    '${tags[i].name} · ${tags[i].count}',
                    tone: _toneForIndex(i),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildDuplicateNotice(
    SketchPalette p,
    List<List<TagWithCount>> groups,
  ) {
    return SketchFrame(
      radius: SketchRadii.c,
      fill: p.surface,
      borderColor: p.red,
      padding: const EdgeInsets.all(SketchSpace.md),
      tilt: SketchTilt.left,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '发现 ${groups.length} 组同名标签',
            style: TextStyle(fontSize: 12.5, color: p.ink),
          ),
          const SizedBox(height: SketchSpace.sm),
          SketchButton(
            label: '合并',
            tone: SketchTone.primary,
            dense: true,
            onPressed: () => _mergeDuplicates(groups),
          ),
        ],
      ),
    );
  }

  /// 标签云轮换三种色调。不按 count 调大小 ——
  /// 大小映射需要渲染前算比例，收益不抵复杂度。
  SketchTone _toneForIndex(int index) {
    const tones = <SketchTone>[
      SketchTone.primary,
      SketchTone.blue,
      SketchTone.ghost,
    ];
    return tones[index % tones.length];
  }
}
