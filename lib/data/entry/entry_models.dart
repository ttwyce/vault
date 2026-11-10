import 'dart:convert';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';

/// 列表页展示用的一条条目。
///
/// 刻意不是 `EntryRow` 的别名：列表需要"展示标题"和"纯文本片段"，
/// 而 `EntryRow` 里存的是 `title`（可能为 null）和 `body`（Markdown 原文）。
/// 把派生逻辑放在这里，UI 就不需要每处都写一遍"标题为空怎么办、
/// 怎么把 Markdown 压成一行"。
class EntrySummary {
  const EntrySummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.snippet,
    required this.updatedAt,
    required this.deleted,
    this.tagNames = const <String>[],
  });

  final String id;
  final EntryKind kind;

  /// 展示标题：`entry.title` 为空时用正文第一行兜底。
  final String title;

  /// 正文纯文本前 N 字（Markdown 标记已剥掉），用于列表预览。
  final String snippet;

  final int updatedAt;
  final bool deleted;
  final List<String> tagNames;
}

/// 标签 + 使用次数。标签云用。
class TagWithCount {
  const TagWithCount({
    required this.id,
    required this.name,
    required this.count,
  });

  final String id;
  final String name;
  final int count;
}

/// 分类树节点。由 [buildCategoryTree] 从扁平行构造。
class CategoryNode {
  const CategoryNode({
    required this.id,
    required this.name,
    required this.children,
    this.entryCount = 0,
  });

  final String id;
  final String name;
  final List<CategoryNode> children;

  /// 本级（不含子级）条目数。
  final int entryCount;
}

/// 由 `entry.meta` 里读日记日期。
///
/// 日记的日期是**显式字段**，不是 `created_at`：
/// 补写、跨时区、"凌晨两点写的算前一天"都要求日期与创建时间分离
/// （见 docs/13 §3，`meta` 结构里的 `date: "YYYY-MM-DD"`）。
///
/// 返回 `null` 表示该条没有日期（可能是旧数据或非日记条目），
/// 调用方自行决定如何处理。
String? diaryDateOf(String? meta) {
  if (meta == null || meta.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(meta);
    if (decoded is! Map<String, Object?>) return null;
    final date = decoded['date'];
    return date is String && date.isNotEmpty ? date : null;
  } on FormatException {
    return null;
  }
}

/// 展示标题：`title` 为空时取正文第一行；正文也没有就统一叫「无标题」。
String displayTitle(String? title, String? body) {
  final trimmed = title?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;

  final firstLine = body?.trim().split('\n').firstWhere(
        (String line) => line.trim().isNotEmpty,
        orElse: () => '',
      );
  if (firstLine != null && firstLine.isNotEmpty) {
    // 第一行可能是 "# 标题" 这种 Markdown 标题，剥掉前缀
    return firstLine.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
  }
  return '无标题';
}

/// 把 Markdown 正文压成一段纯文本，用于列表预览。
///
/// 这是**刻意朴素**的实现：只剥常见标记，不做真正的 Markdown 渲染。
/// 列表页只需要"大致内容"，渲染交给编辑器/阅读器。
String plainSnippet(String? body, {int maxChars = 120}) {
  if (body == null || body.trim().isEmpty) return '';

  var text = body;
  // 图片整个去掉（预览里显示不了）
  text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');
  // 链接留文字
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (Match m) => m.group(1) ?? '',
  );
  // 行内代码
  text = text.replaceAll('`', '');
  // 强调
  text = text.replaceAll('**', '').replaceAll('__', '').replaceAll('~~', '');
  text = text.replaceAll(RegExp(r'(?<![*])\*(?![*])'), '');
  // 标题 / 列表 / 引用前缀
  text = text.replaceAllMapped(
    RegExp(r'^\s{0,3}(#{1,6}\s+|[-*+]\s+|\d+[.)]\s+|>\s?)', multiLine: true),
    (Match m) => '',
  );
  // 折叠空白（包括换行）
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (text.length <= maxChars) return text;
  return '${text.substring(0, maxChars)}…';
}

/// 把扁平的分类行拼成两级树。
///
/// 返回的是一级节点列表，每个节点带 `children`。
/// 孤立数据（parentId 指向不存在的分类）会被挂到根下，避免静默丢失。
List<CategoryNode> buildCategoryTree(List<CategoryRow> rows) {
  final byParent = <String?, List<CategoryRow>>{};
  for (final row in rows) {
    byParent.putIfAbsent(row.parentId, () => <CategoryRow>[]).add(row);
  }

  List<CategoryNode> build(String? parentId) {
    final children = byParent[parentId];
    if (children == null) return const <CategoryNode>[];
    // 排序：sortOrder 升序，再按 name 保证稳定
    children.sort((CategoryRow a, CategoryRow b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    return <CategoryNode>[
      for (final row in children)
        CategoryNode(
          id: row.id,
          name: row.name,
          children: build(row.id),
          entryCount: row.entryCount,
        ),
    ];
  }

  // 根 = 一级（parentId 为 null）+ 任何 parentId 对不上的孤儿
  final roots = <CategoryNode>[...build(null)];
  final known = <String>{for (final row in rows) row.id};
  for (final orphan in byParent.entries) {
    if (orphan.key != null && !known.contains(orphan.key)) {
      for (final row in orphan.value) {
        roots.add(CategoryNode(
          id: row.id,
          name: row.name,
          children: build(row.id),
          entryCount: row.entryCount,
        ));
      }
    }
  }
  return roots;
}
