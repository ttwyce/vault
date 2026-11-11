/// 密码模块的纯判定层（docs/11 §4 / docs/09 §8）。
///
/// 不碰数据库、不碰剪贴板、不碰网络：只做「自定义字段结构与脱敏、
/// 密码强度、健康报告统计、CredentialGuard 代码级拦截」。
/// docs/11 §4.4 三条硬约束在这里被表达成类型与纯函数：
/// 1. `secret:true` 字段与密码同级对待
/// 2. AI 永远读不到明文（`credential_health` 只返回统计）
/// 3. 备注默认 L0 端侧，云端需逐次授权
library;

import 'dart:convert';

/// 自定义字段类型。
enum CustomFieldType { text, url, email, phone, date, multiline }

class CredentialField {
  const CredentialField({
    required this.id,
    required this.label,
    required this.value,
    required this.type,
    required this.secret,
    required this.sort,
  });

  final String id;
  final String label;
  final String value;
  final CustomFieldType type;
  final bool secret;
  final int sort;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'value': value,
        'type': type.name,
        'secret': secret,
        'sort': sort,
      };

  factory CredentialField.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('自定义字段不是 JSON 对象');
    }
    final map = Map<String, Object?>.from(raw);
    final id = map['id'];
    final label = map['label'];
    final value = map['value'];
    final typeRaw = map['type'];
    final type = CustomFieldType.values
        .where((CustomFieldType t) => t.name == typeRaw)
        .firstOrNull;
    if (id is! String || label is! String || value is! String || type == null) {
      throw const FormatException('自定义字段字段类型不合法');
    }
    return CredentialField(
      id: id,
      label: label,
      value: value,
      type: type,
      secret: map['secret'] == true,
      sort: (map['sort'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `credential.custom_fields` 的加密前明文结构。
class CustomFields {
  const CustomFields(this.fields);

  final List<CredentialField> fields;

  static const int maxFields = 20;

  String toJsonString() => jsonEncode(<Object?>[
        for (final field in fields) field.toJson(),
      ]);

  factory CustomFields.fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const CustomFields(<CredentialField>[]);
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('custom_fields 必须是数组');
    }
    final fields = <CredentialField>[
      for (final item in decoded) CredentialField.fromJson(item),
    ];
    if (fields.length > maxFields) {
      throw const FormatException('自定义字段不能超过 20 个');
    }
    final ids = <String>{};
    for (final field in fields) {
      if (!ids.add(field.id)) {
        throw FormatException('自定义字段 id 重复：${field.id}');
      }
    }
    return CustomFields(List<CredentialField>.unmodifiable(fields));
  }

  /// docs/11 §4.4：`get_credential` 工具返回时整体脱敏，只返回字段名。
  List<String> redactedLabels() => List<String>.unmodifiable(
        fields.map((CredentialField f) => f.label),
      );
}

/// 密码强度 0~4（docs/13 §2.3 `credential.strength`）。
/// 纯本地估算，绝不把密码发出设备。
int estimatePasswordStrength(String password) {
  if (password.isEmpty) return 0;
  var score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (password.length >= 16) score++;
  final hasLower = RegExp(r'[a-z]').hasMatch(password);
  final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
  final variety = <bool>[hasLower, hasUpper, hasDigit, hasSymbol]
      .where((bool v) => v)
      .length;
  if (variety >= 2) score++;
  if (variety >= 3) score++;
  // 常见弱模式直接压分，不靠「长度够」蒙混过关。
  if (RegExp(r'^(.)\1*$').hasMatch(password) ||
      RegExp(r'^(?:0123|1234|abcd|password|qwerty|admin)[0-9!@#$%^&*]*$',
              caseSensitive: false)
          .hasMatch(password)) {
    return 0;
  }
  return score.clamp(0, 4);
}

/// 健康报告（docs/09 §8）：只含统计，**无任何明文外发**。
class CredentialHealth {
  const CredentialHealth({
    required this.total,
    required this.weak,
    required this.reused,
    required this.leaked,
    required this.outdated,
    required this.favorite,
  });

  final int total;
  final int weak;
  final int reused;
  final int leaked;
  final int outdated;
  final int favorite;

  Map<String, int> toJson() => <String, int>{
        'total': total,
        'weak': weak,
        'reused': reused,
        'leaked': leaked,
        'outdated': outdated,
        'favorite': favorite,
      };
}

/// 单条凭证用于健康统计的输入。注意：**不含密码明文**，只含本地已算好的
/// 强度与指纹（sha256 前若干位），重复判定在内存里比较指纹即可。
class CredentialHealthSample {
  const CredentialHealthSample({
    required this.strength,
    required this.passwordFingerprint,
    required this.leaked,
    required this.favorite,
    required this.passwordUpdatedAt,
  });

  final int strength;
  final String passwordFingerprint;
  final bool leaked;
  final bool favorite;
  final int? passwordUpdatedAt;
}

CredentialHealth computeCredentialHealth({
  required Iterable<CredentialHealthSample> samples,
  required int nowMs,
  Duration staleAfter = const Duration(days: 180),
}) {
  final list = samples.toList(growable: false);
  final fingerprints = <String, int>{};
  for (final sample in list) {
    fingerprints[sample.passwordFingerprint] =
        (fingerprints[sample.passwordFingerprint] ?? 0) + 1;
  }
  var weak = 0;
  var reused = 0;
  var leaked = 0;
  var outdated = 0;
  var favorite = 0;
  for (final sample in list) {
    if (sample.strength <= 1) weak++;
    if (fingerprints[sample.passwordFingerprint]! > 1) reused++;
    if (sample.leaked) leaked++;
    if (sample.favorite) favorite++;
    final updated = sample.passwordUpdatedAt;
    if (updated == null || nowMs - updated > staleAfter.inMilliseconds) {
      outdated++;
    }
  }
  return CredentialHealth(
    total: list.length,
    weak: weak,
    reused: reused,
    leaked: leaked,
    outdated: outdated,
    favorite: favorite,
  );
}

/// HIBP k-anonymity（docs/09 §8）：只发 SHA1 前 5 位。
String hibpPrefix(String sha1Hex) {
  if (!RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(sha1Hex)) {
    throw const FormatException('需要 40 位十六进制 SHA1');
  }
  return sha1Hex.substring(0, 5).toUpperCase();
}

/// 在本地用「后缀集合」判断是否泄露，不上传完整哈希。
bool hibpHit(String sha1Hex, Set<String> suffixes) {
  final lower = sha1Hex.toLowerCase();
  return suffixes.contains(lower.substring(5).toUpperCase());
}

/// CredentialGuard（docs/11 §4.4 / docs/07 §4.3）：代码级拦截，不靠 prompt。
///
/// 任何要进 prompt / 日志 / 工具返回值的文本，先过这里。
abstract final class CredentialGuard {
  /// 敏感字段名（含自定义字段的 label 与值）。
  static const Set<String> sensitiveKeys = <String>{
    'password',
    'totp_secret',
    'secret',
    'value',
    'custom_fields',
  };

  /// 把工具返回值里的敏感字段整体替换成占位符。
  static Map<String, Object?> redact(Map<String, Object?> raw) {
    return Map<String, Object?>.fromEntries(
      raw.entries.map((MapEntry<String, Object?> entry) {
        if (_isSensitive(entry.key)) {
          return MapEntry<String, Object?>(entry.key, '[已隐藏]');
        }
        if (entry.value is Map) {
          return MapEntry<String, Object?>(
            entry.key,
            redact(Map<String, Object?>.from(entry.value as Map)),
          );
        }
        return entry;
      }),
    );
  }

  /// 扫描一段文本是否夹带了已知明文（用于 prompt / 日志的断言）。
  /// 只做包含检测，不修改文本；命中即拒绝发送。
  static bool containsSecret(String text, Iterable<String> secrets) {
    for (final secret in secrets) {
      if (secret.isNotEmpty && text.contains(secret)) return true;
    }
    return false;
  }

  /// 备注默认 L0：未经逐次授权不得进云端上下文。
  static bool allowNotesInCloud({required bool explicitlyAuthorized}) =>
      explicitlyAuthorized;

  static bool _isSensitive(String key) {
    final lower = key.toLowerCase();
    return sensitiveKeys.contains(lower) ||
        lower.startsWith('secret_') ||
        lower.endsWith('_secret');
  }
}
