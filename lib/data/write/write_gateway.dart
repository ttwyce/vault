// 私有字段 + 同义具名参数：不想为了消除这条 lint 把 `keys` 暴露成公开字段。
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/crypto/secret_bytes.dart';
import '../../core/crypto/vault_keys.dart';
import '../../core/identity/uuid_v7.dart';
import '../../core/sync/hlc.dart';
import '../db/tables/entry_tables.dart';
import '../db/tables/log_tables.dart';
import '../db/vault_database.dart';
import '../search/cjk_segmenter.dart';
import 'entry_snapshot.dart';
import 'item_envelope.dart';

/// 写操作被拒绝。
///
/// 刻意区分 [code]：UI 需要根据它决定是弹错误、还是静默忽略、
/// 还是引导用户去回收站恢复。把三种情况都塞进一个 message 里，
/// 调用方就只能靠字符串匹配，那是维护灾难。
class WriteException implements Exception {
  const WriteException(this.code, this.message);

  /// `not_found` / `already_deleted` / `not_deleted` / `exists` / `invalid`
  final String code;

  final String message;

  @override
  String toString() => 'WriteException($code): $message';
}

/// 一次写入的意图。
enum EntryMutation {
  create,
  update,
  delete,
  restore,
}

/// 描述"要写什么"。
///
/// **`update` 是整体替换，不是部分更新**：`title` / `body` / `meta` 传 null
/// 表示"清空该字段"，不是"保持不变"。要部分更新的话，调用方先读快照再改。
///
/// 为什么不做 `Value<T>` 式的三态补丁：编辑器本来就是整体提交的，
/// 而三态补丁会让每个调用点都要想"我传 null 到底是清空还是不动"。
/// 这个歧义在密码类字段上会直接导致数据丢失。
class EntryWrite {
  const EntryWrite._({
    this.id,
    required this.mutation,
    this.kind = 1,
    this.title,
    this.body,
    this.meta,
  });

  factory EntryWrite.create({
    String? id,
    EntryKind kind = EntryKind.note,
    String? title,
    String? body,
    String? meta,
  }) {
    return EntryWrite._(
      id: id,
      mutation: EntryMutation.create,
      kind: kind.code,
      title: title,
      body: body,
      meta: meta,
    );
  }

  factory EntryWrite.update({
    required String id,
    String? title,
    String? body,
    String? meta,
  }) {
    return EntryWrite._(
      id: id,
      mutation: EntryMutation.update,
      title: title,
      body: body,
      meta: meta,
    );
  }

  factory EntryWrite.delete({required String id}) =>
      EntryWrite._(id: id, mutation: EntryMutation.delete);

  factory EntryWrite.restore({required String id}) =>
      EntryWrite._(id: id, mutation: EntryMutation.restore);

  final String? id;
  final EntryMutation mutation;
  final int kind;
  final String? title;
  final String? body;
  final String? meta;
}

/// 一次写入的结果。
class EntryWriteResult {
  const EntryWriteResult({
    required this.snapshot,
    required this.oplogSeq,
    required this.changed,
  });

  final EntrySnapshot snapshot;

  /// 本次写入产生的 oplog 序号。`changed=false` 时为 -1。
  final int oplogSeq;

  /// 是否真的产生了变更。
  ///
  /// `false` 表示这次调用是**幂等空操作**（例如删一条已经删掉的条目）。
  /// 空操作**不写 oplog** —— 否则一次误触就会把一条无意义的变更
  /// 推送到所有设备，制造出根本不存在的新版本。
  final bool changed;
}

/// 全项目**唯一的写入入口**。
///
/// ## 它存在的唯一理由：让"实体变更"和"变更日志"不可能分开
///
/// 同步引擎依赖 oplog 重放来保证零丢失。如果某个调用点直接
/// `db.into(entries).insert(...)` 而不写 oplog，那条变更就永远不会被推送 ——
/// 用户会看到"这条笔记在 A 设备上有，B 设备上没有"，而且**没有任何报错**。
///
/// 所以这里把两件事关进同一个事务：
///
/// ```
/// 一次写入 =
///   ① 读旧状态（算 rev / base）
///   ② 旧状态归档进 entry_history（三方合并的 base）
///   ③ 新状态封进 ItemEnvelope（加密）
///   ④ 写 oplog（outbox）
///   ⑤ 改 entry
///   ⑥ 更新 FTS 索引
///   ⑦ 持久化 HLC
///   —— 全部在同一个事务里，要么全成，要么全败
/// ```
///
/// ## 为什么不给每个实体类型写一个 Gateway
///
/// `category` / `tag` / `credential` 的写入逻辑确实是同一套骨架
/// （读旧 → 归档 → 封装 → oplog → 改实体 → 索引）。
/// 等它们真正开始写的时候，把这套骨架抽成 `_commit()` 泛型即可，
/// 而不是现在就为三种还不存在的写入路径写三份空实现。
class WriteGateway {
  WriteGateway({
    required VaultDatabase db,
    required VaultKeys keys,
    required HlcClock clock,
    required this.deviceId,
    int Function()? now,
    String Function(String)? segmenter,
    UuidV7? uuid,
  })  : _db = db,
        _keys = keys,
        _clock = clock,
        _now = now ?? _defaultNow,
        _segmenter = segmenter ?? CjkSegmenter.indexText,
        _uuid = uuid ?? UuidV7();

  /// 历史版本保留条数。超过的由写入路径顺手清掉。
  static const int historyDepth = 5;

  /// 回收站保留天数。
  static const int trashRetentionDays = 30;

  final VaultDatabase _db;
  final VaultKeys _keys;
  final HlcClock _clock;
  final int Function() _now;
  final String Function(String) _segmenter;
  final UuidV7 _uuid;

  /// 设备标识。写进每条 oplog，也用于 HLC 的 node 部分。
  final String deviceId;

  static int _defaultNow() => DateTime.now().millisecondsSinceEpoch;

  // ---------------------------------------------------------------------------
  // 写
  // ---------------------------------------------------------------------------

  /// 写一条条目。create / update / delete / restore 都走这里。
  Future<EntryWriteResult> writeEntry(EntryWrite write) async {
    // meta 必须是合法 JSON —— 在事务外校验，避免白开一次事务。
    // 这个校验放在写入口而不是读出口，因为"写进一个坏 meta"是不可逆的，
    // 而读出来时才发现就只能报错给用户，救不回来。
    if (write.meta != null && write.meta!.trim().isNotEmpty) {
      EntrySnapshot.computeContentHash(kind: write.kind, meta: write.meta);
    }

    final key = await _keys.item();
    return _db.transaction(() async {
      final existing = await _loadEntry(write.id);

      switch (write.mutation) {
        case EntryMutation.create:
          return _create(write, existing, key);
        case EntryMutation.update:
          return _update(write, existing, key);
        case EntryMutation.delete:
          return _delete(write, existing, key);
        case EntryMutation.restore:
          return _restore(write, existing, key);
      }
    });
  }

  Future<EntryWriteResult> _create(
    EntryWrite write,
    EntryRow? existing,
    SecretBytes key,
  ) async {
    if (existing != null) {
      throw WriteException(
        'exists',
        '条目 ${existing.id} 已存在，不能重复创建。'
        '要修改请用 update，要恢复请用 restore。',
      );
    }

    final id = write.id ?? _uuid.next();
    if (write.id != null && existing == null) {
      // 允许调用方指定 id（导入、迁移时用），但要挡住格式错误的主键
      if (write.id!.isEmpty) {
        throw const WriteException('invalid', 'id 不能为空');
      }
    }

    final hlc = _clock.tick();
    final snapshot = EntrySnapshot(
      id: id,
      kind: write.kind,
      title: write.title,
      body: write.body,
      meta: write.meta,
      createdAt: hlc.millis,
      updatedAt: hlc.millis,
      hlc: hlc.encode(),
      rev: 1,
      contentHash: EntrySnapshot.computeContentHash(
        kind: write.kind,
        title: write.title,
        body: write.body,
        meta: write.meta,
      ),
    );

    return _commit(
      snapshot: snapshot,
      op: OplogOp.create,
      baseRev: null,
      key: key,
    );
  }

  Future<EntryWriteResult> _update(
    EntryWrite write,
    EntryRow? existing,
    SecretBytes key,
  ) async {
    if (existing == null) {
      throw WriteException('not_found', '条目 ${write.id} 不存在，无法更新');
    }
    if (existing.deleted != 0) {
      // 不自动复活：复活是 restore 的语义，混在一起会让"删除"
      // 在同步合并时变得无法判断用户意图。
      throw WriteException(
        'already_deleted',
        '条目 ${existing.id} 在回收站里，请先恢复再编辑',
      );
    }

    final previous = EntrySnapshot.fromRow(existing);
    final hlc = _clock.tick();
    final snapshot = previous.copyWith(
      title: write.title,
      body: write.body,
      meta: write.meta,
      updatedAt: hlc.millis,
      hlc: hlc.encode(),
      rev: previous.rev + 1,
      contentHash: EntrySnapshot.computeContentHash(
        kind: previous.kind,
        title: write.title,
        body: write.body,
        meta: write.meta,
      ),
    );

    // 内容没变就不产生新版本。
    //
    // 这条很重要：编辑器保存按钮、自动保存、切换焦点都可能触发一次
    // "内容相同的写入"。每次都 +1 rev 的话，同步会在设备之间来回推送
    // 一堆内容一样的版本，冲突副本也会被这些空变更刷屏。
    if (snapshot.contentHash == previous.contentHash) {
      return EntryWriteResult(snapshot: previous, oplogSeq: -1, changed: false);
    }

    return _commit(
      snapshot: snapshot,
      op: OplogOp.update,
      baseRev: previous.rev,
      key: key,
      previous: previous,
    );
  }

  Future<EntryWriteResult> _delete(
    EntryWrite write,
    EntryRow? existing,
    SecretBytes key,
  ) async {
    if (existing == null) {
      throw WriteException('not_found', '条目 ${write.id} 不存在，无法删除');
    }
    if (existing.deleted != 0) {
      // 幂等：重复删除是空操作，不写 oplog
      return EntryWriteResult(
        snapshot: EntrySnapshot.fromRow(existing),
        oplogSeq: -1,
        changed: false,
      );
    }

    final previous = EntrySnapshot.fromRow(existing);
    final hlc = _clock.tick();
    final snapshot = previous.copyWith(
      updatedAt: hlc.millis,
      hlc: hlc.encode(),
      rev: previous.rev + 1,
      deleted: true,
      deletedAt: hlc.millis,
    );

    return _commit(
      snapshot: snapshot,
      op: OplogOp.delete,
      baseRev: previous.rev,
      key: key,
      previous: previous,
      toTrash: true,
    );
  }

  Future<EntryWriteResult> _restore(
    EntryWrite write,
    EntryRow? existing,
    SecretBytes key,
  ) async {
    if (existing == null) {
      throw WriteException('not_found', '条目 ${write.id} 不存在，无法恢复');
    }
    if (existing.deleted == 0) {
      return EntryWriteResult(
        snapshot: EntrySnapshot.fromRow(existing),
        oplogSeq: -1,
        changed: false,
      );
    }

    final previous = EntrySnapshot.fromRow(existing);
    final hlc = _clock.tick();
    final snapshot = previous.copyWith(
      updatedAt: hlc.millis,
      hlc: hlc.encode(),
      rev: previous.rev + 1,
      deleted: false,
      clearDeletedAt: true,
    );

    return _commit(
      snapshot: snapshot,
      op: OplogOp.restore,
      baseRev: previous.rev,
      key: key,
      previous: previous,
      fromTrash: true,
    );
  }

  /// 所有写路径的共同后半段。**必须只在事务内调用**。
  Future<EntryWriteResult> _commit({
    required EntrySnapshot snapshot,
    required OplogOp op,
    required int? baseRev,
    required SecretBytes key,
    EntrySnapshot? previous,
    bool toTrash = false,
    bool fromTrash = false,
  }) async {
    // ② 旧状态进历史（三方合并的 base）
    if (previous != null) {
      await _archiveHistory(previous, key);
    }

    // ③ 新状态加密
    final envelope = await ItemEnvelope.seal(
      key: key,
      entity: SyncEntity.entry,
      entityId: snapshot.id,
      rev: snapshot.rev,
      plaintext: snapshot.toCanonicalBytes(),
    );

    // ④ 写 oplog（outbox）
    final row = await _db.into(_db.oplogs).insertReturning(
          OplogsCompanion.insert(
            hlc: snapshot.hlc,
            deviceId: deviceId,
            entity: SyncEntity.entry,
            entityId: snapshot.id,
            op: op.code,
            payload: Value<Uint8List>(envelope.encode()),
            baseRev: Value<int?>(baseRev),
            createdAt: snapshot.updatedAt,
          ),
        );

    // ⑤ 改实体
    await _db.into(_db.entries).insertOnConflictUpdate(snapshot.toCompanion());

    // ⑥ 索引
    if (snapshot.deleted) {
      await _db.removeSearchDocument(snapshot.id);
    } else {
      await _db.putSearchDocument(
        entryId: snapshot.id,
        title: _segmenter(snapshot.title ?? ''),
        body: _segmenter(snapshot.body ?? ''),
        tags: _segmenter(await _tagText(snapshot.id)),
      );
    }

    // ⑦ 回收站
    if (toTrash) {
      await _db.into(_db.trashRows).insertOnConflictUpdate(
            TrashRowsCompanion.insert(
              entryId: snapshot.id,
              payload: envelope.encode(),
              deletedAt: snapshot.deletedAt ?? snapshot.updatedAt,
              expireAt: (snapshot.deletedAt ?? snapshot.updatedAt) +
                  Duration(days: trashRetentionDays).inMilliseconds,
            ),
          );
    }
    if (fromTrash) {
      await (_db.delete(_db.trashRows)..where((t) => t.entryId.equals(snapshot.id))).go();
    }

    // ⑧ HLC 持久化。放在同一事务里，否则崩溃后重启可能生成
    // 比历史更小的时钟值，合并时会被误判成旧版本。
    await _persistClock();

    return EntryWriteResult(snapshot: snapshot, oplogSeq: row.seq, changed: true);
  }

  Future<EntryRow?> _loadEntry(String? id) async {
    if (id == null) return null;
    return (_db.select(_db.entries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 归档旧版本并裁剪到 [historyDepth] 条。
  Future<void> _archiveHistory(EntrySnapshot previous, SecretBytes key) async {
    final envelope = await ItemEnvelope.seal(
      key: key,
      entity: SyncEntity.entry,
      entityId: previous.id,
      rev: previous.rev,
      plaintext: previous.toCanonicalBytes(),
    );

    await _db.into(_db.entryHistory).insertOnConflictUpdate(
          EntryHistoryCompanion.insert(
            entryId: previous.id,
            rev: previous.rev,
            payload: envelope.encode(),
            hlc: previous.hlc,
            createdAt: previous.updatedAt,
          ),
        );

    await _db.customStatement(
      'DELETE FROM entry_history WHERE entry_id = ? AND rev NOT IN ('
      '  SELECT rev FROM entry_history WHERE entry_id = ? '
      '  ORDER BY rev DESC LIMIT ?'
      ');',
      <Object?>[previous.id, previous.id, historyDepth],
    );
  }

  /// 取条目的标签名拼成一段文本，供全文索引。
  ///
  /// 标签是独立实体（`tag` 表 + `entry_tag` 关联），所以这里要 join。
  /// 现在还没有设置标签的入口，但索引侧先接上 —— 等标签功能上线时，
  /// 搜索会自动生效，不用再回来改这里。
  Future<String> _tagText(String entryId) async {
    final rows = await _db.customSelect(
      'SELECT t.name AS name FROM tag t '
      'INNER JOIN entry_tag et ON et.tag_id = t.id '
      'WHERE et.entry_id = ? ORDER BY t.name;',
      variables: <Variable<Object>>[Variable<String>(entryId)],
    ).get();
    return rows
        .map((QueryRow row) => row.read<String?>('name') ?? '')
        .where((String name) => name.isNotEmpty)
        .join(' ');
  }

  Future<void> _persistClock() async {
    final last = _clock.last;
    if (last == null) return;
    await _db.into(_db.deviceWatermarks).insertOnConflictUpdate(
          DeviceWatermarksCompanion.insert(
            deviceId: deviceId,
            maxHlc: Value<String?>(last.encode()),
            lastSeen: Value<int?>(_now()),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 读（outbox 与回放）
  // ---------------------------------------------------------------------------

  /// 待推送的 oplog，按 seq 升序。
  ///
  /// 按 seq 而不是 hlc 排序：seq 是本地插入顺序，代表**用户操作顺序**。
  /// 同一毫秒内的两次操作 hlc 可能相同，但 seq 一定不同。
  Future<List<OplogRow>> pending({int limit = 500}) {
    return (_db.select(_db.oplogs)
          ..where((t) => t.applied.equals(0))
          ..orderBy(<OrderClauseGenerator<dynamic>>[(t) => OrderingTerm.asc(t.seq)])
          ..limit(limit))
        .get();
  }

  Future<int> pendingCount() async {
    final rows = await _db
        .customSelect('SELECT count(*) AS c FROM oplog WHERE applied = 0;')
        .getSingle();
    return rows.read<int>('c');
  }

  /// 标记已推送。**不删除记录** —— oplog 是审计链与回滚依据。
  Future<void> markApplied(Iterable<int> seqs) async {
    final list = seqs.toList(growable: false);
    if (list.isEmpty) return;
    await _db.transaction(() async {
      for (final seq in list) {
        await (_db.update(_db.oplogs)..where((t) => t.seq.equals(seq)))
            .write(const OplogsCompanion(applied: Value<int>(1)));
      }
    });
  }

  /// 解开一条 oplog 的 payload。
  ///
  /// 会校验信封头与快照内容是否自洽 —— 这是防"密文搬运"的最后一道：
  /// 即使有人把 B 条目的 payload 塞进 A 条目的 oplog 行，
  /// 解出来的 `id` 与行上的 `entityId` 对不上，直接报错。
  Future<EntrySnapshot> readSnapshot(OplogRow row) async {
    final key = await _keys.item();
    final envelope = ItemEnvelope.parse(row.payload!);

    if (envelope.entity != row.entity) {
      throw StateError(
        'oplog #${row.seq} 的信封实体是 ${envelope.entity}，'
        '行上记的是 ${row.entity} —— 数据被篡改或存在实现 bug',
      );
    }
    if (envelope.entityId != row.entityId) {
      throw StateError(
        'oplog #${row.seq} 的信封 id 是 ${envelope.entityId}，'
        '行上记的是 ${row.entityId} —— 数据被篡改或存在实现 bug',
      );
    }

    final plaintext = await envelope.open(key: key);
    final snapshot = EntrySnapshot.fromJson(
      _decodeJson(plaintext),
    );
    if (snapshot.id != row.entityId || snapshot.rev != envelope.rev) {
      throw StateError('oplog #${row.seq} 的快照与信封不一致');
    }
    return snapshot;
  }

  /// 某条实体的最新快照（从 oplog 里读，不读 entry 表）。
  ///
  /// 用于冲突合并时构造 `local` 一侧 —— 走 oplog 而不是 entry 表，
  /// 是为了拿到**与云端可比的那一份**（包含 rev 与 hlc）。
  Future<EntrySnapshot?> latestSnapshot(String entityId) async {
    final row = await (_db.select(_db.oplogs)
          ..where((t) => t.entity.equals(SyncEntity.entry) & t.entityId.equals(entityId))
          ..orderBy(<OrderClauseGenerator<dynamic>>[(t) => OrderingTerm.desc(t.seq)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null || row.payload == null) return null;
    return readSnapshot(row);
  }

  static Map<String, Object?> _decodeJson(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('条目快照顶层不是对象');
    }
    return decoded;
  }
}
