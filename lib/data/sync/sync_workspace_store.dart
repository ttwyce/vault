/// 把真实 drift 库装配成 `SyncWorkspace`，并把一次同步结果原子写回。
///
/// 这里不新增表、不跑 codegen：`sync_state` / `device_watermark` /
/// `oplog` / `entry_history` / `trash` 都用现有表；隔离区由
/// [WriteGateway] 用原生 SQL 建表。实体写入始终走唯一写入口。
library;

import 'package:drift/drift.dart';

import '../../core/identity/uuid_v7.dart';
import '../../core/sync/cloud_layout.dart';
import '../../core/sync/hlc.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_payloads.dart';
import '../db/tables/log_tables.dart';
import '../db/vault_database.dart';
import '../write/entry_snapshot.dart';
import '../write/write_gateway.dart';

class DbSyncWorkspaceStore {
  DbSyncWorkspaceStore({
    required this.db,
    required this.gateway,
    required this.codec,
    required this.clock,
    required this.uuid,
    required this.deviceId,
    required this.vaultId,
    this.schema = 1,
    int Function()? now,
    this.localLabel = '本地设备',
    this.remoteLabel = '云端',
  }) : _now = now ?? _defaultNow;

  final VaultDatabase db;
  final WriteGateway gateway;
  final AsyncSyncPayloadCodec codec;
  final HlcClock clock;
  final UuidV7 uuid;
  final String deviceId;
  final String vaultId;
  final int schema;
  final int Function() _now;
  final String localLabel;
  final String remoteLabel;

  static int _defaultNow() => DateTime.now().millisecondsSinceEpoch;

  /// 单轮待推 oplog 上限。
  ///
  /// docs/04 §10 给 PUSH 预留 60 个请求、§8.2 要求首次同步每批 50 条；
  /// 取 50 让「一轮 = 一批」，超出的 oplog 保持 `applied=0`，下一轮按 seq
  /// 升序自然续跑（不需要额外的分批游标）。以前默认 500 会稳定撞满
  /// 200 的请求预算，日志里全是「预算不足」，虽不丢数据但每次都白跑。
  static const int pendingBatchSize = 50;

  /// 从本地库读出一轮同步所需的全部状态。
  Future<SyncWorkspace> load({int limit = pendingBatchSize}) async {
    final syncRows = await db.select(db.syncStates).get();
    final syncState = <String, String?>{
      for (final row in syncRows) row.path: row.etag,
    };
    final deviceEtags = _deviceEtags(syncRows);
    final localWatermarks = await _localWatermarks();

    final entryRows = await db.select(db.entries).get();
    final entries = <String, EntrySnapshot>{};
    for (final row in entryRows) {
      entries[await codec.hashedName(row.id)] = EntrySnapshot.fromRow(row);
    }

    final appliedRows = await (db.select(db.oplogs)
          ..where((t) => t.applied.equals(1) & t.entity.equals(SyncEntity.entry))
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.asc(t.seq),
          ]))
        .get();
    final baseRevs = <String, int>{};
    final baseSnapshots = <String, EntrySnapshot?>{};
    for (final row in appliedRows) {
      if (row.payload == null) continue;
      try {
        final snapshot = await gateway.readSnapshot(row);
        baseRevs[snapshot.id] = snapshot.rev;
        baseSnapshots[snapshot.id] = snapshot;
      } catch (_) {
        // 坏 oplog 不阻断同步；下次诊断任务处理。
        continue;
      }
    }

    final pendingRows = await (db.select(db.oplogs)
          ..where((t) => t.applied.equals(0) & t.entity.equals(SyncEntity.entry))
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.asc(t.seq),
          ])
          ..limit(limit))
        .get();
    final pendingOps = <SyncPendingOp>[];
    for (final row in pendingRows) {
      if (row.payload == null) continue;
      final EntrySnapshot snapshot;
      try {
        snapshot = await gateway.readSnapshot(row);
      } catch (_) {
        continue;
      }
      final name = await codec.hashedName(snapshot.id);
      final baseRev = row.baseRev ?? baseRevs[snapshot.id] ?? 0;
      if (row.op == OplogOp.delete.code) {
        pendingOps.add(SyncPendingOp.delete(
          id: 'oplog:${row.seq}',
          hashedName: name,
          entryId: snapshot.id,
          rev: snapshot.rev,
          baseRev: baseRev,
        ));
      } else {
        pendingOps.add(SyncPendingOp.upsert(
          id: 'oplog:${row.seq}',
          hashedName: name,
          snapshot: snapshot,
          baseRev: baseRev,
          rawPayload: row.payload,
        ));
      }
    }

    final nowMs = _now();
    final nextHlc = clock
        .observe(Hlc(millis: nowMs, counter: 0, node: deviceId))
        .encode();

    return SyncWorkspace(
      selfDeviceId: deviceId,
      vaultId: vaultId,
      schema: schema,
      localWatermarks: localWatermarks,
      deviceEtags: deviceEtags,
      syncState: syncState,
      entries: entries,
      baseRevs: baseRevs,
      baseSnapshots: baseSnapshots,
      pendingOps: pendingOps,
      nowMs: nowMs,
      nextHlc: nextHlc,
      localLabel: localLabel,
      remoteLabel: remoteLabel,
      newConflictCopyId: uuid.next,
      syncToken: syncState['sync/token'],
    );
  }

  /// 原子提交同步结果。单飞锁跳过时不写日志，避免把「没跑」记成一次同步。
  Future<void> commit(
    SyncRunResult result, {
    String trigger = 'db_workspace',
  }) async {
    if (result.skipped) return;
    await gateway.applySyncRun(result, trigger: trigger);
  }

  /// 便捷闭环：load → SyncEngine.run → commit。
  Future<SyncRunResult> run(
    SyncEngine engine, {
    int limit = pendingBatchSize,
    String trigger = 'db_workspace',
  }) async {
    final workspace = await load(limit: limit);
    final result = await engine.run(workspace);
    await commit(result, trigger: trigger);
    return result;
  }

  Future<Map<String, Hlc?>> _localWatermarks() async {
    final rows = await db.select(db.deviceWatermarks).get();
    return <String, Hlc?>{
      for (final row in rows)
        row.deviceId: row.maxHlc == null ? null : Hlc.tryParse(row.maxHlc!),
    };
  }

  Map<String, String> _deviceEtags(Iterable<SyncStateRow> rows) {
    final out = <String, String>{};
    final prefix = '${CloudLayout.devicesDir}/';
    for (final row in rows) {
      if (!row.path.startsWith(prefix) || !row.path.endsWith('.json')) continue;
      final etag = row.etag;
      if (etag == null) continue;
      final raw = row.path.substring(
        prefix.length,
        row.path.length - '.json'.length,
      );
      out[Uri.decodeComponent(raw)] = etag;
    }
    return out;
  }
}
