import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/password_generator.dart';

/// docs/11 §8.2 密码生成器测试。
void main() {
  test('默认策略：长度 20、四类字符都出现、排除易混字符', () {
    const policy = PasswordPolicy();
    final random = Random(7);
    for (var i = 0; i < 40; i++) {
      final password = generatePassword(policy, random: random);
      expect(password.length, 20);
      expect(password, matches(RegExp(r'[A-Z]')));
      expect(password, matches(RegExp(r'[a-z]')));
      expect(password, matches(RegExp(r'[0-9]')));
      expect(password, matches(RegExp(r'[^A-Za-z0-9]')));
      expect(password, isNot(contains('O')));
      expect(password, isNot(contains('l')));
    }
  });

  test('只启用数字时结果全是数字', () {
    const policy = PasswordPolicy(
      length: 12,
      uppercase: false,
      lowercase: false,
      symbols: false,
      excludeAmbiguous: false,
    );
    final password = generatePassword(policy, random: Random(3));
    expect(password, matches(RegExp(r'^[0-9]{12}$')));
  });

  test('长度 / 字符集 / 长度不足都被明确拒绝', () {
    expect(
      () => generatePassword(const PasswordPolicy(length: 3)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => generatePassword(const PasswordPolicy(
            uppercase: false,
            lowercase: false,
            digits: false,
            symbols: false,
          )),
      throwsA(isA<FormatException>()),
    );
    // 长度 4 恰好容纳四类字符，是合法边界。
    expect(
      generatePassword(const PasswordPolicy(length: 4),
          random: Random(1)),
      hasLength(4),
    );
  });

  test('同一随机源可复现，不同种子结果不同', () {
    const policy = PasswordPolicy(length: 16);
    expect(
      generatePassword(policy, random: Random(42)),
      generatePassword(policy, random: Random(42)),
    );
    expect(
      generatePassword(policy, random: Random(42)),
      isNot(generatePassword(policy, random: Random(43))),
    );
  });
}
