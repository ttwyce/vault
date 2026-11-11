/// 同步分片游标（docs/04 §10「超出预算 → 保存进度，下次续跑」）。
///
/// 不碰网络、不写数据库：只定义「预算耗尽时保存什么、恢复时从哪里接着跑、
/// 哪些路径已完成不能重复推」。真实落库由 SyncWorkspaceStore 注入。
library;

import 'sync_state_machine.dart' show SyncPhase;

class SyncCheckpoint {
  const SyncCheckpoint({
    required this.phase,
    required this.pendingPaths,
    required this.completedPaths,
    required this.watermark,
    required this.createdAtMs,
  });

  final SyncPhase phase;
  final List<String> pendingPaths;
  final List<String> completedPaths;
  final String watermark;
  final int createdAtMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'phase': phase.name,
        'pending': pendingPaths,
        'completed': completedPaths,
        'watermark': watermark,
        'created_at': createdAtMs,
      };

  factory SyncCheckpoint.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('同步游标不是 JSON 对象');
    }
    final phaseName = raw['phase'];
    final phase = SyncPhase.values
        .where((SyncPhase p) => p.name == phaseName)
        .firstOrNull;
    final pending = raw['pending'];
    final completed = raw['completed'];
    final watermark = raw['watermark'];
    final createdAt = raw['created_at'];
    if (phase == null || pending is! List || completed is! List ||
        watermark is! String || createdAt is! num) {
      throw const FormatException('同步游标字段不合法');
    }
    return SyncCheckpoint(
      phase: phase,
      pendingPaths:
          pending.map((Object? v) => v.toString()).toList(growable: false),
      completedPaths:
          completed.map((Object? v) => v.toString()).toList(growable: false),
      watermark: watermark,
      createdAtMs: createdAt.toInt(),
    );
  }

  bool get hasPending => pendingPaths.isNotEmpty;
}

/// 预算耗尽时生成游标。已完成的不重复入列，待处理保持原有顺序。
SyncCheckpoint? createCheckpoint({
  required SyncPhase phase,
  required List<String> remainingPaths,
  required List<String> completedPaths,
  required String watermark,
  required int nowMs,
  required bool budgetExceeded,
}) {
  if (!budgetExceeded || remainingPaths.isEmpty) return null;
  final done = completedPaths.toSet();
  return SyncCheckpoint(
    phase: phase,
    pendingPaths: <String>[
      for (final path in remainingPaths)
        if (!done.contains(path)) path,
    ],
    completedPaths: List<String>.unmodifiable(done.toList()),
    watermark: watermark,
    createdAtMs: nowMs,
  );
}

/// 恢复判定：水位没变且游标未过期（默认 7 天）才续跑；否则全量重来。
enum CheckpointResume { resume, restart }

class CheckpointResumePlan {
  const CheckpointResumePlan({
    required this.action,
    required this.reason,
    required this.paths,
  });

  final CheckpointResume action;
  final String reason;
  final List<String> paths;

  bool get shouldResume => action == CheckpointResume.resume;
}

CheckpointResumePlan planCheckpointResume(
  SyncCheckpoint? checkpoint, {
  required String currentWatermark,
  required int nowMs,
  int maxAgeMs = 604800000,
}) {
  if (checkpoint == null || !checkpoint.hasPending) {
    return const CheckpointResumePlan(
      action: CheckpointResume.restart,
      reason: '没有未完成的分片',
      paths: <String>[],
    );
  }
  if (checkpoint.watermark != currentWatermark) {
    return const CheckpointResumePlan(
      action: CheckpointResume.restart,
      reason: '云端水位已前进，旧游标作废，需重新发现',
      paths: <String>[],
    );
  }
  if (nowMs - checkpoint.createdAtMs > maxAgeMs) {
    return const CheckpointResumePlan(
      action: CheckpointResume.restart,
      reason: '游标超过 7 天，保守重跑',
      paths: <String>[],
    );
  }
  return CheckpointResumePlan(
    action: CheckpointResume.resume,
    reason: '从 ${checkpoint.phase.name} 续跑 ${checkpoint.pendingPaths.length} 项',
    paths: List<String>.unmodifiable(checkpoint.pendingPaths),
  );
}
