/// L1：设备水位（docs/04 §3.1）。
///
/// `/vault/devices/devX.json` 是**明文**，只含 HLC 与时间戳，
/// 不含任何内容信息 —— 所以把它单独放在一个目录、一次 PROPFIND
/// 就能判断"有没有变化"，是整套同步性价比最高的一处优化。
library;

import 'hlc.dart';

class DeviceWatermark {
  const DeviceWatermark({
    required this.deviceId,
    required this.maxHlc,
    required this.lastSeen,
    required this.schema,
    this.platform,
    this.appVersion,
    this.etag,
  });

  final String deviceId;
  final Hlc maxHlc;
  final int lastSeen;
  final int schema;
  final String? platform;
  final String? appVersion;

  /// PROPFIND 返回的 ETag，**不属于 JSON 文件内容**。
  /// 只在"max_hlc 没变但文件被重写了"时用来区分时间戳更新。
  final String? etag;

  /// 解析远端水位文件。
  ///
  /// 损坏的文件不能让整个同步崩掉，也不能当成"没有这个设备"：
  /// 抛 [FormatException] 交给调用方隔离并记录，L1 直接降级进 L2 全量比对。
  factory DeviceWatermark.fromJson(
    Map<String, Object?> json, {
    String? etag,
  }) {
    final deviceId = json['device_id'];
    if (deviceId is! String || deviceId.isEmpty) {
      throw const FormatException('水位文件缺少 device_id');
    }
    final rawHlc = json['max_hlc'];
    if (rawHlc is! String) {
      throw const FormatException('水位文件缺少 max_hlc');
    }
    final hlc = Hlc.tryParse(rawHlc);
    if (hlc == null) {
      throw FormatException('水位文件的 max_hlc 不是合法 HLC：$rawHlc');
    }
    final lastSeen = json['last_seen'];
    if (lastSeen is! int) {
      throw const FormatException('水位文件缺少 last_seen');
    }
    final schema = json['schema'];
    if (schema is! int || schema < 1) {
      throw FormatException('水位文件 schema 非法：$schema');
    }
    return DeviceWatermark(
      deviceId: deviceId,
      maxHlc: hlc,
      lastSeen: lastSeen,
      schema: schema,
      platform: json['platform'] as String?,
      appVersion: json['app_version'] as String?,
      etag: etag,
    );
  }

  /// 键顺序固定：文件内容稳定，ETag 才不会因为序列化顺序抖动。
  Map<String, Object?> toJson() => <String, Object?>{
        'device_id': deviceId,
        'platform': platform,
        'max_hlc': maxHlc.encode(),
        'last_seen': lastSeen,
        'app_version': appVersion,
        'schema': schema,
      };

  /// 云端 schema 高于本地时必须拒绝同步（docs/04 §7 / T18）。
  /// 否则会用旧版代码去读写新版格式，静默损坏数据。
  bool isSchemaTooNew(int localSchema) => schema > localSchema;

  DeviceWatermark copyWith({String? etag, int? lastSeen, Hlc? maxHlc}) =>
      DeviceWatermark(
        deviceId: deviceId,
        maxHlc: maxHlc ?? this.maxHlc,
        lastSeen: lastSeen ?? this.lastSeen,
        schema: schema,
        platform: platform,
        appVersion: appVersion,
        etag: etag ?? this.etag,
      );
}

class WatermarkProbeResult {
  const WatermarkProbeResult({
    required this.hasChanges,
    required this.changedDevices,
    required this.unknownDevices,
    required this.timestampOnlyDevices,
  });

  /// 是否需要进入 L2。
  final bool hasChanges;
  final List<String> changedDevices;
  final List<String> unknownDevices;

  /// ETag 变了但 max_hlc 没前进：只是别的设备刷新了心跳，
  /// **不算内容变化**，不需要进 L2（docs/04 §3.1）。
  final List<String> timestampOnlyDevices;
}

/// 比对远端水位与本地记录。
///
/// [local] 是本地 `device_watermark` 表的快照（设备 id → 上次见到的 HLC）。
/// 未知设备（用户新装了一台）一律进 L2 全量比对 —— 它可能有我们没有的数据。
WatermarkProbeResult probeWatermarks({
  required List<DeviceWatermark> remote,
  required Map<String, Hlc?> local,
  required String selfDeviceId,
  Map<String, String> localEtags = const <String, String>{},
}) {
  final changed = <String>[];
  final unknown = <String>[];
  final timestampOnly = <String>[];

  for (final device in remote) {
    if (device.deviceId == selfDeviceId) continue;

    if (!local.containsKey(device.deviceId)) {
      unknown.add(device.deviceId);
      continue;
    }

    final seen = local[device.deviceId];
    if (seen == null || device.maxHlc > seen) {
      changed.add(device.deviceId);
      continue;
    }

    final previousEtag = localEtags[device.deviceId];
    if (device.etag != null &&
        previousEtag != null &&
        device.etag != previousEtag) {
      timestampOnly.add(device.deviceId);
    }
  }

  return WatermarkProbeResult(
    hasChanges: changed.isNotEmpty || unknown.isNotEmpty,
    changedDevices: changed,
    unknownDevices: unknown,
    timestampOnlyDevices: timestampOnly,
  );
}
