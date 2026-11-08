import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/vault_gate.dart';
import 'package:vault/app/session/vault_session.dart';
import 'package:vault/core/crypto/argon2_params.dart';
import 'package:vault/core/crypto/recovery_code.dart';
import 'package:vault/core/crypto/vault_meta.dart';

/// 闸门路由判断的测试。
///
/// 这里测的是 [resolveGateScreen] 这个纯函数，不是 widget。
/// 原因：这条规则（"未确认的恢复码优先于一切"）是整个 App 最容易写错的
/// 一处判断，而它本身不依赖任何 Flutter 环境 —— 为它搭一套 widget
/// 测试既慢又容易因为无关改动而碎。
void main() {
  VaultSessionState state({
    required VaultStatus status,
    RecoveryCode? recoveryCode,
    String? error,
  }) {
    return VaultSessionState(
      status: status,
      recoveryCode: recoveryCode,
      error: error,
    );
  }

  group('状态 → 屏幕', () {
    test('没有 vault → 首次创建', () {
      expect(
        resolveGateScreen(state(status: VaultStatus.needsSetup)),
        GateScreen.onboarding,
      );
    });

    test('有 vault 未解锁 → 解锁页', () {
      expect(
        resolveGateScreen(state(status: VaultStatus.locked)),
        GateScreen.unlock,
      );
    });

    test('解锁中仍然停在解锁页（不切独立加载页，避免闪一下）', () {
      // 解锁阶段必然已有 meta —— 否则根本没有东西可解。
      final withMeta = VaultSessionState(
        status: VaultStatus.unlocking,
        meta: VaultMeta(
          vaultId: 'v1',
          createdAt: 0,
          kdfParams: Argon2Params.insecureForTests,
          kdfSalt: KdfSalt(Uint8List(16)),
          wrappedDek: Uint8List(73),
        ),
      );
      expect(resolveGateScreen(withMeta), GateScreen.unlock);
    });

    test('首次创建派生中也停在创建页（unlocking 要靠 meta 区分）', () {
      // 创建 vault 的过程中状态也是 `unlocking`，但 meta 还没写盘。
      // 如果这里返回 unlock，用户会看到"刚设完密码，界面突然变成另一个页面"。
      expect(
        resolveGateScreen(state(status: VaultStatus.unlocking)),
        GateScreen.onboarding,
        reason: 'meta 为 null 说明还在创建阶段，不能切到解锁页',
      );
    });

    test('已解锁 → 主界面', () {
      expect(
        resolveGateScreen(state(status: VaultStatus.unlocked)),
        GateScreen.shell,
      );
    });

    test('致命错误 → 错误页', () {
      expect(
        resolveGateScreen(state(status: VaultStatus.failed, error: 'meta.enc 损坏')),
        GateScreen.fatal,
      );
    });
  });

  group('恢复码优先于状态', () {
    test('创建成功但还没确认恢复码时，必须停在 onboarding', () {
      // 这是整个闸门最重要的一条：此时 status 已经是 unlocked，
      // 如果按状态走就会直接进主界面，24 个词永远看不到。
      final screen = resolveGateScreen(
        state(
          status: VaultStatus.unlocked,
          recoveryCode: RecoveryCode.generate(Random(1)),
        ),
      );
      expect(screen, GateScreen.onboarding);
      expect(screen, isNot(GateScreen.shell));
    });

    test('恢复码确认之后才进主界面', () {
      final created = state(
        status: VaultStatus.unlocked,
        recoveryCode: RecoveryCode.generate(Random(2)),
      );
      expect(resolveGateScreen(created), GateScreen.onboarding);
      expect(
        resolveGateScreen(created.copyWith(clearRecoveryCode: true)),
        GateScreen.shell,
      );
    });

    test('恢复码未确认时，即使状态是 failed 也先让用户抄完', () {
      // 边界情况：抄写过程中如果出现了与"看恢复码"无关的失败，
      // 也不该在用户还没抄完的时候把页面换成错误页 ——
      // 那 24 个词只在内存里，页面一走就没了。
      final screen = resolveGateScreen(
        state(
          status: VaultStatus.failed,
          recoveryCode: RecoveryCode.generate(Random(3)),
          error: 'x',
        ),
      );
      expect(screen, GateScreen.onboarding);
    });
  });

  group('状态字段语义', () {
    test('isBusy 只在 unlocking 时为真', () {
      for (final status in VaultStatus.values) {
        expect(
          state(status: status).isBusy,
          status == VaultStatus.unlocking,
          reason: '$status 的 isBusy 判断错了',
        );
      }
    });

    test('没有 derivingSince 时 elapsed 为 null', () {
      expect(state(status: VaultStatus.locked).elapsed, isNull);
    });

    test('clearError 真的清掉错误（否则一次失败会一直显示）', () {
      final failed = state(status: VaultStatus.locked, error: '密码不对');
      expect(failed.error, isNotNull);
      expect(failed.copyWith(clearError: true).error, isNull);
    });

    test('copyWith 不会丢掉 meta —— 它是解锁的唯一依据', () {
      final meta = VaultMeta(
        vaultId: 'v1',
        createdAt: 1731052800000,
        kdfParams: Argon2Params.insecureForTests,
        kdfSalt: KdfSalt(Uint8List(16)),
        wrappedDek: Uint8List(73),
      );
      final locked = VaultSessionState(status: VaultStatus.locked, meta: meta);

      for (final next in <VaultStatus>[
        VaultStatus.unlocking,
        VaultStatus.locked,
        VaultStatus.failed,
      ]) {
        expect(
          locked.copyWith(status: next).meta,
          same(meta),
          reason: '切到 $next 时把 meta 弄丢了，之后就再也解不开',
        );
      }
    });
  });
}
