import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/vault_session.dart';
import 'package:vault/app/session/vault_storage.dart';
import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/core/crypto/argon2_params.dart';
import 'package:vault/core/crypto/recovery_code.dart';
import 'package:vault/features/unlock/onboarding_page.dart';

/// 测试阶段专用的「跳过恢复码抽查」入口。
void main() {
  testWidgets('debug 构建展示跳过入口，二次确认后清掉恢复码',
      (WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('vault_onboarding_skip_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final container = ProviderContainer(
      overrides: [
        vaultBootstrapProvider.overrideWithValue(
          VaultBootstrap(
            storage: VaultStorage(directory: dir),
            deviceId: 'devA',
            meta: null,
            params: Argon2Params.insecureForTests,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final code = RecoveryCode.generate(Random(7));
    // 模拟「刚创建完 vault、24 个词还在内存里」的闸门状态。
    container.read(vaultSessionProvider.notifier).state =
        container.read(vaultSessionProvider).copyWith(
              status: VaultStatus.unlocked,
              recoveryCode: code,
            );

    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: SketchTheme.light,
        home: const OnboardingPage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('把这 24 个词抄下来'), findsOneWidget);
    expect(find.text('测试阶段：跳过抽查'), findsOneWidget);
    expect(container.read(vaultSessionProvider).recoveryCode, isNotNull);

    await tester.tap(find.text('测试阶段：跳过抽查'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('跳过恢复码抽查？'), findsOneWidget);
    expect(find.textContaining('数据会永久无法解密'), findsOneWidget);

    // 取消不推进状态。
    await tester.tap(find.text('继续抽查'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(vaultSessionProvider).recoveryCode, isNotNull);

    // 二次确认才真正跳过。
    await tester.tap(find.text('测试阶段：跳过抽查'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('确认跳过'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(vaultSessionProvider).recoveryCode, isNull);
  });

  testWidgets('进入抽查面板后仍可跳过，且走同一个确认流程',
      (WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('vault_onboarding_skip_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final container = ProviderContainer(
      overrides: [
        vaultBootstrapProvider.overrideWithValue(
          VaultBootstrap(
            storage: VaultStorage(directory: dir),
            deviceId: 'devA',
            meta: null,
            params: Argon2Params.insecureForTests,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final code = RecoveryCode.generate(Random(8));
    container.read(vaultSessionProvider.notifier).state =
        container.read(vaultSessionProvider).copyWith(
              status: VaultStatus.unlocked,
              recoveryCode: code,
            );

    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: SketchTheme.light,
        home: const OnboardingPage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('我已抄好，开始验证'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('抽 3 个词对一下'), findsOneWidget);
    expect(find.text('测试阶段：跳过抽查'), findsOneWidget);

    await tester.tap(find.text('测试阶段：跳过抽查'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('确认跳过'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(vaultSessionProvider).recoveryCode, isNull);
  });
}
