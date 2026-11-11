/// 云端目录布局与路径规范（docs/04 §2）。
///
/// 文件名一律 `[0-9a-f]{32}.enc`（HMAC(entry_id) 的十六进制），
/// 从根上绕开各家 WebDAV 对中文 / 特殊字符的 URL 编码差异；
/// 同时不泄露标题。HMAC 的计算留给加密层（需要 DEK，是异步的），
/// 这里只负责「拿到名字之后怎么摆」。
library;

class CloudLayout {
  const CloudLayout._();

  static const String root = '/vault';
  static const int shardCount = 16;

  static const String metaPath = '$root/meta.enc';
  static const String devicesDir = '$root/devices';

  static final RegExp _itemNamePattern = RegExp(r'^[0-9a-f]{32}\.enc$');
  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

  static bool isValidItemName(String name) =>
      _itemNamePattern.hasMatch(name);

  /// 16 分片取 HMAC 十六进制的首字符。
  /// 名字不合法直接抛错：把它塞进路径再上传，另一台设备永远找不到。
  static String shardOf(String hashedName) {
    if (!isValidItemName(hashedName)) {
      throw ArgumentError.value(
        hashedName,
        'hashedName',
        '云端文件名必须是 32 位小写十六进制 + .enc',
      );
    }
    return hashedName.substring(0, 1);
  }

  static String itemsDir(String shard) => '$root/items/$shard';

  /// 非 entry 实体（category / tag / entry_taxonomy）的独立命名空间。
  ///
  /// 仍用同样的 HMAC 文件名和 16 分片，但不与 `/vault/items/` 混放：
  /// 正文同步器只 L2 扫描 items，taxonomy 由独立通道按实体应用，
  /// 不会把 category 信封误当成 `EntrySnapshot` 去跑 merge3。
  static String entitiesDir(String shard) => '$root/entities/$shard';

  static String itemPath(String hashedName) =>
      '${itemsDir(shardOf(hashedName))}/$hashedName';

  static String entityItemPath(String hashedName) =>
      '${entitiesDir(shardOf(hashedName))}/$hashedName';

  static String tombstonePath(String hashedName) =>
      '$root/tombstones/${_requireItemName(hashedName)}';

  static String vectorPath(String hashedName) =>
      '$root/vec/${_requireItemName(hashedName)}';

  /// blob 按内容寻址、不可变，永不冲突、永不需要合并。
  static String blobPath(String sha256Hex) {
    if (!_sha256Pattern.hasMatch(sha256Hex)) {
      throw ArgumentError.value(sha256Hex, 'sha256Hex', '需要 64 位小写十六进制');
    }
    return '$root/blobs/${sha256Hex.substring(0, 2)}/$sha256Hex.bin';
  }

  /// 设备 id 可能带空格或中文，必须编码，但不编码路径分隔符。
  static String devicePath(String deviceId) =>
      '$devicesDir/${Uri.encodeComponent(deviceId)}.json';

  /// 分段 `encodeComponent`，**保留 `/`**。
  ///
  /// `Uri.encodeComponent('/vault/a b')` 会把斜杠也编成 `%2F`，
  /// 部分 WebDAV 实现不接受，必须按段处理。
  static String encodePath(String path) => path
      .split('/')
      .map((String segment) =>
          segment.isEmpty ? segment : Uri.encodeComponent(segment))
      .join('/');

  static String _requireItemName(String name) {
    if (!isValidItemName(name)) {
      throw ArgumentError.value(name, 'hashedName', '云端文件名不合法');
    }
    return name;
  }
}
