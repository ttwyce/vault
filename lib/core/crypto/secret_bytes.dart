import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 内存中的一段密钥字节。
///
/// 三条设计约束，都是为了"密钥不进磁盘、不进日志、不进崩溃上报"：
///
/// 1. **构造时复制**，读取时也复制。避免调用方持有同一个 `Uint8List` 引用，
///    在我们 `destroy()` 之后还能继续读到明文（或者反过来，被调用方改掉）。
/// 2. **`toString` 只输出指纹**。Dart 里最容易泄露密钥的方式就是
///    某处 `print(key)`、或者异常信息里拼了对象 —— 从源头堵掉。
/// 3. **比较用常量时间**。密钥比较是典型的时序侧信道入口：
///    `a == b` 会在第一个不同字节处提前返回，攻击者可以逐字节试探。
///
/// ## 关于 `destroy()` 的诚实说明
///
/// Dart 没有 `mlock`，GC 会把对象搬来搬去，`String` 与 `Uint8List` 都可能被复制。
/// `destroy()` 只是把**我们能控制的那一份**清零，无法保证内存里不存在其他副本。
/// 真正的保障是"密钥只存在内存 + 不写日志 + 不落盘"，而不是这个函数。
/// 写在这里是为了不让后来的人误以为它提供了强保证。
class SecretBytes {
  /// 从现有字节构造（会复制一份）。
  SecretBytes(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  /// 生成 [length] 字节的密码学随机密钥。
  factory SecretBytes.random({int length = 32, Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return SecretBytes(bytes);
  }

  /// 全零（用于占位与测试，**不要用于真实密钥**）。
  factory SecretBytes.zeroed(int length) => SecretBytes(Uint8List(length));

  final Uint8List _bytes;

  int get length => _bytes.length;

  /// 取一份副本。调用方负责不要把它写进日志或磁盘。
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// 内部使用的零拷贝视图。
  ///
  /// 只在库内部传给加密算法时用 —— 那些算法不会保留引用。
  /// 外部代码请用 [bytes]。
  Uint8List get internalView => _bytes;

  /// 常量时间比较。长度不同直接返回 false（长度本身不是秘密）。
  bool equalsConstantTime(SecretBytes other) {
    if (other.length != length) return false;
    var diff = 0;
    for (var i = 0; i < _bytes.length; i++) {
      diff |= _bytes[i] ^ other._bytes[i];
    }
    return diff == 0;
  }

  /// 十六进制表示。**只用于喂给 SQLCipher 的 `PRAGMA key`**，不要用于日志。
  String toHex() {
    final buffer = StringBuffer();
    for (final byte in _bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// 短指纹：`sha256(密钥)` 的前 4 字节。
  ///
  /// 用途只有一个 —— 在日志/诊断里认出"这两把是不是同一把"。
  ///
  /// **刻意不取密钥本身的字节**。早期版本取的是首尾各 4 字节，
  /// 那样会把 64 bit 真实密钥写进日志。虽然 2^192 的剩余空间仍不可爆破，
  /// 但"日志里出现密钥材料"这件事本身就是不该开的先例 ——
  /// 日志会被贴进 issue、上传到崩溃平台、留在别人的终端里。
  /// 单向哈希让指纹**不含任何密钥信息**，同时保持可比性。
  String get fingerprint {
    final digest = sha256.convert(_bytes).bytes;
    return digest.take(4).map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 尽力清零。见类注释里的诚实说明。
  void destroy() {
    _bytes.fillRange(0, _bytes.length, 0);
  }

  @override
  String toString() => 'SecretBytes($fingerprint, $length bytes)';

  @override
  bool operator ==(Object other) =>
      other is SecretBytes && equalsConstantTime(other);

  @override
  int get hashCode => Object.hashAll(_bytes.take(8));
}
