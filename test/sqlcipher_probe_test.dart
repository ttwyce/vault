import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// M0 假设 A1 的验证：**SQLCipher 是否真的可用，且带 FTS5**。
///
/// 同时验证三件事，任何一件不成立都要改方案：
///
/// 1. `source: sqlcipher` 的预编译产物能被 Native Assets 下载并链接（三端同一套机制）
/// 2. `PRAGMA cipher_version` 有值 —— 即**确实是 SQLCipher**，
///    而不是悄悄退回普通 SQLite（普通 SQLite 会静默忽略 `PRAGMA key`，
///    后果是密码明文落盘，这是整个方案里最危险的一种失败方式）
/// 3. FTS5 编译进去了，且**中文能搜到**
void main() {
  /// 探针库必须落在系统临时目录，**不能落到工作目录**。
  ///
  /// 早期版本用了相对路径，`flutter test` 的工作目录是项目根，
  /// 结果每跑一次就在仓库里留几个 `.db`。这类垃圾文件不会报错，
  /// 只会悄悄堆在 `git status` 里。
  String probePath(String name) {
    final dir = Directory.systemTemp.createTempSync('vault_probe_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return '${dir.path}${Platform.pathSeparator}$name.db';
  }

  test('cipher_salt 能区分"设了 key"与"忘了设 key"', () {
    // 关键：本项目链接的就是 SQLCipher，所以「没设 key」的连接
    // 依然会让 cipher_version 非空 —— 单靠它无法发现"忘了加密"。
    final noKey = sqlite3.openInMemory();
    final emptySalt = noKey.select('PRAGMA cipher_salt;');
    noKey.close();

    final withKey = sqlite3.openInMemory();
    withKey.execute("PRAGMA key = \"x'${'ab' * 32}'\";");
    final salt = withKey.select('PRAGMA cipher_salt;');
    withKey.close();

    // ignore: avoid_print
    print('cipher_salt: noKey=${emptySalt.length} withKey=${salt.length} '
        'value=${salt.isEmpty ? '-' : salt.first.values.first}');

    expect(emptySalt, isEmpty, reason: '没有 key 时不应有 salt');
    expect(salt, isNotEmpty, reason: '设了 key 后应能读到 salt');
  });

  test('加密库的文件头不是明文 SQLite 的 "SQLite format 3"', () {
    final path = probePath('header_probe');
    final db = sqlite3.open(path);
    db.execute("PRAGMA key = \"x'${'cd' * 32}'\";");
    db.execute('CREATE TABLE t (v TEXT);');
    db.execute("INSERT INTO t VALUES ('x');");
    db.close();

    final header = File(path).readAsBytesSync().take(16).toList();
    final asText = String.fromCharCodes(header);
    expect(asText.startsWith('SQLite format 3'), isFalse,
        reason: '文件头仍是明文 SQLite 标记，说明没有真正加密');
  });

  test('SQLCipher 生效：cipher_version 非空', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);

    db.execute("PRAGMA key = 'a-test-passphrase';");
    final version = db.select('PRAGMA cipher_version;');

    expect(
      version,
      isNotEmpty,
      reason: 'PRAGMA cipher_version 为空 = 当前链接的是普通 SQLite，'
          'PRAGMA key 会被静默忽略，数据将明文落盘。必须换 source: sqlcipher。',
    );
    // ignore: avoid_print
    print('cipher_version = ${version.first.values.first}');
  });

  test('SQLCipher 生效：错误的密钥打不开已加密的库', () {
    final path = probePath('cipher_probe');

    final writer = sqlite3.open(path);
    writer.execute("PRAGMA key = 'correct-key';");
    writer.execute('CREATE TABLE secret (v TEXT);');
    writer.execute("INSERT INTO secret VALUES ('口令不能明文落盘');");
    writer.close();

    final reader = sqlite3.open(path);
    reader.execute("PRAGMA key = 'wrong-key';");
    // 用错密钥时第一次访问数据页会报 "file is not a database"（HMAC 校验失败）
    expect(
      () => reader.select('SELECT count(*) FROM secret;'),
      throwsA(anything),
    );
    reader.close();
  });

  test('FTS5 可用（unicode61 原样索引：中文子串搜不到，这是关键发现）', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute("PRAGMA key = 'k';");

    db.execute(
      "CREATE VIRTUAL TABLE raw_fts USING fts5(title, tokenize='unicode61');",
    );
    db.execute("INSERT INTO raw_fts(title) VALUES ('WebDAV 增量同步');");

    // 英文没问题
    expect(
      db.select("SELECT * FROM raw_fts WHERE raw_fts MATCH 'webdav';").length,
      1,
    );

    // 中文：unicode61 把连续汉字当成**一个 token**（"增量同步"），
    // 所以查"同步"匹配不到。这正是 06 文档里"中文检索会打折"的真实原因，
    // 而且它不是"精度低"，是**完全搜不到**。
    expect(
      db.select("SELECT * FROM raw_fts WHERE raw_fts MATCH '同步';").length,
      0,
      reason: '如果这里变成 1，说明 SQLite 的 unicode61 行为变了，'
          '中文分词方案需要重新评估',
    );
  });

  test('FTS5 + 应用层按字切分：中文子串检索可用', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute("PRAGMA key = 'k';");

    db.execute(
      "CREATE VIRTUAL TABLE seg_fts USING fts5(title, tokenize='unicode61');",
    );

    // 索引侧：每个汉字前后加空格，让 unicode61 把每个字切成独立 token
    db.execute(
      "INSERT INTO seg_fts(title) VALUES ('${_segment('WebDAV 增量同步')}');",
    );
    db.execute(
      "INSERT INTO seg_fts(title) VALUES ('${_segment('冲突合并与删除策略')}');",
    );

    // 查询侧：同样的切分，用**短语查询**保证顺序与相邻
    int hits(String query) => db
        .select(
          'SELECT * FROM seg_fts WHERE seg_fts MATCH ?;',
          <Object?>['"${_segment(query)}"'],
        )
        .length;

    expect(hits('同步'), 1, reason: '2 字中文子串');
    expect(hits('增量同步'), 1, reason: '4 字中文子串');
    expect(hits('冲突'), 1);
    expect(hits('删除策略'), 1, reason: '跨词边界的中文串');
    expect(hits('不存在'), 0);
    // 短语语义：不连续的词不应该命中
    expect(hits('同步删除'), 0, reason: '短语查询必须保持相邻');

    // 英文仍然走原路径
    expect(
      db.select("SELECT * FROM seg_fts WHERE seg_fts MATCH 'webdav';").length,
      1,
    );
  });

  test('FTS5 trigram：中文可以，但 2 字查询失效（不采用）', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute("PRAGMA key = 'k';");

    db.execute(
      "CREATE VIRTUAL TABLE tri_fts USING fts5(title, tokenize='trigram');",
    );
    db.execute("INSERT INTO tri_fts(title) VALUES ('WebDAV 增量同步');");

    int hits(String query) =>
        db.select('SELECT * FROM tri_fts WHERE tri_fts MATCH ?;', <Object?>[query]).length;

    expect(hits('增量同'), 1, reason: '3 字以上可用');
    // trigram 要求子串 ≥ 3 个字符，"同步"只有 2 个 → 搜不到。
    // 中文里 2 字词占绝大多数，所以 trigram 不能单独用。
    expect(hits('同步'), 0);
  });

  test('加密库的 WAL 与常规操作正常', () {
    final path = probePath('wal_probe');
    final db = sqlite3.open(path);
    addTearDown(db.close);

    db.execute("PRAGMA key = 'k';");
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT);');
    for (var i = 0; i < 200; i++) {
      db.execute("INSERT INTO t(v) VALUES ('row $i');");
    }
    expect(db.select('SELECT count(*) c FROM t').first['c'], 200);
  });
}

/// 索引/查询共用的切分函数原型：汉字两侧加空格，其余原样。
///
/// 生产实现会放到 `lib/data/search/cjk_segmenter.dart`，并加上
/// 标点归一化、全半角折叠、英文小写化。
String _segment(String input) => input
    .replaceAllMapped(
      RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf]'),
      (Match m) => ' ${m[0]} ',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
