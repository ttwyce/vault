/// 三端能力矩阵的**纯判定层**（docs/08 §1 / §2）。
///
/// 不探测平台、不调原生通道：只把「哪些能力必须原生实现、哪些已由 Dart
/// 判定层/页面覆盖、哪些仍是平台层缺口」写成可复现的清单。
/// 用于发布前自检，避免把「写了纯逻辑」误当成「三端可用」。
library;

enum PlatformKind { android, ios, windows }

enum CapabilityState { dartReady, nativeRequired, unavailable }

class PlatformCapability {
  const PlatformCapability({
    required this.key,
    required this.label,
    required this.android,
    required this.ios,
    required this.windows,
    this.nativeRequired = false,
  });

  final String key;
  final String label;
  final CapabilityState android;
  final CapabilityState ios;
  final CapabilityState windows;

  /// 是否需要写原生模块（Flutter 覆盖不到）。
  final bool nativeRequired;

  CapabilityState stateFor(PlatformKind platform) => switch (platform) {
        PlatformKind.android => android,
        PlatformKind.ios => ios,
        PlatformKind.windows => windows,
      };
}

/// docs/08 §1 的能力矩阵，按「Dart 已落地 / 需原生 / 平台不支持」标注。
const List<PlatformCapability> kPlatformCapabilities = <PlatformCapability>[
  PlatformCapability(
    key: 'db',
    label: 'SQLCipher 本地库',
    android: CapabilityState.dartReady,
    ios: CapabilityState.dartReady,
    windows: CapabilityState.dartReady,
    nativeRequired: true,
  ),
  PlatformCapability(
    key: 'crypto',
    label: '加密库 sodium / VaultKeys',
    android: CapabilityState.dartReady,
    ios: CapabilityState.dartReady,
    windows: CapabilityState.dartReady,
  ),
  PlatformCapability(
    key: 'keys',
    label: 'Keystore / Keychain / Credential Manager',
    android: CapabilityState.nativeRequired,
    ios: CapabilityState.nativeRequired,
    windows: CapabilityState.nativeRequired,
    nativeRequired: true,
  ),
  PlatformCapability(
    key: 'autofill',
    label: '密码自动填充',
    android: CapabilityState.nativeRequired,
    ios: CapabilityState.nativeRequired,
    windows: CapabilityState.unavailable,
    nativeRequired: true,
  ),
  PlatformCapability(
    key: 'clipboard',
    label: '复制 + 30 秒清除',
    android: CapabilityState.dartReady,
    ios: CapabilityState.dartReady,
    windows: CapabilityState.dartReady,
  ),
  PlatformCapability(
    key: 'pdf',
    label: 'PDF 快照',
    android: CapabilityState.nativeRequired,
    ios: CapabilityState.nativeRequired,
    windows: CapabilityState.nativeRequired,
    nativeRequired: true,
  ),
  PlatformCapability(
    key: 'tray',
    label: '托盘 / 悬浮球',
    android: CapabilityState.nativeRequired,
    ios: CapabilityState.unavailable,
    windows: CapabilityState.dartReady,
    nativeRequired: true,
  ),
  PlatformCapability(
    key: 'biometric',
    label: '生物识别解锁',
    android: CapabilityState.nativeRequired,
    ios: CapabilityState.nativeRequired,
    windows: CapabilityState.nativeRequired,
    nativeRequired: true,
  ),
  PlatformCapability(
    key: 'webdav',
    label: 'WebDAV 同步后端',
    android: CapabilityState.dartReady,
    ios: CapabilityState.dartReady,
    windows: CapabilityState.dartReady,
  ),
  PlatformCapability(
    key: 'archive',
    label: '网页归档抓取 / readability',
    android: CapabilityState.nativeRequired,
    ios: CapabilityState.nativeRequired,
    windows: CapabilityState.nativeRequired,
    nativeRequired: true,
  ),
  PlatformCapability(
    key: 'ai_diary',
    label: '日总结 / 滚动摘要（纯逻辑）',
    android: CapabilityState.dartReady,
    ios: CapabilityState.dartReady,
    windows: CapabilityState.dartReady,
  ),
];

/// 平台缺口报告。
class PlatformGapReport {
  const PlatformGapReport(this.byPlatform);

  final Map<PlatformKind, List<String>> byPlatform;

  bool get allClear =>
      byPlatform.values.every((List<String> gaps) => gaps.isEmpty);

  List<String> gapsFor(PlatformKind p) =>
      List<String>.unmodifiable(byPlatform[p] ?? const <String>[]);
}

/// 校验：列出每个平台仍需原生实现的能力。
PlatformGapReport auditPlatformGaps({
  Iterable<PlatformCapability> capabilities = kPlatformCapabilities,
}) {
  final out = <PlatformKind, List<String>>{};
  for (final platform in PlatformKind.values) {
    out[platform] = <String>[
      for (final cap in capabilities)
        if (cap.stateFor(platform) == CapabilityState.nativeRequired)
          cap.label,
    ];
  }
  return PlatformGapReport(Map<PlatformKind, List<String>>.unmodifiable(out));
}

/// 某平台「不可用」的能力（例如 iOS 无托盘、Windows 无系统填充）。
List<String> unavailableFor(
  PlatformKind platform, {
  Iterable<PlatformCapability> capabilities = kPlatformCapabilities,
}) =>
    <String>[
      for (final cap in capabilities)
        if (cap.stateFor(platform) == CapabilityState.unavailable) cap.label,
    ];
