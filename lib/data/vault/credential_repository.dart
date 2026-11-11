import '../db/vault_database.dart';
import 'credential_models.dart';

/// 密码健康只读仓库。
///
/// docs/11 §4.4：`credential_health` **只返回聚合统计**，任何工具都不返回
/// password / totp_secret / secret 字段的 value。这里对外只暴露
/// [CredentialHealth]；明文仅在内存里用于本地强度与重复指纹估算。
class CredentialRepository {
  CredentialRepository(this.db);

  final VaultDatabase db;

  Future<List<CredentialHealthSample>> samples() async {
    final rows = await db.select(db.credentials).get();
    return <CredentialHealthSample>[
      for (final row in rows)
        CredentialHealthSample(
          strength: estimatePasswordStrength(row.password ?? ''),
          // 重复判定用本地 hashCode，绝不把明文写进任何报告 / 日志。
          passwordFingerprint: (row.password ?? '').hashCode.toString(),
          leaked: row.breached == 2,
          favorite: false,
          passwordUpdatedAt: row.passwordChangedAt,
        ),
    ];
  }

  Future<CredentialHealth> health({required int nowMs}) async =>
      computeCredentialHealth(samples: await samples(), nowMs: nowMs);
}
