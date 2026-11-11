/// taxonomy 独立通道的 drift 端口。
///
/// 把 `EntitySyncEngine` 边界接到真实库：`oplog` 是 outbox，`sync_state`
/// 是条件写与 ETag diff 的依据，实体 / 隔离区 / 日志一律走
/// [WriteGateway]，不绕过唯一写入口。
library;

import 'package:drift/drift.dart';

import '../../core/sync/cloud_layout.dart';
import '../../core/sync/entity_sync_engine.dart';
import '../../core/sync/retention_policy.dart';
import '../../core/sync/sync_coordinator.dart';
import '../../core/sync/sync_payloads.dart';
import '../db/tables/log_tables.dart';
import '../db/vault_database.dart';
import '../write/write_gateway.dart';

class DbEntitySyncPort
    implements EntitySyncPort, TrashPurgeRunner, TombstoneLister {
  DbEntitySyncPort({
    required this.db,
    required this.gateway,
    required this.codec,
  });

  final VaultDatabase db;
  final WriteGateway gateway;

  /// 与正文同步器共用同一把 `K_name`：墓碑文件名必须能按 entry id 精确算出，
  /// 不能「看见任意一条墓碑 ETag 就认为本条已确认」。
  final AsyncSyncPayloadCodec codec;

  @override
  Future<List<EntityPendingOp>> pending({int limit = 500}) async {
    final rows = await (db.select(db.oplogs)
          ..where(
            (t) =>
                t.applied.equals(0) &
                t.entity.isIn(kSyncEntityTaxonomy.toList()),
          )
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.asc(t.seq),
          ])
          ..limit(limit))
        .get();
    return <EntityPendingOp>[
      for (final row in rows)
        if (row.payload != null)
          EntityPendingOp(
            seq: row.seq,
            entity: row.entity,
            entityId: row.entityId,
            payload: List<int>.from(row.payload!),
          ),
    ];
  }

  @override
  Future<Map<String, String?>> syncState() async {
    final rows = await db.select(db.syncStates).get();
    return <String, String?>{
      for (final row in rows) row.path: row.etag,
    };
  }

  @override
  Future<void> commitPushes(Iterable<SyncedOplogPush> pushes) =>
      gateway.recordEntityPushes(pushes, trigger: 'entity_push');

  @override
  Future<void> commitPulls(
    Iterable<RemoteTaxonomyFile> files,
    Map<String, String?> entityState,
    Map<String, List<int>> quarantinePayloads,
  ) =>
      gateway.applyEntityPull(
        files,
        entityState: entityState,
        quarantinePayloads: quarantinePayloads,
      );

  @override
  Future<void> commitQuarantine(Map<String, List<int>> payloads) =>
      gateway.quarantineOnly(payloads);

  /// 30 天到期清理任务。
  ///
  /// 只处理 `trash.expireAt <= now` 的行；每一行都先用保留策略闸门判定，
  /// 未通过的一律留到下次任务，绝不「按时间直接删」。
  Future<TrashPurgeReport> purgeExpiredTrash({required int nowMs}) async {
    final expired = await (db.select(db.trashRows)
          ..where((t) => t.expireAt.isSmallerOrEqualValue(nowMs)))
        .get();
    if (expired.isEmpty) {
      return const TrashPurgeReport(
        purged: <String>[],
        skipped: <String, String>{},
      );
    }

    final allState = await syncState();
    final pendingRows = await gateway.pending();
    final pendingIds = <String>{
      for (final row in pendingRows) row.entityId,
    };
    final unconfirmedDeletes = <String>{
      for (final row in pendingRows)
        if (row.entity == SyncEntity.entry && row.op == OplogOp.delete.code)
          row.entityId,
    };
    final purged = <String>[];
    final skipped = <String, String>{};

    for (final trash in expired) {
      final entry = await (db.select(db.entries)
            ..where((t) => t.id.equals(trash.entryId)))
          .getSingleOrNull();
      final stillDeleted = entry != null && entry.deleted != 0;
      final verdict = evaluateTrashPurge(
        nowMs: nowMs,
        expireAt: trash.expireAt,
        entryStillDeleted: stillDeleted,
        tombstoneConfirmed: await _tombstoneConfirmed(
          allState,
          trash.entryId,
        ),
        hasPendingOps: pendingIds.contains(trash.entryId),
        hasUnconfirmedDelete: unconfirmedDeletes.contains(trash.entryId),
      );
      if (verdict.canPurge) {
        await gateway.purgeTrashEntry(trash.entryId);
        purged.add(trash.entryId);
      } else {
        skipped[trash.entryId] = verdict.reason;
      }
    }

    return TrashPurgeReport(
      purged: List<String>.unmodifiable(purged),
      skipped: Map<String, String>.unmodifiable(skipped),
    );
  }

  /// 顶层调度器的本地清理边界：只返回真正被清空的 id。
  @override
  Future<List<String>> purgedEntryIds({required int nowMs}) async =>
      (await purgeExpiredTrash(nowMs: nowMs)).purged;

  /// 从已确认的 `sync_state` 里列出云端墓碑。
  ///
  /// `deleted_at` 用 `sync_state.updatedAt`（确认写墓碑的时间）兜底；
  /// 没有时间信息的记录一律返回 0（视为未过期），绝不自作主张按「看不见
  /// 就算老」来删。真实接入层可以换成 GET 墓碑信封读 `deleted_at`。
  @override
  Future<List<TombstoneRecord>> tombstones() async {
    final rows = await (db.select(db.syncStates)
          ..where((t) => t.path.like('${CloudLayout.root}/tombstones/%')))
        .get();
    return <TombstoneRecord>[
      for (final row in rows)
        TombstoneRecord(path: row.path, deletedAt: row.updatedAt ?? 0),
    ];
  }

  /// 只有「这一条 entry 对应的墓碑路径」拿到服务端 ETag 才算确认。
  Future<bool> _tombstoneConfirmed(
    Map<String, String?> state,
    String entryId,
  ) async {
    final name = await codec.hashedName(entryId);
    return isTombstoneConfirmed(state, CloudLayout.tombstonePath(name));
  }
}

/// 一次清理任务的结果，供 UI / 日志诊断。
class TrashPurgeReport {
  const TrashPurgeReport({
    required this.purged,
    required this.skipped,
  });

  final List<String> purged;
  final Map<String, String> skipped;
}
