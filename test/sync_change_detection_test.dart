import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/sync/change_diff.dart';
import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/device_watermark.dart';
import 'package:vault/core/sync/hlc.dart';

DeviceWatermark watermark(
  String deviceId,
  Hlc maxHlc, {
  String? etag,
  int schema = 1,
}) {
  return DeviceWatermark(
    deviceId: deviceId,
    maxHlc: maxHlc,
    lastSeen: 1731052800000,
    schema: schema,
    platform: 'windows',
    appVersion: '0.15',
    etag: etag,
  );
}

void main() {
  group('DeviceWatermark（L1 / T18）', () {
    test('解析、序列化与 schema 兼容性', () {
      const hlc = Hlc(millis: 1731052800123, counter: 7, node: 'devB');
      final parsed = DeviceWatermark.fromJson(
        <String, Object?>{
          'device_id': 'devB',
          'platform': 'android',
          'max_hlc': hlc.encode(),
          'last_seen': 1731052800123,
          'app_version': '0.15',
          'schema': 3,
        },
        etag: 'etag-1',
      );

      expect(parsed.deviceId, 'devB');
      expect(parsed.maxHlc, hlc);
      expect(parsed.etag, 'etag-1');
      expect(parsed.schema, 3);
      expect(parsed.isSchemaTooNew(2), isTrue);
      expect(parsed.isSchemaTooNew(3), isFalse);
      expect(
        parsed.toJson(),
        <String, Object?>{
          'device_id': 'devB',
          'platform': 'android',
          'max_hlc': hlc.encode(),
          'last_seen': 1731052800123,
          'app_version': '0.15',
          'schema': 3,
        },
      );
      expect(
        parsed.toJson().keys.toList(),
        <String>[
          'device_id',
          'platform',
          'max_hlc',
          'last_seen',
          'app_version',
          'schema',
        ],
        reason: '键顺序固定，避免心跳重写让 ETag 抖动',
      );
    });

    test('损坏水位抛 FormatException，交给调用方降级 L2', () {
      final validHlc =
          const Hlc(millis: 1731052800000, counter: 0, node: 'devB').encode();
      Object? nullValue;

      expect(
        () => DeviceWatermark.fromJson(<String, Object?>{}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DeviceWatermark.fromJson(<String, Object?>{
              'device_id': '',
              'max_hlc': validHlc,
              'last_seen': 1,
              'schema': 1,
            }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DeviceWatermark.fromJson(<String, Object?>{
              'device_id': 'devB',
              'max_hlc': 'garbage',
              'last_seen': 1,
              'schema': 1,
            }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DeviceWatermark.fromJson(<String, Object?>{
              'device_id': 'devB',
              'max_hlc': validHlc,
              'last_seen': nullValue,
              'schema': 1,
            }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DeviceWatermark.fromJson(<String, Object?>{
              'device_id': 'devB',
              'max_hlc': validHlc,
              'last_seen': 1,
              'schema': 0,
            }),
        throwsA(isA<FormatException>()),
      );
    });

    test('水位前进 / 未知设备才进 L2；自身设备永远忽略', () {
      const h1 = Hlc(millis: 1731052800000, counter: 0, node: 'devB');
      const h2 = Hlc(millis: 1731052800001, counter: 0, node: 'devB');
      final result = probeWatermarks(
        remote: <DeviceWatermark>[
          watermark('devA', const Hlc(
            millis: 1731052999999,
            counter: 0,
            node: 'devA',
          ), etag: 'self-changed'),
          watermark('devB', h2, etag: 'b2'),
          watermark('devC', h2, etag: 'c2'),
        ],
        local: <String, Hlc?>{'devB': h1},
        selfDeviceId: 'devA',
      );

      expect(result.hasChanges, isTrue);
      expect(result.changedDevices, <String>['devB']);
      expect(result.unknownDevices, <String>['devC']);
      expect(result.timestampOnlyDevices, isEmpty);
    });

    test('ETag 变了但 max_hlc 没前进只是心跳，不触发全量比对', () {
      const h2 = Hlc(millis: 1731052800001, counter: 0, node: 'devB');
      final result = probeWatermarks(
        remote: <DeviceWatermark>[
          watermark('devA', h2, etag: 'self-changed'),
          watermark('devD', h2, etag: 'heartbeat'),
          watermark('devE', h2, etag: 'same'),
        ],
        local: <String, Hlc?>{
          'devD': h2,
          'devE': h2,
        },
        localEtags: <String, String>{
          'devD': 'old',
          'devE': 'same',
        },
        selfDeviceId: 'devA',
      );

      expect(result.hasChanges, isFalse);
      expect(result.changedDevices, isEmpty);
      expect(result.unknownDevices, isEmpty);
      expect(result.timestampOnlyDevices, <String>['devD']);
    });

    test('本地记录为 null 或远端 HLC 倒退都按安全方向处理', () {
      const older = Hlc(millis: 1731052800000, counter: 0, node: 'devB');
      const newer = Hlc(millis: 1731052800001, counter: 0, node: 'devB');

      final nullLocal = probeWatermarks(
        remote: <DeviceWatermark>[watermark('devB', newer)],
        local: <String, Hlc?>{'devB': null},
        selfDeviceId: 'devA',
      );
      expect(nullLocal.hasChanges, isTrue);
      expect(nullLocal.changedDevices, <String>['devB']);

      final staleRemote = probeWatermarks(
        remote: <DeviceWatermark>[watermark('devB', older)],
        local: <String, Hlc?>{'devB': newer},
        selfDeviceId: 'devA',
      );
      expect(staleRemote.hasChanges, isFalse);
    });
  });

  group('L2 目录 diff（docs/04 §3.2）', () {
    test('按 ETag 分出新增、修改、删除，并计算拉取请求数', () {
      final diff = diffListings(
        remote: <String, String?>{
          'a': 'e1',
          'b': 'e2',
          'd': 'e4',
        },
        local: <String, String?>{
          'a': 'e1',
          'b': 'e1',
          'c': 'e1',
        },
      );

      expect(diff.added, <String>{'d'});
      expect(diff.modified, <String>{'b'});
      expect(diff.deleted, <String>{'c'});
      expect(diff.pullCount, 2);
      expect(diff.isEmpty, isFalse);
      expect(SyncDiff.empty.isEmpty, isTrue);
    });

    test('只扫了部分分片时禁止从目录缺失推断删除', () {
      final diff = diffListings(
        remote: <String, String?>{'b': 'e2'},
        local: <String, String?>{
          'a': 'e1',
          'b': 'e1',
          'c': 'e1',
        },
        includeDeletes: false,
      );

      expect(diff.modified, <String>{'b'});
      expect(diff.added, isEmpty);
      expect(diff.deleted, isEmpty, reason: 'a/c 可能只是没扫到的分片');
    });

    test('sync-collection 的删除列表优先合入，不从缺失猜测', () {
      final partial = diffListings(
        remote: <String, String?>{'new': 'n1'},
        local: <String, String?>{
          'old': 'o1',
          'gone': 'g1',
        },
        includeDeletes: false,
      );
      final withDeletes = withServerDeletes(
        partial,
        <String>['old', 'gone'],
      );

      expect(partial.deleted, isEmpty);
      expect(withDeletes.deleted, <String>{'old', 'gone'});
      expect(withDeletes.added, <String>{'new'});
      expect(withDeletes.modified, isEmpty);
    });
  });

  group('CloudLayout（docs/04 §2）', () {
    const name = '0123456789abcdef0123456789abcdef.enc';

    test('文件名 / 分片 / 三类路径都符合固定布局', () {
      expect(CloudLayout.root, '/vault');
      expect(CloudLayout.shardCount, 16);
      expect(CloudLayout.isValidItemName(name), isTrue);
      expect(CloudLayout.shardOf(name), '0');
      expect(CloudLayout.itemPath(name), '/vault/items/0/$name');
      expect(CloudLayout.tombstonePath(name), '/vault/tombstones/$name');
      expect(CloudLayout.vectorPath(name), '/vault/vec/$name');
      expect(CloudLayout.metaPath, '/vault/meta.enc');
      expect(CloudLayout.devicesDir, '/vault/devices');
    });

    test('blob 按内容寻址且不可变', () {
      final sha = List<String>.filled(64, 'a').join();
      expect(CloudLayout.blobPath(sha), '/vault/blobs/aa/$sha.bin');
      expect(
        () => CloudLayout.blobPath('abc'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('设备 id 与完整路径按段编码，保留路径分隔符', () {
      const deviceId = '设备 A';
      final encodedId = Uri.encodeComponent(deviceId);
      expect(
        CloudLayout.devicePath(deviceId),
        '/vault/devices/$encodedId.json',
      );
      expect(CloudLayout.devicePath(deviceId).contains(deviceId), isFalse);

      final encoded = CloudLayout.encodePath('/vault/a b/中文');
      expect(
        encoded,
        '/vault/${Uri.encodeComponent('a b')}/${Uri.encodeComponent('中文')}',
      );
      expect(encoded.toLowerCase().contains('%2f'), isFalse);
    });

    test('非法文件名绝不塞进云端路径', () {
      expect(CloudLayout.isValidItemName(name.toUpperCase()), isFalse);
      expect(CloudLayout.isValidItemName('0123.enc'), isFalse);
      expect(CloudLayout.isValidItemName('z123456789abcdef0123456789abcdef.enc'), isFalse);
      expect(
        () => CloudLayout.itemPath('bad.enc'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CloudLayout.tombstonePath('bad'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CloudLayout.vectorPath('bad'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
