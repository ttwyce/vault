import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/crypto/vault_meta.dart';
import '../../core/identity/uuid_v7.dart';

/// `meta.enc` 读取失败。
///
/// 单独一个类型是因为 UI 要区分两种完全不同的处理：
/// - **文件不存在** → 首次使用，走创建流程
/// - **文件存在但读不懂** → 数据可能被破坏 / 被手工改坏，必须让用户知道，
///   绝不能当成"首次使用"去新建一个 vault（那等于把老数据丢在一边）
class VaultMetaException implements Exception {
  const VaultMetaException(this.message);

  final String message;

  @override
  String toString() => 'VaultMetaException: $message';
}

/// vault 的本地文件布局。
///
/// ```
/// <appSupport>/
///   meta.enc         vault 元数据（明文 JSON，含两段被包裹的 DEK）
///   device_id        本机标识（UUIDv7，纯文本）
///   vault.db         SQLCipher 加密库
///   fonts/           字体子系统（见 docs/15）
/// ```
///
/// **`device_id` 为什么不放数据库或 meta.enc**：
/// - 放 `meta.enc` 会让它每次写设备列表时成为同步写热点（见 docs/04 §2）
/// - 放数据库要先解锁才能读到，而 HLC 需要在解锁过程中就带上 node
class VaultStorage {
  // 私有字段 + 同义具名参数，与 WriteGateway / ActivityLogger 保持一致的写法。
  // ignore: prefer_initializing_formals
  VaultStorage({Directory? directory}) : _directory = directory;

  static const String metaFileName = 'meta.enc';
  static const String deviceIdFileName = 'device_id';
  static const String databaseFileName = 'vault.db';

  final Directory? _directory;

  Directory? _resolved;

  Future<Directory> ensureDirectory() async {
    final cached = _resolved;
    if (cached != null) return cached;
    final dir = _directory ?? await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _resolved = dir;
    return dir;
  }

  Future<File> _metaFile() async =>
      File(p.join((await ensureDirectory()).path, metaFileName));

  Future<bool> hasVault() async => (await _metaFile()).exists();

  /// 读 `meta.enc`。文件不存在返回 null。
  ///
  /// 存在但解析失败**抛异常**，不返回 null —— 见 [VaultMetaException] 的说明。
  Future<VaultMeta?> readMeta() async {
    final file = await _metaFile();
    if (!await file.exists()) return null;

    final text = await file.readAsString();
    if (text.trim().isEmpty) {
      throw const VaultMetaException('meta.enc 是空文件，可能写入时断电');
    }
    try {
      return VaultMeta.fromJsonString(text);
    } on FormatException catch (e) {
      throw VaultMetaException('meta.enc 格式不正确：${e.message}');
    } on Object catch (e) {
      throw VaultMetaException('meta.enc 无法读取：$e');
    }
  }

  /// 写 `meta.enc`。
  ///
  /// **先写临时文件再 rename**：直接覆写的话，写到一半断电会留下一个
  /// 半截 JSON，而它是解锁的唯一入口 —— 那等于永久锁死整个库。
  ///
  /// 注意这个方法**会覆盖**已有文件。它的用途是"改主密码后写回新的包裹结果"。
  /// 首次创建请用 [writeMetaIfAbsent]。
  Future<void> writeMeta(VaultMeta meta) async {
    final dir = await ensureDirectory();
    final target = File(p.join(dir.path, metaFileName));
    final temp = File(p.join(dir.path, '$metaFileName.tmp'));

    await temp.writeAsString(meta.toJsonString(), flush: true);
    await temp.rename(target.path);
  }

  /// 只在"本机还没有 vault"时写入。已存在返回 `false`，**绝不覆盖**。
  ///
  /// 这是防止一类**不可逆**事故的最后一道闸：
  /// `meta.enc` 里存的是被 KEK 包裹的 DEK。一旦被新的包裹结果覆盖，
  /// 旧 DEK 就再也解不出来了 —— 老数据全部作废，而且没有任何报错。
  ///
  /// 调用方（`VaultSession.createVault`）还会在更前面拦一次"已有 vault"，
  /// 这里是纵深防御：状态判断可能因为竞态或将来重构而漏掉，
  /// 但文件存在与否是事实。
  Future<bool> writeMetaIfAbsent(VaultMeta meta) async {
    final dir = await ensureDirectory();
    final target = File(p.join(dir.path, metaFileName));
    if (await target.exists()) return false;
    await writeMeta(meta);
    return true;
  }

  /// 本机标识。首次调用生成，之后一直复用。
  ///
  /// 为什么必须稳定：它是 HLC 的 node 部分。两台设备用了同一个 id，
  /// 时钟比较就失去意义，合并会把较新的修改判成旧的。
  Future<String> loadOrCreateDeviceId() async {
    final dir = await ensureDirectory();
    final file = File(p.join(dir.path, deviceIdFileName));

    if (await file.exists()) {
      final existing = (await file.readAsString()).trim();
      if (UuidV7.isValid(existing)) return existing;
      // 文件存在但内容不合法：不静默重生成，先留个备份再换新的。
      // 悄悄换掉会让该设备的历史 HLC 与新 id 对不上。
      await file.rename('${file.path}.broken-${DateTime.now().millisecondsSinceEpoch}');
    }

    final id = UuidV7().next();
    await file.writeAsString(id, flush: true);
    return id;
  }

  Future<File> databaseFile() async =>
      File(p.join((await ensureDirectory()).path, databaseFileName));

  /// 导出为可读的诊断信息（设置页"关于"用，**不含任何密钥**）。
  Future<Map<String, Object?>> describe() async {
    final dir = await ensureDirectory();
    final db = await databaseFile();
    return <String, Object?>{
      'directory': dir.path,
      'has_vault': await hasVault(),
      'database_bytes': await db.exists() ? await db.length() : 0,
      'device_id': await loadOrCreateDeviceId(),
    };
  }

  /// 供测试构造：直接给出一个临时目录下的实例。
  static VaultStorage inDirectory(Directory dir) => VaultStorage(directory: dir);
}

/// 把异常翻译成用户能看懂的一句话。
///
/// 原则：**不吞掉技术细节，但也不把堆栈甩给用户**。
/// 用户需要知道"接下来该做什么"，开发者需要能在日志里找到原因。
String describeFailure(Object error) {
  if (error is VaultMetaException) return error.message;
  if (error is FileSystemException) {
    return '读写本地文件失败（${error.osError?.message ?? error.message}）。'
        '请检查设备存储空间是否已满。';
  }
  if (error is StateError) return error.message;
  return error.toString();
}

/// 让 JSON 解析失败时能带上原始片段，方便定位（**只在调试日志里用**）。
String snippetForLog(String text) {
  final trimmed = text.trim();
  return trimmed.length <= 120 ? trimmed : '${trimmed.substring(0, 120)}…';
}

/// 便于把 meta 转成日志友好的摘要（不含密文）。
String describeMeta(VaultMeta meta) => jsonEncode(<String, Object?>{
      'vault_id': meta.vaultId,
      'schema': meta.schema,
      'kdf': meta.kdfParams.toJson(),
      'has_recovery': meta.hasRecoveryCode,
      'items': meta.itemCount,
    });
