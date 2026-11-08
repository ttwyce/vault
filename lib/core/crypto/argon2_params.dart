import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Argon2id 的代价参数。
///
/// 这些数字**必须随 vault 一起持久化**（写进 `meta.enc` 的 `kdf` 字段），
/// 原因有两个：
///
/// 1. **未来可升级**：今天的 `m=64MB` 五年后可能偏弱。升级路径是
///    「用旧参数解 → 用新参数重新包裹」，没有旧参数就永远解不开老数据。
/// 2. **跨设备一致**：三端必须用同一组参数算出同一把 KEK，否则 B 设备解不开
///    A 设备写的库。
///
/// ## 字段单位
///
/// `memoryKb` 的单位是 **KiB**，与 `cryptography` 包和 RFC 9106 一致。
/// 64 MB 写作 `65536`，不是 `64` —— 这个单位在三个库里各不相同
/// （RFC 用 KiB、libsodium 用 bytes、某些封装用 MB），写错一位就是
/// 要么 OOM 要么把安全强度降到接近 0。
class Argon2Params {
  const Argon2Params({
    this.memoryKb = 65536,
    this.iterations = 3,
    this.parallelism = 4,
    this.hashLength = 32,
  });

  /// 默认参数：`m=64MiB, t=3, p=4, 输出 32 字节`。
  ///
  /// 对齐 OWASP 2024 对 Argon2id 的最低建议（`m=19MiB, t=2, p=1`）之上，
  /// 取 64 MiB 是因为这是移动端"能忍受"与"值得"的平衡点。
  /// 实测耗时见 `docs/16-密钥与恢复码.md` §2 —— **不要凭感觉调这组数字**。
  static const Argon2Params recommended = Argon2Params();

  /// 测试专用：把代价压到几乎为零。
  ///
  /// 只在单元测试里用。生产代码出现这个值等于没有加密。
  static const Argon2Params insecureForTests = Argon2Params(
    memoryKb: 64,
    iterations: 1,
    parallelism: 1,
  );

  /// 内存代价，单位 KiB。
  final int memoryKb;

  /// 迭代次数。
  final int iterations;

  /// 并行度（lane 数）。
  final int parallelism;

  /// 输出长度（字节）。
  final int hashLength;

  /// 参数上下界。
  ///
  /// 上界不是洁癖，是**防拒绝服务**：`meta.enc` 是用户可以手工编辑的明文 JSON
  /// （它必须能在解锁前被读到）。如果攻击者或有 bug 的版本写入
  /// `memoryKb: 2147483647`，设备一解锁就 OOM 崩溃，而且每次重装都复现。
  ///
  /// 下界同理：`memoryKb` 必须 ≥ `8 * parallelism`（Argon2 的硬性要求，
  /// 否则算法内部断言失败）。
  static const int minMemoryKb = 8;
  static const int maxMemoryKb = 1 << 20; // 1 GiB
  static const int minIterations = 1;
  static const int maxIterations = 64;
  static const int minParallelism = 1;
  static const int maxParallelism = 64;
  static const int minHashLength = 16;
  static const int maxHashLength = 64;

  bool get isValid =>
      memoryKb >= minMemoryKb &&
      memoryKb <= maxMemoryKb &&
      memoryKb >= 8 * parallelism &&
      iterations >= minIterations &&
      iterations <= maxIterations &&
      parallelism >= minParallelism &&
      parallelism <= maxParallelism &&
      hashLength >= minHashLength &&
      hashLength <= maxHashLength;

  Map<String, Object?> toJson() => <String, Object?>{
        'algo': 'argon2id',
        'version': 19,
        'memory_kb': memoryKb,
        'iterations': iterations,
        'parallelism': parallelism,
        'hash_length': hashLength,
      };

  /// 从 `meta.enc` 解析。
  ///
  /// **解析即校验**：不合法直接抛，不允许"带着可疑参数继续跑"。
  /// 宁可让用户看到"配置文件损坏"，也不能在错误的代价下派生密钥 ——
  /// 那会生成一把解不开自己数据的 KEK，而用户完全不知道发生了什么。
  factory Argon2Params.fromJson(Map<String, Object?> json) {
    final algo = json['algo'];
    if (algo != null && algo != 'argon2id') {
      throw FormatException('不支持的 KDF 算法：$algo（只支持 argon2id）');
    }
    final params = Argon2Params(
      memoryKb: _readInt(json, 'memory_kb', Argon2Params.recommended.memoryKb),
      iterations: _readInt(json, 'iterations', Argon2Params.recommended.iterations),
      parallelism: _readInt(json, 'parallelism', Argon2Params.recommended.parallelism),
      hashLength: _readInt(json, 'hash_length', Argon2Params.recommended.hashLength),
    );
    if (!params.isValid) {
      throw FormatException(
        'KDF 参数超出允许范围：m=${params.memoryKb}KiB t=${params.iterations} '
        'p=${params.parallelism} len=${params.hashLength}。'
        '合法范围 m=${Argon2Params.minMemoryKb}..${Argon2Params.maxMemoryKb}、'
        't=${Argon2Params.minIterations}..${Argon2Params.maxIterations}、'
        'p=${Argon2Params.minParallelism}..${Argon2Params.maxParallelism}。',
      );
    }
    return params;
  }

  static int _readInt(Map<String, Object?> json, String key, int fallback) {
    final value = json[key];
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('KDF 参数 $key 不是数字：$value');
  }

  /// 人类可读的强度描述，用于设置页展示。
  String get label {
    final mb = (memoryKb / 1024).round();
    return 'Argon2id · ${mb}MB · $iterations 轮 · $parallelism 线程';
  }

  @override
  String toString() => 'Argon2Params(m=${memoryKb}KiB, t=$iterations, p=$parallelism, '
      'len=$hashLength)';

  @override
  bool operator ==(Object other) =>
      other is Argon2Params &&
      other.memoryKb == memoryKb &&
      other.iterations == iterations &&
      other.parallelism == parallelism &&
      other.hashLength == hashLength;

  @override
  int get hashCode => Object.hash(memoryKb, iterations, parallelism, hashLength);
}

/// KDF 盐。16 字节随机，随 vault 一起存。
///
/// 为什么单独一个类型：盐和密钥长得一样，都是 `Uint8List`，
/// 传参时极容易把两者搞混。用类型区分开，编译器就能挡住这类错误。
class KdfSalt {
  KdfSalt(Uint8List bytes)
      : assert(bytes.length == length, 'KDF 盐必须是 $length 字节'),
        _bytes = Uint8List.fromList(bytes);

  factory KdfSalt.random([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return KdfSalt(bytes);
  }

  factory KdfSalt.fromBase64(String encoded) {
    final bytes = base64Decode(encoded);
    if (bytes.length != length) {
      throw FormatException('KDF 盐长度错误：期望 $length 字节，实际 ${bytes.length}');
    }
    return KdfSalt(bytes);
  }

  /// 16 字节。RFC 9106 建议至少 8 字节，16 足够且与 libsodium 默认一致。
  static const int length = 16;

  final Uint8List _bytes;

  Uint8List get bytes => Uint8List.fromList(_bytes);

  Uint8List get internalView => _bytes;

  String toBase64() => base64Encode(_bytes);

  @override
  String toString() => 'KdfSalt(${toBase64()})';

  @override
  bool operator ==(Object other) =>
      other is KdfSalt && _constantTimeEquals(other._bytes, _bytes);

  @override
  int get hashCode => Object.hashAll(_bytes);

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
