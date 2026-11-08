import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/argon2_params.dart';
import 'package:vault/core/crypto/kdf.dart';
import 'package:vault/core/crypto/secret_bytes.dart';
import 'package:vault/core/crypto/secret_wrapper.dart';
import 'package:vault/core/crypto/vault_keys.dart';

void main() {
  group('SecretBytes', () {
    test('构造与读取都复制，外部改动不影响内部', () {
      final source = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final secret = SecretBytes(source);

      source[0] = 99;
      expect(secret.bytes[0], 1, reason: '构造时必须复制');

      final out = secret.bytes;
      out[0] = 77;
      expect(secret.bytes[0], 1, reason: '读取时必须复制');
    });

    test('常量时间比较', () {
      final a = SecretBytes(Uint8List.fromList(<int>[1, 2, 3]));
      final b = SecretBytes(Uint8List.fromList(<int>[1, 2, 3]));
      final c = SecretBytes(Uint8List.fromList(<int>[1, 2, 4]));
      final d = SecretBytes(Uint8List.fromList(<int>[1, 2]));

      expect(a.equalsConstantTime(b), isTrue);
      expect(a.equalsConstantTime(c), isFalse);
      expect(a.equalsConstantTime(d), isFalse);
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('toString 不泄露内容，指纹不含密钥字节', () {
      final secret = SecretBytes(Uint8List.fromList(List<int>.filled(32, 0xAB)));
      final text = secret.toString();

      expect(text, contains('32 bytes'));
      expect(text, isNot(contains('ababab')), reason: '指纹不能直接取密钥字节');
      expect(
        secret.toHex().contains(secret.fingerprint),
        isFalse,
        reason: '指纹必须是密钥的单向哈希，不能是它的子串',
      );
      expect(secret.fingerprint.length, 8);
      expect(secret.toHex().length, 64);
    });

    test('指纹稳定且对单字节改动敏感', () {
      final a = SecretBytes(Uint8List.fromList(List<int>.generate(32, (int i) => i)));
      final b = SecretBytes(Uint8List.fromList(List<int>.generate(32, (int i) => i)));
      final c = SecretBytes(Uint8List.fromList(List<int>.generate(32, (int i) => i + 1)));

      expect(a.fingerprint, b.fingerprint, reason: '同一把 key 的指纹必须稳定');
      expect(a.fingerprint, isNot(c.fingerprint), reason: '改一个字节指纹就该全变（哈希雪崩）');
    });

    test('destroy 清零', () {
      final secret = SecretBytes(Uint8List.fromList(List<int>.filled(8, 5)));
      secret.destroy();
      expect(secret.bytes.every((int b) => b == 0), isTrue);
    });

    test('随机生成的长度正确且不重复', () {
      final a = SecretBytes.random(length: 32, random: Random(1));
      final b = SecretBytes.random(length: 32, random: Random(2));
      expect(a.length, 32);
      expect(a.equalsConstantTime(b), isFalse);
    });
  });

  group('SecretWrapper', () {
    final kek = SecretBytes(Uint8List.fromList(List<int>.generate(32, (int i) => i)));
    final plaintext = SecretBytes(Uint8List.fromList(List<int>.generate(32, (int i) => 255 - i)));
    final aad = SecretWrapper.aadFor(vaultId: 'vault-1', purpose: 'dek');

    test('包裹后能解回原文', () async {
      final blob = await SecretWrapper.wrap(
        key: kek,
        plaintext: plaintext,
        aad: aad,
        random: Random(3),
      );
      expect(blob.length, 32 + SecretWrapper.overhead);
      expect(blob[0], SecretWrapper.formatVersion);

      final back = await SecretWrapper.unwrap(key: kek, blob: blob, aad: aad);
      expect(back.equalsConstantTime(plaintext), isTrue);
    });

    test('同一明文两次包裹的密文不同（nonce 随机）', () async {
      final a = await SecretWrapper.wrap(
        key: kek,
        plaintext: plaintext,
        aad: aad,
        random: Random(4),
      );
      final b = await SecretWrapper.wrap(
        key: kek,
        plaintext: plaintext,
        aad: aad,
        random: Random(5),
      );
      expect(a, isNot(equals(b)));
    });

    test('错误的 KEK 解不开', () async {
      final blob = await SecretWrapper.wrap(
        key: kek,
        plaintext: plaintext,
        aad: aad,
        random: Random(6),
      );
      final wrong = SecretBytes(Uint8List.fromList(List<int>.filled(32, 9)));
      await expectLater(
        SecretWrapper.unwrap(key: wrong, blob: blob, aad: aad),
        throwsA(isA<SecretUnwrapException>()),
      );
    });

    test('AAD 不匹配解不开 —— 这是防"密文搬运"的关键', () async {
      // 场景：攻击者把 wrapped_dek 和 recovery_wrapped_dek 互换位置。
      // 两段密文长度相同、都能通过 AEAD 认证，只有 AAD 能区分它们。
      final blob = await SecretWrapper.wrap(
        key: kek,
        plaintext: plaintext,
        aad: SecretWrapper.aadFor(vaultId: 'vault-1', purpose: 'dek'),
        random: Random(7),
      );
      await expectLater(
        SecretWrapper.unwrap(
          key: kek,
          blob: blob,
          aad: SecretWrapper.aadFor(vaultId: 'vault-1', purpose: 'recovery-dek'),
        ),
        throwsA(isA<SecretUnwrapException>()),
      );
      // 换个 vault 也不行
      await expectLater(
        SecretWrapper.unwrap(
          key: kek,
          blob: blob,
          aad: SecretWrapper.aadFor(vaultId: 'vault-2', purpose: 'dek'),
        ),
        throwsA(isA<SecretUnwrapException>()),
      );
    });

    test('密文被改一个字节就解不开', () async {
      final blob = await SecretWrapper.wrap(
        key: kek,
        plaintext: plaintext,
        aad: aad,
        random: Random(8),
      );
      final tampered = Uint8List.fromList(blob);
      tampered[tampered.length - 20] ^= 0x01;
      await expectLater(
        SecretWrapper.unwrap(key: kek, blob: tampered, aad: aad),
        throwsA(isA<SecretUnwrapException>()),
      );
    });

    test('未知格式版本给出可读错误，而不是含糊的认证失败', () async {
      final blob = await SecretWrapper.wrap(
        key: kek,
        plaintext: plaintext,
        aad: aad,
        random: Random(9),
      );
      final future = Uint8List.fromList(blob)..[0] = 99;
      await expectLater(
        SecretWrapper.unwrap(key: kek, blob: future, aad: aad),
        throwsA(
          isA<SecretUnwrapException>().having(
            (SecretUnwrapException e) => e.message,
            'message',
            contains('版本'),
          ),
        ),
      );
    });

    test('过短的密文直接拒绝', () async {
      await expectLater(
        SecretWrapper.unwrap(key: kek, blob: Uint8List(10), aad: aad),
        throwsA(isA<SecretUnwrapException>()),
      );
    });
  });

  group('Argon2Params', () {
    test('默认参数在合法范围内', () {
      expect(Argon2Params.recommended.isValid, isTrue);
      expect(Argon2Params.recommended.memoryKb, 65536);
      expect(Argon2Params.recommended.label, contains('64MB'));
    });

    test('JSON 往返保真', () {
      const params = Argon2Params(memoryKb: 32768, iterations: 4, parallelism: 2);
      final back = Argon2Params.fromJson(params.toJson());
      expect(back, params);
      expect(params.toJson()['algo'], 'argon2id');
      expect(params.toJson()['memory_kb'], 32768, reason: '单位必须是 KiB');
    });

    test('内存超上限被拒绝 —— 防 meta.enc 被写入天文数字导致 OOM', () {
      expect(
        () => Argon2Params.fromJson(<String, Object?>{'memory_kb': 1 << 30}),
        throwsA(isA<FormatException>()),
      );
    });

    test('内存小于 8×并行度被拒绝（Argon2 硬性要求）', () {
      expect(
        () => Argon2Params.fromJson(<String, Object?>{
          'memory_kb': 16,
          'parallelism': 4,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('未知算法被拒绝', () {
      expect(
        () => Argon2Params.fromJson(<String, Object?>{'algo': 'scrypt'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Kdf', () {
    const params = Argon2Params.insecureForTests;

    test('同密码同盐 → 同一把 KEK', () async {
      final salt = KdfSalt.random(Random(10));
      final a = await Kdf.fromPassphrase(passphrase: 'correct horse', salt: salt, params: params);
      final b = await Kdf.fromPassphrase(passphrase: 'correct horse', salt: salt, params: params);
      expect(a.equalsConstantTime(b), isTrue);
      expect(a.length, 32);
    });

    test('不同盐 → 不同 KEK', () async {
      final a = await Kdf.fromPassphrase(
        passphrase: 'correct horse',
        salt: KdfSalt.random(Random(11)),
        params: params,
      );
      final b = await Kdf.fromPassphrase(
        passphrase: 'correct horse',
        salt: KdfSalt.random(Random(12)),
        params: params,
      );
      expect(a.equalsConstantTime(b), isFalse);
    });

    test('不同密码 → 不同 KEK', () async {
      final salt = KdfSalt.random(Random(13));
      final a = await Kdf.fromPassphrase(passphrase: 'aaa', salt: salt, params: params);
      final b = await Kdf.fromPassphrase(passphrase: 'aab', salt: salt, params: params);
      expect(a.equalsConstantTime(b), isFalse);
    });

    test('空密码被拒绝', () async {
      await expectLater(
        Kdf.fromPassphrase(
          passphrase: '',
          salt: KdfSalt.random(Random(14)),
          params: params,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('恢复码熵走 HKDF，不需要 Argon2', () async {
      final entropy = SecretBytes(Uint8List.fromList(List<int>.generate(32, (int i) => i)));
      final a = await Kdf.fromRecoveryEntropy(entropy);
      final b = await Kdf.fromRecoveryEntropy(entropy);
      expect(a.equalsConstantTime(b), isTrue);
      expect(a.length, 32);

      final other = SecretBytes(Uint8List.fromList(List<int>.generate(32, (int i) => i + 1)));
      final c = await Kdf.fromRecoveryEntropy(other);
      expect(a.equalsConstantTime(c), isFalse);
    });

    test('恢复码熵与主密码派生出的 KEK 不同域（同字节输入也不相等）', () async {
      // 域分离检查：即使输入字节完全相同，两条派生路径也必须给出不同结果。
      final bytes = Uint8List.fromList(List<int>.generate(32, (int i) => i));
      final salt = KdfSalt(Uint8List.fromList(List<int>.filled(16, 0)));
      final viaPassphrase = await Kdf.fromPassphrase(
        passphrase: base64Encode(bytes),
        salt: salt,
        params: params,
      );
      final viaRecovery = await Kdf.fromRecoveryEntropy(SecretBytes(bytes));
      expect(viaPassphrase.equalsConstantTime(viaRecovery), isFalse);
    });
  });

  group('VaultKeys', () {
    test('所有子密钥互不相同', () async {
      final keys = VaultKeys(SecretBytes.random(length: 32, random: Random(20)));
      final item = await keys.item();
      final blob = await keys.blob();
      final name = await keys.name();
      final meta = await keys.meta();
      final local = await keys.localDatabase();

      final all = <SecretBytes>[item, blob, name, meta, local];
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          expect(
            all[i].equalsConstantTime(all[j]),
            isFalse,
            reason: '第 $i 与第 $j 条子密钥相同 —— 域分离失效',
          );
        }
      }
    });

    test('同一 DEK 派生出同样的子密钥（可复现）', () async {
      final dek = SecretBytes.random(length: 32, random: Random(21));
      final a = await VaultKeys(dek).item();
      final b = await VaultKeys(dek).item();
      expect(a.equalsConstantTime(b), isTrue);
    });

    test('缓存生效：两次调用返回同一实例', () async {
      final keys = VaultKeys(SecretBytes.random(length: 32, random: Random(22)));
      expect(identical(await keys.item(), await keys.item()), isTrue);
    });

    test('DEK 长度不对直接拒绝', () {
      expect(
        () => VaultKeys(SecretBytes(Uint8List(16))),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('destroy 清掉 DEK 与缓存', () async {
      final keys = VaultKeys(SecretBytes.random(length: 32, random: Random(23)));
      final item = await keys.item();
      keys.destroy();
      expect(item.bytes.every((int b) => b == 0), isTrue, reason: '缓存的子密钥也要清零');
    });
  });
}
