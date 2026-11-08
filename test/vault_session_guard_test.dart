import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/vault_session.dart';
import 'package:vault/app/session/vault_storage.dart';
import 'package:vault/core/crypto/argon2_params.dart';
import 'package:vault/core/crypto/vault_meta.dart';

/// 会话状态机的**防御性**测试。
///
/// 与 `vault_session_test.dart` 的分工：那个文件测"正常路径能走通"，
/// 这个文件测"不该发生的调用必须被拦住"。
///
/// 为什么单独一个文件：这里每一条都对应一个**不可逆**的失败模式
/// （覆盖 meta.enc = 老数据永久打不开），值得独立成组，一眼能看出
/// 哪些事故是被测试钉住的。
void main() {
  late Directory dir;
  late VaultStorage storage;

  /// 本用例创建过的容器。tearDown 里要逐个关库再删目录。
  final containers = <ProviderContainer>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vault_guard_');
    storage = VaultStorage(directory: dir);
    containers.clear();
  });

  tearDown(() async {
    // **必须先 lock 再删目录。**
    //
    // `ProviderContainer.dispose()` 只销毁 provider，不会关闭会话持有的
    // 数据库句柄 —— SQLCipher 的文件还开着。Windows 上这时删目录会报
    // `PathAccessException: 另一个程序正在使用此文件`，而这个异常发生在
    // tearDown 里会被记成"测试失败"，掩盖掉断言其实是通过的。
    for (final container in containers) {
      try {
        if (container.read(vaultSessionProvider).opener != null) {
          await container.read(vaultSessionProvider.notifier).lock();
        }
      } on Object {
        // 会话可能已经处于不可用状态，清理阶段不必因此失败
      }
      container.dispose();
    }
    containers.clear();

    // 句柄释放到文件系统真正可用之间可能有极短延迟，给几次重试。
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    }
  });

  /// 造一个会话容器。`meta` 为 null 表示"本机没有 vault"的启动状态。
  ProviderContainer containerWith({VaultMeta? meta, String deviceId = 'devA'}) {
    final container = ProviderContainer(
      overrides: [
        vaultBootstrapProvider.overrideWithValue(
          VaultBootstrap(
            storage: storage,
            deviceId: deviceId,
            meta: meta,
            params: Argon2Params.insecureForTests,
          ),
        ),
      ],
    );
    containers.add(container);
    return container;
  }

  Future<String> metaFileContent() async {
    final file = File('${dir.path}/${VaultStorage.metaFileName}');
    return file.readAsString();
  }

  group('已有 vault 时禁止重复创建（不可逆事故）', () {
    test('createVault 在已有 vault 时直接拒绝，不碰 meta.enc', () async {
      // ① 先正常创建一个
      final first = containerWith();
      await first.read(vaultSessionProvider.notifier).createVault('first-passphrase');
      expect(first.read(vaultSessionProvider).status, VaultStatus.unlocked);

      final before = await metaFileContent();
      final originalVaultId = first.read(vaultSessionProvider).meta!.vaultId;

      // ② 模拟一个"带着 meta 启动"的会话，然后**仍然调 createVault**
      //    这正是闸门判断出错、或将来重构时最可能发生的误用。
      final second = containerWith(meta: first.read(vaultSessionProvider).meta);

      await second.read(vaultSessionProvider.notifier).createVault('second-passphrase');

      // ③ 必须被拦住
      final state = second.read(vaultSessionProvider);
      expect(state.status, VaultStatus.locked, reason: '应停在解锁态，而不是又创建一次');
      expect(state.error, isNotNull, reason: '必须告诉用户为什么没成');
      expect(state.unlocked, isNull);
      expect(state.database, isNull, reason: '不能留下半个数据库句柄');

      // ④ 最关键的一条：meta.enc 一个字节都不能变。
      //    变了就意味着旧 DEK 的包裹结果被覆盖 —— 老数据永久打不开。
      expect(await metaFileContent(), before, reason: 'meta.enc 被覆盖了，这是数据永久丢失');
      expect(
        VaultMeta.fromJsonString(await metaFileContent()).vaultId,
        originalVaultId,
      );
    });

    test('writeMetaIfAbsent 是文件层的最后一道闸', () async {
      final first = containerWith();
      await first.read(vaultSessionProvider.notifier).createVault('p1');
      final existing = first.read(vaultSessionProvider).meta!;
      final before = await metaFileContent();

      // 即使绕过会话层直接调存储，也不能覆盖
      final wrote = await storage.writeMetaIfAbsent(
        existing.copyWith(itemCount: 999),
      );
      expect(wrote, isFalse, reason: '已存在时必须返回 false');
      expect(await metaFileContent(), before, reason: '文件内容不能变');
    });

    test('创建失败且 meta 未落盘时，回到 needsSetup 允许重试', () async {
      final container = containerWith();
      // 空密码会在 VaultLock 里被拒，此时 meta 还没写
      await container.read(vaultSessionProvider.notifier).createVault('');

      final state = container.read(vaultSessionProvider);
      expect(state.status, VaultStatus.needsSetup);
      expect(state.error, isNotNull);
      expect(await storage.hasVault(), isFalse);
    });
  });

  group('缺 meta 时的调用不能静默', () {
    test('unlock 在没有 meta 时推进 needsSetup，而不是钉在 failed', () async {
      final container = containerWith();
      await container.read(vaultSessionProvider.notifier).unlock('whatever');

      final state = container.read(vaultSessionProvider);
      expect(
        state.status,
        VaultStatus.needsSetup,
        reason: 'failed 是没有出路的页面；这种情况应该引导用户去创建',
      );
      expect(state.error, isNotNull);
    });

    test('unlockWithRecoveryCode 在没有 meta 时给出提示，而不是什么都不做', () async {
      final container = containerWith();
      await container
          .read(vaultSessionProvider.notifier)
          .unlockWithRecoveryCode('abandon abandon abandon');

      final state = container.read(vaultSessionProvider);
      expect(state.status, VaultStatus.needsSetup);
      expect(state.error, isNotNull, reason: '静默 return 会让用户以为按钮坏了');
    });
  });

  group('copyWith 的置空语义', () {
    test('clearHandles 清掉解锁四件套，但保留 meta 与 deviceId', () async {
      final container = containerWith();
      await container.read(vaultSessionProvider.notifier).createVault('passphrase-1');
      final unlocked = container.read(vaultSessionProvider);

      expect(unlocked.database, isNotNull);
      expect(unlocked.gateway, isNotNull);
      expect(unlocked.activity, isNotNull);

      final locked = unlocked.copyWith(
        status: VaultStatus.locked,
        clearHandles: true,
        clearRecoveryCode: true,
      );

      expect(locked.database, isNull);
      expect(locked.gateway, isNull);
      expect(locked.activity, isNull);
      expect(locked.unlocked, isNull);
      expect(locked.recoveryCode, isNull);
      // meta 是解锁的唯一依据，必须留着
      expect(locked.meta, isNotNull);
      expect(locked.deviceId, 'devA');
    });

    test('不加 clearHandles 时，四件套不会被 null 参数意外清掉', () async {
      final container = containerWith();
      await container.read(vaultSessionProvider.notifier).createVault('passphrase-2');
      final unlocked = container.read(vaultSessionProvider);

      // 传一堆 null 只是"不改"，不是"清空"
      final next = unlocked.copyWith(status: VaultStatus.unlocked);
      expect(next.database, isNotNull);
      expect(next.gateway, isNotNull);
    });
  });
}
