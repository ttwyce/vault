/// 密码生成器（docs/11 §8.2）。
///
/// 纯 Dart：`Random.secure()` 提供密码学安全随机数，可注入随机源做确定性
/// 测试。策略只输出密码字符串，不写日志、不进 prompt、不进向量。
library;

import 'dart:math';

/// 生成选项。
class PasswordPolicy {
  const PasswordPolicy({
    this.length = 20,
    this.uppercase = true,
    this.lowercase = true,
    this.digits = true,
    this.symbols = true,
    this.excludeAmbiguous = true,
  });

  final int length;
  final bool uppercase;
  final bool lowercase;
  final bool digits;
  final bool symbols;

  /// 排除 `0 O 1 l I |` 等易混字符。
  final bool excludeAmbiguous;

  static const String _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const String _digit = '0123456789';
  static const String _symbol = '!@#\$%^&*()-_=+[]{}:,.?';
  static const String _ambiguous = '0O1lI|';

  List<String> characterClasses() {
    String drop(String source) => excludeAmbiguous
        ? source.replaceAll(RegExp('[${RegExp.escape(_ambiguous)}]'), '')
        : source;
    return <String>[
      if (uppercase) drop(_upper),
      if (lowercase) drop(_lower),
      if (digits) drop(_digit),
      if (symbols) drop(_symbol),
    ];
  }
}

/// 按策略生成密码。
///
/// 保证**每个启用的字符类至少出现一次**，再均匀填满剩余长度并打乱，
/// 避免「全小写」或「没有符号」这类随机退化。
String generatePassword(
  PasswordPolicy policy, {
  Random? random,
}) {
  if (policy.length < 4 || policy.length > 128) {
    throw const FormatException('密码长度必须在 4~128 之间');
  }
  final classes = policy.characterClasses()
    ..removeWhere((String c) => c.isEmpty);
  if (classes.isEmpty) {
    throw const FormatException('至少启用一个字符集');
  }
  if (classes.length > policy.length) {
    throw const FormatException('密码长度不足以容纳所有启用的字符集');
  }
  final rng = random ?? Random.secure();
  int next(int max) => rng.nextInt(max);

  final chars = <String>[];
  for (final pool in classes) {
    chars.add(pool[next(pool.length)]);
  }
  final all = classes.join();
  while (chars.length < policy.length) {
    chars.add(all[next(all.length)]);
  }
  // Fisher–Yates（用同一个安全随机源）。
  for (var i = chars.length - 1; i > 0; i--) {
    final j = next(i + 1);
    final tmp = chars[i];
    chars[i] = chars[j];
    chars[j] = tmp;
  }
  final result = chars.join();
  assert(result.length == policy.length);
  return result;
}
