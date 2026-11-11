import 'package:drift/drift.dart';

import '../db/vault_database.dart';
import '../entry/entry_models.dart';
import 'credential_groups.dart';
import 'credential_models.dart';
import 'hibp_client.dart';
import '../write/write_gateway.dart';
import 'totp.dart';

/// 密码列表展示用的一行。只带非敏感字段，绝不把 password 带进 UI。
class CredentialSummary {
  const CredentialSummary({
    required this.id,
    required this.title,
    required this.username,
    required this.hasTotp,
    required this.breached,
    required this.changedAt,
    this.totpCode,
  });

  final String id;
  final String title;
  final String? username;
  final bool hasTotp;
  final bool breached;
  final int? changedAt;

  /// 内存里由 TOTP 密钥生成的当前验证码；密钥本身绝不出仓库。
  final String? totpCode;

  String get letter {
    final source = title.trim().isEmpty ? '?' : title.trim();
    return source.substring(0, 1).toUpperCase();
  }
}

/// 密码健康只读仓库。
///
/// docs/11 §4.4：`credential_health` **只返回聚合统计**，任何工具都不返回
/// password / totp_secret / secret 字段的 value。这里对外只暴露
/// [CredentialHealth]；明文仅在内存里用于本地强度与重复指纹估算。
class CredentialRepository {
  CredentialRepository(this.db, this.gateway);

  final VaultDatabase db;
  final WriteGateway gateway;

  /// 本机已知的敏感值（密码 / TOTP 密钥 / secret 自定义字段的值）。
  ///
  /// 解密只在内存里发生；返回值只给 [CredentialGuard.containsSecret] 做
  /// 「是否夹带」判定，绝不写日志、报告或工具返回值。
  Future<Set<String>> knownSecretValues() async {
    final rows = await db.select(db.credentials).get();
    final out = <String>{};
    for (final row in rows) {
      for (final field in const <String>[
        'password',
        'totp_secret',
      ]) {
        final value = await _openField(
          row,
          field,
          field == 'password' ? row.password : row.totpSecret,
        );
        if (value.length >= 4) out.add(value);
      }
      try {
        final custom = CustomFields.fromJsonString(
          await _openField(row, 'custom_fields', row.customFields),
        );
        for (final item in custom.fields) {
          if (item.secret && item.value.length >= 4) out.add(item.value);
        }
      } on Object {
        // 坏字段不影响其它值的 Guard 判定。
      }
    }
    return Set<String>.unmodifiable(out);
  }

  /// 解出密码明文（只在内存里用于强度估算，绝不写日志 / 报告）。
  Future<String> _passwordOf(CredentialRow row) async {
    final raw = row.password;
    if (raw == null || raw.isEmpty) return '';
    // 旧数据可能是明文（M6 之前）；密文一定是 base64 且能 parse。
    // 只有「明显不是密文」才按明文算强度，绝不把解密失败当成明文。
    return _openField(row, 'password', raw);
  }

  static bool _looksLikeEnvelope(String raw) =>
      raw.length > 32 && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(raw);
  Future<String> _openField(
    CredentialRow row,
    String field,
    String? raw,
  ) async {
    if (raw == null || raw.isEmpty) return '';
    if (!_looksLikeEnvelope(raw)) return raw;
    try {
      return await gateway.openCredentialField(
        raw,
        credentialId: row.id,
        field: field,
      );
    } on Object {
      return '';
    }
  }

  Future<void> _writeField(
    String credentialId,
    String field,
    String plaintext, {
    bool updateChangedAt = false,
  }) async {
    final sealed = await gateway.sealCredentialField(
      credentialId: credentialId,
      field: field,
      plaintext: plaintext,
    );
    await (db.update(db.credentials)
          ..where((t) => t.id.equals(credentialId)))
        .write(CredentialsCompanion(
      password: field == 'password' ? Value<String?>(sealed) : const Value<String?>.absent(),
      totpSecret: field == 'totp_secret' ? Value<String?>(sealed) : const Value<String?>.absent(),
      customFields: field == 'custom_fields' ? Value<String?>(sealed) : const Value<String?>.absent(),
      passwordChangedAt: updateChangedAt
          ? Value<int?>(DateTime.now().millisecondsSinceEpoch)
          : const Value<int?>.absent(),
    ));
  }


  /// 写入密码（字段级加密）。明文绝不落库。
  Future<void> setPassword(String credentialId, String plaintext) =>
      _writeField(credentialId, 'password', plaintext, updateChangedAt: true);

  /// 写入 TOTP Base32 密钥（字段级加密）。
  Future<void> setTotpSecret(String credentialId, String base32Secret) {
    // 先校验格式，避免把垃圾密钥封进密文。
    decodeBase32(base32Secret);
    return _writeField(credentialId, 'totp_secret', base32Secret);
  }

  /// 写入自定义字段（含 secret:true 的项，整体加密）。
  Future<void> setCustomFields(String credentialId, CustomFields fields) =>
      _writeField(credentialId, 'custom_fields', fields.toJsonString());

  /// HIBP k-anonymity **离线判定**：平台层把 `/range/<prefix>` 的响应体
  /// 交给这里，完整哈希与密码明文都不出设备。返回是否泄露并更新缓存列。
  ///
  /// 不联网、不自动发请求；响应体缺失 / 过期 / 无法比对时返回 null，
  /// 绝不把「未知」误标成「安全」。
  Future<bool?> applyHibpResponse(
    String credentialId, {
    required String responseBody,
    required int nowMs,
    HibpChecker? checker,
  }) async {
    final row = await (db.select(db.credentials)
          ..where((t) => t.id.equals(credentialId)))
        .getSingleOrNull();
    if (row == null) return null;
    final password = await _openField(row, 'password', row.password);
    if (password.isEmpty) return null;

    final hibp = checker ?? HibpChecker();
    final request = hibp.requestFor(password);
    hibp.store(request.prefix, hibp.parseResponse(responseBody), nowMs);
    bool breached;
    try {
      breached = hibp.isBreached(request, nowMs);
    } on FormatException {
      return null;
    }
    await (db.update(db.credentials)
          ..where((t) => t.id.equals(credentialId)))
        .write(CredentialsCompanion(
      breached: Value<int>(breached ? 2 : 1),
    ));
    return breached;
  }

  /// 读回自定义字段（只在需要展示详情时调用）。
  Future<CustomFields> customFields(String credentialId) async {
    final row = await (db.select(db.credentials)
          ..where((t) => t.id.equals(credentialId)))
        .getSingleOrNull();
    if (row == null) return const CustomFields(<CredentialField>[]);
    return CustomFields.fromJsonString(
      await _openField(row, 'custom_fields', row.customFields),
    );
  }

  Future<List<CredentialHealthSample>> samples() async {
    final rows = await db.select(db.credentials).get();
    final out = <CredentialHealthSample>[];
    for (final row in rows) {
      final password = await _passwordOf(row);
      out.add(CredentialHealthSample(
        strength: estimatePasswordStrength(password),
        // 重复判定用本地 hashCode，绝不把明文写进任何报告 / 日志。
        passwordFingerprint: password.hashCode.toString(),
        leaked: row.breached == 2,
        favorite: false,
        passwordUpdatedAt: row.passwordChangedAt,
      ));
    }
    return out;
  }

  /// 智能分组（docs/09 §8）：用已有健康样本派生，不额外读明文。
  Future<List<CredentialGroupBucket>> smartGroups({
    required int nowMs,
    Set<String> favoriteIds = const <String>{},
    Map<String, String?> categoryById = const <String, String?>{},
  }) async {
    final rows = await db.select(db.credentials).get();
    final health = await samples();
    final ids = <String>[for (final row in rows) row.id];
    return groupCredentials(
      samplesForGroups(
        health,
        ids,
        favoriteIds: favoriteIds,
        categoryById: categoryById,
      ),
      nowMs: nowMs,
    );
  }

  Future<CredentialHealth> health({required int nowMs}) async =>
      computeCredentialHealth(samples: await samples(), nowMs: nowMs);

  /// 列表数据：`credential.id` = `entry.id`，标题从 entry 取。
  /// 只 select 非敏感列；已删除条目不显示。
  Future<List<CredentialSummary>> listSummaries({
    int limit = 200,
    int? nowMs,
  }) async {
    final rows = await (db.select(db.credentials)
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.asc(t.id),
          ])
          ..limit(limit))
        .get();
    final out = <CredentialSummary>[];
    for (final row in rows) {
      final entry = await (db.select(db.entries)
            ..where((t) => t.id.equals(row.id) & t.deleted.equals(0)))
          .getSingleOrNull();
      if (entry == null) continue;
      String? totpCode;
      final totpSecret = await _openField(row, 'totp_secret', row.totpSecret);
      if (totpSecret.isNotEmpty) {
        try {
          totpCode = generateTotp(
            base32Secret: totpSecret,
            nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
          );
        } on FormatException {
          totpCode = null;
        }
      }
      out.add(CredentialSummary(
        id: row.id,
        title: displayTitle(entry.title, entry.body),
        username: row.username,
        hasTotp: (row.totpSecret ?? '').isNotEmpty,
        breached: row.breached == 2,
        changedAt: row.passwordChangedAt,
        totpCode: totpCode,
      ));
    }
    return List<CredentialSummary>.unmodifiable(out);
  }
}
