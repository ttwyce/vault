import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:vault/app/session/vault_session.dart';
import 'package:vault/app/session/vault_storage.dart';
import 'package:vault/core/crypto/argon2_params.dart';
import 'package:vault/core/crypto/vault_meta.dart';
import 'package:vault/data/write/write_gateway.dart';

/// `VaultSession` 的测试 —— App 的根状态机。
///
/// 这里验证的不是"状态枚举有没有被赋值"，而是三件**错了会让用户彻底丢数据**
/// 的事情：
///
/// 1. **启动时状态判断对不对**：把"读不懂的 meta.enc"误判成"首次使用"，
///    等于在旧库旁边新建一个空 vault，用户以为数据全没了。
/// 2. **解锁出来的东西能不能真的用**：状态是 `unlocked` 但 gateway 打不开，
///    单元测试照样全绿，用户第一次保存笔记时才发现。
/// 3. **锁定有没有真的清干净**：锁屏后内存里还留着 DEK，
///    "本地加密"这个承诺就是假的。
///
/// 全程使用 [Argon2Params.insecureForTests]：真实参数单次派生要 2 秒，
/// 十几个用例叠加会把单元测试跑成集成测试，本地没人会跑它。
/// 这里要验的是**状态迁移与装配关系**，不是 KDF 的耗时
/// （耗时由 `kdf_perf_probe_test.dart` 单独量）。
///
/// 注意：`VaultStorage` 会真的往磁盘写 `meta.enc` / `device_id` / `vault.db`
/// （SQLCipher 加密库），所以每个用例必须用**独立的临时目录**，
/// 用完按"先关库、再删目录"的顺序清理 —— 顺序反了在 Windows 上会因
/// 文件被占用而删不掉，留下垃圾目录。
void main() {
  // 固定密码：所有用例共用同一个口令，失败时一眼能看出是哪一步串了。
  const passphrase = '正确 horse battery staple';

  /// 一个用例一个独立临时目录。
  ///
  /// 共用目录会让"首次启动"与"已有 vault"两种状态互相污染 ——
  /// 那种测试失败起来像随机 flaky，极难定位。
  Directory tempDir() {
    final dir = Directory.systemTemp.createTempSync('vault_session_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return dir;
  }

  /// 启动一次会话，等价于 `main()` 里读完 meta 后 override 掉
  /// `vaultBootstrapProvider`。
  ///
  /// `meta` 为 null 表示"磁盘上没有 vault"；`bootError` 非空表示
  /// "有 meta.enc 但读不懂" —— 这两种情况在 UI 上是完全不同的出路，
  /// 所以用例里必须能分别构造。
  ({ProviderContainer container, VaultSession session}) start(
    Directory dir, {
    VaultMeta? meta,
    String? bootError,
    String deviceId = 'devA',
  }) {
    final storage = VaultStorage(directory: dir);
    final container = ProviderContainer(
      overrides: [
        vaultBootstrapProvider.overrideWithValue(
          VaultBootstrap(
            storage: storage,
            deviceId: deviceId,
            meta: meta,
            params: Argon2Params.insecureForTests,
            bootError: bootError,
          ),
        ),
      ],
    );

    // 清理顺序写死在一个 tearDown 里：先关库 → 再放密钥 → 最后 dispose。
    // 分成三个 addTearDown 的话执行顺序是反的（LIFO），很容易写错。
    addTearDown(() async {
      final state = container.read(vaultSessionProvider);
      await state.opener?.close();
      state.unlocked?.dispose();
      container.dispose();
    });

    return (
      container: container,
      session: container.read(vaultSessionProvider.notifier),
    );
  }

  /// 造出"这台机器上已经有一个 vault"的磁盘状态，并把会话锁掉
  /// （模拟用户上次用完 App 退出）。
  ///
  /// 走真实的 `createVault` 而不是手搓一个 [VaultMeta]：只有真跑一遍才能保证
  /// `meta.enc` 里的盐、KDF 参数、两段包裹密文互相自洽。手搓的 meta 能通过
  /// 断言却解不开，会把"重启后解锁"这条用例测成假绿。
  Future<({VaultMeta meta, List<String> words, String fingerprint})> seed(
    Directory dir,
  ) async {
    final env = start(dir);
    await env.session.createVault(passphrase);

    final state = env.container.read(vaultSessionProvider);
    expect(
      state.status,
      VaultStatus.unlocked,
      reason: '前置条件不成立：创建都失败的话，后面所有"重启后解锁"用例都没有意义',
    );

    final seeded = (
      meta: state.meta!,
      words: state.recoveryCode!.words,
      fingerprint: state.unlocked!.keys.fingerprint,
    );

    await env.session.lock();
    return seeded;
  }

  /// 从磁盘重读 meta，模拟"App 重启时 main() 干的事"。
  Future<VaultMeta> readMetaFromDisk(Directory dir) async {
    final meta = await VaultStorage(directory: dir).readMeta();
    expect(meta, isNotNull, reason: '创建流程必须把 meta.enc 落盘，否则重启后 vault 永久锁死');
    return meta!;
  }

  // ---------------------------------------------------------------------------
  // 启动
  // ---------------------------------------------------------------------------

  group('启动状态', () {
    test('没有 meta 时落到 needsSetup，而不是弹一个解不开的解锁页', () {
      final env = start(tempDir());
      final state = env.container.read(vaultSessionProvider);

      expect(
        state.status,
        VaultStatus.needsSetup,
        reason: '没有 meta.enc 就是首次使用；判成 locked 会让用户面对一个永远解不开的解锁页',
      );
      expect(state.hasVault, isFalse);
      expect(state.meta, isNull);
      expect(state.error, isNull, reason: '首次启动不是错误，不该显示任何红色提示');
      expect(
        state.deviceId,
        'devA',
        reason: 'deviceId 是 HLC 的 node，首帧就要有值，不能等解锁后才补',
      );
    });

    test('磁盘上已有 vault 时落到 locked，且启动阶段不碰密钥与数据库', () async {
      final dir = tempDir();
      final seeded = await seed(dir);

      final env = start(dir, meta: await readMetaFromDisk(dir));
      final state = env.container.read(vaultSessionProvider);

      expect(state.status, VaultStatus.locked);
      expect(state.meta?.vaultId, seeded.meta.vaultId);
      expect(state.unlocked, isNull, reason: '没输密码就不该有任何 DEK');
      expect(
        state.database,
        isNull,
        reason: '没解锁就开库等于绕过整个密钥流程，加密库也会变成明文可读',
      );
      expect(state.gateway, isNull);
      expect(
        state.recoveryCode,
        isNull,
        reason: '重启后拿不回恢复码 —— 系统只存被包裹的 DEK，不存词',
      );
      expect(state.elapsed, isNull, reason: '不在派生中时不该显示已用秒数');
    });

    test('meta.enc 读不懂时落到 failed，绝不能当成首次使用', () async {
      final dir = tempDir();
      final storage = VaultStorage(directory: dir);
      // 手工写坏 meta.enc：模拟写入时断电 / 被用户改坏 / 磁盘坏块
      File(p.join(dir.path, VaultStorage.metaFileName)).writeAsStringSync('{"vault_id": 1');

      String? bootError;
      try {
        await storage.readMeta();
      } on VaultMetaException catch (e) {
        bootError = e.message;
      }
      expect(
        bootError,
        isNotNull,
        reason: 'readMeta 必须抛 VaultMetaException 而不是返回 null，'
            '否则损坏的库会被静默当成"没有库"',
      );

      final env = start(dir, bootError: bootError);
      final state = env.container.read(vaultSessionProvider);

      expect(state.status, VaultStatus.failed);
      expect(state.error, isNotNull);
      expect(
        state.status,
        isNot(VaultStatus.needsSetup),
        reason: '判成首次使用就会在旧数据旁边新建一个空 vault，'
            '用户会以为数据全丢了，而真正的老库还躺在磁盘上',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 创建
  // ---------------------------------------------------------------------------

  group('创建', () {
    test('创建成功：恢复码、数据库、写入口、埋点一次到位，磁盘上真的落了文件', () async {
      final dir = tempDir();
      final env = start(dir);

      await env.session.createVault(passphrase);
      final state = env.container.read(vaultSessionProvider);

      expect(state.status, VaultStatus.unlocked);
      expect(
        state.recoveryCode,
        isNotNull,
        reason: '这是 24 个词唯一一次出现在内存里的时机，'
            '这里拿不到就等于用户永远没有恢复码',
      );
      expect(state.recoveryCode!.words.length, 24, reason: '24 词 = 256 bit，少一个词就少 11 bit 熵');
      expect(state.meta?.hasRecoveryCode, isTrue);
      expect(state.database, isNotNull, reason: '状态说 unlocked 就必须真的有一把打开的库');
      expect(state.gateway, isNotNull, reason: '没有写入口的 unlocked 是假解锁');
      expect(state.activity, isNotNull);
      expect(state.unlocked, isNotNull);
      expect(state.error, isNull);
      expect(
        state.elapsed,
        isNull,
        reason: '派生已经结束，UI 不能继续显示"正在派生"的秒数',
      );

      expect(
        File(p.join(dir.path, VaultStorage.metaFileName)).existsSync(),
        isTrue,
        reason: 'meta.enc 不落盘 = 重启后这个 vault 永远打不开',
      );
      expect(
        File(p.join(dir.path, VaultStorage.databaseFileName)).existsSync(),
        isTrue,
        reason: 'vault.db 不落盘说明数据库开在了内存里，重启即丢全部数据',
      );
    });

    test('创建后能真的写入 —— 会话层交出来的 gateway 是一条通的链路', () async {
      final env = start(tempDir());
      await env.session.createVault(passphrase);

      final gateway = env.container.read(vaultSessionProvider).gateway!;
      final result = await gateway.writeEntry(EntryWrite.create(title: '第一条'));

      expect(
        result.changed,
        isTrue,
        reason: 'changed=false 说明写入被当成幂等空操作吞掉了，'
            '同步层永远不会知道这条笔记存在',
      );
      expect(
        result.oplogSeq,
        greaterThan(0),
        reason: '没有 oplog 序号 = 这条变更推不出去，只在本地可见',
      );
      expect(result.snapshot.rev, 1);
    });

    test('acknowledgeRecoveryCode 只清内存里的词，不动已解锁的会话', () async {
      final env = start(tempDir());
      await env.session.createVault(passphrase);

      final before = env.container.read(vaultSessionProvider);
      final fingerprint = before.unlocked!.keys.fingerprint;

      env.session.acknowledgeRecoveryCode();
      final after = env.container.read(vaultSessionProvider);

      expect(
        after.recoveryCode,
        isNull,
        reason: '用户确认抄写后必须立刻抹掉明文词 —— '
            '留着它，一次内存 dump 就等于拿到永久后门',
      );
      expect(
        after.status,
        VaultStatus.unlocked,
        reason: '清词是"确认抄写"，不是"锁定"，不能把用户踢回解锁页',
      );
      expect(after.gateway, isNotNull);
      expect(
        after.unlocked!.keys.fingerprint,
        fingerprint,
        reason: '清词不该动 DEK，否则刚解锁的库会立刻变成一把解不开的钥匙',
      );
    });

    test('派生期间 isBusy 为 true，结束后 elapsed 归 null', () async {
      final env = start(tempDir());

      // 故意不 await：createVault 是 async 函数，函数体会同步执行到第一个
      // await，所以调用返回时状态已经是 unlocking。这条断言的价值在于
      // UI 的"正在派生"提示真的会被触发 —— 如果它同步跑完，
      // 用户面对真实参数时会看到 2 秒白屏，没有任何反馈。
      final future = env.session.createVault(passphrase);

      final during = env.container.read(vaultSessionProvider);
      expect(
        during.status,
        VaultStatus.unlocking,
        reason: '没有这个中间态，UI 就无法在 2 秒的派生期间给出任何反馈',
      );
      expect(during.isBusy, isTrue);
      expect(
        during.elapsed,
        isNotNull,
        reason: 'elapsed 是 UI 显示已用秒数的唯一来源，null 就等于界面卡死',
      );

      await future;
      final after = env.container.read(vaultSessionProvider);
      expect(after.status, VaultStatus.unlocked);
      expect(after.isBusy, isFalse);
      expect(
        after.elapsed,
        isNull,
        reason: '派生结束后还留着 derivingSince，界面会一直显示在转圈',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 解锁
  // ---------------------------------------------------------------------------

  group('解锁', () {
    test('重启后能用主密码解锁，且解出的是同一把 DEK', () async {
      final dir = tempDir();
      final seeded = await seed(dir);

      final env = start(dir, meta: await readMetaFromDisk(dir));
      await env.session.unlock(passphrase);
      final state = env.container.read(vaultSessionProvider);

      expect(state.status, VaultStatus.unlocked);
      expect(state.unlocked, isNotNull);
      expect(
        state.unlocked!.keys.fingerprint,
        seeded.fingerprint,
        reason: '指纹不一致意味着解出的不是同一把 DEK —— '
            '库能打开，但里面每个字段都会是乱码，且没有任何报错',
      );
      expect(state.database, isNotNull);
      expect(state.gateway, isNotNull);
      expect(state.recoveryCode, isNull, reason: '正常解锁不是"创建"，不该有恢复码明文');
    });

    test('密码错误：回到 locked、给出错误，且不留下半个数据库或密钥', () async {
      final dir = tempDir();
      await seed(dir);

      final env = start(dir, meta: await readMetaFromDisk(dir));
      await env.session.unlock('错误密码');
      final state = env.container.read(vaultSessionProvider);

      expect(
        state.status,
        VaultStatus.locked,
        reason: '密码错必须可重试；落到 failed 会让 UI 只给出"重装"这一条死路',
      );
      expect(state.error, isNotNull);
      expect(
        state.database,
        isNull,
        reason: '失败后还留着数据库句柄，后续判断会以为已经解锁',
      );
      expect(state.gateway, isNull);
      expect(state.unlocked, isNull, reason: '密码错还留着 DEK，解锁就形同虚设');
      expect(state.meta, isNotNull, reason: 'meta 必须留着，否则用户连重试的机会都没有');
      expect(state.elapsed, isNull);
    });

    test('恢复码解锁：24 个词是灾难恢复的唯一路径', () async {
      final dir = tempDir();
      final seeded = await seed(dir);

      final env = start(dir, meta: await readMetaFromDisk(dir));
      await env.session.unlockWithRecoveryCode(seeded.words.join(' '));
      final state = env.container.read(vaultSessionProvider);

      expect(state.status, VaultStatus.unlocked);
      expect(
        state.unlocked!.keys.fingerprint,
        seeded.fingerprint,
        reason: '恢复码包裹的是同一把 DEK，解出别的指纹说明恢复路径走了另一把钥匙',
      );
      expect(state.database, isNotNull);
      expect(
        state.recoveryCode,
        isNull,
        reason: '用恢复码解锁不是"创建"，不该把词重新塞回内存',
      );
    });

    test('恢复码抄错一个词：校验和拦下，不静默解出垃圾', () async {
      final dir = tempDir();
      final seeded = await seed(dir);

      final env = start(dir, meta: await readMetaFromDisk(dir));
      // 'zoo' 是词表里的合法词，所以这里考的正是校验和，而不是"词不在表里"
      final broken = List<String>.from(seeded.words)..[7] = 'zoo';
      await env.session.unlockWithRecoveryCode(broken.join(' '));
      final state = env.container.read(vaultSessionProvider);

      expect(state.status, VaultStatus.locked);
      expect(
        state.error,
        isNotNull,
        reason: '用户必须看到"某个词抄错了"，而不是静默进入一个空库',
      );
      expect(state.database, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 锁定
  // ---------------------------------------------------------------------------

  group('锁定', () {
    test('lock() 清空内存密钥与数据库句柄，但保留 meta', () async {
      final env = start(tempDir());
      await env.session.createVault(passphrase);
      final vaultId = env.container.read(vaultSessionProvider).meta!.vaultId;

      await env.session.lock();
      final state = env.container.read(vaultSessionProvider);

      expect(state.status, VaultStatus.locked);
      expect(
        state.database,
        isNull,
        reason: '锁屏后还留着数据库句柄，等于别人拿到设备可以直接读',
      );
      expect(state.opener, isNull);
      expect(state.gateway, isNull);
      expect(state.activity, isNull);
      expect(state.unlocked, isNull, reason: 'DEK 必须跟着一起销毁');
      expect(state.recoveryCode, isNull);
      expect(
        state.meta?.vaultId,
        vaultId,
        reason: 'meta 是解锁的唯一入口，锁定时绝不能一起清掉',
      );
      expect(state.error, isNull, reason: '主动锁定不是错误，不该显示报错文案');
    });

    test('锁定后同一会话能再次解锁（密钥没被毁掉，meta 还在）', () async {
      final dir = tempDir();
      final env = start(dir);
      await env.session.createVault(passphrase);
      final first = env.container.read(vaultSessionProvider).unlocked!.keys.fingerprint;

      await env.session.lock();
      expect(env.container.read(vaultSessionProvider).status, VaultStatus.locked);

      await env.session.unlock(passphrase);
      final again = env.container.read(vaultSessionProvider);

      expect(again.status, VaultStatus.unlocked);
      expect(
        again.unlocked!.keys.fingerprint,
        first,
        reason: '同一份 meta 解出的必须是同一把 DEK；'
            '锁一次就换一把钥匙，等于每锁一次就把历史数据废掉',
      );
      expect(again.database, isNotNull);
    });

    test('未解锁时读 writeGatewayProvider 直接抛错，而不是给出一个失效的 gateway', () {
      final env = start(tempDir());

      // 断言只看"有没有抛"和"文案能不能认出是没解锁"，不看异常的具体类型：
      // Riverpod 3 会把 provider 里抛出的异常再包一层 ProviderException，
      // 而这个类型没有从 flutter_riverpod 导出（在 riverpod/misc.dart 里）。
      // 真正要保证的是 UI 不会拿到一个已经销毁的 gateway。
      Object? thrown;
      try {
        env.container.read(writeGatewayProvider);
      } on Object catch (error) {
        thrown = error;
      }

      expect(thrown, isNotNull, reason: '没解锁时拿到 gateway，错误会推迟到用户点保存时才炸');
      expect(
        thrown.toString(),
        contains('vault 未解锁'),
        reason: '文案里必须能看出根因是"没解锁"；'
            '否则排查时只会看到一堆 AEAD / SQLCipher 的次级错误',
      );
    });
  });
}
