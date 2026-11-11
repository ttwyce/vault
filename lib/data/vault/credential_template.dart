/// 自定义字段模板与增删排序（docs/09 §8 / docs/13 §4）。
///
/// 纯逻辑：不碰数据库。所有操作返回新的 [CustomFields]，保持 append-only
/// 之外的编辑语义可控；`secret:true` 字段在任何输出里都不带 value。
library;

import 'credential_models.dart';

/// 一个字段模板项（只有结构，不预填真实值）。
class FieldTemplateItem {
  const FieldTemplateItem({
    required this.id,
    required this.label,
    required this.type,
    this.secret = false,
  });

  final String id;
  final String label;
  final CustomFieldType type;
  final bool secret;
}

/// 按分类复用的字段模板（docs/09 §8 组内字段模板）。
class FieldTemplate {
  const FieldTemplate(this.id, this.label, this.items);

  final String id;
  final String label;
  final List<FieldTemplateItem> items;

  /// 用模板生成一组空字段，sort 按模板顺序。
  CustomFields instantiate() => CustomFields(<CredentialField>[
        for (var i = 0; i < items.length; i++)
          CredentialField(
            id: items[i].id,
            label: items[i].label,
            value: '',
            type: items[i].type,
            secret: items[i].secret,
            sort: i,
          ),
      ]);
}

const List<FieldTemplate> kDefaultFieldTemplates = <FieldTemplate>[
  FieldTemplate('social', '社交账号', <FieldTemplateItem>[
    FieldTemplateItem(id: 'username', label: '用户名', type: CustomFieldType.text),
    FieldTemplateItem(id: 'email', label: '绑定邮箱', type: CustomFieldType.email),
    FieldTemplateItem(id: 'recovery', label: '恢复码', type: CustomFieldType.text, secret: true),
  ]),
  FieldTemplate('dev', '开发平台', <FieldTemplateItem>[
    FieldTemplateItem(id: 'username', label: '账号', type: CustomFieldType.text),
    FieldTemplateItem(id: 'url', label: '控制台地址', type: CustomFieldType.url),
    FieldTemplateItem(id: 'token', label: 'API Token', type: CustomFieldType.text, secret: true),
  ]),
  FieldTemplate('finance', '金融', <FieldTemplateItem>[
    FieldTemplateItem(id: 'card', label: '卡号后四位', type: CustomFieldType.text),
    FieldTemplateItem(id: 'phone', label: '预留手机', type: CustomFieldType.phone),
    FieldTemplateItem(id: 'pin', label: '查询密码', type: CustomFieldType.text, secret: true),
  ]),
];

FieldTemplate? templateById(String id) =>
    kDefaultFieldTemplates
        .where((FieldTemplate t) => t.id == id)
        .firstOrNull;

/// 不可变编辑操作。任何越界 / 重复 / 超上限都明确拒绝。
extension CustomFieldsEdit on CustomFields {
  CustomFields add(CredentialField field) {
    if (fields.length >= CustomFields.maxFields) {
      throw const FormatException('自定义字段不能超过 20 个');
    }
    if (fields.any((CredentialField f) => f.id == field.id)) {
      throw FormatException('自定义字段 id 重复：${field.id}');
    }
    return CustomFields(<CredentialField>[
      ...fields,
      field.copyWith(sort: fields.length),
    ]);
  }

  CustomFields remove(String id) => CustomFields(<CredentialField>[
        for (final field in fields)
          if (field.id != id) field,
      ]..sort((CredentialField a, CredentialField b) =>
          a.sort.compareTo(b.sort)));

  /// 把 [id] 移到 [newIndex]（0 起），其余顺序重排；越界 clamp。
  CustomFields reorder(String id, int newIndex) {
    final current = fields.toList()
      ..sort((CredentialField a, CredentialField b) =>
          a.sort.compareTo(b.sort));
    final oldIndex = current.indexWhere((CredentialField f) => f.id == id);
    if (oldIndex < 0) {
      throw FormatException('字段不存在：$id');
    }
    final moved = current.removeAt(oldIndex);
    final clamped = newIndex.clamp(0, current.length);
    current.insert(clamped, moved);
    return CustomFields(<CredentialField>[
      for (var i = 0; i < current.length; i++)
        current[i].copyWith(sort: i),
    ]);
  }

  /// secret 字段的展示掩码（只给字段名与类型，绝不返回 value）。
  List<String> maskedLabels() => <String>[
        for (final field in fields)
          if (field.secret) '${field.label} · ${field.type.name} · ••••',
      ];
}
