import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/device_watermark.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/core/sync/sync_engine.dart';
import 'package:vault/core/sync/sync_payloads.dart';
import 'package:vault/core/sync/sync_runtime.dart';
import 'package:vault/core/sync/sync_state_machine.dart';
import 'package:vault/core/sync/webdav_backend.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/entry_snapshot.dart';

const String _vaultId = 'vault-alpha';
const String _self = 'devA';
const String _other = 'devB';
const int _now = 1731052800000;
const String _tombstonesDir = '${CloudLayout.root}/tombstones';

String _hlc(int millis, String node) =>
    Hlc(millis: millis, counter: 0, node: node).encode();

Map<String, String> _syncCollectionHeaders() => <String, String>{
      'DAV': '1, 3, sync-collection',
      'Allow': 'OPTIONS, PROPFIND, REPORT, GET, PUT, DELETE',
      'ETag': '"vault-1"',
    };

Map<String, String> _shardedHeaders() => <String, String>{
      'DAV': '1',
      'Allow': 'OPTIONS, PROPFIND, GET, PUT, DELETE',
    };

class _File {
  const _File(this.bytes, this.etag);

  final List<int> bytes;
  final String etag;
}

class _MemoryWebDavBackend implements WebDavBackend {
  _MemoryWebDavBackend({
    required this.optionsHeaders,
    required this.files,
    required this.listings,
    required this.delta,
  });

  final Map<String, String> optionsHeaders;
  final Map<String, _File> files;
  final Map<String, List<WebDavListing>> listings;
  final SyncCollectionDelta delta;

  final Map<String, List<WebDavException>> putFailures =
      <String, List<WebDavException>>{};
  final Map<String, int> putCount = <String, int>{};
  final List<String> calls = <String>[];
  final List<String> deletedPaths = <String>[];
  int _etagCounter = 100;

  @override
  Future<Map<String, String>> options(String path) async {
    calls.add('OPTIONS $path');
    return optionsHeaders;
  }

  @override
  Future<List<WebDavListing>> propfind(String path, {int depth = 1}) async {
    calls.add('PROPFIND $path depth=$depth');
    return listings[path] ?? const <WebDavListing>[];
  }

  @override
  Future<SyncCollectionDelta> reportSyncCollection(
    String path, {
    String? syncToken,
  }) async {
    calls.add('REPORT $path token=$syncToken');
    return delta;
  }

  @override
  Future<WebDavGetResult> get(String path) async {
    calls.add('GET $path');
    final file = files[path];
    if (file == null) {
      throw WebDavException(
        statusCode: 404,
        method: 'GET',
        path: path,
      );
    }
    return WebDavGetResult(bytes: file.bytes, etag: file.etag);
  }

  @override
  Future<WebDavPutResult> put(
    String path,
    List<int> bytes, {
    required WebDavCondition condition,
  }) async {
    calls.add('PUT $path ${condition.headerName}: ${condition.headerValue}');
    putCount[path] = (putCount[path] ?? 0) + 1;
    if (!condition.isValid) {
      throw ArgumentError('条件写不能同时为空');
    }

    final failures = putFailures[path];
    if (failures != null && failures.isNotEmpty) {
      throw failures.removeAt(0);
    }

    final current = files[path];
    if (condition.isCreateOnly && current != null) {
      throw WebDavPreconditionFailed(method: 'PUT', path: path);
    }
    if (!condition.isCreateOnly &&
        (current == null || current.etag != condition.ifMatchEtag)) {
      throw WebDavPreconditionFailed(method: 'PUT', path: path);
    }

    final etag = 'e${_etagCounter++}';
    files[path] = _File(List<int>.from(bytes), etag);
    return WebDavPutResult(
      etag: etag,
      statusCode: current == null ? 201 : 204,
    );
  }

  @override
  Future<void> delete(String path, {required String ifMatch}) async {
    calls.add('DELETE $path If-Match: $ifMatch');
    final current = files[path];
    if (current == null) {
      throw WebDavException(statusCode: 404, method: 'DELETE', path: path);
    }
    if (ifMatch != '*' && current.etag != ifMatch) {
      throw WebDavPreconditionFailed(method: 'DELETE', path: path);
    }
    files.remove(path);
    deletedPaths.add(path);
  }

  @override
  Future<void> mkcol(String path) async {
    calls.add('MKCOL $path');
  }
}

class _JsonCodec implements SyncPayloadCodec {
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
  List<int> encodeTombstone(SyncTombstone tombstone) =>
      _bytes(tombstone.toJson());

  @override
  SyncTombstone decodeTombstone(List<int> bytes) =>
      SyncTombstone.fromJson(_object(bytes));

  @override
  List<int> encodeWatermark(DeviceWatermark watermark) =>
      _bytes(watermark.toJson());

  @override
  DeviceWatermark decodeWatermark(List<int> bytes, {String? etag}) =>
      DeviceWatermark.fromJson(_object(bytes), etag: etag);

  List<int> _bytes(Object? value) => utf8.encode(jsonEncode(value));

  Map<String, Object?> _object(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('载荷不是 JSON 对象');
    }
    return Map<String, Object?>.from(decoded);
  }
}

class _Harness {
  _Harness({
    required this.codec,
    required this.backend,
    required this.workspace,
  });

  final _JsonCodec codec;
  final _MemoryWebDavBackend backend;
  final SyncWorkspace workspace;

  SyncEngine engine({int budgetLimit = 200, SingleFlightLock? lock}) =>
      SyncEngine(
        backend: backend,
        codec: SyncPayloadCodecAdapter(codec),
        budgetLimit: budgetLimit,
        lock: lock,
      );
}

_Harness _harness({
  String vaultId = _vaultId,
  String cloudVaultId = _vaultId,
  int schema = 1,
  int cloudSchema = 1,
  List<int>? metaBytes,
  String deviceListingEtag = 'dev-e1',
  String deviceFileEtag = 'dev-e1',
  Hlc? remoteWatermarkHlc,
  Map<String, Hlc?>? localWatermarks,
  Map<String, String>? deviceEtags,
  Map<String, String?>? syncState,
  Map<String, EntrySnapshot>? entries,
  Map<String, int>? baseRevs,
  Map<String, EntrySnapshot?>? baseSnapshots,
  List<SyncPendingOp>? pendingOps,
  Map<String, String>? optionsHeaders,
  Map<String, _File>? fileOverrides,
  Map<String, List<WebDavListing>>? listingOverrides,
  SyncCollectionDelta? delta,
  int maxPreconditionRetries = 3,
  String? nextHlc,
}) {
  final codec = _JsonCodec();
  final remoteHlc = remoteWatermarkHlc ??
      Hlc(millis: 1000, counter: 0, node: _other);
  final otherDevicePath = CloudLayout.devicePath(_other);

  final files = <String, _File>{
    CloudLayout.metaPath: _File(
      metaBytes ??
          codec.encodeMeta(
            SyncVaultMeta(vaultId: cloudVaultId, schema: cloudSchema),
          ),
      'meta-e1',
    ),
    otherDevicePath: _File(
      codec.encodeWatermark(
        DeviceWatermark(
          deviceId: _other,
          maxHlc: remoteHlc,
          lastSeen: _now,
          schema: cloudSchema,
          etag: deviceFileEtag,
        ),
      ),
      deviceFileEtag,
    ),
    ...?fileOverrides,
  };

  final listings = <String, List<WebDavListing>>{
    CloudLayout.devicesDir: <WebDavListing>[
      WebDavListing(path: otherDevicePath, etag: deviceListingEtag),
    ],
    _tombstonesDir: <WebDavListing>[],
    for (var i = 0; i < CloudLayout.shardCount; i++)
      CloudLayout.itemsDir(i.toRadixString(16)): <WebDavListing>[],
    ...?listingOverrides,
  };

  final backend = _MemoryWebDavBackend(
    optionsHeaders: optionsHeaders ?? _syncCollectionHeaders(),
    files: files,
    listings: listings,
    delta: delta ??
        SyncCollectionDelta(
          changed: <String, String?>{},
          deleted: <String>{},
          syncToken: 'token-2',
        ),
  );

  var copyCounter = 0;
  final workspace = SyncWorkspace(
    selfDeviceId: _self,
    vaultId: vaultId,
    schema: schema,
    localWatermarks: localWatermarks ??
        <String, Hlc?>{
          _other: Hlc(millis: 1000, counter: 0, node: _other),
        },
    deviceEtags: deviceEtags ?? <String, String>{_other: 'dev-e1'},
    syncState: syncState ?? <String, String?>{},
    entries: entries ?? <String, EntrySnapshot>{},
    baseRevs: baseRevs ?? <String, int>{},
    baseSnapshots: baseSnapshots ?? <String, EntrySnapshot?>{},
    pendingOps: pendingOps ?? <SyncPendingOp>[],
    nowMs: _now,
    nextHlc: nextHlc ?? _hlc(_now, _self),
    localLabel: '设备 A',
    remoteLabel: '设备 B',
    newConflictCopyId: () => 'copy-${++copyCounter}',
    maxPreconditionRetries: maxPreconditionRetries,
    syncToken: 'token-1',
  );

  return _Harness(codec: codec, backend: backend, workspace: workspace);
}

EntrySnapshot _snapshot({
  String id = 'entry-1',
  EntryKind kind = EntryKind.note,
  String? title = '标题',
  String? body = '',
  String? meta,
  int createdAt = 1000,
  int updatedAt = 1000,
  int rev = 1,
  String? hlc,
  bool deleted = false,
  int? deletedAt,
}) {
  final code = kind.code;
  return EntrySnapshot(
    id: id,
    kind: code,
    title: title,
    body: body,
    meta: meta,
    createdAt: createdAt,
    updatedAt: updatedAt,
    hlc: hlc ?? _hlc(1000, 'devA'),
    rev: rev,
    contentHash: EntrySnapshot.computeContentHash(
      kind: code,
      title: title,
      body: body,
      meta: meta,
    ),
    deleted: deleted,
    deletedAt: deletedAt,
  );
}

String _addRemoteItem(
  _Harness harness,
  EntrySnapshot snapshot, {
  String etag = 'item-e1',
}) {
  final name = harness.codec.hashedName(snapshot.id);
  final path = CloudLayout.itemPath(name);
  harness.backend.files[path] = _File(
    harness.codec.encodeEntry(snapshot),
    etag,
  );
  harness.backend.delta.changed[path] = etag;

  final dir = CloudLayout.itemsDir(CloudLayout.shardOf(name));
  final shardListings =
      harness.backend.listings.putIfAbsent(dir, () => <WebDavListing>[]);
  if (!shardListings.any((WebDavListing item) => item.path == path)) {
    shardListings.add(WebDavListing(path: path, etag: etag));
  }
  return path;
}

String _addTombstone(
  _Harness harness,
  SyncTombstone tombstone, {
  String etag = 'tomb-e1',
}) {
  final path = CloudLayout.tombstonePath(tombstone.hashedName);
  harness.backend.files[path] = _File(
    harness.codec.encodeTombstone(tombstone),
    etag,
  );
  final listings = harness.backend.listings.putIfAbsent(
    _tombstonesDir,
    () => <WebDavListing>[],
  );
  if (!listings.any((WebDavListing item) => item.path == path)) {
    listings.add(WebDavListing(path: path, etag: etag));
  }
  return path;
}

SyncPendingOp _upsertOp(_Harness harness, EntrySnapshot snapshot) {
  return SyncPendingOp.upsert(
    id: 'oplog:${snapshot.id}',
    hashedName: harness.codec.hashedName(snapshot.id),
    snapshot: snapshot,
    baseRev: harness.workspace.baseRevs[snapshot.id] ?? 0,
  );
}

void main() {
  group('L1 / L2 编排', () {
    test('T19：L1 静默只发布水位，不进 L2，且请求数 ≤ 3', () async {
      final harness = _harness();
      final selfPath = CloudLayout.devicePath(_self);

      final result = await harness.engine().run(harness.workspace);

      expect(result.skipped, isFalse);
      expect(result.isIdle, isTrue);
      expect(result.watermarkPublished, isTrue);
      expect(result.pullOrder, isEmpty);
      expect(result.diff.isEmpty, isTrue);
      expect(result.requestCount, lessThanOrEqualTo(3));
      expect(result.requestLog, <String>[
        'PROPFIND /vault/devices',
        'PUT $selfPath',
      ]);
      expect(
        result.requestLog.any((String request) => request.startsWith('OPTIONS')),
        isFalse,
      );
      expect(
        result.requestLog.any(
          (String request) => request.startsWith('PROPFIND /vault/items/'),
        ),
        isFalse,
      );
      expect(result.reason, contains('L1 静默'));
      expect(result.syncState[selfPath], isNotNull);
    });

    test('ETag 变化但 max_hlc 未前进只是心跳，不触发 L2', () async {
      final harness = _harness(
        deviceListingEtag: 'dev-e2',
        deviceFileEtag: 'dev-e2',
        deviceEtags: <String, String>{_other: 'dev-e1'},
      );
      final otherPath = CloudLayout.devicePath(_other);
      final selfPath = CloudLayout.devicePath(_self);

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(result.watermarkPublished, isTrue);
      expect(result.requestCount, lessThanOrEqualTo(3));
      expect(result.requestLog, <String>[
        'PROPFIND /vault/devices',
        'GET $otherPath',
        'PUT $selfPath',
      ]);
      expect(
        result.requestLog.any((String request) => request.startsWith('OPTIONS')),
        isFalse,
      );
      expect(result.reason, contains('L1 静默'));
    });

    test('已有设备水位用 If-Match 更新，不做无条件覆盖', () async {
      final harness = _harness(
        deviceEtags: <String, String>{_other: 'dev-e1', _self: 'self-e1'},
      );
      final selfPath = CloudLayout.devicePath(_self);
      harness.backend.files[selfPath] = _File(
        harness.codec.encodeWatermark(
          DeviceWatermark(
            deviceId: _self,
            maxHlc: Hlc(millis: 900, counter: 0, node: _self),
            lastSeen: 900,
            schema: 1,
            etag: 'self-e1',
          ),
        ),
        'self-e1',
      );

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(result.watermarkPublished, isTrue);
      expect(
        harness.backend.calls,
        contains('PUT $selfPath If-Match: self-e1'),
      );
      expect(harness.workspace.deviceEtags[_self], isNot('self-e1'));
    });

    test('只有本地 oplog 待发时跳过 L2，条件 PUT 后发布水位', () async {
      final harness = _harness();
      final local = _snapshot(id: 'local-only', body: '本地新建');
      final name = harness.codec.hashedName(local.id);
      final itemPath = CloudLayout.itemPath(name);
      final selfPath = CloudLayout.devicePath(_self);
      harness.workspace.entries[name] = local;
      final op = _upsertOp(harness, local);
      harness.workspace.pendingOps.add(op);

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(result.phases, <SyncPhase>[
        SyncPhase.idle,
        SyncPhase.acquireLock,
        SyncPhase.probe,
        SyncPhase.push,
        SyncPhase.verify,
        SyncPhase.publish,
        SyncPhase.idle,
      ]);
      expect(result.pullOrder, isEmpty);
      expect(result.diff.isEmpty, isTrue);
      expect(result.requestLog, <String>[
        'PROPFIND /vault/devices',
        'PUT $itemPath',
        'PUT $selfPath',
      ]);
      expect(
        harness.backend.calls,
        contains('PUT $itemPath If-None-Match: *'),
      );
      expect(result.appliedOps, contains(op.id));
      expect(result.pushedPaths, contains(itemPath));
      expect(result.syncState[itemPath], isNotNull);
      expect(result.watermarkPublished, isTrue);
    });

    test('未知设备触发 sync-collection：严格按墓碑→meta→条目拉取', () async {
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
      );
      final remote = _snapshot(id: 'remote-1', body: '来自 B');
      final itemPath = _addRemoteItem(harness, remote, etag: 'remote-e1');

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(
        result.capabilities?.discoveryStrategy,
        WebDavDiscoveryStrategy.syncCollection,
      );
      expect(result.pullOrder, <String>['tombstones', 'meta', 'entries']);
      expect(result.phases, <SyncPhase>[
        SyncPhase.idle,
        SyncPhase.acquireLock,
        SyncPhase.probe,
        SyncPhase.discover,
        SyncPhase.pullTombstones,
        SyncPhase.pullMeta,
        SyncPhase.pullEntries,
        SyncPhase.merge,
        SyncPhase.push,
        SyncPhase.verify,
        SyncPhase.publish,
        SyncPhase.idle,
      ]);
      expect(result.requestLog, contains('REPORT sync-collection'));
      expect(
        result.requestLog.any(
          (String request) => request.startsWith('PROPFIND /vault/items/'),
        ),
        isFalse,
      );

      final tombstonesIndex =
          result.requestLog.indexOf('PROPFIND $_tombstonesDir');
      final metaIndex = result.requestLog.indexOf('GET ${CloudLayout.metaPath}');
      final itemIndex = result.requestLog.indexOf('GET $itemPath');
      expect(tombstonesIndex, greaterThanOrEqualTo(0));
      expect(metaIndex, greaterThan(tombstonesIndex));
      expect(itemIndex, greaterThan(metaIndex));

      expect(result.diff.added, contains(itemPath));
      expect(result.entries[harness.codec.hashedName(remote.id)]?.body, '来自 B');
      expect(result.syncState[itemPath], 'remote-e1');
      expect(result.syncState[CloudLayout.metaPath], 'meta-e1');
      expect(result.watermarkPublished, isTrue);
    });

    test('不支持 RFC 6578 时扫满 16 分片，完整扫描才推断删除', () async {
      const String stalePath =
          '/vault/items/1/11111111111111111111111111111111.enc';
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
        optionsHeaders: _shardedHeaders(),
        syncState: <String, String?>{stalePath: 'stale-e1'},
      );
      final remote = _snapshot(id: 'remote-shard', body: '分片条目');
      final itemPath = _addRemoteItem(harness, remote, etag: 'shard-e1');

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(
        result.capabilities?.discoveryStrategy,
        WebDavDiscoveryStrategy.shardedPropfind,
      );
      expect(
        result.requestLog
            .where((String request) =>
                request.startsWith('PROPFIND /vault/items/'))
            .length,
        CloudLayout.shardCount,
      );
      expect(
        result.requestLog.any(
          (String request) => request.startsWith('REPORT sync-collection'),
        ),
        isFalse,
      );
      expect(result.diff.added, contains(itemPath));
      expect(result.diff.deleted, contains(stalePath));
      expect(
        result.entries[harness.codec.hashedName(remote.id)]?.body,
        '分片条目',
      );
    });
  });

  group('同步安全闸门', () {
    test('T12：meta vault_id 不匹配时拒绝同步，本地数据不变', () async {
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
        cloudVaultId: 'vault-beta',
      );
      final local = _snapshot(id: 'unchanged', body: '本地完好');
      final name = harness.codec.hashedName(local.id);
      harness.workspace.entries[name] = local;

      final result = await harness.engine().run(harness.workspace);

      expect(result.isFailed, isTrue);
      expect(result.state.error, SyncErrorCode.vaultMismatch);
      expect(result.reason, contains('另一个 vault'));
      expect(result.pullOrder, <String>['tombstones', 'meta']);
      expect(result.entries[name], same(local));
      expect(result.pushedPaths, isEmpty);
      expect(result.watermarkPublished, isFalse);
      expect(
        harness.backend.calls.any((String call) => call.startsWith('PUT ')),
        isFalse,
      );
    });

    test('T18：云端 schema 高于本地时拒绝同步并提示升级', () async {
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
        schema: 1,
        cloudSchema: 2,
      );
      final local = _snapshot(id: 'old-schema', body: '旧版本本地数据');
      final name = harness.codec.hashedName(local.id);
      harness.workspace.entries[name] = local;

      final result = await harness.engine().run(harness.workspace);

      expect(result.isFailed, isTrue);
      expect(result.state.error, SyncErrorCode.schemaTooNew);
      expect(result.reason, contains('schema'));
      expect(result.entries[name], same(local));
      expect(result.watermarkPublished, isFalse);
      expect(result.pushedPaths, isEmpty);
    });

    test('服务器不支持条件写时直接失败，不发出任何 PUT', () async {
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
        optionsHeaders: <String, String>{},
      );

      final result = await harness.engine().run(harness.workspace);

      expect(result.isFailed, isTrue);
      expect(result.state.error, SyncErrorCode.path);
      expect(result.capabilities?.conditionalPut, isFalse);
      expect(result.reason, contains('条件写'));
      expect(result.requestLog, contains('OPTIONS /vault/'));
      expect(result.pushedPaths, isEmpty);
      expect(
        harness.backend.calls.any((String call) => call.startsWith('PUT ')),
        isFalse,
      );
    });

    test('T11：云端条目损坏时隔离，不覆盖本地数据', () async {
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
      );
      final local = _snapshot(id: 'corrupt-remote', body: '本地完好');
      final name = harness.codec.hashedName(local.id);
      final itemPath = CloudLayout.itemPath(name);
      harness.workspace.entries[name] = local;
      harness.backend.files[itemPath] = _File(
        utf8.encode('不是合法 JSON'),
        'bad-e1',
      );
      harness.backend.delta.changed[itemPath] = 'bad-e1';

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(result.quarantined, contains(itemPath));
      expect(result.entries[name], same(local));
      expect(result.pushedPaths, isNot(contains(itemPath)));
      expect(result.requestLog, contains('GET $itemPath'));
      expect(result.watermarkPublished, isTrue);
    });
  });

  group('冲突矩阵、merge3 与墓碑', () {
    test('T03：A、B 各自新建不同条目，双向可见且无冲突', () async {
      final local = _snapshot(id: 'A-local', body: 'A 新建');
      final remote = _snapshot(id: 'B-remote', body: 'B 新建');
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
      );
      final localName = harness.codec.hashedName(local.id);
      final remoteName = harness.codec.hashedName(remote.id);
      final localPath = CloudLayout.itemPath(localName);
      final remotePath = _addRemoteItem(harness, remote, etag: 'remote-e1');
      harness.workspace.entries[localName] = local;
      harness.workspace.pendingOps.add(_upsertOp(harness, local));

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(result.conflicts, 0);
      expect(result.conflictCopyIds, isEmpty);
      expect(result.entries[localName], same(local));
      expect(result.entries[remoteName]?.body, 'B 新建');
      expect(result.pushedPaths, contains(localPath));
      expect(result.syncState[remotePath], 'remote-e1');
      expect(
        result.requestLog.indexOf('GET $remotePath'),
        lessThan(result.requestLog.indexOf('PUT $localPath')),
      );
    });

    test('T04：不同段落经 SyncEngine 自动合并并推回新 rev', () async {
      final base = _snapshot(
        id: 'merge-auto',
        body: '开头\n第一段原文\n中间不变\n第二段原文\n结尾',
        meta: '{"tags":["公共"]}',
        rev: 2,
        hlc: _hlc(1000, 'devA'),
      );
      final local = _snapshot(
        id: 'merge-auto',
        body: '开头\nA 改第一段\n中间不变\n第二段原文\n结尾',
        meta: '{"tags":["公共","A"]}',
        rev: 3,
        hlc: _hlc(1100, 'devA'),
      );
      final remote = _snapshot(
        id: 'merge-auto',
        body: '开头\n第一段原文\n中间不变\nB 改第二段\n结尾',
        meta: '{"tags":["公共","B"]}',
        rev: 3,
        hlc: _hlc(1200, 'devB'),
      );
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
        baseRevs: <String, int>{base.id: 2},
        baseSnapshots: <String, EntrySnapshot?>{base.id: base},
      );
      final name = harness.codec.hashedName(local.id);
      final itemPath = _addRemoteItem(harness, remote, etag: 'remote-e1');
      harness.workspace.entries[name] = local;
      harness.workspace.syncState[itemPath] = 'base-e1';

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(result.conflicts, 0);
      expect(result.conflictCopyIds, isEmpty);
      final merged = result.entries[name]!;
      expect(merged.body, contains('A 改第一段'));
      expect(merged.body, contains('B 改第二段'));
      expect(merged.body, isNot(contains('<<<<<<<')));
      expect(merged.rev, 4);
      expect(result.pushedPaths, contains(itemPath));
      final pushed = harness.codec.decodeEntry(
        harness.backend.files[itemPath]!.bytes,
      );
      expect(pushed.body, merged.body);
      expect(pushed.contentHash, merged.contentHash);
    });

    test('T05：同一段落冲突保留双方内容，并推送冲突副本', () async {
      final base = _snapshot(
        id: 'merge-conflict',
        body: '开头\n同一段原文\n结尾',
        rev: 2,
        hlc: _hlc(1000, 'devA'),
      );
      final local = _snapshot(
        id: 'merge-conflict',
        body: '开头\nA 改写同一段\n结尾',
        rev: 3,
        hlc: _hlc(1100, 'devA'),
      );
      final remote = _snapshot(
        id: 'merge-conflict',
        body: '开头\nB 改写同一段\n结尾',
        rev: 3,
        hlc: _hlc(1200, 'devB'),
      );
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
        baseRevs: <String, int>{base.id: 2},
        baseSnapshots: <String, EntrySnapshot?>{base.id: base},
      );
      final name = harness.codec.hashedName(local.id);
      final itemPath = _addRemoteItem(harness, remote, etag: 'remote-e1');
      harness.workspace.entries[name] = local;
      harness.workspace.syncState[itemPath] = 'base-e1';

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(result.conflicts, greaterThanOrEqualTo(1));
      expect(result.conflictCopyIds, hasLength(1));
      final merged = result.entries[name]!;
      expect(merged.body, contains('<<<<<<< 本地'));
      expect(merged.body, contains('A 改写同一段'));
      expect(merged.body, contains('B 改写同一段'));
      expect(merged.body, contains('>>>>>>> 云端'));

      final copyId = result.conflictCopyIds.single;
      final copyName = harness.codec.hashedName(copyId);
      final copyPath = CloudLayout.itemPath(copyName);
      final copy = result.entries[copyName]!;
      expect(copy.body, remote.body);
      expect(copy.title, contains('冲突副本'));
      expect(result.pushedPaths, contains(itemPath));
      expect(result.pushedPaths, contains(copyPath));
      expect(harness.backend.files[copyPath], isNotNull);
      expect(result.syncState[copyPath], isNotNull);
    });

    test('T07：远端墓碑不能吞掉本地未推编辑，复活并推送新 rev', () async {
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
      );
      final local = _snapshot(
        id: 'edit-wins',
        body: '本地未同步编辑',
        rev: 3,
        hlc: _hlc(1100, 'devA'),
      );
      final base = _snapshot(
        id: local.id,
        body: '共同祖先',
        rev: 2,
        hlc: _hlc(1000, 'devA'),
      );
      final name = harness.codec.hashedName(local.id);
      final itemPath = CloudLayout.itemPath(name);
      harness.workspace.entries[name] = local;
      harness.workspace.baseRevs[local.id] = 2;
      harness.workspace.baseSnapshots[local.id] = base;
      _addTombstone(
        harness,
        SyncTombstone(
          entryId: local.id,
          hashedName: name,
          deletedAt: _now,
          deviceId: _other,
          rev: 3,
        ),
      );

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(result.deletedEntries, isNot(contains(name)));
      expect(result.entries[name]?.deleted, isFalse);
      expect(result.entries[name]?.body, '本地未同步编辑');
      expect(result.entries[name]?.rev, greaterThan(local.rev));
      expect(result.pushedPaths, contains(itemPath));
      expect(result.tombstonesWritten, isEmpty);
      expect(result.appliedOps, contains('generated:upsert:${local.id}'));
    });

    test('普通远端墓碑软删本地；双方已删时幂等清理', () async {
      final normalHarness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
      );
      final local = _snapshot(id: 'soft-delete', body: '待软删', rev: 2);
      final name = normalHarness.codec.hashedName(local.id);
      normalHarness.workspace.entries[name] = local;
      normalHarness.workspace.baseRevs[local.id] = 2;
      normalHarness.workspace.baseSnapshots[local.id] = _snapshot(
        id: local.id,
        body: '待软删',
        rev: 2,
      );
      _addTombstone(
        normalHarness,
        SyncTombstone(
          entryId: local.id,
          hashedName: name,
          deletedAt: _now,
          deviceId: _other,
          rev: 2,
        ),
      );

      final normalResult =
          await normalHarness.engine().run(normalHarness.workspace);
      expect(normalResult.isIdle, isTrue);
      expect(normalResult.deletedEntries, contains(name));
      expect(normalResult.entries[name]?.deleted, isTrue);
      expect(normalResult.entries[name]?.deletedAt, _now);
      expect(normalResult.tombstonesWritten, isEmpty);
      expect(
        normalResult.pushedPaths,
        isNot(contains(CloudLayout.itemPath(name))),
      );

      final bothHarness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
      );
      final deleted = _snapshot(
        id: 'both-deleted',
        body: '双方都删',
        rev: 2,
        deleted: true,
        deletedAt: _now - 1000,
      );
      final deletedName = bothHarness.codec.hashedName(deleted.id);
      bothHarness.workspace.entries[deletedName] = deleted;
      bothHarness.workspace.baseRevs[deleted.id] = 2;
      bothHarness.workspace.baseSnapshots[deleted.id] = _snapshot(
        id: deleted.id,
        body: '双方都删',
        rev: 2,
      );
      _addTombstone(
        bothHarness,
        SyncTombstone(
          entryId: deleted.id,
          hashedName: deletedName,
          deletedAt: _now,
          deviceId: _other,
          rev: 2,
        ),
      );

      final bothResult =
          await bothHarness.engine().run(bothHarness.workspace);
      expect(bothResult.isIdle, isTrue);
      expect(bothResult.deletedEntries, contains(deletedName));
      expect(bothResult.entries[deletedName]?.rev, deleted.rev);
      expect(bothResult.entries[deletedName]?.deletedAt, _now - 1000);
      expect(bothResult.tombstonesWritten, isEmpty);
    });

    test('T06：本地删除遇到远端编辑，编辑胜且跳过同一轮墓碑', () async {
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
      );
      final base = _snapshot(
        id: 'delete-vs-edit',
        body: '共同祖先',
        rev: 2,
        hlc: _hlc(1000, 'devA'),
      );
      final local = _snapshot(
        id: base.id,
        body: '共同祖先',
        rev: 2,
        hlc: _hlc(1050, 'devA'),
        deleted: true,
        deletedAt: _now,
      );
      final remote = _snapshot(
        id: base.id,
        body: 'B 在删除期间编辑',
        rev: 3,
        hlc: _hlc(1200, 'devB'),
      );
      final name = harness.codec.hashedName(local.id);
      harness.workspace.entries[name] = local;
      harness.workspace.baseRevs[base.id] = 2;
      harness.workspace.baseSnapshots[base.id] = base;
      _addRemoteItem(harness, remote, etag: 'remote-edit-e1');
      _addTombstone(
        harness,
        SyncTombstone(
          entryId: base.id,
          hashedName: name,
          deletedAt: _now,
          deviceId: _self,
          rev: 2,
        ),
      );

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(result.deletedEntries, isEmpty);
      expect(result.entries[name]?.deleted, isFalse);
      expect(result.entries[name]?.body, 'B 在删除期间编辑');
      expect(result.entries[name]?.rev, 3);
      expect(result.tombstonesWritten, isEmpty);
    });
  });

  group('推送与运行时约束', () {
    test('删除顺序：先写墓碑再 DELETE 条目，PUT/DELETE 都带条件', () async {
      final harness = _harness();
      final snapshot = _snapshot(id: 'delete-order', body: '将删除');
      final name = harness.codec.hashedName(snapshot.id);
      final itemPath = CloudLayout.itemPath(name);
      final tombstonePath = CloudLayout.tombstonePath(name);
      harness.backend.files[itemPath] = _File(
        harness.codec.encodeEntry(snapshot),
        'item-e1',
      );
      harness.workspace.syncState[itemPath] = 'item-e1';
      harness.workspace.entries[name] = snapshot.copyWith(
        deleted: true,
        deletedAt: _now,
      );
      const String opId = 'oplog-delete-1';
      harness.workspace.pendingOps.add(
        SyncPendingOp.delete(
          id: opId,
          hashedName: name,
          entryId: snapshot.id,
          rev: snapshot.rev,
          baseRev: snapshot.rev,
        ),
      );

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(result.tombstonesWritten, contains(tombstonePath));
      expect(result.pushedPaths, contains(tombstonePath));
      expect(result.pushedPaths, contains(itemPath));
      expect(result.appliedOps, contains(opId));
      expect(
        harness.backend.calls,
        contains('PUT $tombstonePath If-None-Match: *'),
      );
      expect(
        harness.backend.calls,
        contains('DELETE $itemPath If-Match: item-e1'),
      );
      expect(
        result.requestLog.indexOf('PUT $tombstonePath'),
        lessThan(result.requestLog.indexOf('DELETE $itemPath')),
      );
      expect(harness.backend.files[tombstonePath], isNotNull);
      expect(harness.backend.files[itemPath], isNull);
      expect(harness.backend.deletedPaths, contains(itemPath));
      expect(result.syncState[tombstonePath], isNotNull);
      expect(result.syncState.containsKey(itemPath), isFalse);
    });

    test('T10：连续 4 次 412 后生成冲突副本并继续 VERIFY/PUBLISH', () async {
      final harness = _harness();
      final local = _snapshot(
        id: 'precondition',
        body: '本地待推',
        rev: 2,
        hlc: _hlc(1100, 'devA'),
      );
      final remote = _snapshot(
        id: 'precondition',
        body: '远端已改',
        rev: 3,
        hlc: _hlc(1200, 'devB'),
      );
      final name = harness.codec.hashedName(local.id);
      final itemPath = CloudLayout.itemPath(name);
      harness.workspace.entries[name] = local;
      harness.workspace.syncState[itemPath] = 'remote-e1';
      harness.backend.files[itemPath] = _File(
        harness.codec.encodeEntry(remote),
        'remote-e1',
      );
      final op = _upsertOp(harness, local);
      harness.workspace.pendingOps.add(op);
      harness.backend.putFailures[itemPath] = <WebDavException>[
        for (var i = 0; i < 4; i++)
          WebDavPreconditionFailed(method: 'PUT', path: itemPath),
      ];

      final result = await harness.engine().run(harness.workspace);

      expect(result.isIdle, isTrue);
      expect(result.preconditionAttempts[op.id], 4);
      expect(harness.backend.putCount[itemPath], 4);
      expect(
        result.requestLog
            .where((String request) => request == 'PUT $itemPath')
            .length,
        4,
      );
      expect(
        result.requestLog
            .where(
              (String request) => request == 'GET $itemPath after 412',
            )
            .length,
        4,
      );
      expect(result.reason, contains('连续 412 超过 3 轮'));
      expect(result.conflicts, greaterThanOrEqualTo(1));
      expect(result.conflictCopyIds, isNotEmpty);
      expect(result.entries[name]?.body, '本地待推');
      expect(result.pushedPaths, isNot(contains(itemPath)));
      expect(
        result.pushedPaths.any(
          (String path) =>
              path.startsWith('${CloudLayout.root}/items/') &&
              path != itemPath,
        ),
        isTrue,
      );
      final remotePreserved = result.conflictCopyIds
          .map((String id) => result.entries[harness.codec.hashedName(id)])
          .whereType<EntrySnapshot>()
          .any((EntrySnapshot copy) => copy.body == '远端已改');
      expect(remotePreserved, isTrue);
      expect(harness.backend.files[itemPath], isNotNull);
      expect(result.watermarkPublished, isTrue);
    });

    test('T09/T14：E_NET 与 E_RATE 在 PUSH 阶段进入 BACKOFF', () async {
      for (final statusCode in <int>[500, 429]) {
        final harness = _harness();
        final local = _snapshot(
          id: 'backoff-$statusCode',
          body: '未推送内容',
        );
        final name = harness.codec.hashedName(local.id);
        final itemPath = CloudLayout.itemPath(name);
        harness.workspace.entries[name] = local;
        harness.workspace.pendingOps.add(_upsertOp(harness, local));
        harness.backend.putFailures[itemPath] = <WebDavException>[
          WebDavException(
            statusCode: statusCode,
            method: 'PUT',
            path: itemPath,
          ),
        ];

        final result = await harness.engine().run(harness.workspace);

        expect(result.isBackoff, isTrue, reason: 'status=$statusCode');
        expect(result.isFailed, isFalse, reason: 'status=$statusCode');
        expect(result.phases.last, SyncPhase.backoff);
        expect(result.requestLog, contains('PUT $itemPath'));
        expect(result.pushedPaths, isEmpty);
        expect(result.appliedOps, isEmpty);
        expect(result.watermarkPublished, isFalse);
      }
    });

    test('请求预算耗尽时保存进度，不标记为已推送、不发布水位', () async {
      final harness = _harness();
      final local = _snapshot(id: 'budget', body: '预算不足');
      final name = harness.codec.hashedName(local.id);
      harness.workspace.entries[name] = local;
      harness.workspace.pendingOps.add(_upsertOp(harness, local));

      final result =
          await harness.engine(budgetLimit: 1).run(harness.workspace);

      expect(result.budgetExceeded, isTrue);
      expect(result.requestCount, 1);
      expect(result.pushedPaths, isEmpty);
      expect(result.appliedOps, isEmpty);
      expect(result.watermarkPublished, isFalse);
      expect(result.reason, contains('请求预算不足'));
      expect(result.entries[name], same(local));
      expect(result.isIdle, isTrue);
    });

    test('单飞锁忙时直接跳过，不排队发请求；释放后可继续', () async {
      final harness = _harness();
      final lock = SingleFlightLock();
      expect(lock.tryAcquire(), isTrue);

      final skipped = await harness.engine(lock: lock).run(harness.workspace);
      expect(skipped.skipped, isTrue);
      expect(skipped.isIdle, isTrue);
      expect(skipped.requestLog, isEmpty);
      expect(skipped.requestCount, 0);
      expect(skipped.reason, contains('跳过'));
      expect(harness.backend.calls, isEmpty);

      lock.release();
      final next = await harness.engine(lock: lock).run(harness.workspace);
      expect(next.skipped, isFalse);
      expect(next.isIdle, isTrue);
      expect(next.requestLog, isNotEmpty);
      expect(harness.backend.calls, isNotEmpty);
    });
  });

  group('L2 删除列表（远端 item 文件消失）', () {
    /// 构造一份「本地有该条目、远端明确给了删除列表」的工作区。
    _Harness deletedHarness({
      required EntrySnapshot local,
      required int baseRev,
      Map<String, String?>? syncState,
    }) {
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
        baseRevs: <String, int>{local.id: baseRev},
        baseSnapshots: <String, EntrySnapshot?>{
          local.id: baseRev == 0 ? null : _snapshot(id: local.id, rev: baseRev),
        },
        syncState: syncState,
        delta: SyncCollectionDelta(
          changed: <String, String?>{},
          deleted: <String>{},
          syncToken: 'token-2',
        ),
      );
      final name = harness.codec.hashedName(local.id);
      final itemPath = CloudLayout.itemPath(name);
      harness.workspace.entries[name] = local;
      harness.backend.delta.deleted.add(itemPath);
      return harness;
    }

    test('规则 7：远端文件消失且本地未变时软删进回收站，清掉陈旧 ETag',
        () async {
      final local = _snapshot(id: 'entry-vanished', body: '原文', rev: 2);
      final harness = deletedHarness(local: local, baseRev: 2);
      final itemPath = harness.backend.delta.deleted.single;
      harness.workspace.syncState[itemPath] = 'gone-e1';

      final result = await harness.engine().run(harness.workspace);

      expect(result.diff.deleted, <String>{itemPath});
      final applied = result.entries[harness.codec.hashedName(local.id)]!;
      expect(applied.deleted, isTrue);
      expect(applied.deletedAt, _now);
      expect(result.deletedEntries, contains(harness.codec.hashedName(local.id)));
      expect(result.syncState.containsKey(itemPath), isFalse,
          reason: '陈旧 sync_state 必须移除，否则下轮反复误判删除');
      expect(result.cloudAppliedEntryIds, contains(local.id));
      expect(result.pushedPaths, isEmpty,
          reason: '本地未变时只是软删，不推新版本');
    });

    test('编辑胜：本地有未推编辑时复活并写新 rev，绝不因文件消失吞内容',
        () async {
      final local = _snapshot(id: 'entry-edited', body: '本地改过', rev: 3);
      final harness = deletedHarness(local: local, baseRev: 2);
      final itemPath = harness.backend.delta.deleted.single;
      harness.workspace.syncState[itemPath] = 'gone-e1';

      final result = await harness.engine().run(harness.workspace);

      final applied = result.entries[harness.codec.hashedName(local.id)]!;
      expect(applied.deleted, isFalse);
      expect(applied.rev, 4);
      expect(applied.body, '本地改过');
      expect(result.syncState[itemPath], isNot('gone-e1'),
          reason: '复活后推回云端会写入新 ETag，陈旧 ETag 必须被替换');
      expect(result.pushedPaths, contains(itemPath),
          reason: '复活的新版本必须推回云端');
    });

    test('本轮已有墓碑判定时，文件消失不重复 bump rev / 软删', () async {
      final local = _snapshot(id: 'entry-both', body: '原文', rev: 3);
      final harness = deletedHarness(local: local, baseRev: 2);
      // 墓碑的 hashedName 必须与条目一致才会命中同一条。
      _addTombstone(
        harness,
        SyncTombstone(
          entryId: local.id,
          hashedName: harness.codec.hashedName(local.id),
          deletedAt: _now,
          deviceId: _other,
          rev: 3,
        ),
      );

      final result = await harness.engine().run(harness.workspace);

      final applied = result.entries[harness.codec.hashedName(local.id)]!;
      expect(applied.rev, 4, reason: '墓碑的编辑胜已经 bump 一次，不能变成 5');
      expect(result.pushedPaths.length, 1);
      expect(
        result.syncState[harness.backend.delta.deleted.single],
        isNot('gone-e1'),
        reason: '墓碑编辑胜推回云端后写入新 ETag，不会被删除列表二次处理',
      );
    });

    test('非 items 命名空间的 deleted 只清状态，不动本地实体', () async {
      final local = _snapshot(id: 'entry-keep', body: '本地完好', rev: 1);
      final harness = _harness(
        localWatermarks: <String, Hlc?>{},
        deviceEtags: <String, String>{},
        delta: SyncCollectionDelta(
          changed: <String, String?>{},
          deleted: <String>{},
          syncToken: 'token-2',
        ),
      );
      final name = harness.codec.hashedName(local.id);
      harness.workspace.entries[name] = local;
      const String entityPath =
          '/vault/entities/0/11111111111111111111111111111111.enc';
      harness.backend.delta.deleted.add(entityPath);
      harness.workspace.syncState[entityPath] = 'entity-e1';

      final result = await harness.engine().run(harness.workspace);

      expect(result.entries[name], same(local));
      expect(result.syncState.containsKey(entityPath), isFalse);
      expect(result.cloudAppliedEntryIds, isEmpty);
    });
  });
}
