/// 密码条目 `entry.meta` 轻量标记（docs/13 §3 kind=6）。
///
/// 业务字段都在 `credential` 表；这里只放 `category_hint` / `has_totp`，
/// 便于列表快速筛选，不复制任何敏感值。
library;

import 'dart:convert';

class CredentialMeta {
  const CredentialMeta({
    this.categoryHint,
    this.hasTotp = false,
  });

  final String? categoryHint;
  final bool hasTotp;

  Map<String, Object?> toJson() => <String, Object?>{
        if (categoryHint != null) 'category_hint': categoryHint,
        'has_totp': hasTotp,
      };

  String toJsonString() => jsonEncode(toJson());

  /// 坏 JSON / 非对象回默认，不让旧数据把列表搞崩。
  factory CredentialMeta.fromJson(Object? raw) {
    Object? decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } on Object {
        return const CredentialMeta();
      }
    }
    if (decoded is! Map) return const CredentialMeta();
    final map = Map<String, Object?>.from(decoded);
    final hint = map['category_hint'];
    return CredentialMeta(
      categoryHint: hint is String && hint.trim().isNotEmpty
          ? hint.trim()
          : null,
      hasTotp: map['has_totp'] == true,
    );
  }

  CredentialMeta copyWith({
    String? categoryHint,
    bool? hasTotp,
    bool clearCategoryHint = false,
  }) =>
      CredentialMeta(
        categoryHint:
            clearCategoryHint ? null : (categoryHint ?? this.categoryHint),
        hasTotp: hasTotp ?? this.hasTotp,
      );
}
