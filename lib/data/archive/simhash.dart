/// 64 位 simhash 的**纯计算**（docs/05 §6.2）。
///
/// 不联网、不写库：把正文切成特征（中文按 2-gram、英文按词），
/// 用每个特征的 64 位 FNV-1a 哈希给 64 个计数器加权投票，
/// 输出 16 位大写十六进制指纹。相同/相近文本汉明距离小，
/// 供 `hasContentChanged` 判定「相似度 < 0.9 → 内容有变化」。
library;

const int kSimhashBits = 64;

/// FNV-1a 64 位；用位掩码把 Dart int 限制在无符号 64 位空间。
int _fnv1a64(String text) {
  const int offset = 0xcbf29ce484222325;
  const int prime = 0x100000001b3;
  const int mask = 0xffffffffffffffff;
  var hash = offset;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * prime) & mask;
  }
  return hash;
}

/// 提取特征：中文 2-gram + 英文/数字词；去空白与标点噪声。
List<String> _features(String text) {
  final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final out = <String>[];
  final words = RegExp(r'[a-z0-9]+').allMatches(normalized);
  for (final match in words) {
    out.add(match.group(0)!);
  }
  final cjk = RegExp(r'[\u4e00-\u9fff]+').allMatches(normalized);
  for (final run in cjk) {
    final s = run.group(0)!;
    if (s.length == 1) {
      out.add(s);
    } else {
      for (var i = 0; i + 1 < s.length; i++) {
        out.add(s.substring(i, i + 2));
      }
    }
  }
  return out;
}

/// 返回 16 位大写十六进制（不足 64 位时高位补 0）。
String computeSimhash(String text) {
  final features = _features(text);
  if (features.isEmpty) return '0' * 16;
  final votes = List<int>.filled(kSimhashBits, 0);
  for (final feature in features) {
    final hash = _fnv1a64(feature);
    for (var bit = 0; bit < kSimhashBits; bit++) {
      // 左移可能越过有符号边界，用无符号位测试：hash & (1 << bit)
      final mask = (bit == 63) ? 0x8000000000000000 : (1 << bit);
      votes[bit] += (hash & mask) != 0 ? 1 : -1;
    }
  }
  var result = 0;
  for (var bit = 0; bit < kSimhashBits; bit++) {
    if (votes[bit] > 0) {
      result |= (bit == 63) ? 0x8000000000000000 : (1 << bit);
    }
  }
  // Dart int 最高位为 1 时是负数；用 BigInt 取无符号 64 位表示，
  // 避免 toRadixString 输出带 '-' 的 17 位字符串。
  return BigInt.from(result)
      .toUnsigned(kSimhashBits)
      .toRadixString(16)
      .toUpperCase()
      .padLeft(16, '0');
}
