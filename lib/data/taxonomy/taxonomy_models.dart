import 'dart:convert';

import '../../core/crypto/canonical.dart';
import '../db/tables/entry_tables.dart';
import '../entry/entry_models.dart';

/// 分类与标签的硬规则（docs/11 §2）。
///
/// 这几条不是"建议"：分类放开到三级、标签放开到多选树，用户会陷入
/// 整理瘫痪，AI 也失去"这条该放哪"的判断依据。所以规则收敛到一个地方，
/// 写入口和 UI 都从这里读，不许各自写魔法数字。
abstract final class TaxonomyRules {
  const TaxonomyRules._();

  /// 一条条目最多 8 个标签。
  static const int maxTagsPerEntry = 8;

  /// 分类最多两级。
  static const int maxCategoryDepth = 2;

  /// 名称长度上限（按 UTF-16 code unit 计，够用且不引入 characters 依赖）。
  static const int maxNameLength = 40;
}

/// 名称规范化：去首尾空白、折叠内部连续空白、限长。
///
/// **唯一性与同名合并都必须基于这个结果**，否则「工作 」和「工作」
/// 会变成两个标签，合并向导也认不出来。
String normalizeTaxonomyName(String raw) {
  final folded = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (folded.length <= TaxonomyRules.maxNameLength) return folded;
  return folded.substring(0, TaxonomyRules.maxNameLength);
}

/// 同名比较用的键：英文大小写不敏感（中文不受影响）。
String taxonomyNameKey(String name) =>
    normalizeTaxonomyName(name).toLowerCase();

/// 同名标签分组。只返回长度 ≥ 2 的组，组内按使用次数降序。
///
/// 合并向导拿到的第一个元素就是「保留谁」的默认答案 —— 取 usage 最大的，
/// 因为它的关联最多，改指成本最小（docs/11 §2.5）。
List<List<TagWithCount>> duplicateTagGroups(Iterable<TagWithCount> tags) {
  final groups = <String, List<TagWithCount>>{};
  for (final tag in tags) {
    groups
        .putIfAbsent(taxonomyNameKey(tag.name), () => <TagWithCount>[])
        .add(tag);
  }

  final dupes = <List<TagWithCount>>[];
  for (final group in groups.values) {
    if (group.length < 2) continue;
    group.sort((TagWithCount a, TagWithCount b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.id.compareTo(b.id);
    });
    dupes.add(group);
  }
  dupes.sort((List<TagWithCount> a, List<TagWithCount> b) =>
      taxonomyNameKey(a.first.name).compareTo(taxonomyNameKey(b.first.name)));
  return dupes;
}

/// 一条 taxonomy 实体的快照，封进 oplog payload 与云端 item 文件。
///
/// 与 `EntrySnapshot` 的区别：category / tag / entry_taxonomy 三张表的字段
/// 完全不同，但它们**共享同一套信封格式**（明文头 {entity,id,rev} +
/// AAD = 头部字节 + XChaCha20-Poly1305）。同步层只需要认 entity，不需要
/// 为每种实体写一套解析器。
///
/// [fields] 是各实体自己的业务字段（name / kind / parent_id / tag_ids…），
/// 用 Canonical JSON 序列化，保证两台设备算出的字节完全一致。
class TaxonomySnapshot {
  const TaxonomySnapshot({
    required this.entity,
    required this.id,
    required this.rev,
    required this.hlc,
    required this.updatedAt,
    required this.deleted,
    required this.fields,
  });

  final String entity;
  final String id;
  final int rev;
  final String hlc;
  final int updatedAt;
  final bool deleted;
  final Map<String, Object?> fields;

  Map<String, Object?> toJson() => <String, Object?>{
        'entity': entity,
        'id': id,
        'rev': rev,
        'hlc': hlc,
        'updated_at': updatedAt,
        'deleted': deleted ? 1 : 0,
        'fields': fields,
      };

  List<int> toCanonicalBytes() => utf8.encode(Canonical.json(toJson()));

  static TaxonomySnapshot fromJson(Map<String, Object?> json) {
    final entity = json['entity'];
    final id = json['id'];
    final rev = json['rev'];
    final hlc = json['hlc'];
    final updatedAt = json['updated_at'];
    final deleted = json['deleted'];
    final fields = json['fields'];
    if (entity is! String ||
        id is! String ||
        rev is! int ||
        hlc is! String ||
        updatedAt is! int ||
        deleted is! int ||
        fields is! Map) {
      throw const FormatException('taxonomy 快照字段类型不合法');
    }
    return TaxonomySnapshot(
      entity: entity,
      id: id,
      rev: rev,
      hlc: hlc,
      updatedAt: updatedAt,
      deleted: deleted != 0,
      fields: Map<String, Object?>.from(fields),
    );
  }

  String? get name => fields['name'] as String?;
}

/// taxonomy 的写入意图。
enum TaxonomyMutation { create, update, delete, restore, merge }

/// 分类写入。
///
/// `update` 与 `EntryWrite.update` 一样是**整体替换**：`parentId` 传 null
/// 表示「设为一级分类」，不是「保持不变」。调用方先读旧行再原样传回。
class CategoryWrite {
  const CategoryWrite._({
    required this.mutation,
    this.id,
    this.name,
    this.kind,
    this.parentId,
    this.sortOrder,
  });

  factory CategoryWrite.create({
    String? id,
    required String name,
    EntryKind kind = EntryKind.note,
    String? parentId,
    int sortOrder = 0,
  }) {
    return CategoryWrite._(
      mutation: TaxonomyMutation.create,
      id: id,
      name: name,
      kind: kind.code,
      parentId: parentId,
      sortOrder: sortOrder,
    );
  }

  factory CategoryWrite.update({
    required String id,
    required String name,
    String? parentId,
    int sortOrder = 0,
  }) {
    return CategoryWrite._(
      mutation: TaxonomyMutation.update,
      id: id,
      name: name,
      parentId: parentId,
      sortOrder: sortOrder,
    );
  }

  factory CategoryWrite.delete({required String id}) =>
      CategoryWrite._(mutation: TaxonomyMutation.delete, id: id);

  factory CategoryWrite.restore({required String id}) =>
      CategoryWrite._(mutation: TaxonomyMutation.restore, id: id);

  final TaxonomyMutation mutation;
  final String? id;
  final String? name;
  final int? kind;
  final String? parentId;
  final int? sortOrder;
}

/// 标签写入。
class TagWrite {
  const TagWrite._({
    required this.mutation,
    this.id,
    this.name,
    this.sourceId,
    this.targetId,
  });

  factory TagWrite.create({String? id, required String name}) =>
      TagWrite._(mutation: TaxonomyMutation.create, id: id, name: name);

  factory TagWrite.rename({required String id, required String name}) =>
      TagWrite._(mutation: TaxonomyMutation.update, id: id, name: name);

  factory TagWrite.delete({required String id}) =>
      TagWrite._(mutation: TaxonomyMutation.delete, id: id);

  factory TagWrite.restore({required String id}) =>
      TagWrite._(mutation: TaxonomyMutation.restore, id: id);

  /// 同名合并：把 [sourceId] 的关联全部改指 [targetId]，然后软删 source。
  factory TagWrite.merge({
    required String sourceId,
    required String targetId,
  }) =>
      TagWrite._(
        mutation: TaxonomyMutation.merge,
        sourceId: sourceId,
        targetId: targetId,
      );

  final TaxonomyMutation mutation;
  final String? id;
  final String? name;
  final String? sourceId;
  final String? targetId;
}

/// 一次 taxonomy 写入的结果。
class TaxonomyWriteResult {
  const TaxonomyWriteResult({
    required this.snapshot,
    required this.oplogSeq,
    required this.changed,
    this.relatedOplogSeqs = const <int>[],
  });

  final TaxonomySnapshot snapshot;

  /// `changed=false` 时为 -1（幂等空操作不写 oplog）。
  final int oplogSeq;
  final bool changed;

  /// 同一操作里附带产生的其它 oplog 序号。
  /// 例如删除父分类时把子分类提升为一级、合并标签时更新 target 的 usageCount。
  final List<int> relatedOplogSeqs;
}
