import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/change_diff.dart';
import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/device_watermark.dart';
import 'package:vault/core/sync/entity_sync_engine.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/core/sync/retention_policy.dart';
import 'package:vault/core/sync/retry_scheduler.dart';
import 'package:vault/core/sync/sync_coordinator.dart';
import 'package:vault/core/sync/sync_engine.dart';
import 'package:vault/core/sync/sync_payloads.dart';
import 'package:vault/core/sync/sync_runtime.dart';
import 'package:vault/core/sync/sync_state_machine.dart';
import 'package:vault/core/sync/webdav_backend.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart';
import 'package:vault/data/write/entry_snapshot.dart';
import 'package:vault/data/write/write_gateway.dart';

/// `SyncCoordinator` 的确定性测试。
///
/// 这里不搭数据库：正文 / taxonomy / 清理三条链路都用内存替身，验证的是
/// **顺序与保守闸门** —— 清理不可逆，所以正文失败、退避、预算不足、
/// taxonomy 半途中断时都必须跳过；只有两条链路都完整才允许 DELETE 墓碑。
const int _now = 1731052800000;
const Duration _day = Duration(days: 1);

class _File {
  const _File(this.bytes, this.etag);

  final List<int> bytes;
  final String etag;
}

class _Backend implements WebDavBackend {
  _Backend({
    Map<String, _File>? files,
    Map<String, List<WebDavListing>>? listings,
    SyncCollectionDelta? delta,
  })  : files = files ?? <String, _File>{},
        listings = listings ?? <String, List<WebDavListing>>{},
        delta = delta ??
            const SyncCollectionDelta(
              changed: <String, String?>{},
              deleted: <String>{},
              syncToken: 'token-2',
            );

  final Map<String, _File> files;
  final Map<String, List<WebDavListing>> listings;
  final SyncCollectionDelta delta;
  final List<String> calls = <String>[];
  final List<String> deleteIfMatch = <String>[];
  final Set<String> failures = <String>{};
  int _etag = 1000;

  @override
  Future<Map<String, String>> options(String path) async => <String, String>{
        'DAV': '1, 3, sync-collection',
        'Allow': 'OPTIONS, PROPFIND, REPORT, GET, PUT, DELETE',
        'ETag': '"root"',
      };

  @override
  Future<List<WebDavListing>> propfind(String path, {int depth = 1}) async {
    calls.add('PROPFIND $path');
    return listings[path] ?? const <WebDavListing>[];
  }

  @override
  Future<SyncCollectionDelta> reportSyncCollection(
    String path, {
    String? syncToken,
  }) async {
    calls.add('REPORT $path');
    return delta;
  }

  @override
  Future<WebDavGetResult> get(String path) async {
    calls.add('GET $path');
    final file = files[path];
    if (file == null) {
      throw WebDavException(statusCode: 404, method: 'GET', path: path);
    }
    return WebDavGetResult(bytes: file.bytes, etag: file.etag);
  }

  @override
  Future<WebDavPutResult> put(
    String path,
    List<int> bytes, {
    required WebDavCondition condition,
  }) async {
    calls.add('PUT $path');
    if (!condition.isValid) throw ArgumentError('无条件 PUT');
    final etag = 'e${_etag++}';
    files[path] = _File(List<int>.from(bytes), etag);
    return WebDavPutResult(etag: etag, statusCode: 201);
  }

  @override
  Future<void> delete(String path, {required String ifMatch}) async {
    calls.add('DELETE $path');
    deleteIfMatch.add(ifMatch);
    if (failures.contains(path)) {
      throw WebDavException(statusCode: 503, method: 'DELETE', path: path);
    }
    files.remove(path);
  }

  @override
  Future<void> mkcol(String path) async {}
}

/// 纯 JSON codec：这里只关心调度顺序，不需要真实加密字节。
class _Codec implements SyncPayloadCodec {
  final Map<String, String> _names = <String, String>{};

  @override
  String hashedName(String entryId) => _names.putIfAbsent(
        entryId,
        () => '${(_names.length + 1).toRadixString(16).padLeft(32, '0')}.enc',
      );

  @override
  List<int> encodeEntry(EntrySnapshot snapshot) => _bytes(snapshot.toJson());

  @override
  EntrySnapshot decodeEntry(List<int> bytes) =>
      EntrySnapshot.fromJson(_object(bytes));

  @override
  List<int> encodeMeta(SyncVaultMeta meta) => _bytes(meta.toJson());

  @override
  SyncVaultMeta decodeMeta(List<int> bytes) =>
      SyncVaultMeta.fromJson(_object(bytes));

  @override
  List<int> encodeTombstone(SyncTombstone t) => _bytes(t.toJson());

  @override
  SyncTombstone decodeTombstone(List<int> bytes) =>
      SyncTombstone.fromJson(_object(bytes));

  @override
  List<int> encodeWatermark(DeviceWatermark w) => _bytes(w.toJson());

  @override
  DeviceWatermark decodeWatermark(List<int> bytes, {String? etag}) =>
      DeviceWatermark.fromJson(_object(bytes), etag: etag);

  List<int> _bytes(Object? value) => <int>[
        for (final unit in value.toString().codeUnits) unit & 0xFF,
      ];

  Map<String, Object?> _object(List<int> bytes) =>
      <String, Object?>{'raw': bytes.length};
}

/// 让正文链路直接返回指定结果，不必再搭一整套内存后端。
/// 按给定序列返回结果的正文引擎替身。
class _SequenceEntryEngine extends SyncEngine {
  _SequenceEntryEngine(this.results)
      : super(backend: _Backend(), codec: SyncPayloadCodecAdapter(_Codec()));

  final List<SyncRunResult> results;
  int runs = 0;

  @override
  Future<SyncRunResult> run(SyncWorkspace workspace) async {
    final result = results[runs.clamp(0, results.length - 1)];
    runs++;
    return result;
  }
}

class _EntryEngine extends SyncEngine {
  _EntryEngine(this.result) : super(backend: _Backend(), codec: SyncPayloadCodecAdapter(_Codec()));

  final SyncRunResult result;

  @override
  Future<SyncRunResult> run(SyncWorkspace workspace) async => result;
}

/// taxonomy 通道替身：直接返回指定结果。
class _EntityEngine extends EntitySyncEngine {
  _EntityEngine(this.result)
      : super(
          backend: _Backend(),
          codec: _EntityCodec(),
          port: _NoopPort(),
        );

  final EntitySyncRunResult result;

  @override
  Future<EntitySyncRunResult> run() async => result;
}

class _NoopPort implements EntitySyncPort {
  @override
  Future<void> commitPulls(
    Iterable<RemoteTaxonomyFile> files,
    Map<String, String?> entityState,
    Map<String, List<int>> quarantinePayloads,
  ) async {}

  @override
  Future<void> commitPushes(Iterable<SyncedOplogPush> pushes) async {}

  @override
  Future<void> commitQuarantine(Map<String, List<int>> payloads) async {}

  @override
  Future<List<EntityPendingOp>> pending({int limit = 500}) async =>
      const <EntityPendingOp>[];

  @override
  Future<Map<String, String?>> syncState() async => const <String, String?>{};
}

class _EntityCodec implements SyncEntityPayloadCodec {
  @override
  Future<String> hashedEntityName(String entity, String id) async =>
      '${(id.hashCode & 0xFFFFFFFF).toRadixString(16).padLeft(32, '0')}.enc';

  @override
  Future<SyncEnvelopeHeader> peekEntity(List<int> bytes) async =>
      const SyncEnvelopeHeader(entity: 'category', entityId: 'x', rev: 1);

  @override
  Future<List<int>> encodeTaxonomy(TaxonomySnapshot snapshot) async =>
      const <int>[1];

  @override
  Future<TaxonomySnapshot> decodeTaxonomy(List<int> bytes) async =>
      _taxonomy();
}

class _PurgeRunner implements TrashPurgeRunner {
  _PurgeRunner(this.ids);

  final List<String> ids;
  int calls = 0;

  @override
  Future<List<String>> purgedEntryIds({required int nowMs}) async {
    calls++;
    return ids;
  }
}

class _TombstoneLister implements TombstoneLister {
  _TombstoneLister(this.records);

  final List<TombstoneRecord> records;

  @override
  Future<List<TombstoneRecord>> tombstones() async => records;
}

SyncWorkspace _workspace() => SyncWorkspace(
      selfDeviceId: 'devA',
      vaultId: 'vault-alpha',
      schema: 1,
      localWatermarks: const <String, Hlc?>{},
      deviceEtags: const <String, String>{},
      syncState: const <String, String?>{},
      entries: const <String, EntrySnapshot>{},
      baseRevs: const <String, int>{},
      baseSnapshots: const <String, EntrySnapshot?>{},
      pendingOps: const <SyncPendingOp>[],
      nowMs: _now,
      nextHlc: Hlc(millis: _now, counter: 0, node: 'devA').encode(),
      localLabel: '设备 A',
      remoteLabel: '设备 B',
      newConflictCopyId: () => 'copy-1',
    );

SyncRunResult _entryResult({
  bool skipped = false,
  bool failed = false,
  bool backoff = false,
  bool budgetExceeded = false,
  bool watermarkPublished = true,
  SyncErrorCode? retryCode,
}) {
  final state = failed
      ? const SyncState(SyncPhase.failed, error: SyncErrorCode.auth)
      : backoff
          ? const SyncState(SyncPhase.backoff)
          : const SyncState(SyncPhase.idle);
  return SyncRunResult(
    skipped: skipped,
    state: state,
    phases: const <SyncPhase>[SyncPhase.idle],
    requestLog: const <String>[],
    pullOrder: const <String>[],
    requestCount: 0,
    conflicts: 0,
    budgetExceeded: budgetExceeded,
    watermarkPublished: watermarkPublished,
    entries: const <String, EntrySnapshot>{},
    syncState: const <String, String?>{},
    deletedEntries: const <String>{},
    quarantined: const <String>{},
    quarantinePayloads: const <String, List<int>>{},
    nextHlc: Hlc(millis: _now, counter: 0, node: 'devA').encode(),
    pushedPaths: const <String>[],
    conflictCopyIds: const <String>{},
    appliedOps: const <String>{},
    cloudAppliedEntryIds: const <String>{},
    tombstonesWritten: const <String>{},
    preconditionAttempts: const <String, int>{},
    reason: '测试构造',
    diff: SyncDiff.empty,
    retryCode: retryCode,
  );
}

EntitySyncRunResult _entityResult({
  bool skipped = false,
  bool failed = false,
  bool budgetExceeded = false,
}) =>
    EntitySyncRunResult(
      skipped: skipped,
      pushedPaths: const <String>[],
      pulledPaths: const <String>[],
      quarantinedPaths: const <String>{},
      quarantinePayloads: const <String, List<int>>{},
      requestCount: 0,
      requestLog: const <String>[],
      errorCode: failed ? SyncErrorCode.auth : null,
      reason: failed ? '通道失败' : '通道完成',
      syncState: const <String, String?>{},
      budgetExceeded: budgetExceeded,
    );

SyncCoordinator _coordinator({
  required SyncRunResult entry,
  required EntitySyncRunResult entity,
  required _Backend backend,
  required _PurgeRunner purge,
  required _TombstoneLister lister,
  Map<String, String?>? state,
  int budgetLimit = 32,
  SingleFlightLock? lock,
}) {
  return SyncCoordinator(
    entryEngine: _EntryEngine(entry),
    entityEngine: _EntityEngine(entity),
    purgeRunner: purge,
    tombstoneLister: lister,
    backend: backend,
    workspaceLoader: () async => _workspace(),
    commitEntryRun: (SyncRunResult _) async {},
    commitQuarantine: (Map<String, List<int>> _) async {},
    syncState: () async =>
        state ??
        <String, String?>{
          for (final record in lister.records) record.path: 'tomb-e1',
        },
    now: () => _now,
    retentionBudgetLimit: budgetLimit,
    lock: lock,
    // 测试不能真睡 1s→2s→4s；生产默认用 Future.delayed。
    retryScheduler: RetryScheduler(
      sleep: (Duration _) async {},
    ),
  );
}

TaxonomySnapshot _taxonomy() => TaxonomySnapshot(
      entity: 'category',
      id: 'cat-1',
      rev: 1,
      hlc: Hlc(millis: _now, counter: 0, node: 'devB').encode(),
      updatedAt: _now,
      deleted: false,
      fields: const <String, Object?>{'name': '分类'},
    );

void main() {
  const String oldTomb = '/vault/tombstones/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.enc';
  const String freshTomb = '/vault/tombstones/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.enc';

  final tombstones = <TombstoneRecord>[
    TombstoneRecord(
      path: oldTomb,
      deletedAt: _now - 91 * _day.inMilliseconds,
    ),
    TombstoneRecord(
      path: freshTomb,
      deletedAt: _now - 10 * _day.inMilliseconds,
    ),
    TombstoneRecord(
      path: '${CloudLayout.root}/tombstones/cccccccccccccccccccccccccccccccc.enc',
      deletedAt: _now - 92 * _day.inMilliseconds,
    ),
  ];

  test('两条链路都完整时按序执行：正文 → taxonomy → 本地清理 → 云端 TTL',
      () async {
    final backend = _Backend();
    final purge = _PurgeRunner(<String>['entry-purged']);
    final lister = _TombstoneLister(tombstones);
    final coordinator = _coordinator(
      entry: _entryResult(),
      entity: _entityResult(),
      backend: backend,
      purge: purge,
      lister: lister,
    );

    final report = await coordinator.run();

    expect(report, isNotNull);
    expect(report!.completed, isTrue);
    expect(report.retention.executed, isTrue);
    expect(purge.calls, 1);
    expect(report.retention.purgedEntryIds, <String>['entry-purged']);
    expect(
      report.retention.expiredTombstonePaths,
      <String>[
        oldTomb,
        '${CloudLayout.root}/tombstones/cccccccccccccccccccccccccccccccc.enc',
      ],
    );
    expect(report.retention.deletedTombstonePaths, hasLength(2));
    expect(backend.calls, hasLength(2));
    expect(backend.deleteIfMatch, <String>['tomb-e1', 'tomb-e1'],
        reason: '每个云端 DELETE 都必须带 If-Match');
  });

  test('正文失败 / 退避 / 预算不足 / 水位未发布时一律跳过清理', () async {
    final variants = <SyncRunResult>[
      _entryResult(failed: true),
      _entryResult(backoff: true),
      _entryResult(budgetExceeded: true),
      _entryResult(watermarkPublished: false),
      _entryResult(skipped: true),
    ];
    for (final entry in variants) {
      final backend = _Backend();
      final purge = _PurgeRunner(<String>['should-not-purge']);
      final lister = _TombstoneLister(tombstones);
      final report = await _coordinator(
        entry: entry,
        entity: _entityResult(),
        backend: backend,
        purge: purge,
        lister: lister,
      ).run();

      expect(report!.retention.executed, isFalse);
      expect(report.completed, isFalse);
      expect(purge.calls, 0, reason: '正文不完整时不能删本地行');
      expect(backend.calls, isEmpty, reason: '正文不完整时不能删云端墓碑');
    }
  });

  test('taxonomy 通道失败 / 跳过 / 预算不足时一律跳过清理', () async {
    final variants = <EntitySyncRunResult>[
      _entityResult(failed: true),
      _entityResult(skipped: true),
      _entityResult(budgetExceeded: true),
    ];
    for (final entity in variants) {
      final backend = _Backend();
      final purge = _PurgeRunner(<String>['should-not-purge']);
      final lister = _TombstoneLister(tombstones);
      final report = await _coordinator(
        entry: _entryResult(),
        entity: entity,
        backend: backend,
        purge: purge,
        lister: lister,
      ).run();

      expect(report!.retention.executed, isFalse);
      expect(purge.calls, 0);
      expect(backend.calls, isEmpty);
    }
  });

  test('墓碑没有确认 ETag 时不发 DELETE，也不误删 90 天内的墓碑', () async {
    final backend = _Backend();
    final purge = _PurgeRunner(const <String>[]);
    final lister = _TombstoneLister(tombstones);
    final report = await _coordinator(
      entry: _entryResult(),
      entity: _entityResult(),
      backend: backend,
      purge: purge,
      lister: lister,
      state: <String, String?>{freshTomb: 'tomb-e1'},
    ).run();

    expect(report!.retention.executed, isTrue);
    expect(
      report.retention.expiredTombstonePaths,
      <String>[
        oldTomb,
        '${CloudLayout.root}/tombstones/cccccccccccccccccccccccccccccccc.enc',
      ],
    );
    expect(report.retention.deletedTombstonePaths, isEmpty);
    expect(backend.calls, isEmpty);
    expect(report.retention.reason, contains('部分完成'));
  });

  test('云端 DELETE 失败时保留其它已删结果，标记部分完成', () async {
    final backend = _Backend()..failures.add(oldTomb);
    final purge = _PurgeRunner(const <String>[]);
    final lister = _TombstoneLister(tombstones);
    final report = await _coordinator(
      entry: _entryResult(),
      entity: _entityResult(),
      backend: backend,
      purge: purge,
      lister: lister,
    ).run();

    expect(report!.retention.executed, isTrue);
    expect(report.completed, isTrue,
        reason: '清理阶段的部分完成不推翻已成功的两条同步链路');
    expect(report.retention.deletedTombstonePaths, isEmpty);
    expect(report.retention.reason, contains('部分完成'));
  });

  test('正文 E_NET 退避后重试成功，仍继续 taxonomy 与清理阶段', () async {
    final firstBackoff = _entryResult(
      backoff: true,
      retryCode: SyncErrorCode.net,
    );
    final ok = _entryResult(skipped: false);
    // 第一次 BACKOFF、第二次 IDLE：用可切换结果的 SyncEngine。
    final engine = _SequenceEntryEngine(<SyncRunResult>[firstBackoff, ok]);
    final backend = _Backend();
    final purge = _PurgeRunner(<String>['purged']);
    final lister = _TombstoneLister(<TombstoneRecord>[]);
    final coordinator = SyncCoordinator(
      entryEngine: engine,
      entityEngine: _EntityEngine(_entityResult()),
      purgeRunner: purge,
      tombstoneLister: lister,
      backend: backend,
      workspaceLoader: () async => _workspace(),
      commitEntryRun: (SyncRunResult _) async {},
      commitQuarantine: (Map<String, List<int>> _) async {},
      syncState: () async => <String, String?>{},
      now: () => _now,
      retryScheduler: RetryScheduler(sleep: (Duration _) async {}),
    );

    final report = await coordinator.run();

    expect(report, isNotNull);
    expect(engine.runs, 2, reason: 'BACKOFF 必须真的重试一次');
    expect(report!.entry.isIdle, isTrue);
    expect(report.completed, isTrue);
    expect(purge.calls, 1, reason: '重试成功后不能跳过清理');
    expect(report.retention.purgedEntryIds, <String>['purged']);
  });

  test('顶层单飞锁忙时整轮跳过，不执行任何子阶段', () async {
    final lock = SingleFlightLock()..tryAcquire();
    final backend = _Backend();
    final purge = _PurgeRunner(<String>['x']);
    final lister = _TombstoneLister(tombstones);
    final report = await _coordinator(
      entry: _entryResult(),
      entity: _entityResult(),
      backend: backend,
      purge: purge,
      lister: lister,
      lock: lock,
    ).run();

    expect(report, isNull);
    expect(purge.calls, 0);
    expect(backend.calls, isEmpty);
    lock.release();
  });

  test('清理预算不足时不发 DELETE，留到下一轮续跑', () async {
    final backend = _Backend();
    final purge = _PurgeRunner(const <String>[]);
    final lister = _TombstoneLister(tombstones);
    final report = await _coordinator(
      entry: _entryResult(),
      entity: _entityResult(),
      backend: backend,
      purge: purge,
      lister: lister,
      state: <String, String?>{
        oldTomb: 'tomb-old',
        '${CloudLayout.root}/tombstones/cccccccccccccccccccccccccccccccc.enc':
            'tomb-c',
      },
      budgetLimit: 1, // 只够发一个 DELETE
    ).run();

    expect(report!.retention.executed, isTrue);
    expect(report.retention.deletedTombstonePaths, hasLength(1),
        reason: '第一个 DELETE 用掉唯一预算，第二个留到下一轮');
    expect(backend.calls, hasLength(1));
    expect(backend.deleteIfMatch, <String>['tomb-old']);
    expect(report.retention.reason, contains('部分完成'));
  });
}
