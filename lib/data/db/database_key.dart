import 'dart:math';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../core/crypto/secret_bytes.dart';

/// 数据库主密钥。
///
/// 32 字节随机密钥，**不是从主密码直接算出来的**。
/// 主密码派生的 KEK 只负责"包裹"它（见 docs/03 §2），所以：
///
/// - 改主密码 = 重新包裹同一个 key，毫秒级完成，不用对几百 MB 的库跑 `PRAGMA rekey`
/// - 生物识别解锁 = 系统安全区解出被包裹的 key，跳过 Argon2id
/// - 恢复码 = 另一个 KEK' 包裹同一把 key
///
/// 字节层面的零拷贝 / 常量时间比较 / 擦除全部委托给 [SecretBytes]，
/// 这里只保留 SQLCipher 特有的 `PRAGMA key` 字面量拼装。
class DatabaseKey {
  DatabaseKey(Uint8List bytes)
      : assert(bytes.length == length, '数据库密钥必须是 $length 字节'),
        _secret = SecretBytes(bytes);

  /// 随机生成一把新密钥（首次创建 vault 时用）。
  factory DatabaseKey.random([Random? random]) {
    return DatabaseKey(SecretBytes.random(length: length, random: random).bytes);
  }

  static const int length = 32;

  final SecretBytes _secret;

  Uint8List get bytes => _secret.bytes;

  /// SQLCipher 的 `PRAGMA key` 用**二进制字面量**：`"x'<hex>'"`。
  ///
  /// 注意外面那层双引号不能省。SQLite 的 PRAGMA 解析器不接受裸 blob 字面量
  /// （`PRAGMA key = x'..'` 会直接报 syntax error），SQLCipher 的约定是把
  /// 整个 `x'..'` 当成一个字符串传进去，由它自己再解析成字节。
  ///
  /// 为什么不传普通字符串密码：字符串形式会再过一遍 PBKDF2，
  /// 而我们自己已经用 Argon2id 派生过了，再套一层既慢又没必要。
  /// 二进制形式是"原样当密钥用"，语义清晰、启动更快。
  String get pragmaLiteral => '"x\'${_secret.toHex()}\'"';

  /// 用于日志/诊断的短指纹。**不可逆，且不泄露密钥**。
  String get fingerprint => _secret.fingerprint;

  /// 密钥擦除。解锁会话结束时调用。
  ///
  /// 说明：Dart 无法保证 GC 前不被复制，这里只是尽力而为，
  /// 真正的保障是"密钥只存在内存 + 不写日志 + 不进崩溃上报"。
  void destroy() => _secret.destroy();

  @override
  String toString() => 'DatabaseKey($fingerprint)';

  // 供 opener 判断"同一个 key 已应用"，避免重复 PRAGMA key
  @override
  bool operator ==(Object other) =>
      other is DatabaseKey && _secret.equalsConstantTime(other._secret);

  @override
  int get hashCode => _secret.hashCode;
}

/// 打开数据库时的 pragma 设置。
///
/// 抽出来是因为**顺序有硬性要求**，而且三端默认值不同。
class SqlitePragmas {
  const SqlitePragmas({
    this.journalMode = 'WAL',
    this.synchronous = 'NORMAL',
    this.busyTimeoutMs = 5000,
    this.foreignKeys = true,
    this.cacheSizeKb = -8000,
  });

  final String journalMode;

  /// WAL 下用 NORMAL 是标准取舍：崩溃最多丢最后一个事务，但不会损坏库。
  /// 用 FULL 会让每次写入都 fsync，在 Android 上肉眼可见地卡。
  final String synchronous;

  final int busyTimeoutMs;

  final bool foreignKeys;

  /// 负数表示 KiB。−8000 ≈ 8MB page cache。
  final int cacheSizeKb;

  /// 应用到原始连接。**必须在 `PRAGMA key` 之后调用** ——
  /// 加密库在设置 key 之前读任何页面都会失败。
  void applyTo(sqlite.Database db) {
    db.execute('PRAGMA journal_mode = $journalMode;');
    db.execute('PRAGMA synchronous = $synchronous;');
    db.execute('PRAGMA busy_timeout = $busyTimeoutMs;');
    db.execute('PRAGMA foreign_keys = ${foreignKeys ? 'ON' : 'OFF'};');
    db.execute('PRAGMA cache_size = $cacheSizeKb;');
  }
}
