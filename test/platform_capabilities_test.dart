import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/platform/platform_capabilities.dart';

/// docs/08 §1 / §2 三端能力矩阵测试。
void main() {
  test('矩阵覆盖 11 项能力，三端都有明确状态', () {
    expect(kPlatformCapabilities, hasLength(11));
    for (final cap in kPlatformCapabilities) {
      for (final platform in PlatformKind.values) {
        expect(cap.stateFor(platform), isA<CapabilityState>());
      }
    }
  });

  test('平台缺口：每个平台都列出需原生实现的能力，不会误报已落地项', () {
    final report = auditPlatformGaps();
    expect(report.allClear, isFalse,
        reason: 'M8 原生能力未完成，不能假装三端可用');
    for (final platform in PlatformKind.values) {
      final gaps = report.gapsFor(platform);
      expect(gaps, isNotEmpty);
      if (platform == PlatformKind.windows) {
        expect(unavailableFor(platform), contains('密码自动填充'),
            reason: 'Windows 无系统 API');
      } else {
        expect(gaps, contains('密码自动填充'),
            reason: 'Android / iOS 需原生 Autofill');
      }
      expect(gaps, isNot(contains('日总结 / 滚动摘要（纯逻辑）')));
      expect(gaps, isNot(contains('复制 + 30 秒清除')));
      expect(gaps, isNot(contains('WebDAV 同步后端')));
    }
  });

  test('不可用能力：iOS 无托盘、Windows 无系统填充', () {
    expect(unavailableFor(PlatformKind.ios), contains('托盘 / 悬浮球'));
    expect(unavailableFor(PlatformKind.windows),
        contains('密码自动填充'));
    expect(unavailableFor(PlatformKind.android), isEmpty);
  });

  test('自定义矩阵可注入，已全部 Dart 就绪时报告全清', () {
    const onlyDart = <PlatformCapability>[
      PlatformCapability(
        key: 'x',
        label: '纯逻辑',
        android: CapabilityState.dartReady,
        ios: CapabilityState.dartReady,
        windows: CapabilityState.dartReady,
      ),
    ];
    expect(auditPlatformGaps(capabilities: onlyDart).allClear, isTrue);
  });
}
