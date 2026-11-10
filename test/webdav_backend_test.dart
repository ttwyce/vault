import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/sync/sync_state_machine.dart';
import 'package:vault/core/sync/webdav_backend.dart';

class _MemoryWebDavBackend implements WebDavBackend {
  _MemoryWebDavBackend({
    required this.optionsHeaders,
    required this.listings,
    required this.delta,
    this.getResults = const <String, WebDavGetResult>{},
  });

  final Map<String, String> optionsHeaders;
  final List<WebDavListing> listings;
  final SyncCollectionDelta delta;
  final Map<String, WebDavGetResult> getResults;
  final List<String> calls = <String>[];

  @override
  Future<Map<String, String>> options(String path) async {
    calls.add('OPTIONS $path');
    return optionsHeaders;
  }

  @override
  Future<List<WebDavListing>> propfind(
    String path, {
    int depth = 1,
  }) async {
    calls.add('PROPFIND $path depth=$depth');
    return listings;
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
    final result = getResults[path];
    if (result == null) {
      throw WebDavException(
        statusCode: 404,
        method: 'GET',
        path: path,
      );
    }
    return result;
  }

  @override
  Future<WebDavPutResult> put(
    String path,
    List<int> bytes, {
    required WebDavCondition condition,
  }) async {
    calls.add('PUT $path ${condition.headerName}: ${condition.headerValue}');
    if (!condition.isValid) {
      throw ArgumentError('条件写不能同时为空');
    }
    return const WebDavPutResult(etag: 'etag-new', statusCode: 201);
  }

  @override
  Future<void> delete(String path, {required String ifMatch}) async {
    calls.add('DELETE $path If-Match: $ifMatch');
  }

  @override
  Future<void> mkcol(String path) async {
    calls.add('MKCOL $path');
  }
}

void main() {
  group('能力探测（docs/04 §3.2）', () {
    test('大小写不敏感地识别 sync-collection 与条件写能力', () {
      final capabilities = detectWebDavCapabilities(<String, String>{
        'dAv': '1, 3, sync-collection',
        'allow': 'OPTIONS, PROPFIND, REPORT, GET, PUT, DELETE',
        'eTaG': '"vault-1"',
      });

      expect(capabilities.davTokens, <String>['1', '3', 'sync-collection']);
      expect(capabilities.syncCollection, isTrue);
      expect(capabilities.conditionalPut, isTrue);
      expect(capabilities.depthOnePropfind, isTrue);
      expect(
        capabilities.discoveryStrategy,
        WebDavDiscoveryStrategy.syncCollection,
      );
      expect(capabilities.maxConcurrentRequests, 3);
      expect(capabilities.cacheTtl, const Duration(hours: 24));
      expect(
        capabilities.isCacheExpired(0, kWebDavCapabilityCacheTtl.inMilliseconds),
        isFalse,
      );
      expect(
        capabilities.isCacheExpired(
          0,
          kWebDavCapabilityCacheTtl.inMilliseconds + 1,
        ),
        isTrue,
      );
    });

    test('不支持 RFC 6578 时降级为 16 分片 PROPFIND', () {
      final fallback = detectWebDavCapabilities(<String, String>{
        'DAV': '1',
        'Allow': 'OPTIONS, PROPFIND, GET, PUT, DELETE',
      });
      expect(fallback.syncCollection, isFalse);
      expect(
        fallback.discoveryStrategy,
        WebDavDiscoveryStrategy.shardedPropfind,
      );
      expect(fallback.conditionalPut, isTrue);
      expect(fallback.depthOnePropfind, isTrue);

      final bare = detectWebDavCapabilities(<String, String>{});
      expect(bare.davTokens, isEmpty);
      expect(bare.syncCollection, isFalse);
      expect(bare.conditionalPut, isFalse);
      expect(bare.depthOnePropfind, isFalse);
      expect(
        bare.discoveryStrategy,
        WebDavDiscoveryStrategy.shardedPropfind,
      );
    });
  });

  group('条件写与错误分类', () {
    test('If-Match / If-None-Match 二选一，杜绝无条件 PUT 形态', () {
      const match = WebDavCondition.ifMatch('etag-7');
      expect(match.isValid, isTrue);
      expect(match.headerName, 'If-Match');
      expect(match.headerValue, 'etag-7');
      expect(match.toString(), contains('If-Match: etag-7'));

      const create = WebDavCondition.createOnly();
      expect(create.isValid, isTrue);
      expect(create.isCreateOnly, isTrue);
      expect(create.headerName, 'If-None-Match');
      expect(create.headerValue, '*');
    });

    test('HTTP 状态码映射到统一错误码；412 是冲突不是损坏', () {
      expect(syncErrorCodeForStatus(401), SyncErrorCode.auth);
      expect(syncErrorCodeForStatus(403), SyncErrorCode.auth);
      expect(syncErrorCodeForStatus(404), SyncErrorCode.path);
      expect(syncErrorCodeForStatus(409), SyncErrorCode.path);
      expect(syncErrorCodeForStatus(412), SyncErrorCode.conflict);
      expect(syncErrorCodeForStatus(429), SyncErrorCode.rate);
      expect(syncErrorCodeForStatus(503), SyncErrorCode.rate);
      expect(syncErrorCodeForStatus(507), SyncErrorCode.quota);
      expect(syncErrorCodeForStatus(500), SyncErrorCode.net);

      const failure = WebDavPreconditionFailed(
        method: 'PUT',
        path: '/vault/items/0/a.enc',
      );
      expect(failure.isPreconditionFailed, isTrue);
      expect(failure.syncErrorCode, SyncErrorCode.conflict);
      expect(failure.toString(), contains('412'));
    });
  });

  group('L2 增量 diff', () {
    test('PROPFIND 列表跳过集合目录，只保留文件 etag', () {
      final etags = listingsToEtags(<WebDavListing>[
        const WebDavListing(path: '/vault/items/0', etag: null, isCollection: true),
        const WebDavListing(path: '/vault/items/0/a.enc', etag: 'e1'),
        const WebDavListing(path: '/vault/items/0/b.enc', etag: null),
      ]);
      expect(etags, <String, String?>{
        '/vault/items/0/a.enc': 'e1',
        '/vault/items/0/b.enc': null,
      });
    });

    test('sync-collection 只相信服务器给出的删除列表', () {
      final diff = diffSyncCollection(
        delta: const SyncCollectionDelta(
          changed: <String, String?>{'/vault/items/0/a.enc': 'e2'},
          deleted: <String>{'/vault/items/0/c.enc'},
          syncToken: 'token-2',
        ),
        local: <String, String?>{
          '/vault/items/0/a.enc': 'e1',
          '/vault/items/0/b.enc': 'e1',
          '/vault/items/0/c.enc': 'e1',
        },
      );

      expect(diff.added, isEmpty);
      expect(diff.modified, <String>{'/vault/items/0/a.enc'});
      expect(diff.deleted, <String>{'/vault/items/0/c.enc'});
      expect(diff.pullCount, 1);
    });

    test('只有 16 个分片全部扫完才允许从缺失推断删除', () {
      Map<String, List<WebDavListing>> shards([int count = 16]) =>
          <String, List<WebDavListing>>{
            for (var i = 0; i < count; i++)
              i.toRadixString(16): <WebDavListing>[],
          };

      expect(
        () => diffAllShards(
          shards: shards(15),
          local: <String, String?>{'a': 'e1'},
        ),
        throwsA(isA<ArgumentError>()),
      );

      final all = shards();
      all['0'] = <WebDavListing>[
        const WebDavListing(path: '/vault/items/0/a.enc', etag: 'e2'),
      ];
      final diff = diffAllShards(
        shards: all,
        local: <String, String?>{
          '/vault/items/0/a.enc': 'e1',
          '/vault/items/0/b.enc': 'e1',
        },
      );
      expect(diff.modified, <String>{'/vault/items/0/a.enc'});
      expect(diff.deleted, <String>{'/vault/items/0/b.enc'});
    });
  });

  group('后端接口', () {
    test('内存实现能记录全部方法，且 PUT/DELETE 都带条件', () async {
      final backend = _MemoryWebDavBackend(
        optionsHeaders: <String, String>{'DAV': '1, sync-collection'},
        listings: <WebDavListing>[
          const WebDavListing(path: '/vault/devices/devA.json', etag: 'e1'),
        ],
        delta: const SyncCollectionDelta(
          changed: <String, String?>{},
          deleted: <String>{},
          syncToken: 't1',
        ),
        getResults: <String, WebDavGetResult>{
          '/vault/meta.enc': WebDavGetResult(
            bytes: <int>[1, 2, 3],
            etag: 'meta-1',
          ),
        },
      );

      expect((await backend.options('/vault/'))['DAV'], contains('sync-collection'));
      expect((await backend.propfind('/vault/devices/', depth: 1)), hasLength(1));
      expect((await backend.reportSyncCollection('/vault/', syncToken: 't0')).syncToken, 't1');
      expect((await backend.get('/vault/meta.enc')).etag, 'meta-1');

      final put = await backend.put(
        '/vault/items/0/a.enc',
        <int>[9],
        condition: const WebDavCondition.ifMatch('e1'),
      );
      expect(put.etag, 'etag-new');
      await backend.put(
        '/vault/items/0/new.enc',
        <int>[8],
        condition: const WebDavCondition.createOnly(),
      );
      await backend.delete('/vault/items/0/a.enc', ifMatch: 'e2');
      await backend.mkcol('/vault/items/0');

      expect(backend.calls, <String>[
        'OPTIONS /vault/',
        'PROPFIND /vault/devices/ depth=1',
        'REPORT /vault/ token=t0',
        'GET /vault/meta.enc',
        'PUT /vault/items/0/a.enc If-Match: e1',
        'PUT /vault/items/0/new.enc If-None-Match: *',
        'DELETE /vault/items/0/a.enc If-Match: e2',
        'MKCOL /vault/items/0',
      ]);
    });
  });
}
