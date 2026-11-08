import 'package:drift/drift.dart';

import 'tables/archive_tables.dart';
import 'tables/content_tables.dart';
import 'tables/entry_tables.dart';
import 'tables/log_tables.dart';
import 'tables/search_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/taxonomy_tables.dart';

part 'vault_database.g.dart';

/// 本地库。SQLCipher 整库加密，密钥由 [DatabaseOpener] 在打开时注入。
///
/// 表结构见 `docs/13-数据模型总表.md`（唯一事实来源）。
/// 这里只做三件额外的事：建 FTS5 虚拟表、开库时校验加密、提供全文检索入口。
@DriftDatabase(
  tables: <Type>[
    // 核心
    Entries,
    EntryHistory,
    TrashRows,
    // 组织
    Categories,
    Tags,
    EntryCategories,
    EntryTags,
    CategoryFieldTemplates,
    // 内容
    Credentials,
    Conversations,
    Messages,
    // 日志
    Oplogs,
    Activities,
    // 同步
    SyncStates,
    DeviceWatermarks,
    SyncLogs,
    // 检索
    DiaryIndexes,
    EntryVecs,
    EmbeddingModels,
    // 归档与任务
    BlobRefs,
    LinkChecks,
    JobQueues,
  ],
)
class VaultDatabase extends _$VaultDatabase {
  VaultDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createSearchIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // 目前只有 v1。后续每次 schema 变更都要在这里加分支，
          // 并配一条「升级 + 回滚」测试（docs/13 §7）。
        },
        beforeOpen: (OpeningDetails details) async {
          // 二道防线：即使有人绕过 DatabaseOpener 直接 new VaultDatabase，
          // 这里也会拦住。普通 SQLite 会静默忽略 PRAGMA key，
          // 让密码明文落盘 —— 这是唯一一种"无声失效"的失败方式。
          await _assertEncrypted();
        },
      );

  // ---------------------------------------------------------------------------
  // 加密自检
  // ---------------------------------------------------------------------------

  /// 确认当前连接是 SQLCipher。返回版本号（如 `4.20.0 community`）。
  Future<String> cipherVersion() async {
    final rows = await customSelect('PRAGMA cipher_version;').get();
    if (rows.isEmpty) return '';
    return rows.first.data.values.first?.toString() ?? '';
  }

  /// 确认当前连接真的加密了。
  ///
  /// 两条断言缺一不可：
  /// - `cipher_version` 非空 → 链接的是 SQLCipher（而不是普通 SQLite）
  /// - `cipher_salt` 非空 → `PRAGMA key` 真的生效了
  ///
  /// 只查第一条是不够的：本项目全局用 SQLCipher，所以"忘了设 key"的连接
  /// 也会报出版本号，然后以明文建库。
  Future<void> _assertEncrypted() async {
    final version = await cipherVersion();
    if (version.isEmpty) {
      throw StateError(
        '当前 SQLite 连接不是 SQLCipher（PRAGMA cipher_version 为空）。\n'
        'PRAGMA key 会被静默忽略，数据将以明文落盘。\n'
        '请检查 pubspec.yaml 的 hooks.user_defines.sqlite3.source 是否为 sqlcipher。',
      );
    }
    final salt = await customSelect('PRAGMA cipher_salt;').get();
    if (salt.isEmpty) {
      throw StateError(
        '当前连接没有加密（PRAGMA cipher_salt 为空）：PRAGMA key 没有生效。\n'
        '请通过 VaultDatabaseOpener 打开数据库，不要直接 new VaultDatabase。',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 全文索引（FTS5 虚拟表）
  //
  // FTS5 建表语句 drift 生成不出来，只能手写 SQL。
  // 它们是**派生数据**，坏了可以从 entry 全量重建，所以不进迁移版本管理。
  // ---------------------------------------------------------------------------

  static const String entryFtsTable = 'entry_fts';
  static const String conversationFtsTable = 'conversation_fts';

  /// `tokenize` 用 `unicode61 remove_diacritics 2`：
  /// 拉丁文本按词切分（这是它擅长的），中文由应用层先按字切分再写入
  /// （见 `lib/data/search/cjk_segmenter.dart` 与 docs/06 §1.3）。
  Future<void> _createSearchIndexes() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $entryFtsTable USING fts5(
        entry_id UNINDEXED,
        title,
        body,
        tags,
        tokenize = 'unicode61 remove_diacritics 2'
      );
    ''');
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $conversationFtsTable USING fts5(
        conversation_id UNINDEXED,
        title,
        body,
        tokenize = 'unicode61 remove_diacritics 2'
      );
    ''');
  }

  /// 重建全文索引。索引损坏或换分词方案时用。
  ///
  /// [segment] 由调用方注入（通常是 `CjkSegmenter.indexText`），
  /// 这样数据库层不依赖具体分词实现，换方案不用改这里。
  Future<int> rebuildEntryIndex(
    String Function(String text) segment,
  ) async {
    final all = await select(entries).get();
    await transaction(() async {
      await customStatement('DELETE FROM $entryFtsTable;');
      for (final row in all) {
        if (row.deleted != 0) continue;
        await putSearchDocument(
          entryId: row.id,
          title: segment(row.title ?? ''),
          body: segment(row.body ?? ''),
          tags: '',
        );
      }
    });
    return all.length;
  }

  /// 写入 / 更新一条全文索引。
  ///
  /// **传进来的文本必须已经过 `CjkSegmenter.indexText`**：
  /// FTS5 的 unicode61 会把连续汉字当成一个 token，
  /// 不切分的话「同步」搜不到「增量同步」。
  Future<void> putSearchDocument({
    required String entryId,
    required String title,
    required String body,
    required String tags,
  }) async {
    await transaction(() async {
      await customStatement(
        'DELETE FROM $entryFtsTable WHERE entry_id = ?;',
        <Object?>[entryId],
      );
      await customStatement(
        'INSERT INTO $entryFtsTable(entry_id, title, body, tags) VALUES (?, ?, ?, ?);',
        <Object?>[entryId, title, body, tags],
      );
    });
  }

  Future<void> removeSearchDocument(String entryId) => customStatement(
        'DELETE FROM $entryFtsTable WHERE entry_id = ?;',
        <Object?>[entryId],
      );

  /// 检索。[matchQuery] 必须已经过 `CjkSegmenter.matchQuery` 处理。
  ///
  /// 返回按相关度排序的 entry id。`readsFrom: {entries}` 让 drift 在
  /// entry 表变化时自动失效缓存（FTS 是虚拟表，无法参与 readsFrom）。
  Future<List<String>> searchEntryIds(
    String matchQuery, {
    int limit = 50,
  }) async {
    final query = matchQuery.trim();
    if (query.isEmpty) return const <String>[];

    final rows = await customSelect(
      'SELECT entry_id FROM $entryFtsTable '
      'WHERE $entryFtsTable MATCH ? ORDER BY rank LIMIT ?;',
      variables: <Variable<Object>>[
        Variable<String>(query),
        Variable<int>(limit),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{entries},
    ).get();

    return rows
        .map((QueryRow row) => row.read<String>('entry_id'))
        .toList(growable: false);
  }

  /// 带高亮片段的检索。UI 直接渲染片段，不用再回表取正文。
  Future<List<SearchHit>> searchWithSnippet(
    String matchQuery, {
    int limit = 20,
  }) async {
    final query = matchQuery.trim();
    if (query.isEmpty) return const <SearchHit>[];

    final rows = await customSelect(
      'SELECT entry_id, '
      "snippet($entryFtsTable, 1, '⟦', '⟧', '…', 14) AS snip "
      'FROM $entryFtsTable WHERE $entryFtsTable MATCH ? '
      'ORDER BY rank LIMIT ?;',
      variables: <Variable<Object>>[
        Variable<String>(query),
        Variable<int>(limit),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{entries},
    ).get();

    return rows
        .map(
          (QueryRow row) => SearchHit(
            entryId: row.read<String>('entry_id'),
            snippet: row.read<String>('snip'),
          ),
        )
        .toList(growable: false);
  }
}

/// 一条检索结果：条目 id + 高亮片段。
class SearchHit {
  const SearchHit({required this.entryId, required this.snippet});

  final String entryId;

  /// 命中的正文片段，命中词用 `⟦ ⟧` 包裹
  final String snippet;
}
