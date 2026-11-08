import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/argon2_params.dart';
import 'package:vault/core/crypto/vault_lock.dart';
import 'package:vault/core/crypto/vault_meta.dart';

/// 这些用例覆盖"数据能不能被打开"这件事。
///
/// 用 [Argon2Params.insecureForTests] 把 KDF 代价压到几乎为零 ——
/// 这里验证的是**逻辑**（AAD 是否绑对、盐是否换、恢复码是否真的能解），
/// 不是耗时。真实代价的性能单独在 `kdf_perf_probe_test.dart` 里量。
void main() {
  const fast = Argon2Params.insecureForTests;

  Future<UnlockedVault> createSample({String passphrase = 'correct horse battery'}) {
    return VaultLock.create(
      passphrase: passphrase,
      params: fast,
      random: Random(42),
      vaultId: '0192f0aa-1111-7222-8333-444455556666',
      nowMillis: 1731052800000,
    );
  }

  group('创建', () {
    test('返回 24 词恢复码，且两条解锁路径都能解出同一把 DEK', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      expect(vault.recoveryCode, isNotNull);
      expect(vault.recoveryCode!.words.length, 24);
      expect(vault.meta.hasRecoveryCode, isTrue);
      expect(vault.meta.vaultId, '0192f0aa-1111-7222-8333-444455556666');
      expect(vault.meta.createdAt, 1731052800000);
      expect(vault.meta.kdfParams, fast);

      final viaPassphrase = await VaultLock.unlock(
        meta: vault.meta,
        passphrase: 'correct horse battery',
      );
      addTearDown(viaPassphrase.dispose);

      final viaRecovery = await VaultLock.unlockWithRecoveryCode(
        meta: vault.meta,
        input: vault.recoveryCode!.words.join(' '),
      );
      addTearDown(viaRecovery.dispose);

      expect(viaPassphrase.keys.fingerprint, vault.keys.fingerprint);
      expect(viaRecovery.keys.fingerprint, vault.keys.fingerprint);
    });

    test('两次创建的 vaultId / 盐 / 包裹结果都不同', () async {
      final a = await VaultLock.create(passphrase: 'x', params: fast, random: Random(1));
      final b = await VaultLock.create(passphrase: 'x', params: fast, random: Random(2));
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      expect(a.meta.vaultId, isNot(b.meta.vaultId));
      expect(a.meta.kdfSalt, isNot(b.meta.kdfSalt));
      expect(a.meta.wrappedDek, isNot(b.meta.wrappedDek));
      expect(a.keys.fingerprint, isNot(b.keys.fingerprint));
    });

    test('空密码被拒绝', () async {
      await expectLater(
        VaultLock.create(passphrase: '', params: fast, random: Random(3)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('解锁', () {
    test('密码错误时抛 VaultUnlockException，且文案不区分"密码错"与"文件坏"', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      await expectLater(
        VaultLock.unlock(meta: vault.meta, passphrase: 'wrong'),
        throwsA(
          isA<VaultUnlockException>().having(
            (VaultUnlockException e) => e.message,
            'message',
            contains('无法区分'),
          ),
        ),
      );
    });

    test('恢复码输错时校验和会拦下（不是静默解出垃圾）', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      final broken = List<String>.from(vault.recoveryCode!.words)..[5] = 'zoo';
      await expectLater(
        VaultLock.unlockWithRecoveryCode(meta: vault.meta, input: broken.join(' ')),
        throwsA(isA<VaultUnlockException>()),
      );
    });

    test('没有恢复码的 vault 用恢复码解锁会给出明确提示', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      final noRecovery = vault.meta.copyWith(clearRecovery: true);
      final dummy = <String>[
        for (var i = 0; i < 23; i++) 'abandon',
        'art',
      ].join(' ');
      await expectLater(
        VaultLock.unlockWithRecoveryCode(meta: noRecovery, input: dummy),
        throwsA(
          isA<VaultUnlockException>().having(
            (VaultUnlockException e) => e.message,
            'message',
            contains('没有设置恢复码'),
          ),
        ),
      );
    });

    test('把两段包裹密文互换位置解不开 —— AAD 绑定了用途', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      // 攻击者能改 meta.enc（它是明文 JSON），尝试把恢复码密文塞进主密码槽位
      final swapped = VaultMeta(
        vaultId: vault.meta.vaultId,
        createdAt: vault.meta.createdAt,
        kdfParams: vault.meta.kdfParams,
        kdfSalt: vault.meta.kdfSalt,
        wrappedDek: vault.meta.recoveryWrappedDek!,
        recoveryWrappedDek: vault.meta.wrappedDek,
      );

      await expectLater(
        VaultLock.unlock(meta: swapped, passphrase: 'correct horse battery'),
        throwsA(isA<VaultUnlockException>()),
      );
    });

    test('wrappedDek 被改一个字节就解不开', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      final tampered = Uint8List.fromList(vault.meta.wrappedDek);
      tampered[tampered.length - 1] ^= 0x01;
      final broken = vault.meta.copyWith(wrappedDek: tampered);

      await expectLater(
        VaultLock.unlock(meta: broken, passphrase: 'correct horse battery'),
        throwsA(isA<VaultUnlockException>()),
      );
    });
  });

  group('改主密码', () {
    test('旧密码失效、新密码可用、DEK 不变', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);
      final originalFingerprint = vault.keys.fingerprint;

      final newMeta = await VaultLock.changePassphrase(
        meta: vault.meta,
        currentPassphrase: 'correct horse battery',
        newPassphrase: '新的主密码 passphrase',
        random: Random(7),
      );

      await expectLater(
        VaultLock.unlock(meta: newMeta, passphrase: 'correct horse battery'),
        throwsA(isA<VaultUnlockException>()),
      );

      final reopened = await VaultLock.unlock(meta: newMeta, passphrase: '新的主密码 passphrase');
      addTearDown(reopened.dispose);
      expect(reopened.keys.fingerprint, originalFingerprint, reason: 'DEK 不该变，只重新包裹');
    });

    test('改密码会换新盐（避免新旧密码共享派生上下文）', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      final newMeta = await VaultLock.changePassphrase(
        meta: vault.meta,
        currentPassphrase: 'correct horse battery',
        newPassphrase: 'another',
        random: Random(8),
      );
      expect(newMeta.kdfSalt, isNot(vault.meta.kdfSalt));
      expect(newMeta.wrappedDek, isNot(vault.meta.wrappedDek));
      // 恢复码仍然有效：它包裹的是同一把 DEK，与主密码无关
      expect(newMeta.recoveryWrappedDek, vault.meta.recoveryWrappedDek);
    });

    test('当前密码不对时拒绝改', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      await expectLater(
        VaultLock.changePassphrase(
          meta: vault.meta,
          currentPassphrase: 'nope',
          newPassphrase: 'x',
        ),
        throwsA(isA<VaultUnlockException>()),
      );
    });

    test('新密码为空被拒绝', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      await expectLater(
        VaultLock.changePassphrase(
          meta: vault.meta,
          currentPassphrase: 'correct horse battery',
          newPassphrase: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('改完密码后恢复码依然能解锁', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      final newMeta = await VaultLock.changePassphrase(
        meta: vault.meta,
        currentPassphrase: 'correct horse battery',
        newPassphrase: 'rotated',
        random: Random(9),
      );

      final viaRecovery = await VaultLock.unlockWithRecoveryCode(
        meta: newMeta,
        input: vault.recoveryCode!.words.join(' '),
      );
      addTearDown(viaRecovery.dispose);
      expect(viaRecovery.keys.fingerprint, vault.keys.fingerprint);
    });
  });

  group('重置恢复码', () {
    test('旧恢复码立即失效，新恢复码可用', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      final regenerated = await VaultLock.regenerateRecoveryCode(
        meta: vault.meta,
        passphrase: 'correct horse battery',
        random: Random(11),
      );

      expect(regenerated.code.words, isNot(vault.recoveryCode!.words));

      await expectLater(
        VaultLock.unlockWithRecoveryCode(
          meta: regenerated.meta,
          input: vault.recoveryCode!.words.join(' '),
        ),
        throwsA(isA<VaultUnlockException>()),
      );

      final viaNew = await VaultLock.unlockWithRecoveryCode(
        meta: regenerated.meta,
        input: regenerated.code.words.join(' '),
      );
      addTearDown(viaNew.dispose);
      expect(viaNew.keys.fingerprint, vault.keys.fingerprint);
    });

    test('必须提供正确主密码 —— 只拿到恢复码的人不能换掉恢复码', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      await expectLater(
        VaultLock.regenerateRecoveryCode(meta: vault.meta, passphrase: 'wrong'),
        throwsA(isA<VaultUnlockException>()),
      );
    });
  });

  group('meta.enc 序列化', () {
    test('JSON 往返保真', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);

      final json = vault.meta.toJsonString();
      final back = VaultMeta.fromJsonString(json);

      expect(back.vaultId, vault.meta.vaultId);
      expect(back.createdAt, vault.meta.createdAt);
      expect(back.kdfParams, vault.meta.kdfParams);
      expect(back.kdfSalt, vault.meta.kdfSalt);
      expect(back.wrappedDek, vault.meta.wrappedDek);
      expect(back.recoveryWrappedDek, vault.meta.recoveryWrappedDek);

      // 往返后仍然能解锁 —— 这是最有意义的断言
      final reopened = await VaultLock.unlock(meta: back, passphrase: 'correct horse battery');
      addTearDown(reopened.dispose);
      expect(reopened.keys.fingerprint, vault.keys.fingerprint);
    });

    test('同一份 meta 两次序列化字节完全一致（避免无意义的 If-Match 冲突）', () async {
      final vault = await createSample();
      addTearDown(vault.dispose);
      expect(vault.meta.toJsonString(), vault.meta.toJsonString());
      expect(vault.meta.toBytes(), vault.meta.toBytes());
    });

    test('schema 比本机高时拒绝打开', () {
      final json = <String, Object?>{
        'schema': VaultMeta.currentSchema + 1,
        'vault_id': 'x',
        'kdf': <String, Object?>{'salt': 'AAAAAAAAAAAAAAAAAAAAAA=='},
        'wrapped_dek': 'AAAA',
      };
      expect(
        () => VaultMeta.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('升级 App'),
          ),
        ),
      );
    });

    test('缺字段时给出具体缺哪个', () {
      expect(
        () => VaultMeta.fromJson(<String, Object?>{'schema': 1}),
        throwsA(isA<FormatException>().having(
          (FormatException e) => e.message,
          'message',
          contains('vault_id'),
        )),
      );
    });
  });
}
