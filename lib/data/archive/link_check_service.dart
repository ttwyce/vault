/// 死链 / 内容变更重检查的**编排层**（docs/05 §6 / docs/11 §3.4）。
///
/// 把纯判定函数串成一次可复现的检查：HTTP 状态分类 → simhash 变更 →
/// 是否回退 Wayback → 是否要落 link_check 证据 → 是否需要更新归档 meta。
/// 不发 HTTP 请求；真实状态与 simhash 由平台层传入。
library;

import 'package:drift/drift.dart';

import '../db/vault_database.dart';
import '../write/write_gateway.dart';
import 'archive_meta.dart';
import 'archive_policy.dart';

/// 30 天 = 30 × 24 × 3600 × 1000，写成字面量保留 const 默认值。
const int kRecheckIntervalMs = 2592000000;

class LinkCheckOutcome {
  const LinkCheckOutcome({
    required this.result,
    required this.changed,
    required this.tryWayback,
    required this.shouldRecord,
    required this.reasons,
  });

  final LinkCheckResult result;
  final bool changed;
  final bool tryWayback;
  final bool shouldRecord;
  final List<String> reasons;

  Map<String, Object?> toJson() => <String, Object?>{
        'result': result.name,
        'changed': changed,
        'try_wayback': tryWayback,
        'should_record': shouldRecord,
        'reasons': reasons,
      };
}

/// 纯判定：给定本次观察与上一次证据，算出该做什么。
LinkCheckOutcome decideLinkCheck({
  required int? httpStatus,
  required int retries,
  required String? previousSimhash,
  required String? currentSimhash,
  String? finalUrl,
  int? nowMs,
  int? previousCheckedAt,
  int recheckIntervalMs = kRecheckIntervalMs,
  RecheckPolicy policy = RecheckPolicy.monthly,
}) {
  final result = classifyHttpStatus(httpStatus, retries: retries);
  final contentChanged =
      hasContentChanged(previousSimhash, currentSimhash);
  final wayback = shouldTryWayback(result);
  final reasons = <String>[];

  var effective = result;
  if (contentChanged && result == LinkCheckResult.ok) {
    effective = LinkCheckResult.changed;
    reasons.add('simhash 汉明距离 > 3，内容有实质变化');
  }
  if (wayback) reasons.add('${result.name} → 建议回退 Wayback 快照');
  if (finalUrl != null && finalUrl.isNotEmpty) {
    reasons.add('最终跳转 URL：$finalUrl');
  }

  // 按该条目的 recheck_policy 定间隔（docs/11 §3.4）：
  // weekly 7 天 / monthly 30 天 / never 永不自动重检查。
  final intervalMs = switch (policy) {
    RecheckPolicy.weekly => 7 * 86400000,
    RecheckPolicy.monthly => kRecheckIntervalMs,
    RecheckPolicy.never => null,
  };
  final effectiveInterval = recheckIntervalMs == kRecheckIntervalMs
      ? intervalMs
      : recheckIntervalMs;
  var shouldRecord = true;
  if (effectiveInterval == null) {
    shouldRecord = false;
    reasons.add('策略为 never，不做自动重检查');
  } else if (nowMs != null &&
      previousCheckedAt != null &&
      nowMs - previousCheckedAt < effectiveInterval) {
    shouldRecord = false;
    reasons.add('距上次检查未过 ${effectiveInterval ~/ 86400000} 天，跳过本次落库');
  }

  return LinkCheckOutcome(
    result: effective,
    changed: contentChanged,
    tryWayback: wayback,
    shouldRecord: shouldRecord,
    reasons: List<String>.unmodifiable(reasons),
  );
}

/// 编排服务：判定 + 经 WriteGateway 落 link_check 证据。
class LinkCheckService {
  const LinkCheckService({
    required this.db,
    required this.gateway,
  });

  final VaultDatabase db;
  final WriteGateway gateway;

  Future<LinkCheckOutcome> run({
    required String entryId,
    required int? httpStatus,
    required int retries,
    required String? previousSimhash,
    required String? currentSimhash,
    String? finalUrl,
    required int nowMs,
    RecheckPolicy policy = RecheckPolicy.monthly,
  }) async {
    final previous = await (db.select(db.linkChecks)
          ..where((t) => t.entryId.equals(entryId))
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.desc(t.checkedAt),
          ])
          ..limit(1))
        .getSingleOrNull();
    final outcome = decideLinkCheck(
      httpStatus: httpStatus,
      retries: retries,
      previousSimhash: previous?.simhash ?? previousSimhash,
      currentSimhash: currentSimhash,
      finalUrl: finalUrl,
      nowMs: nowMs,
      previousCheckedAt: previous?.checkedAt,
      policy: policy,
    );
    if (outcome.shouldRecord) {
      await gateway.recordLinkCheck(
        entryId: entryId,
        checkedAt: nowMs,
        result: outcome.result.name,
        httpStatus: httpStatus,
        finalUrl: finalUrl,
        simhash: currentSimhash,
      );
    }
    return outcome;
  }
}
