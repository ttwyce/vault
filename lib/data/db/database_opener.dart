import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'database_key.dart';
import 'vault_database.dart';

/// 数据库打开器。**全项目唯一的 open 入口。**
///
/// 为什么要收敛到一处：加密是"错了不会报错"的那类配置。有**两种**失败方式，
/// 而且第二种更隐蔽：
///
/// 1. **链接的不是 SQLCipher**（普通 SQLite）→ `PRAGMA cipher_version` 为空。
/// 2. **链接的是 SQLCipher，但忘了执行 `PRAGMA key`** →
///    `cipher_version` **照样有值**，数据库以明文创建，一切正常，测试全绿。
///
/// 所以光查 `cipher_version` 是不够的（这一条是实测踩出来的：
/// 本项目全局用 SQLCipher，任何连接都能报出版本号）。
/// 真正能区分"设了 key"的是 `PRAGMA cipher_salt` ——
/// 没有密钥上下文时它返回空集，设了 key 才返回 16 字节 salt。
///
/// 打开顺序（不可调换）：
/// ```
/// 1. PRAGMA key              ← 加密库在设 key 之前读任何页面都会失败
/// 2. cipher_version 断言      ← 拦住"链接错了库"
/// 3. cipher_salt 断言         ← 拦住"忘了设 key"
/// 4. journal_mode / synchronous / busy_timeout / foreign_keys
/// 5. drift 建表与迁移
/// ```
class VaultDatabaseOpener {
  VaultDatabaseOpener({
    required this.key,
    this.pragmas = const SqlitePragmas(),
    this.fileName = 'vault.db',
    Directory? storageDir,
    this.inMemory = false,
    this.logStatements = false,
  }) : _directory = storageDir;

  final DatabaseKey key;
  final SqlitePragmas pragmas;
  final String fileName;

  /// 测试注入用。为 null 时走 `getApplicationSupportDirectory()`。
  final Directory? _directory;

  /// 测试用内存库。仍然走完整加密流程（内存库同样被 SQLCipher 加密）。
  final bool inMemory;

  final bool logStatements;

  /// 已打开的库。同一个 opener 只应打开一次。
  VaultDatabase? _opened;

  VaultDatabase get database {
    final db = _opened;
    if (db == null) {
      throw StateError('数据库尚未打开，先 await open()');
    }
    return db;
  }

  Future<VaultDatabase> open() async {
    if (_opened != null) return _opened!;

    final QueryExecutor executor;
    if (inMemory) {
      // 内存库不建在后台 isolate：测试里需要同步可控，且没有 IO 收益
      executor = NativeDatabase.memory(
        setup: _setupConnection,
        logStatements: logStatements,
      );
    } else {
      final file = await _resolveFile();
      // 后台 isolate：建库、迁移、首次 FTS 索引都可能几百毫秒，
      // 放主 isolate 会让冷启动卡一下。
      executor = NativeDatabase.createInBackground(
        file,
        setup: _setupConnection,
        logStatements: logStatements,
      );
    }

    final db = VaultDatabase(executor);

    // 触发一次真实查询：drift 是懒初始化的，不查一下，
    // setup 里的异常会拖到第一次业务查询才抛，堆栈里看不出根因。
    await db.customSelect('SELECT 1;').get();

    _opened = db;
    return db;
  }

  Future<File> _resolveFile() async {
    final dir = _directory ?? await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, fileName));
  }

  /// 在原始连接上执行加密与 pragma。**由 drift 在 open 之后、任何查询之前调用。**
  void _setupConnection(sqlite.Database raw) {
    raw.execute('PRAGMA key = ${key.pragmaLiteral};');

    // 断言一：链接的必须是 SQLCipher。普通 SQLite 在这里返回空集。
    final version = raw.select('PRAGMA cipher_version;');
    if (version.isEmpty) {
      raw.close();
      throw StateError(
        '数据库未启用加密：PRAGMA cipher_version 为空。\n'
        '当前链接的是普通 SQLite，PRAGMA key 被静默忽略 —— '
        '继续运行会让密码与日记以明文落盘。\n'
        '检查 pubspec.yaml：\n'
        '  hooks:\n'
        '    user_defines:\n'
        '      sqlite3:\n'
        '        source: sqlcipher',
      );
    }

    // 断言二：密钥必须真的生效。这一条才是真正的保险 ——
    // 本项目全局用 SQLCipher，所以"忘了设 key"时 cipher_version 照样有值。
    // 没有密钥上下文时 cipher_salt 返回空集。
    final salt = raw.select('PRAGMA cipher_salt;');
    if (salt.isEmpty) {
      raw.close();
      throw StateError(
        '数据库未启用加密：PRAGMA cipher_salt 为空，说明 PRAGMA key 没有生效。\n'
        '这会静默创建一个明文数据库。检查密钥是否为空、是否在连接建立后立刻应用。',
      );
    }

    pragmas.applyTo(raw);
  }

  /// 关闭并释放密钥。锁屏 / 退出登录时调用。
  Future<void> close() async {
    final db = _opened;
    _opened = null;
    if (db != null) {
      await db.close();
    }
    key.destroy();
  }
}
