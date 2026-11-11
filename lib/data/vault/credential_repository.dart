import 'package:drift/drift.dart';

import '../db/vault_database.dart';
import '../entry/entry_models.dart';
import 'credential_models.dart';

/// 密码列表展示用的一行。只带非敏感字段，绝不把 password 带进 UI。
class CredentialSummary {
  const CredentialSummary({
    required this.id,
    required this.title,
    required this.username,
    required this.hasTotp,
    required this.breached,
    required this.changedAt,
  });

  final String id;
  final String title;
  final String? username;
  final bool hasTotp;
  final bool breached;
  final int? changedAt;

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

  /// 列表数据：`credential.id` = `entry.id`，标题从 entry 取。
  /// 只 select 非敏感列；已删除条目不显示。
  Future<List<CredentialSummary>> listSummaries({int limit = 200}) async {
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
      out.add(CredentialSummary(
        id: row.id,
        title: displayTitle(entry.title, entry.body),
        username: row.username,
        hasTotp: (row.totpSecret ?? '').isNotEmpty,
        breached: row.breached == 2,
        changedAt: row.passwordChangedAt,
      ));
    }
    return List<CredentialSummary>.unmodifiable(out);
  }
}
