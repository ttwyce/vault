/// Passkey 本地登记（docs/11 §4.7 二期）。
///
/// **不是 WebAuthn 实现**：真正的创建 / 签名需要系统认证器与平台通道。
/// 本层把用户在设备上已有的 Passkey 元数据登记到账号的自定义字段里：
/// relying party、credential id、公钥指纹、用户句柄、创建时间。
/// 私钥材料绝不进入 Vault，也不写日志；登记项标为 secret 走字段级加密。
library;

import 'dart:convert';

import 'credential_models.dart';
import 'credential_template.dart';

class PasskeyRecord {
  const PasskeyRecord({
    required this.id,
    required this.relyingParty,
    required this.credentialId,
    required this.publicKeyFingerprint,
    required this.userHandle,
    required this.createdAtMs,
  });

  final String id;
  final String relyingParty;
  final String credentialId;
  final String publicKeyFingerprint;
  final String userHandle;
  final int createdAtMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'rp': relyingParty,
        'credential_id': credentialId,
        'public_key_fingerprint': publicKeyFingerprint,
        'user_handle': userHandle,
        'created_at': createdAtMs,
      };

  static PasskeyRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, Object?>.from(raw);
    final id = map['id'];
    final rp = map['rp'];
    final credentialId = map['credential_id'];
    final fingerprint = map['public_key_fingerprint'];
    final handle = map['user_handle'];
    final created = map['created_at'];
    if (id is! String || rp is! String || credentialId is! String ||
        fingerprint is! String || handle is! String || created is! int) {
      return null;
    }
    return PasskeyRecord(
      id: id,
      relyingParty: rp,
      credentialId: credentialId,
      publicKeyFingerprint: fingerprint,
      userHandle: handle,
      createdAtMs: created,
    );
  }
}

const String kPasskeyFieldPrefix = 'passkey:';

bool isPasskeyField(CredentialField field) =>
    field.id.startsWith(kPasskeyFieldPrefix) && field.secret;

/// 把一条登记写进 custom_fields；同 id 覆盖、超上限明确抛错。
CustomFields upsertPasskey(CustomFields current, PasskeyRecord record) {
  final id = '$kPasskeyFieldPrefix${record.id}';
  final field = CredentialField(
    id: id,
    label: 'Passkey · ${record.relyingParty}',
    value: jsonEncode(record.toJson()),
    type: CustomFieldType.text,
    secret: true,
    sort: current.fields.length,
  );
  final remaining = <CredentialField>[
    for (final item in current.fields)
      if (item.id != id) item,
  ];
  if (remaining.length >= CustomFields.maxFields) {
    throw const FormatException('自定义字段不能超过 20 个');
  }
  return CustomFields(<CredentialField>[...remaining, field]);
}

CustomFields removePasskey(CustomFields current, String recordId) =>
    current.remove('$kPasskeyFieldPrefix$recordId');

List<PasskeyRecord> passkeysIn(CustomFields fields) => <PasskeyRecord>[
      for (final field in fields.fields)
        if (isPasskeyField(field))
          if (PasskeyRecord.fromJson(_decode(field.value))
              case PasskeyRecord record)
            record,
    ];

Object? _decode(String raw) {
  try {
    return jsonDecode(raw);
  } on Object {
    return null;
  }
}
