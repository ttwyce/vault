/// 账号分组与组内字段模板（docs/11 §4.6）。
///
/// 分组复用 `category.kind = 6`，模板存 `category_field_template`；
/// 模板只带结构不带值，建号时用 [instantiateForGroup] 生成空 [CustomFields]。
/// 不碰同步通道（模板随 taxonomy 通道加密同步由平台层接）。
library;

import 'package:drift/drift.dart';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import '../../core/identity/uuid_v7.dart' show UuidV7;
import 'credential_models.dart';

/// 模板项（数据库行）。
class FieldTemplateRowView {
  const FieldTemplateRowView({
    required this.id,
    required this.label,
    required this.type,
    required this.secret,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final String type;
  final bool secret;
  final int sortOrder;
}

class CredentialGroupRepository {
  CredentialGroupRepository({
    required this.db,
    UuidV7? uuid,
  }) : _uuid = uuid ?? UuidV7();

  final VaultDatabase db;
  final UuidV7 _uuid;

  /// 只读列出账号分组（两级树，kind=6，未删除）。
  Future<List<CategoryRow>> groups() async =>
      (db.select(db.categories)
            ..where((t) =>
                t.kind.equals(EntryKind.credential.code) &
                t.deleted.equals(0))
            ..orderBy(<OrderClauseGenerator<dynamic>>[
              (t) => OrderingTerm.asc(t.sortOrder),
            ]))
          .get();

  /// 写入一条模板字段；label 重复时明确拒绝。
  Future<void> addTemplateField({
    required String categoryId,
    required String label,
    String type = 'text',
    bool secret = false,
    int sortOrder = 0,
    String? hlc,
  }) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('模板字段名不能为空');
    }
    final existing = await (db.select(db.categoryFieldTemplates)
          ..where((t) =>
              t.categoryId.equals(categoryId) & t.label.equals(trimmed)))
        .get();
    if (existing.isNotEmpty) {
      throw FormatException('该分组已有字段「$trimmed」');
    }
    await db.into(db.categoryFieldTemplates).insert(
          CategoryFieldTemplatesCompanion.insert(
            id: _uuid.next(),
            categoryId: categoryId,
            label: trimmed,
            type: Value<String>(type),
            secret: Value<int>(secret ? 1 : 0),
            sortOrder: Value<int>(sortOrder),
            hlc: hlc ?? '0000000000000000:0000:local',
          ),
        );
  }

  /// 读取某分组的模板字段（按 sortOrder）。
  Future<List<FieldTemplateRowView>> templateFields(
      String categoryId) async {
    final rows = await (db.select(db.categoryFieldTemplates)
          ..where((t) => t.categoryId.equals(categoryId))
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .get();
    return <FieldTemplateRowView>[
      for (final row in rows)
        FieldTemplateRowView(
          id: row.id,
          label: row.label,
          type: row.type,
          secret: row.secret != 0,
          sortOrder: row.sortOrder,
        ),
    ];
  }

  /// 建号时按组模板实例化空字段；无模板时返回空 [CustomFields]。
  Future<CustomFields> instantiateForGroup(String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty) {
      return const CustomFields(<CredentialField>[]);
    }
    final templates = await templateFields(categoryId);
    return CustomFields(<CredentialField>[
      for (var i = 0; i < templates.length; i++)
        CredentialField(
          id: templates[i].id,
          label: templates[i].label,
          value: '',
          type: _toFieldType(templates[i].type),
          secret: templates[i].secret,
          sort: templates[i].sortOrder,
        ),
    ]);
  }

  static CustomFieldType _toFieldType(String type) => switch (type) {
        'url' => CustomFieldType.url,
        'email' => CustomFieldType.email,
        'phone' => CustomFieldType.phone,
        'date' => CustomFieldType.date,
        'multiline' || 'number' => CustomFieldType.multiline,
        _ => CustomFieldType.text,
      };
}
