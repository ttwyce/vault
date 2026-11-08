import 'package:drift/drift.dart';

/// 密码条目扩展表（与 `entry` 一对一，`id` 就是 `entry.id`）。
///
/// 为什么不塞进 `entry.meta`：密码的加密粒度不同。
/// `meta` 里是明文 JSON（受 SQLCipher 页级保护），而这里的字段要**额外**
/// 在同步边界做字段级 AEAD，且 `custom_fields` 里 `secret:true` 的项与密码同级。
///
/// **任何工具都不返回这里的敏感字段值**（`CredentialGuard` 代码级拦截，
/// 不靠 prompt 约束），见 docs/07 §3。
@DataClassName('CredentialRow')
class Credentials extends Table {
  @override
  String get tableName => 'credential';

  /// = entry.id
  TextColumn get id => text()();

  TextColumn get username => text().nullable()();

  TextColumn get password => text().nullable()();

  /// Base32 TOTP secret。有值即表示这条带 2FA。
  TextColumn get totpSecret => text().nullable()();

  TextColumn get url => text().nullable()();

  /// 自由备注。允许 AI 读，但默认 L0 端侧，云端需逐次授权。
  TextColumn get notes => text().nullable()();

  /// 自定义字段 JSON 数组，见 docs/13 §4。
  /// `secret:true` 的项与 password 同级加密。
  TextColumn get customFields => text().nullable()();

  /// 密码最后一次修改时间，健康报告用它算"超期未改"
  IntColumn get passwordChangedAt => integer().nullable()();

  /// 是否已泄露（HIBP k-anonymity 结果缓存：0 未知 / 1 安全 / 2 泄露）
  IntColumn get breached => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// 会话。与 `entry` 物理隔离 —— 会话是"过程"，条目是"结果"。
///
/// 这条边界不能模糊：AI 在对话里整理出的东西，必须显式落成 entry 才算数，
/// 否则知识库会被聊天记录稀释。
@DataClassName('ConversationRow')
@TableIndex(name: 'idx_conv_time', columns: {#deleted, #updatedAt})
class Conversations extends Table {
  @override
  String get tableName => 'conversation';

  TextColumn get id => text()();

  /// 默认取首条消息前 20 字
  TextColumn get title => text().nullable()();

  /// 可空；空则按日期自动分组
  TextColumn get groupId => text().nullable()();

  IntColumn get createdAt => integer().nullable()();

  IntColumn get updatedAt => integer().nullable()();

  TextColumn get hlc => text()();

  IntColumn get messageCount => integer().withDefault(const Constant(0))();

  IntColumn get deleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// 消息。append-only，合并时只追加不改写。
@DataClassName('MessageRow')
@TableIndex(name: 'idx_msg_conv', columns: {#conversationId, #createdAt})
class Messages extends Table {
  @override
  String get tableName => 'message';

  TextColumn get id => text()();

  TextColumn get conversationId => text()();

  /// 1 user / 2 assistant / 3 tool
  IntColumn get role => integer()();

  TextColumn get content => text().nullable()();

  /// JSON：工具调用与结果
  TextColumn get toolCalls => text().nullable()();

  /// JSON：entry id 数组，用于"每条结论可点开溯源"
  TextColumn get citations => text().nullable()();

  IntColumn get createdAt => integer().nullable()();

  TextColumn get hlc => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
