/// M3 同步编排器：把纯判定层串成一次可测试的同步。
///
/// 它只依赖 [WebDavBackend] 抽象与 [AsyncSyncPayloadCodec]，不碰 drift、
/// 不碰真实 HTTP 客户端、不新增依赖。真实落地时把 codec 换成加密实现、
/// 把 backend 换成 WebDAV 客户端、把 `SyncWorkspace` 换成数据库事务即可。
library;

import 'change_diff.dart';
import 'cloud_layout.dart';
import 'conflict_matrix.dart';
import 'device_watermark.dart';
import 'hlc.dart';
import 'sync_payloads.dart';
import 'sync_runtime.dart';
import 'sync_state_machine.dart';
import 'webdav_backend.dart';

import '../../data/sync/merge3.dart';
import '../../data/write/entry_snapshot.dart';

/// 一次同步的结果。测试主要断言这里的阶段轨迹、请求顺序与最终本地状态。
class SyncRunResult {
  const SyncRunResult({
    required this.skipped,
    required this.state,
    required this.phases,
    required this.requestLog,
    required this.pullOrder,
    required this.requestCount,
    required this.conflicts,
    required this.budgetExceeded,
    required this.watermarkPublished,
    required this.entries,
    required this.syncState,
    required this.deletedEntries,
    required this.quarantined,
    required this.quarantinePayloads,
    required this.nextHlc,
    required this.pushedPaths,
    required this.conflictCopyIds,
    required this.appliedOps,
    required this.cloudAppliedEntryIds,
    required this.tombstonesWritten,
    required this.preconditionAttempts,
    required this.reason,
    required this.diff,
    this.capabilities,
  });

  factory SyncRunResult.skipped(SyncWorkspace workspace) {
    return SyncRunResult(
      skipped: true,
      state: const SyncState(SyncPhase.idle),
      phases: const <SyncPhase>[SyncPhase.idle],
      requestLog: const <String>[],
      pullOrder: const <String>[],
      requestCount: 0,
      conflicts: 0,
      budgetExceeded: false,
      watermarkPublished: false,
      entries: Map<String, EntrySnapshot>.from(workspace.entries),
      syncState: Map<String, String?>.from(workspace.syncState),
      deletedEntries: _deletedNames(workspace),
      quarantined: const <String>{},
      quarantinePayloads: const <String, List<int>>{},
      nextHlc: workspace.nextHlc,
      pushedPaths: const <String>[],
      conflictCopyIds: const <String>{},
      appliedOps: const <String>{},
      cloudAppliedEntryIds: const <String>{},
      tombstonesWritten: const <String>{},
      preconditionAttempts: const <String, int>{},
      reason: '单飞锁被占用：本次跳过，不排队',
      diff: SyncDiff.empty,
    );
  }

  final bool skipped;
  final SyncState state;
  final List<SyncPhase> phases;
  final List<String> requestLog;
  final List<String> pullOrder;
  final int requestCount;
  final int conflicts;
  final bool budgetExceeded;
  final bool watermarkPublished;
  final Map<String, EntrySnapshot> entries;
  final Map<String, String?> syncState;
  final Set<String> deletedEntries;
  final Set<String> quarantined;
  final Map<String, List<int>> quarantinePayloads;
  final String nextHlc;
  final List<String> pushedPaths;
  final Set<String> conflictCopyIds;
  final Set<String> appliedOps;

  /// 这一轮已经由云端确认的 entry id。
  ///
  /// DB 落库时这些快照对应的 oplog 可以标为 `applied=1`；其余合并结果
  /// 必须保留 `applied=0`，否则还没推上去的本地编辑会被静默吃掉。
  final Set<String> cloudAppliedEntryIds;
  final Set<String> tombstonesWritten;
  final Map<String, int> preconditionAttempts;
  final String reason;
  final SyncDiff diff;
  final WebDavCapabilities? capabilities;

  bool get isIdle => state.phase == SyncPhase.idle;
  bool get isBackoff => state.phase == SyncPhase.backoff;
  bool get isFailed => state.phase == SyncPhase.failed;
}

Set<String> _deletedNames(SyncWorkspace workspace) => <String>{
      for (final entry in workspace.entries.entries)
        if (entry.value.deleted) entry.key,
    };

class _SyncFatal implements Exception {
  const _SyncFatal(this.code, this.message);

  final SyncErrorCode code;
  final String message;
}

enum _PushOutcome { completed, backoff, failed }

class _RunContext {
  _RunContext(this.workspace, int budgetLimit)
      : budget = RequestBudget(limit: budgetLimit);

  final SyncWorkspace workspace;
  final RequestBudget budget;

  final List<SyncPhase> phases = <SyncPhase>[SyncPhase.idle];
  final List<String> requestLog = <String>[];
  final List<String> pullOrder = <String>[];
  final List<DeviceWatermark> remoteWatermarks = <DeviceWatermark>[];
  final List<SyncTombstone> tombstones = <SyncTombstone>[];
  final Map<String, EntrySnapshot> remoteEntries = <String, EntrySnapshot>{};
  final Map<String, String> remoteEtags = <String, String>{};
  final Map<String, List<int>> remoteRawBytes = <String, List<int>>{};
  final List<SyncPendingOp> generatedOps = <SyncPendingOp>[];
  final Set<String> quarantined = <String>{};
  final Map<String, List<int>> quarantinePayloads = <String, List<int>>{};
  final List<String> pushedPaths = <String>[];
  final Set<String> conflictCopyIds = <String>{};
  final Set<String> appliedOps = <String>{};
  final Set<String> cloudAppliedEntryIds = <String>{};
  final Set<String> tombstonesWritten = <String>{};
  final Set<String> resurrectedEntryIds = <String>{};

  /// 本轮已由 `/vault/tombstones/` 明确处理过的 entry id。
  ///
  /// L2 的 `diff.deleted`（条目文件消失）是** weaker 信号**：同一轮里
  /// 墓碑已经给出判定，就不能再用「文件不见」重复 bump rev 或软删一次。
  final Set<String> tombstoneHandledEntryIds = <String>{};

  final Map<String, int> preconditionAttempts = <String, int>{};

  SyncState state = const SyncState(SyncPhase.idle);
  SyncDiff diff = SyncDiff.empty;
  WebDavCapabilities? capabilities;
  bool forceL2 = false;
  bool hasChanges = false;
  bool budgetExceeded = false;
  bool watermarkPublished = false;
  int conflicts = 0;
  String reason = '';

  SyncState advance(SyncEvent event, {SyncErrorCode? error}) {
    state = syncTransition(state, event, error: error);
    phases.add(state.phase);
    return state;
  }

  Future<T?> request<T>(String label, Future<T> Function() call) async {
    if (!budget.tryConsume()) {
      budgetExceeded = true;
      return null;
    }
    requestLog.add(label);
    return await call();
  }

  SyncRunResult result() => SyncRunResult(
        skipped: false,
        state: state,
        phases: List<SyncPhase>.unmodifiable(phases),
        requestLog: List<String>.unmodifiable(requestLog),
        pullOrder: List<String>.unmodifiable(pullOrder),
        requestCount: budget.used,
        conflicts: conflicts,
        budgetExceeded: budgetExceeded,
        watermarkPublished: watermarkPublished,
        entries: Map<String, EntrySnapshot>.from(workspace.entries),
        syncState: Map<String, String?>.from(workspace.syncState),
        deletedEntries: _deletedNames(workspace),
        quarantined: Set<String>.unmodifiable(quarantined),
        quarantinePayloads: Map<String, List<int>>.unmodifiable(
          <String, List<int>>{
            for (final entry in quarantinePayloads.entries)
              entry.key: List<int>.unmodifiable(entry.value),
          },
        ),
        nextHlc: workspace.nextHlc,
        pushedPaths: List<String>.unmodifiable(pushedPaths),
        conflictCopyIds: Set<String>.unmodifiable(conflictCopyIds),
        appliedOps: Set<String>.unmodifiable(appliedOps),
        cloudAppliedEntryIds: Set<String>.unmodifiable(cloudAppliedEntryIds),
        tombstonesWritten: Set<String>.unmodifiable(tombstonesWritten),
        preconditionAttempts:
            Map<String, int>.unmodifiable(preconditionAttempts),
        reason: reason,
        diff: diff,
        capabilities: capabilities,
      );
}

/// 编排器实例。单飞锁是实例级的：同一实例并发触发时后者直接跳过。
class SyncEngine {
  SyncEngine({
    required this.backend,
    required this.codec,
    this.budgetLimit = 200,
    SingleFlightLock? lock,
  }) : _lock = lock ?? SingleFlightLock();

  final WebDavBackend backend;
  final AsyncSyncPayloadCodec codec;
  final int budgetLimit;
  final SingleFlightLock _lock;

  Future<SyncRunResult> run(SyncWorkspace workspace) {
    return _lock.run(
      () => _run(workspace),
      skipped: SyncRunResult.skipped(workspace),
    );
  }

  Future<SyncRunResult> _run(SyncWorkspace workspace) async {
    final ctx = _RunContext(workspace, budgetLimit);
    try {
      ctx.advance(SyncEvent.trigger);
      ctx.advance(SyncEvent.lockAcquired);

      await _probeDevices(ctx);

      if (!ctx.hasChanges && workspace.pendingOps.isEmpty) {
        ctx.advance(SyncEvent.probeQuiet);
        await _publishWatermark(ctx);
        if (ctx.state.phase == SyncPhase.publish) {
          ctx.advance(SyncEvent.publishDone);
        }
        ctx.reason = 'L1 静默：无远端变化且无待推送，直接发布水位';
        return ctx.result();
      }

      if (!ctx.hasChanges) {
        // 只有本地 oplog 待发，跳过 L2。
        ctx.advance(SyncEvent.probePendingOnly);
      } else {
        ctx.advance(SyncEvent.probeChanged);
        final discovered = await _discover(ctx);
        if (!discovered) {
          ctx.advance(SyncEvent.discoverBudgetExceeded);
          ctx.reason = 'L2 发现阶段请求超预算：先推本地，剩余下次续跑';
        } else {
          ctx.advance(SyncEvent.discoverDone);
          final pulled = await _pull(ctx);
          if (!pulled) return ctx.result();
          await _merge(ctx);
        }
      }

      final pushOutcome = await _push(ctx);
      if (pushOutcome != _PushOutcome.completed) return ctx.result();

      if (ctx.state.phase == SyncPhase.verify) {
        await _verifyAndPublish(ctx);
      } else if (ctx.state.phase == SyncPhase.publish) {
        await _publishWatermark(ctx);
        ctx.advance(SyncEvent.publishDone);
      }

      if (ctx.reason.isEmpty) ctx.reason = '同步完成';
      return ctx.result();
    } on _SyncFatal catch (e) {
      ctx.reason = e.message;
      ctx.advance(SyncEvent.fatalError, error: e.code);
      return ctx.result();
    } on WebDavException catch (e) {
      ctx.reason = e.toString();
      final code = e.syncErrorCode;
      if ((code == SyncErrorCode.net || code == SyncErrorCode.rate) &&
          ctx.state.phase == SyncPhase.push) {
        ctx.advance(
          code == SyncErrorCode.net
              ? SyncEvent.networkError
              : SyncEvent.rateLimited,
        );
      } else {
        ctx.advance(SyncEvent.fatalError, error: code);
      }
      return ctx.result();
    } catch (e) {
      ctx.reason = e.toString();
      ctx.advance(SyncEvent.fatalError, error: SyncErrorCode.corrupt);
      return ctx.result();
    }
  }

  Future<void> _probeDevices(_RunContext ctx) async {
    final listings = await ctx.request<List<WebDavListing>>(
      'PROPFIND /vault/devices',
      () => backend.propfind(CloudLayout.devicesDir),
    );
    if (listings == null) {
      throw const _SyncFatal(SyncErrorCode.quota, 'L1 设备目录请求预算不足');
    }

    for (final listing in listings) {
      if (listing.isCollection) continue;
      final deviceId = _deviceIdFromPath(listing.path);
      if (deviceId == ctx.workspace.selfDeviceId) continue;

      final localEtag = ctx.workspace.deviceEtags[deviceId];
      final remoteEtag = listing.etag;
      if (localEtag != null && remoteEtag != null && localEtag == remoteEtag) {
        // ETag 没变就不需要 GET 文件：本地水位表里的 HLC 仍然有效。
        final seen = ctx.workspace.localWatermarks[deviceId] ??
            Hlc(millis: 0, counter: 0, node: deviceId);
        ctx.remoteWatermarks.add(DeviceWatermark(
          deviceId: deviceId,
          maxHlc: seen,
          lastSeen: ctx.workspace.nowMs,
          schema: ctx.workspace.schema,
          etag: remoteEtag,
        ));
        continue;
      }

      final get = await ctx.request<WebDavGetResult>(
        'GET ${listing.path}',
        () => backend.get(listing.path),
      );
      if (get == null) {
        throw const _SyncFatal(SyncErrorCode.quota, 'L1 水位读取请求预算不足');
      }
      try {
        ctx.remoteWatermarks.add(
          await codec.decodeWatermark(get.bytes, etag: get.etag),
        );
      } catch (_) {
        ctx.quarantined.add(listing.path);
        ctx.quarantinePayloads[listing.path] = List<int>.from(get.bytes);
        ctx.forceL2 = true;
      }
    }

    final probe = probeWatermarks(
      remote: ctx.remoteWatermarks,
      local: ctx.workspace.localWatermarks,
      selfDeviceId: ctx.workspace.selfDeviceId,
      localEtags: ctx.workspace.deviceEtags,
    );
    ctx.hasChanges = probe.hasChanges || ctx.forceL2;
  }

  Future<bool> _discover(_RunContext ctx) async {
    final headers = await ctx.request<Map<String, String>>(
      'OPTIONS /vault/',
      () => backend.options('${CloudLayout.root}/'),
    );
    if (headers == null) return false;

    final capabilities = detectWebDavCapabilities(headers);
    ctx.capabilities = capabilities;
    if (!capabilities.conditionalPut) {
      throw const _SyncFatal(
        SyncErrorCode.path,
        '服务器不支持条件写：拒绝同步，避免无条件 PUT 覆盖数据',
      );
    }

    final localItems = _itemSyncState(ctx.workspace);
    if (capabilities.syncCollection) {
      final delta = await ctx.request<SyncCollectionDelta>(
        'REPORT sync-collection',
        () => backend.reportSyncCollection(
          CloudLayout.root,
          syncToken: ctx.workspace.syncToken,
        ),
      );
      if (delta == null) return false;
      ctx.diff = diffSyncCollection(delta: delta, local: localItems);
      return true;
    }

    final shards = <String, List<WebDavListing>>{};
    for (var i = 0; i < CloudLayout.shardCount; i++) {
      final shard = i.toRadixString(16);
      final listings = await ctx.request<List<WebDavListing>>(
        'PROPFIND /vault/items/$shard',
        () => backend.propfind(CloudLayout.itemsDir(shard)),
      );
      if (listings == null) return false;
      shards[shard] = listings;
    }
    ctx.diff = diffAllShards(shards: shards, local: localItems);
    return true;
  }

  Future<bool> _pull(_RunContext ctx) async {
    ctx.pullOrder.add('tombstones');
    final tombListings = await ctx.request<List<WebDavListing>>(
      'PROPFIND /vault/tombstones',
      () => backend.propfind('${CloudLayout.root}/tombstones'),
    );
    if (tombListings == null) {
      throw const _SyncFatal(SyncErrorCode.quota, '拉取墓碑时请求预算不足');
    }
    for (final listing in tombListings) {
      if (listing.isCollection) continue;
      final get = await ctx.request<WebDavGetResult>(
        'GET ${listing.path}',
        () => backend.get(listing.path),
      );
      if (get == null) {
        throw const _SyncFatal(SyncErrorCode.quota, '读取墓碑时请求预算不足');
      }
      try {
        ctx.tombstones.add(await codec.decodeTombstone(get.bytes));
        ctx.workspace.syncState[listing.path] = get.etag;
      } catch (_) {
        ctx.quarantined.add(listing.path);
        ctx.quarantinePayloads[listing.path] = List<int>.from(get.bytes);
      }
    }

    ctx.advance(SyncEvent.tombstonesDone);

    ctx.pullOrder.add('meta');
    final metaGet = await ctx.request<WebDavGetResult>(
      'GET /vault/meta.enc',
      () => backend.get(CloudLayout.metaPath),
    );
    if (metaGet == null) {
      throw const _SyncFatal(SyncErrorCode.quota, '读取 meta 时请求预算不足');
    }
    final SyncVaultMeta meta;
    try {
      meta = await codec.decodeMeta(metaGet.bytes);
    } catch (_) {
      ctx.quarantined.add(CloudLayout.metaPath);
      ctx.quarantinePayloads[CloudLayout.metaPath] =
          List<int>.from(metaGet.bytes);
      throw const _SyncFatal(SyncErrorCode.corrupt, 'meta.enc 损坏或解密失败');
    }
    ctx.workspace.syncState[CloudLayout.metaPath] = metaGet.etag;

    if (meta.vaultId != ctx.workspace.vaultId) {
      ctx.advance(SyncEvent.metaVaultMismatch);
      ctx.reason = '误连另一个 vault：拒绝同步';
      return false;
    }
    if (meta.schema > ctx.workspace.schema) {
      ctx.advance(SyncEvent.metaSchemaTooNew);
      ctx.reason = '云端 schema 高于本地：拒绝同步并提示升级';
      return false;
    }

    ctx.advance(SyncEvent.metaOk);

    ctx.pullOrder.add('entries');
    final paths = <String>{...ctx.diff.added, ...ctx.diff.modified};
    for (final path in paths) {
      final get = await ctx.request<WebDavGetResult>(
        'GET $path',
        () => backend.get(path),
      );
      if (get == null) {
        throw const _SyncFatal(SyncErrorCode.quota, '拉取条目时请求预算不足');
      }
      try {
        final snapshot = await codec.decodeEntry(get.bytes);
        if (snapshot.contentHash != _hash(snapshot)) {
          throw const FormatException('content_hash 不匹配');
        }
        ctx.remoteEntries[path] = snapshot;
        ctx.remoteEtags[path] = get.etag;
        ctx.remoteRawBytes[path] = List<int>.from(get.bytes);
        ctx.workspace.syncState[path] = get.etag;
      } catch (_) {
        ctx.quarantined.add(path);
        ctx.quarantinePayloads[path] = List<int>.from(get.bytes);
      }
    }

    ctx.advance(SyncEvent.pullDone);
    return true;
  }

  Future<void> _merge(_RunContext ctx) async {
    for (final remoteEntry in ctx.remoteEntries.entries) {
      final path = remoteEntry.key;
      final remote = remoteEntry.value;
      final hashedName = path.split('/').last;
      final local = ctx.workspace.entries[hashedName];
      final baseRev = ctx.workspace.baseRevs[remote.id] ?? 0;
      final base = ctx.workspace.baseSnapshots[remote.id];
      final decision = resolveConflict(
        local: _localSide(local, baseRev, base),
        remote: _remoteSide(remote, baseRev, base),
      );

      switch (decision.action) {
        case ConflictAction.insertRemote:
        case ConflictAction.overwriteLocal:
        case ConflictAction.resurrectRemoteEdit:
          ctx.workspace.entries[hashedName] = remote;
          ctx.cloudAppliedEntryIds.add(remote.id);
          if (decision.action == ConflictAction.resurrectRemoteEdit) {
            ctx.resurrectedEntryIds.add(remote.id);
          }
          break;

        case ConflictAction.keepLocal:
        case ConflictAction.pushLocal:
          if (local != null) await _addUpsert(ctx, local);
          break;

        case ConflictAction.resurrectLocalEdit:
          if (local != null) {
            final revived = _bumpSnapshot(
              local,
              rev: (local.rev > remote.rev ? local.rev : remote.rev) + 1,
              ctx: ctx,
            );
            ctx.workspace.entries[hashedName] = revived;
            await _addUpsert(ctx, revived);
          }
          break;

        case ConflictAction.merge3:
          if (local == null) break;
          final merged = merge3(
            base: base,
            local: local,
            remote: remote,
            context: _mergeContext(ctx),
          );
          ctx.workspace.entries[hashedName] = merged.merged;
          await _addUpsert(ctx, merged.merged);
          if (merged.isConflict) ctx.conflicts++;
          final copy = merged.conflictCopy;
          if (copy != null) {
            final copyName = await codec.hashedName(copy.id);
            ctx.workspace.entries[copyName] = copy;
            ctx.conflictCopyIds.add(copy.id);
            await _addUpsert(ctx, copy);
          }
          break;

        case ConflictAction.writeTombstone:
          if (local != null) await _addDelete(ctx, local, baseRev);
          break;

        case ConflictAction.softDeleteLocal:
          if (local != null) {
            ctx.workspace.entries[hashedName] = local.copyWith(
              deleted: true,
              deletedAt: ctx.workspace.nowMs,
            );
            ctx.cloudAppliedEntryIds.add(local.id);
          }
          break;

        case ConflictAction.noop:
          break;

        case ConflictAction.quarantine:
          ctx.quarantined.add(path);
          ctx.quarantinePayloads.putIfAbsent(
            path,
            () => List<int>.from(ctx.remoteRawBytes[path] ?? const <int>[]),
          );
          break;
      }
    }

    await _applyTombstones(ctx);
    _applyDeletedItemFiles(ctx);
    ctx.advance(
      ctx.conflicts > 0
          ? SyncEvent.mergeDoneWithConflicts
          : SyncEvent.mergeDone,
    );
  }

  Future<void> _applyTombstones(_RunContext ctx) async {
    for (final tombstone in ctx.tombstones) {
      ctx.tombstoneHandledEntryIds.add(tombstone.entryId);
      if (ctx.resurrectedEntryIds.contains(tombstone.entryId)) {
        // 远端编辑已经通过规则 9 复活，不能再被同一轮墓碑软删回去。
        continue;
      }
      final hashedName = tombstone.hashedName;
      final local = ctx.workspace.entries[hashedName];
      final localDeleted = local?.deleted ?? false;
      final localRev = local?.rev ?? tombstone.rev;
      final baseRev = ctx.workspace.baseRevs[tombstone.entryId] ?? 0;
      final base = ctx.workspace.baseSnapshots[tombstone.entryId];

      EntrySnapshot? remoteEdit;
      for (final snapshot in ctx.remoteEntries.values) {
        if (snapshot.id == tombstone.entryId &&
            snapshot.rev > localRev &&
            _differsFromBase(snapshot, base)) {
          remoteEdit = snapshot;
          break;
        }
      }
      if (remoteEdit != null &&
          shouldResurrectAfterDelete(
            localDeleted: localDeleted,
            localRev: localRev,
            remoteRev: remoteEdit.rev,
            remoteDiffersFromBase: true,
          )) {
        ctx.workspace.entries[hashedName] = remoteEdit;
        ctx.resurrectedEntryIds.add(tombstone.entryId);
        ctx.cloudAppliedEntryIds.add(remoteEdit.id);
        continue;
      }

      final action = decideTombstone(
        localDeleted: localDeleted,
        localRev: localRev,
        baseRev: baseRev,
      );
      if (action == TombstoneAction.ignoreKeepLocal && local != null) {
        final revived = _bumpSnapshot(
          local,
          rev: (local.rev > tombstone.rev ? local.rev : tombstone.rev) + 1,
          ctx: ctx,
        );
        ctx.workspace.entries[hashedName] = revived;
        await _addUpsert(ctx, revived);
      } else if (action == TombstoneAction.apply && local != null) {
        ctx.workspace.entries[hashedName] = local.copyWith(
          deleted: true,
          deletedAt: ctx.workspace.nowMs,
        );
        ctx.cloudAppliedEntryIds.add(local.id);
      } else if (action == TombstoneAction.alreadyDeleted) {
        ctx.cloudAppliedEntryIds.add(tombstone.entryId);
      }
      // alreadyDeleted：幂等清理，不重复写墓碑。
    }
  }

  /// 消费 L2 的 `diff.deleted`：远端 `/vault/items/` 文件消失。
  ///
  /// docs/04 §3.2 规定完整 16 分片扫描 / `sync-collection` 明确删除列表
  /// 才能推断删除。这里把它当作**弱于墓碑**的信号：
  ///
  /// - 只处理 `/vault/items/` 路径，其它命名空间（entities / tombstones /
  ///   devices）的 ETag 记录只清理，不碰本地实体；
  /// - 本轮已有墓碑给出判定的 entry 一律跳过，避免重复 bump rev / 软删；
  /// - 复用 [decideTombstone]：`localRev > baseRev` 说明本地有未推编辑，
  ///   **编辑胜**，复活并写新版本，绝不因文件消失吞掉用户内容；
  /// - 本地未变 → 规则 7 软删进回收站；本地已删 → 幂等，只清状态。
  /// - 无论哪种结果，`sync_state` 里那条陈旧 path → ETag 都必须移除，
  ///   否则下一轮会反复把它当成远端删除。
  void _applyDeletedItemFiles(_RunContext ctx) {
    const String itemsPrefix = '${CloudLayout.root}/items/';
    for (final path in ctx.diff.deleted) {
      ctx.workspace.syncState.remove(path);
      if (!path.startsWith(itemsPrefix)) continue;

      final hashedName = path.split('/').last;
      final local = ctx.workspace.entries[hashedName];
      if (local == null) continue;
      if (ctx.tombstoneHandledEntryIds.contains(local.id)) continue;
      if (ctx.resurrectedEntryIds.contains(local.id)) continue;

      final baseRev = ctx.workspace.baseRevs[local.id] ?? 0;
      final action = decideTombstone(
        localDeleted: local.deleted,
        localRev: local.rev,
        baseRev: baseRev,
      );
      if (action == TombstoneAction.ignoreKeepLocal) {
        final revived = _bumpSnapshot(local, rev: local.rev + 1, ctx: ctx);
        ctx.workspace.entries[hashedName] = revived;
        ctx.generatedOps.add(SyncPendingOp.upsert(
          id: 'generated:upsert:${revived.id}',
          hashedName: hashedName,
          snapshot: revived,
          baseRev: baseRev,
        ));
      } else if (action == TombstoneAction.apply) {
        ctx.workspace.entries[hashedName] = local.copyWith(
          deleted: true,
          deletedAt: ctx.workspace.nowMs,
        );
        ctx.cloudAppliedEntryIds.add(local.id);
      } else {
        ctx.cloudAppliedEntryIds.add(local.id);
      }
    }
  }

  Future<_PushOutcome> _push(_RunContext ctx) async {
    final ops = <SyncPendingOp>[
      ...ctx.workspace.pendingOps,
      ...ctx.generatedOps,
    ];
    final seen = <String>{};

    for (final op in ops) {
      if (!seen.add(op.id)) continue;
      if (ctx.state.phase != SyncPhase.push) break;

      final outcome = op.kind == SyncPendingOpKind.upsert
          ? await _pushUpsert(ctx, op)
          : await _pushDelete(ctx, op);
      if (outcome != _PushOutcome.completed) return outcome;
    }

    if (ctx.state.phase == SyncPhase.push) {
      ctx.advance(SyncEvent.pushDone);
    }
    return _PushOutcome.completed;
  }

  Future<_PushOutcome> _pushUpsert(
    _RunContext ctx,
    SyncPendingOp op,
  ) async {
    var snapshot = op.snapshot!;
    var payload = op.rawPayload ?? await codec.encodeEntry(snapshot);
    final path = CloudLayout.itemPath(op.hashedName);
    var condition = _conditionFor(ctx, path);
    var attempts = 0;
    EntrySnapshot? lastRemote;

    while (true) {
      try {
        final put = await ctx.request<WebDavPutResult>(
          'PUT $path',
          () => backend.put(
            path,
            payload,
            condition: condition,
          ),
        );
        if (put == null) {
          ctx.advance(SyncEvent.pushDone);
          ctx.reason = '推送阶段请求预算不足：保存进度，下次续跑';
          return _PushOutcome.completed;
        }
        ctx.workspace.syncState[path] = put.etag;
        ctx.pushedPaths.add(path);
        ctx.appliedOps.add(op.id);
        ctx.cloudAppliedEntryIds.add(snapshot.id);
        return _PushOutcome.completed;
      } on WebDavException catch (e) {
        if (!e.isPreconditionFailed) return _handlePushError(ctx, e);

        attempts++;
        ctx.preconditionAttempts[op.id] = attempts;
        ctx.advance(SyncEvent.pushPreconditionFailed);

        final get = await ctx.request<WebDavGetResult>(
          'GET $path after 412',
          () => backend.get(path),
        );
        if (get == null) {
          ctx.advance(SyncEvent.pullDone);
          ctx.advance(SyncEvent.mergeDone);
          ctx.advance(SyncEvent.pushPreconditionExhausted);
          return _PushOutcome.completed;
        }

        EntrySnapshot? remote;
        try {
          remote = await codec.decodeEntry(get.bytes);
          if (remote.contentHash != _hash(remote)) {
            throw const FormatException('412 后拉取的远端 hash 不匹配');
          }
          lastRemote = remote;
          ctx.workspace.syncState[path] = get.etag;
        } catch (_) {
          ctx.quarantined.add(path);
          ctx.quarantinePayloads[path] = List<int>.from(get.bytes);
        }

        if (attempts <= ctx.workspace.maxPreconditionRetries) {
          if (remote != null && remote.id == snapshot.id) {
            final merged = merge3(
              base: ctx.workspace.baseSnapshots[snapshot.id],
              local: snapshot,
              remote: remote,
              context: _mergeContext(ctx),
            );
            snapshot = merged.merged;
            payload = await codec.encodeEntry(snapshot);
            op.snapshot = snapshot;
            if (merged.isConflict) ctx.conflicts++;
            final copy = merged.conflictCopy;
            if (copy != null) {
              final copyName = await codec.hashedName(copy.id);
              ctx.workspace.entries[copyName] = copy;
              ctx.conflictCopyIds.add(copy.id);
              await _pushConflictCopy(ctx, copy);
            }
          }
          ctx.advance(SyncEvent.pullDone);
          ctx.advance(
            ctx.conflicts > 0
                ? SyncEvent.mergeDoneWithConflicts
                : SyncEvent.mergeDone,
          );
          condition = WebDavCondition.ifMatch(get.etag);
          continue;
        }

        // 第 4 次 412：不再重试，远端另存冲突副本，两边都留。
        final remoteForCopy = lastRemote ?? snapshot;
        final conflict = merge3(
          base: null,
          local: snapshot,
          remote: remoteForCopy,
          context: _mergeContext(ctx),
        );
        final copy = conflict.conflictCopy!;
        final copyName = await codec.hashedName(copy.id);
        ctx.workspace.entries[copyName] = copy;
        ctx.conflictCopyIds.add(copy.id);
        ctx.conflicts++;
        ctx.advance(SyncEvent.pullDone);
        ctx.advance(SyncEvent.mergeDoneWithConflicts);
        await _pushConflictCopy(ctx, copy);
        ctx.advance(SyncEvent.pushPreconditionExhausted);
        ctx.reason = '连续 412 超过 3 轮：生成冲突副本后继续校验';
        return _PushOutcome.completed;
      }
    }
  }

  Future<_PushOutcome> _pushDelete(
    _RunContext ctx,
    SyncPendingOp op,
  ) async {
    final tombstonePath = CloudLayout.tombstonePath(op.hashedName);
    final itemPath = CloudLayout.itemPath(op.hashedName);
    final tombstone = SyncTombstone(
      entryId: op.entryId,
      hashedName: op.hashedName,
      deletedAt: ctx.workspace.nowMs,
      deviceId: ctx.workspace.selfDeviceId,
      rev: op.rev,
    );
    final tombstoneBytes = await codec.encodeTombstone(tombstone);

    try {
      final put = await ctx.request<WebDavPutResult>(
        'PUT $tombstonePath',
        () => backend.put(
          tombstonePath,
          tombstoneBytes,
          condition: _conditionFor(ctx, tombstonePath),
        ),
      );
      if (put == null) {
        ctx.advance(SyncEvent.pushDone);
        ctx.reason = '写墓碑时请求预算不足：不删除条目文件';
        return _PushOutcome.completed;
      }
      ctx.workspace.syncState[tombstonePath] = put.etag;
      ctx.tombstonesWritten.add(tombstonePath);
      ctx.pushedPaths.add(tombstonePath);
      ctx.cloudAppliedEntryIds.add(op.entryId);

      final itemEtag = ctx.workspace.syncState[itemPath] ?? '*';
      final deleted = await ctx.request<bool>(
        'DELETE $itemPath',
        () async {
          await backend.delete(itemPath, ifMatch: itemEtag);
          return true;
        },
      );
      if (deleted == null) {
        ctx.reason = 'DELETE 条目文件时请求预算不足：墓碑已写，下次续跑';
      } else {
        ctx.workspace.syncState.remove(itemPath);
        ctx.pushedPaths.add(itemPath);
      }
      ctx.appliedOps.add(op.id);
      return _PushOutcome.completed;
    } on WebDavException catch (e) {
      return _handlePushError(ctx, e);
    }
  }

  Future<void> _pushConflictCopy(
    _RunContext ctx,
    EntrySnapshot copy,
  ) async {
    final copyName = await codec.hashedName(copy.id);
    final copyPath = CloudLayout.itemPath(copyName);
    final payload = await codec.encodeEntry(copy);
    final put = await ctx.request<WebDavPutResult>(
      'PUT $copyPath',
      () => backend.put(
        copyPath,
        payload,
        condition: const WebDavCondition.createOnly(),
      ),
    );
    if (put == null) return;
    ctx.workspace.syncState[copyPath] = put.etag;
    ctx.pushedPaths.add(copyPath);
    ctx.cloudAppliedEntryIds.add(copy.id);
  }

  _PushOutcome _handlePushError(_RunContext ctx, WebDavException error) {
    ctx.reason = error.toString();
    final code = error.syncErrorCode;
    if (code == SyncErrorCode.net || code == SyncErrorCode.rate) {
      ctx.advance(
        code == SyncErrorCode.net
            ? SyncEvent.networkError
            : SyncEvent.rateLimited,
      );
      return _PushOutcome.backoff;
    }
    ctx.advance(SyncEvent.fatalError, error: code);
    return _PushOutcome.failed;
  }

  Future<void> _verifyAndPublish(_RunContext ctx) async {
    for (final entry in ctx.workspace.entries.values) {
      if (_hash(entry) != entry.contentHash) {
        ctx.advance(SyncEvent.verifyHashMismatch);
        ctx.reason = 'content_hash 对账失败：合并结果损坏';
        return;
      }
    }
    ctx.advance(SyncEvent.verifyOk);
    await _publishWatermark(ctx);
    if (ctx.state.phase == SyncPhase.publish) {
      ctx.advance(SyncEvent.publishDone);
    }
  }

  Future<void> _publishWatermark(_RunContext ctx) async {
    final path = CloudLayout.devicePath(ctx.workspace.selfDeviceId);
    final existing = ctx.workspace.deviceEtags[ctx.workspace.selfDeviceId] ??
        ctx.workspace.syncState[path];
    final hlc = Hlc.tryParse(ctx.workspace.nextHlc) ??
        Hlc(
          millis: ctx.workspace.nowMs,
          counter: 0,
          node: ctx.workspace.selfDeviceId,
        );
    final watermark = DeviceWatermark(
      deviceId: ctx.workspace.selfDeviceId,
      maxHlc: hlc,
      lastSeen: ctx.workspace.nowMs,
      schema: ctx.workspace.schema,
      etag: existing,
    );
    final watermarkBytes = await codec.encodeWatermark(watermark);
    final put = await ctx.request<WebDavPutResult>(
      'PUT $path',
      () => backend.put(
        path,
        watermarkBytes,
        condition: existing == null
            ? const WebDavCondition.createOnly()
            : WebDavCondition.ifMatch(existing),
      ),
    );
    if (put == null) {
      ctx.reason = '发布设备水位时请求预算不足';
      return;
    }
    ctx.workspace.deviceEtags[ctx.workspace.selfDeviceId] = put.etag;
    ctx.workspace.syncState[path] = put.etag;
    ctx.watermarkPublished = true;
  }

  Future<void> _addUpsert(_RunContext ctx, EntrySnapshot snapshot) async {
    final id = 'generated:upsert:${snapshot.id}';
    if (ctx.generatedOps.any((SyncPendingOp op) => op.id == id)) return;
    ctx.generatedOps.add(SyncPendingOp.upsert(
      id: id,
      hashedName: await codec.hashedName(snapshot.id),
      snapshot: snapshot,
      baseRev: ctx.workspace.baseRevs[snapshot.id] ?? 0,
    ));
  }

  Future<void> _addDelete(
    _RunContext ctx,
    EntrySnapshot snapshot,
    int baseRev,
  ) async {
    final id = 'generated:delete:${snapshot.id}';
    if (ctx.generatedOps.any((SyncPendingOp op) => op.id == id)) return;
    ctx.generatedOps.add(SyncPendingOp.delete(
      id: id,
      hashedName: await codec.hashedName(snapshot.id),
      entryId: snapshot.id,
      rev: snapshot.rev,
      baseRev: baseRev,
    ));
  }

  WebDavCondition _conditionFor(_RunContext ctx, String path) {
    final etag = ctx.workspace.syncState[path];
    return etag == null || etag.isEmpty
        ? const WebDavCondition.createOnly()
        : WebDavCondition.ifMatch(etag);
  }

  MergeContext _mergeContext(_RunContext ctx) => MergeContext(
        nextHlc: ctx.workspace.nextHlc,
        nowMs: ctx.workspace.nowMs,
        localLabel: ctx.workspace.localLabel,
        remoteLabel: ctx.workspace.remoteLabel,
        conflictCopyId: ctx.workspace.newConflictCopyId(),
        conflictCopyHlc: ctx.workspace.nextHlc,
      );

  Map<String, String?> _itemSyncState(SyncWorkspace workspace) =>
      <String, String?>{
        for (final entry in workspace.syncState.entries)
          if (entry.key.startsWith('${CloudLayout.root}/items/'))
            entry.key: entry.value,
      };
}

String _deviceIdFromPath(String path) {
  final name = path.split('/').last;
  final raw = name.endsWith('.json')
      ? name.substring(0, name.length - '.json'.length)
      : name;
  return Uri.decodeComponent(raw);
}

String _hash(EntrySnapshot snapshot) => EntrySnapshot.computeContentHash(
      kind: snapshot.kind,
      title: snapshot.title,
      body: snapshot.body,
      meta: snapshot.meta,
    );

bool _differsFromBase(EntrySnapshot snapshot, EntrySnapshot? base) =>
    base == null || _hash(snapshot) != _hash(base);

EntrySnapshot _bumpSnapshot(
  EntrySnapshot source, {
  required int rev,
  required _RunContext ctx,
}) {
  return source.copyWith(
    updatedAt: ctx.workspace.nowMs,
    hlc: ctx.workspace.nextHlc,
    rev: rev,
    contentHash: _hash(source),
    deleted: false,
    clearDeletedAt: true,
  );
}

SyncSide _localSide(EntrySnapshot? local, int baseRev, EntrySnapshot? base) {
  if (local == null) return SyncSide.absent;
  if (local.deleted) return SyncSide.deleted;
  if (base == null) return SyncSide.created;
  if (local.rev > baseRev) return SyncSide.modified;
  return SyncSide.unchanged;
}

SyncSide _remoteSide(EntrySnapshot remote, int baseRev, EntrySnapshot? base) {
  if (remote.deleted) return SyncSide.deleted;
  if (base == null) return SyncSide.created;
  if (remote.rev > baseRev) return SyncSide.modified;
  return SyncSide.unchanged;
}
