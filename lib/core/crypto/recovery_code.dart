import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'bip39_english.dart';
import 'secret_bytes.dart';

/// 恢复码解析失败。
///
/// 刻意细分 [reason]：用户在灾难恢复现场，需要知道"是少输了几个词"
/// 还是"某个词抄错了"，而不是笼统的"无效"。
class RecoveryCodeException implements Exception {
  const RecoveryCodeException(this.reason);

  final String reason;

  @override
  String toString() => 'RecoveryCodeException: $reason';
}

/// BIP-39 恢复码（24 词 / 256 bit）。
///
/// ## 为什么是 24 词而不是 12 词
///
/// 12 词 = 128 bit 熵。对"防离线爆破"来说 128 bit 已经够用，
/// 但恢复码在这个产品里承担的是**唯一救命绳**的角色 ——
/// 它被手抄在纸上、拍照存在相册里、可能被家人看到。
/// 256 bit 让"恢复码被部分泄露"这件事的风险显著下降
/// （比如有人看到了前 12 个词，仍然无法解出任何东西）。
///
/// 代价是多抄 12 个词。这个代价换来的确定性值得。
///
/// ## 校验和是这里最重要的东西
///
/// 24 词的最后 8 bit 是前 256 bit 的 SHA-256 校验和。
/// 抄错一个词，校验和立刻不匹配 —— 用户在**设置恢复码的当下**就能发现，
/// 而不是三年后换设备时才发现解不开。
///
/// 这也是不用自造词表的核心原因：没有校验和，手抄错误完全无法检测。
class RecoveryCode {
  RecoveryCode._(this.words);

  /// 从 24 个词构造。**不做校验** —— 用 [parse] 从用户输入构造。
  factory RecoveryCode.fromWords(List<String> words) {
    if (words.length != wordCount) {
      throw RecoveryCodeException('恢复码必须是 $wordCount 个词，实际 ${words.length} 个');
    }
    return RecoveryCode._(List<String>.unmodifiable(words));
  }

  /// 从熵构造。熵必须是 32 字节（256 bit）。
  factory RecoveryCode.fromEntropy(SecretBytes entropy) {
    if (entropy.length != entropyLength) {
      throw RecoveryCodeException(
        '恢复码熵必须是 $entropyLength 字节（256 bit），实际 ${entropy.length}',
      );
    }
    return RecoveryCode._(_encode(entropy.internalView));
  }

  /// 生成一个新的随机恢复码。
  ///
  /// **必须用 [Random.secure]**：普通 `Random` 是可预测的 PRNG，
  /// 用它生成的恢复码等于把库的备份钥匙交给任何知道种子的人。
  factory RecoveryCode.generate([Random? random]) {
    return RecoveryCode.fromEntropy(
      SecretBytes.random(length: entropyLength, random: random ?? Random.secure()),
    );
  }

  /// 从用户输入解析。
  ///
  /// 容忍度（都是为了"用户在手抄纸上认字"这个真实场景）：
  ///
  /// - 大小写不敏感
  /// - 任意分隔符：空格、换行、逗号、中文逗号、顿号、制表符
  /// - 序号前缀：`1. abandon`、`1、abandon`、`1) abandon`
  /// - **4 字母缩写**：`aban` → `abandon`（词表保证前 4 字母唯一）
  ///
  /// 不容忍的（会明确报错而不是猜）：
  ///
  /// - 少于 3 个字母的片段（无法定位）
  /// - 前 3 字母有歧义的缩写（如 `act` 之外还有 `action`、`actor`，
  ///   此时 `act` 必须完整输入）
  factory RecoveryCode.parse(String input) {
    final tokens = _tokenize(input);
    if (tokens.isEmpty) {
      throw const RecoveryCodeException('没有读到任何词');
    }
    if (tokens.length != wordCount) {
      throw RecoveryCodeException(
        '恢复码必须是 $wordCount 个词，当前读到 ${tokens.length} 个。'
        '请检查是否漏抄或多抄。',
      );
    }

    final resolved = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final word = _resolve(token);
      if (word == null) {
        throw RecoveryCodeException(
          '第 ${i + 1} 个词 `$token` 不在词表中'
          '${token.length < 4 ? '（少于 4 个字母时无法按缩写匹配，请输完整单词）' : ''}',
        );
      }
      resolved.add(word);
    }

    final code = RecoveryCode._(List<String>.unmodifiable(resolved));
    // 立刻验校验和：早失败比晚失败好，用户还在页面上就能改。
    code.toEntropy();
    return code;
  }

  /// 24 词，按词表顺序。
  static const int wordCount = 24;

  /// 256 bit。
  static const int entropyLength = 32;

  /// 校验和长度：ENT / 32 = 8 bit。
  static const int checksumBits = 8;

  final List<String> words;

  /// 词 → 熵。**校验和不匹配时抛异常**。
  SecretBytes toEntropy() {
    final packed = Uint8List(entropyLength + 1); // 256 bit + 8 bit 校验和
    for (var i = 0; i < wordCount; i++) {
      final index = _wordIndex[words[i]];
      if (index == null) {
        throw RecoveryCodeException('第 ${i + 1} 个词 `${words[i]}` 不在词表中');
      }
      _writeBits(packed, i * 11, 11, index);
    }

    final entropy = Uint8List.sublistView(packed, 0, entropyLength);
    final expected = sha256.convert(entropy).bytes[0];
    final actual = packed[entropyLength];
    if (actual != expected) {
      throw const RecoveryCodeException(
        '校验和不匹配 —— 大概率有某个词抄错了。'
        '请逐个核对（这是恢复码自带的纠错机制，不是系统故障）。',
      );
    }
    return SecretBytes(Uint8List.fromList(entropy));
  }

  /// 展示用：每 6 个词一组，共 4 行。
  ///
  /// 分组不是为了好看 —— 24 个连续的词用户很容易抄漏一行，
  /// 分组后"第 3 行少了一个"是肉眼可见的。
  List<String> get grouped => <String>[
        for (var i = 0; i < wordCount; i += 6) words.sublist(i, i + 6).join(' '),
      ];

  /// 校验用户对第 [position]（1 起）个词的回忆是否正确。
  ///
  /// 用于首次设置的"抽 3 个词"环节。允许 4 字母缩写。
  bool matches(int position, String answer) {
    if (position < 1 || position > wordCount) {
      throw ArgumentError('位置越界：$position');
    }
    final resolved = _resolve(_normalizeToken(answer));
    return resolved != null && resolved == words[position - 1];
  }

  /// 抽 [count] 个不重复的位置（1 起，升序返回）。
  ///
  /// 用调用方提供的 [random] 以便测试可复现；生产传 `Random.secure()`。
  static List<int> pickPositions(int count, Random random) {
    if (count < 1 || count > wordCount) {
      throw ArgumentError('抽取数量必须在 1..$wordCount 之间');
    }
    final pool = List<int>.generate(wordCount, (int i) => i + 1);
    pool.shuffle(random);
    final picked = pool.take(count).toList()..sort();
    return picked;
  }

  @override
  String toString() => 'RecoveryCode(${words.length} words)';

  // ── 内部 ──────────────────────────────────────────────────────────

  static List<String> _encode(Uint8List entropy) {
    final checksum = sha256.convert(entropy).bytes[0];
    final packed = Uint8List(entropyLength + 1)
      ..setRange(0, entropyLength, entropy)
      ..[entropyLength] = checksum;

    return <String>[
      for (var i = 0; i < wordCount; i++)
        bip39English[_readBits(packed, i * 11, 11)],
    ];
  }

  static int _readBits(Uint8List data, int bitOffset, int count) {
    var value = 0;
    for (var i = 0; i < count; i++) {
      final bitPos = bitOffset + i;
      final bit = (data[bitPos >> 3] >> (7 - (bitPos & 7))) & 1;
      value = (value << 1) | bit;
    }
    return value;
  }

  static void _writeBits(Uint8List data, int bitOffset, int count, int value) {
    for (var i = 0; i < count; i++) {
      final bitPos = bitOffset + i;
      final bit = (value >> (count - 1 - i)) & 1;
      if (bit == 1) {
        data[bitPos >> 3] |= 1 << (7 - (bitPos & 7));
      }
    }
  }

  static final Map<String, int> _wordIndex = <String, int>{
    for (var i = 0; i < bip39English.length; i++) bip39English[i]: i,
  };

  static String _normalizeToken(String raw) {
    var token = raw.toLowerCase().trim();
    // 去掉序号前缀：`1.` `1、` `1)` `1:` `(1)`
    token = token.replaceFirst(RegExp(r'^\(?\d+[.)、:：]\s*'), '');
    // 只保留字母（去掉尾随标点）
    token = token.replaceAll(RegExp(r'[^a-z]'), '');
    return token;
  }

  static List<String> _tokenize(String input) {
    final cleaned = input
        .toLowerCase()
        // 各种分隔符统一成空格：换行、制表、中英文逗号、顿号、分号、竖线
        .replaceAll(RegExp(r'[\s,，、;；|]+'), ' ')
        .trim();
    if (cleaned.isEmpty) return const <String>[];

    return <String>[
      for (final raw in cleaned.split(' '))
        if (_normalizeToken(raw).isNotEmpty) _normalizeToken(raw),
    ];
  }

  /// 词 → 规范词。支持完整单词与 4 字母以上唯一前缀。
  static String? _resolve(String token) {
    if (token.isEmpty) return null;
    final exact = _wordIndex.containsKey(token) ? token : null;
    if (exact != null) return exact;

    // 缩写匹配要求至少 4 个字母：3 字母在词表里普遍有歧义。
    if (token.length < 4) return null;

    String? found;
    for (final word in bip39English) {
      if (word.startsWith(token)) {
        if (found != null) return null; // 有歧义
        found = word;
      }
    }
    return found;
  }
}

/// 便于测试构造确定性熵（BIP-39 官方测试向量都是 hex 形式）。
SecretBytes entropyFromHex(String hex) {
  if (hex.length.isOdd) throw ArgumentError('hex 长度必须是偶数');
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return SecretBytes(out);
}
