import 'package:drift/drift.dart';

import '../db/vault_database.dart';
import '../entry/entry_models.dart';
import '../write/write_gateway.dart';
import 'credential_models.dart';
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

  /// 解出密码明文（只在内存里用于强度估算，绝不写日志 / 报告）。
  Future<String> _passwordOf(CredentialRow row) async {
    final raw = row.password;
    if (raw == null || raw.isEmpty) return '';
    // 旧数据可能是明文（M6 之前）；密文一定是 base64 且能 parse。
    // 只有「明显不是密文」才按明文算强度，绝不把解密失败当成明文。
    if (!_looksLikeEnvelope(raw)) return raw;
    try {
      return await gateway.openCredentialField(
        raw,
        credentialId: row.id,
        field: 'password',
      );
    } on Object {
      return '';
    }
  }

  static bool _looksLikeEnvelope(String raw) =>
      raw.length > 32 && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(raw);

  /// 写入密码（字段级加密）。明文绝不落库。
  Future<void> setPassword(String credentialId, String plaintext) async {
    final sealed = await gateway.sealCredentialField(
      credentialId: credentialId,
      field: 'password',
      plaintext: plaintext,
    );
    await (db.update(db.credentials)
          ..where((t) => t.id.equals(credentialId)))
        .write(CredentialsCompanion(
      password: Value<String?>(sealed),
      passwordChangedAt: Value<int?>(DateTime.now().millisecondsSinceEpoch),
    ));
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
      final totpSecret = row.totpSecret;
      if (totpSecret != null && totpSecret.isNotEmpty) {
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
