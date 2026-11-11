// 私有字段 + 同义具名参数：不想为了消除这条 lint 把 `keys` 暴露成公开字段。
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/crypto/secret_bytes.dart';
import '../../core/crypto/vault_keys.dart';
import '../../core/identity/uuid_v7.dart';
import '../../core/sync/hlc.dart';
import '../../core/sync/sync_engine.dart';
import '../db/tables/entry_tables.dart';
import '../db/tables/log_tables.dart';
import '../db/vault_database.dart';
import '../search/cjk_segmenter.dart';
import '../taxonomy/taxonomy_models.dart';
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

/// 一次非 entry 实体推送成功后要落库的进度。
class SyncedOplogPush {
  const SyncedOplogPush({
    required this.oplogSeq,
    required this.path,
    required this.etag,
  });

  final int oplogSeq;
  final String path;
  final String etag;
}

/// 隔离区里的一条坏文件记录。
class SyncQuarantineRecord {
  const SyncQuarantineRecord({
    required this.path,
    required this.bytes,
    required this.reason,
    required this.createdAt,
  });

  final String path;
  final Uint8List bytes;
  final String reason;
  final int createdAt;
}

/// 一个已解密、等待应用落库的远端 taxonomy 信封。
class RemoteTaxonomyFile {
  const RemoteTaxonomyFile({
    required this.path,
    required this.etag,
    required this.snapshot,
  });

  final String path;
  final String etag;
  final TaxonomySnapshot snapshot;
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
    bool applied = false,
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
            applied: Value<int>(applied ? 1 : 0),
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

  // ---------------------------------------------------------------------------
  // taxonomy 写入（category / tag / entry_taxonomy）
  // ---------------------------------------------------------------------------
  //
  // 这三类写入和 entry 共享**同一个事务骨架**：读旧 → 加密快照 → 写 oplog
  // → 改实体 → 更新索引 → 持久化 HLC。它们没有另起一个 Gateway，因为
  // 「唯一写入口」不是文件名层面的规矩，而是「实体变更与 oplog 不可能分开」
  // 这件事本身。拆成第二个类，就等于给了后来者一个绕过 oplog 的入口。
  //
  // 与 entry 的差别：category / tag 表没有 rev 列，版本号从该实体
  // 最近一条 oplog 里读出来再 +1（见 [_nextRev]）。这样即使本地库被
  // 重建过，rev 也不会倒退。

  /// 写一条分类。create / update / delete / restore 都走这里。
  Future<TaxonomyWriteResult> writeCategory(CategoryWrite write) {
    return _db.transaction(() async {
      final key = await _keys.item();
      return switch (write.mutation) {
        TaxonomyMutation.create => _createCategory(write, key),
        TaxonomyMutation.update => _updateCategory(write, key),
        TaxonomyMutation.delete => _deleteCategory(write, key),
        TaxonomyMutation.restore => _restoreCategory(write, key),
        TaxonomyMutation.merge => throw const WriteException(
            'invalid', '分类不支持合并，请用 update 改名'),
      };
    });
  }

  /// 写一条标签。merge 用于同名合并向导。
  Future<TaxonomyWriteResult> writeTag(TagWrite write) {
    return _db.transaction(() async {
      final key = await _keys.item();
      return switch (write.mutation) {
        TaxonomyMutation.create => _createTag(write, key),
        TaxonomyMutation.update => _renameTag(write, key),
        TaxonomyMutation.delete => _deleteTag(write, key),
        TaxonomyMutation.restore => _restoreTag(write, key),
        TaxonomyMutation.merge => _mergeTags(write, key),
      };
    });
  }

  /// 设置一条条目的分类与标签。**整体替换**：[categoryId] 为 null 表示
  /// 「未分类」，[tagIds] 为空表示清空全部标签。
  ///
  /// 标签参与全文索引（`entry_fts.tags`），所以改关联后必须重建该条目的
  /// 检索文档 —— 否则「打了标签却搜不到」，而且这个 bug 不报错。
  Future<TaxonomyWriteResult> setEntryTaxonomy({
    required String entryId,
    String? categoryId,
    List<String> tagIds = const <String>[],
  }) {
    return _db.transaction(() async {
      final key = await _keys.item();
      final entry = await _loadEntry(entryId);
      if (entry == null) {
        throw WriteException('not_found', '条目 $entryId 不存在，无法设置分类标签');
      }
      if (entry.deleted != 0) {
        throw const WriteException(
            'already_deleted', '条目在回收站里，请先恢复再整理');
      }
      if (tagIds.length > TaxonomyRules.maxTagsPerEntry) {
        throw WriteException(
          'invalid',
          '一条内容最多 ${TaxonomyRules.maxTagsPerEntry} 个标签'
          '（收到 ${tagIds.length} 个）',
        );
      }
      final nextTagIds = tagIds.toSet().toList(growable: false);
      for (final id in nextTagIds) {
        final row = await _tagRow(id);
        if (row == null || row.deleted != 0) {
          throw WriteException('not_found', '标签 $id 不存在或已删除');
        }
      }
      if (categoryId != null) {
        final row = await _categoryRow(categoryId);
        if (row == null || row.deleted != 0) {
          throw WriteException('not_found', '分类 $categoryId 不存在或已删除');
        }
      }

      final oldTagRows = await (_db.select(_db.entryTags)
            ..where((t) => t.entryId.equals(entryId)))
          .get();
      final oldTagIds = <String>{for (final r in oldTagRows) r.tagId};
      final oldCatRows = await (_db.select(_db.entryCategories)
            ..where((t) => t.entryId.equals(entryId)))
          .get();
      final oldCategoryId =
          oldCatRows.isEmpty ? null : oldCatRows.first.categoryId;

      final unchanged = oldCategoryId == categoryId &&
          oldTagIds.length == nextTagIds.length &&
          oldTagIds.containsAll(nextTagIds);
      if (unchanged) {
        final prev = await _latestTaxonomy(SyncEntity.entryTaxonomy, entryId);
        return TaxonomyWriteResult(
          snapshot: prev ?? TaxonomySnapshot(
            entity: SyncEntity.entryTaxonomy,
            id: entryId,
            rev: 0,
            hlc: '',
            updatedAt: _now(),
            deleted: false,
            fields: <String, Object?>{
              'category_id': categoryId,
              'tag_ids': nextTagIds,
            },
          ),
          oplogSeq: -1,
          changed: false,
        );
      }

      final hlc = _clock.tick();
      final rev = await _nextRev(SyncEntity.entryTaxonomy, entryId);
      final snapshot = TaxonomySnapshot(
        entity: SyncEntity.entryTaxonomy,
        id: entryId,
        rev: rev,
        hlc: hlc.encode(),
        updatedAt: hlc.millis,
        deleted: false,
        fields: <String, Object?>{
          'category_id': categoryId,
          'tag_ids': nextTagIds,
        },
      );

      return _commitTaxonomy(
        snapshot: snapshot,
        op: OplogOp.update,
        key: key,
        apply: () async {
          await (_db.delete(_db.entryCategories)
                ..where((t) => t.entryId.equals(entryId)))
              .go();
          if (categoryId != null) {
            await _db.into(_db.entryCategories).insert(
                  EntryCategoriesCompanion.insert(
                    entryId: entryId,
                    categoryId: categoryId,
                  ),
                );
          }
          await (_db.delete(_db.entryTags)
                ..where((t) => t.entryId.equals(entryId)))
              .go();
          for (final id in nextTagIds) {
            await _db.into(_db.entryTags).insert(
                  EntryTagsCompanion.insert(entryId: entryId, tagId: id),
                );
          }
          await _recountTags(<String>{...oldTagIds, ...nextTagIds});
          await _recountCategories(<String>{
            ?oldCategoryId,
            ?categoryId,
          });
          await _rebuildEntrySearch(entryId);
        },
      );
    });
  }

  /// 把条目的某个历史版本重新写回当前内容。
  ///
  /// **不是把 rev 倒回去**：回滚也是一次新的编辑，rev 必须继续递增，
  /// 否则另一台设备会用「rev 更大」判定我们这条是旧数据，直接覆盖掉。
  /// 回滚的内容来自 `entry_history` 里加密的旧快照。
  Future<EntryWriteResult> restoreVersion({
    required String entryId,
    required int rev,
  }) async {
    final row = await (_db.select(_db.entryHistory)
          ..where((t) => t.entryId.equals(entryId) & t.rev.equals(rev)))
        .getSingleOrNull();
    if (row == null) {
      throw WriteException('not_found', '版本 r$rev 不存在，可能已被清理');
    }
    final snapshot = await readEntryPayload(row.payload, expectedId: entryId);
    return writeEntry(EntryWrite.update(
      id: entryId,
      title: snapshot.title,
      body: snapshot.body,
      meta: snapshot.meta,
    ));
  }

  /// 解开一条历史 / 回收站里的条目信封（与 oplog payload 同源）。
  Future<EntrySnapshot> readEntryPayload(
    Uint8List payload, {
    required String expectedId,
  }) async {
    final key = await _keys.item();
    final envelope = ItemEnvelope.parse(payload);
    if (envelope.entity != SyncEntity.entry) {
      throw StateError('信封实体是 ${envelope.entity}，不是 entry');
    }
    if (envelope.entityId != expectedId) {
      throw StateError('信封 id 是 ${envelope.entityId}，期望 $expectedId');
    }
    final snapshot = EntrySnapshot.fromJson(
      _decodeJson(await envelope.open(key: key)),
    );
    if (snapshot.id != expectedId || snapshot.rev != envelope.rev) {
      throw StateError('条目快照与信封不一致');
    }
    return snapshot;
  }

  /// 解开一条 taxonomy oplog 的 payload。校验信封头与行元数据交叉一致。
  Future<TaxonomySnapshot> readTaxonomySnapshot(OplogRow row) async {
    final key = await _keys.item();
    final envelope = ItemEnvelope.parse(row.payload!);
    if (envelope.entity != row.entity || envelope.entityId != row.entityId) {
      throw StateError('oplog #${row.seq} 的信封头与行元数据不一致');
    }
    final decoded = jsonDecode(utf8.decode(await envelope.open(key: key)));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('taxonomy 快照顶层不是对象');
    }
    final snapshot = TaxonomySnapshot.fromJson(decoded);
    if (snapshot.id != row.entityId || snapshot.rev != envelope.rev) {
      throw StateError('oplog #${row.seq} 的 taxonomy 快照与信封不一致');
    }
    return snapshot;
  }

  // ---------------------------------------------------------------------------
  // category
  // ---------------------------------------------------------------------------

  Future<TaxonomyWriteResult> _createCategory(
    CategoryWrite write,
    SecretBytes key,
  ) async {
    final name = _validName(write.name);
    final id = write.id ?? _uuid.next();
    if (await _categoryRow(id) != null) {
      throw WriteException('exists', '分类 $id 已存在');
    }
    final parentId = write.parentId;
    if (parentId != null) {
      final parent = await _categoryRow(parentId);
      if (parent == null || parent.deleted != 0) {
        throw WriteException('not_found', '父分类 $parentId 不存在或已删除');
      }
      // 两级封顶：父分类自己不能已经是二级
      if (parent.parentId != null) {
        throw const WriteException(
            'invalid', '分类最多两级，不能再给二级分类建子分类');
      }
    }
    if (await _siblingNameExists(name, parentId, excludeId: null)) {
      throw WriteException('exists', '同级已有名为「$name」的分类');
    }

    final hlc = _clock.tick();
    final snapshot = TaxonomySnapshot(
      entity: SyncEntity.category,
      id: id,
      rev: 1,
      hlc: hlc.encode(),
      updatedAt: hlc.millis,
      deleted: false,
      fields: <String, Object?>{
        'name': name,
        'kind': write.kind ?? EntryKind.note.code,
        'parent_id': parentId,
        'sort_order': write.sortOrder ?? 0,
      },
    );

    return _commitTaxonomy(
      snapshot: snapshot,
      op: OplogOp.create,
      key: key,
      apply: () async {
        await _db.into(_db.categories).insert(CategoriesCompanion(
              id: Value<String>(id),
              kind: Value<int>(write.kind ?? EntryKind.note.code),
              parentId: Value<String?>(parentId),
              name: Value<String>(name),
              sortOrder: Value<int>(write.sortOrder ?? 0),
              entryCount: const Value<int>(0),
              createdAt: Value<int?>(hlc.millis),
              updatedAt: Value<int?>(hlc.millis),
              hlc: Value<String>(hlc.encode()),
              deleted: const Value<int>(0),
            ));
      },
    );
  }

  Future<TaxonomyWriteResult> _updateCategory(
    CategoryWrite write,
    SecretBytes key,
  ) async {
    final id = write.id!;
    final row = await _categoryRow(id);
    if (row == null) throw WriteException('not_found', '分类 $id 不存在');
    if (row.deleted != 0) {
      throw const WriteException('already_deleted', '分类已删除，请先恢复');
    }
    final name = _validName(write.name);
    final parentId = write.parentId;
    if (parentId == id) {
      throw const WriteException('invalid', '分类不能做自己的父分类');
    }
    if (parentId != null) {
      final parent = await _categoryRow(parentId);
      if (parent == null || parent.deleted != 0) {
        throw WriteException('not_found', '父分类 $parentId 不存在或已删除');
      }
      if (parent.parentId != null) {
        throw const WriteException('invalid', '分类最多两级');
      }
      // 自己已有子分类时不能变成二级（否则会造出第三级）
      final children = await (_db.select(_db.categories)
            ..where((t) => t.parentId.equals(id) & t.deleted.equals(0)))
          .get();
      if (children.isNotEmpty) {
        throw const WriteException(
            'invalid', '这个分类下还有子分类，不能把它变成二级分类');
      }
    }
    if (await _siblingNameExists(name, parentId, excludeId: id)) {
      throw WriteException('exists', '同级已有名为「$name」的分类');
    }

    final hlc = _clock.tick();
    final snapshot = TaxonomySnapshot(
      entity: SyncEntity.category,
      id: id,
      rev: await _nextRev(SyncEntity.category, id),
      hlc: hlc.encode(),
      updatedAt: hlc.millis,
      deleted: false,
      fields: <String, Object?>{
        'name': name,
        'kind': row.kind,
        'parent_id': parentId,
        'sort_order': write.sortOrder ?? 0,
      },
    );

    return _commitTaxonomy(
      snapshot: snapshot,
      op: OplogOp.update,
      key: key,
      apply: () async {
        await (_db.update(_db.categories)..where((t) => t.id.equals(id)))
            .write(CategoriesCompanion(
          name: Value<String>(name),
          parentId: Value<String?>(parentId),
          sortOrder: Value<int>(write.sortOrder ?? 0),
          hlc: Value<String>(hlc.encode()),
          updatedAt: Value<int?>(hlc.millis),
        ));
      },
    );
  }

  Future<TaxonomyWriteResult> _deleteCategory(
    CategoryWrite write,
    SecretBytes key,
  ) async {
    final id = write.id!;
    final row = await _categoryRow(id);
    if (row == null) throw WriteException('not_found', '分类 $id 不存在');
    if (row.deleted != 0) {
      return _noopTaxonomy(SyncEntity.category, id);
    }

    // 删除分类不删条目：清掉 entry_category 关联，条目回到「未分类」。
    // 子分类提升为一级并各自写 oplog —— 否则会留下一批 parent_id 指向
    // 已删除分类的孤儿，两级树重建时它们会神秘消失。
    final children = await (_db.select(_db.categories)
          ..where((t) => t.parentId.equals(id) & t.deleted.equals(0)))
        .get();
    final related = <int>[];
    for (final child in children) {
      final childHlc = _clock.tick();
      final childSnapshot = TaxonomySnapshot(
        entity: SyncEntity.category,
        id: child.id,
        rev: await _nextRev(SyncEntity.category, child.id),
        hlc: childHlc.encode(),
        updatedAt: childHlc.millis,
        deleted: false,
        fields: <String, Object?>{
          'name': child.name,
          'kind': child.kind,
          'parent_id': null,
          'sort_order': child.sortOrder,
        },
      );
      final r = await _commitTaxonomy(
        snapshot: childSnapshot,
        op: OplogOp.update,
        key: key,
        apply: () async {
          await (_db.update(_db.categories)
                ..where((t) => t.id.equals(child.id)))
              .write(CategoriesCompanion(
            parentId: const Value<String?>(null),
            hlc: Value<String>(childHlc.encode()),
            updatedAt: Value<int?>(childHlc.millis),
          ));
        },
      );
      related.add(r.oplogSeq);
    }

    final hlc = _clock.tick();
    final snapshot = TaxonomySnapshot(
      entity: SyncEntity.category,
      id: id,
      rev: await _nextRev(SyncEntity.category, id),
      hlc: hlc.encode(),
      updatedAt: hlc.millis,
      deleted: true,
      fields: <String, Object?>{
        'name': row.name,
        'kind': row.kind,
        'parent_id': row.parentId,
        'sort_order': row.sortOrder,
      },
    );
    final result = await _commitTaxonomy(
      snapshot: snapshot,
      op: OplogOp.delete,
      key: key,
      apply: () async {
        await (_db.delete(_db.entryCategories)
              ..where((t) => t.categoryId.equals(id)))
            .go();
        await (_db.update(_db.categories)..where((t) => t.id.equals(id)))
            .write(CategoriesCompanion(
          deleted: const Value<int>(1),
          entryCount: const Value<int>(0),
          hlc: Value<String>(hlc.encode()),
          updatedAt: Value<int?>(hlc.millis),
        ));
      },
    );
    return TaxonomyWriteResult(
      snapshot: result.snapshot,
      oplogSeq: result.oplogSeq,
      changed: true,
      relatedOplogSeqs: related,
    );
  }

  Future<TaxonomyWriteResult> _restoreCategory(
    CategoryWrite write,
    SecretBytes key,
  ) async {
    final id = write.id!;
    final row = await _categoryRow(id);
    if (row == null) throw WriteException('not_found', '分类 $id 不存在');
    if (row.deleted == 0) return _noopTaxonomy(SyncEntity.category, id);

    final hlc = _clock.tick();
    final snapshot = TaxonomySnapshot(
      entity: SyncEntity.category,
      id: id,
      rev: await _nextRev(SyncEntity.category, id),
      hlc: hlc.encode(),
      updatedAt: hlc.millis,
      deleted: false,
      fields: <String, Object?>{
        'name': row.name,
        'kind': row.kind,
        'parent_id': row.parentId,
        'sort_order': row.sortOrder,
      },
    );
    return _commitTaxonomy(
      snapshot: snapshot,
      op: OplogOp.restore,
      key: key,
      apply: () async {
        await (_db.update(_db.categories)..where((t) => t.id.equals(id)))
            .write(CategoriesCompanion(
          deleted: const Value<int>(0),
          hlc: Value<String>(hlc.encode()),
          updatedAt: Value<int?>(hlc.millis),
        ));
      },
    );
  }

  // ---------------------------------------------------------------------------
  // tag
  // ---------------------------------------------------------------------------

  Future<TaxonomyWriteResult> _createTag(
    TagWrite write,
    SecretBytes key,
  ) async {
    final name = _validName(write.name);
    final id = write.id ?? _uuid.next();
    if (await _tagRow(id) != null) throw WriteException('exists', '标签 $id 已存在');
    if (await _tagNameExists(name, excludeId: null)) {
      throw WriteException('exists', '已有名为「$name」的标签');
    }

    final hlc = _clock.tick();
    final snapshot = TaxonomySnapshot(
      entity: SyncEntity.tag,
      id: id,
      rev: 1,
      hlc: hlc.encode(),
      updatedAt: hlc.millis,
      deleted: false,
      fields: <String, Object?>{'name': name, 'usage_count': 0},
    );
    return _commitTaxonomy(
      snapshot: snapshot,
      op: OplogOp.create,
      key: key,
      apply: () async {
        await _db.into(_db.tags).insert(TagsCompanion(
              id: Value<String>(id),
              name: Value<String>(name),
              usageCount: const Value<int>(0),
              createdAt: Value<int?>(hlc.millis),
              updatedAt: Value<int?>(hlc.millis),
              hlc: Value<String>(hlc.encode()),
              deleted: const Value<int>(0),
            ));
      },
    );
  }

  Future<TaxonomyWriteResult> _renameTag(
    TagWrite write,
    SecretBytes key,
  ) async {
    final id = write.id!;
    final row = await _tagRow(id);
    if (row == null) throw WriteException('not_found', '标签 $id 不存在');
    if (row.deleted != 0) {
      throw const WriteException('already_deleted', '标签已删除，请先恢复');
    }
    final name = _validName(write.name);
    if (await _tagNameExists(name, excludeId: id)) {
      throw WriteException('exists', '已有名为「$name」的标签');
    }

    final hlc = _clock.tick();
    final snapshot = TaxonomySnapshot(
      entity: SyncEntity.tag,
      id: id,
      rev: await _nextRev(SyncEntity.tag, id),
      hlc: hlc.encode(),
      updatedAt: hlc.millis,
      deleted: false,
      fields: <String, Object?>{'name': name, 'usage_count': row.usageCount},
    );
    return _commitTaxonomy(
      snapshot: snapshot,
      op: OplogOp.update,
      key: key,
      apply: () async {
        await (_db.update(_db.tags)..where((t) => t.id.equals(id)))
            .write(TagsCompanion(
          name: Value<String>(name),
          hlc: Value<String>(hlc.encode()),
          updatedAt: Value<int?>(hlc.millis),
        ));
        await _rebuildEntriesForTag(id);
      },
    );
  }

  Future<TaxonomyWriteResult> _deleteTag(
    TagWrite write,
    SecretBytes key,
  ) async {
    final id = write.id!;
    final row = await _tagRow(id);
    if (row == null) throw WriteException('not_found', '标签 $id 不存在');
    if (row.deleted != 0) return _noopTaxonomy(SyncEntity.tag, id);

    final affected = await _entriesForTag(id);
    final hlc = _clock.tick();
    final snapshot = TaxonomySnapshot(
      entity: SyncEntity.tag,
      id: id,
      rev: await _nextRev(SyncEntity.tag, id),
      hlc: hlc.encode(),
      updatedAt: hlc.millis,
      deleted: true,
      fields: <String, Object?>{'name': row.name, 'usage_count': row.usageCount},
    );
    return _commitTaxonomy(
      snapshot: snapshot,
      op: OplogOp.delete,
      key: key,
      apply: () async {
        await (_db.delete(_db.entryTags)..where((t) => t.tagId.equals(id))).go();
        await (_db.update(_db.tags)..where((t) => t.id.equals(id)))
            .write(TagsCompanion(
          deleted: const Value<int>(1),
          usageCount: const Value<int>(0),
          hlc: Value<String>(hlc.encode()),
          updatedAt: Value<int?>(hlc.millis),
        ));
        for (final entryId in affected) {
          await _rebuildEntrySearch(entryId);
        }
      },
    );
  }

  Future<TaxonomyWriteResult> _restoreTag(
    TagWrite write,
    SecretBytes key,
  ) async {
    final id = write.id!;
    final row = await _tagRow(id);
    if (row == null) throw WriteException('not_found', '标签 $id 不存在');
    if (row.deleted == 0) return _noopTaxonomy(SyncEntity.tag, id);

    final hlc = _clock.tick();
    final snapshot = TaxonomySnapshot(
      entity: SyncEntity.tag,
      id: id,
      rev: await _nextRev(SyncEntity.tag, id),
      hlc: hlc.encode(),
      updatedAt: hlc.millis,
      deleted: false,
      fields: <String, Object?>{'name': row.name, 'usage_count': row.usageCount},
    );
    return _commitTaxonomy(
      snapshot: snapshot,
      op: OplogOp.restore,
      key: key,
      apply: () async {
        await (_db.update(_db.tags)..where((t) => t.id.equals(id)))
            .write(TagsCompanion(
          deleted: const Value<int>(0),
          hlc: Value<String>(hlc.encode()),
          updatedAt: Value<int?>(hlc.millis),
        ));
      },
    );
  }

  /// 同名合并：source 的关联全部改指 target，然后软删 source。
  ///
  /// `INSERT OR IGNORE` 是关键：同一条条目可能同时挂着两个同名标签，
  /// 直接 UPDATE 会撞主键，丢掉整批关联。
  Future<TaxonomyWriteResult> _mergeTags(
    TagWrite write,
    SecretBytes key,
  ) async {
    final sourceId = write.sourceId!;
    final targetId = write.targetId!;
    if (sourceId == targetId) {
      throw const WriteException('invalid', '不能把标签合并到自己');
    }
    final source = await _tagRow(sourceId);
    final target = await _tagRow(targetId);
    if (source == null || target == null) {
      throw const WriteException('not_found', '待合并的标签不存在');
    }
    if (source.deleted != 0 || target.deleted != 0) {
      throw const WriteException('already_deleted', '已删除的标签不能参与合并');
    }
    if (taxonomyNameKey(source.name) != taxonomyNameKey(target.name)) {
      throw const WriteException('invalid', '只能合并同名标签');
    }

    final affected = await _entriesForTag(sourceId);
    final hlc = _clock.tick();
    final snapshot = TaxonomySnapshot(
      entity: SyncEntity.tag,
      id: sourceId,
      rev: await _nextRev(SyncEntity.tag, sourceId),
      hlc: hlc.encode(),
      updatedAt: hlc.millis,
      deleted: true,
      fields: <String, Object?>{
        'name': source.name,
        'usage_count': source.usageCount,
        'merged_into': targetId,
      },
    );

    final result = await _commitTaxonomy(
      snapshot: snapshot,
      op: OplogOp.merge,
      key: key,
      apply: () async {
        await _db.customStatement(
          'INSERT OR IGNORE INTO entry_tag(entry_id, tag_id) '
          'SELECT entry_id, ? FROM entry_tag WHERE tag_id = ?;',
          <Object?>[targetId, sourceId],
        );
        await (_db.delete(_db.entryTags)..where((t) => t.tagId.equals(sourceId)))
            .go();
        await _recountTags(<String>{sourceId, targetId});
        for (final entryId in affected) {
          await _rebuildEntrySearch(entryId);
        }
        await (_db.update(_db.tags)..where((t) => t.id.equals(sourceId)))
            .write(TagsCompanion(
          deleted: const Value<int>(1),
          usageCount: const Value<int>(0),
          hlc: Value<String>(hlc.encode()),
          updatedAt: Value<int?>(hlc.millis),
        ));
      },
    );

    // target 的 usageCount 变了，也要让另一台设备知道（否则它的标签云
    // 会一直显示旧数字，合并结果在两个设备上不一致）。
    final targetHlc = _clock.tick();
    final targetSnapshot = TaxonomySnapshot(
      entity: SyncEntity.tag,
      id: targetId,
      rev: await _nextRev(SyncEntity.tag, targetId),
      hlc: targetHlc.encode(),
      updatedAt: targetHlc.millis,
      deleted: false,
      fields: <String, Object?>{
        'name': target.name,
        'usage_count': await _tagUsage(targetId),
      },
    );
    final related = await _commitTaxonomy(
      snapshot: targetSnapshot,
      op: OplogOp.update,
      key: key,
      apply: () async => _db.customStatement(
        'UPDATE tag SET hlc = ?, updated_at = ? WHERE id = ?;',
        <Object?>[targetHlc.encode(), targetHlc.millis, targetId],
      ),
    );
    return TaxonomyWriteResult(
      snapshot: result.snapshot,
      oplogSeq: result.oplogSeq,
      changed: true,
      relatedOplogSeqs: <int>[related.oplogSeq],
    );
  }

  // ---------------------------------------------------------------------------
  // taxonomy 内部
  // ---------------------------------------------------------------------------

  /// 所有 taxonomy 写路径的共同后半段。**必须只在事务内调用**。
  Future<TaxonomyWriteResult> _commitTaxonomy({
    required TaxonomySnapshot snapshot,
    required OplogOp op,
    required SecretBytes key,
    required Future<void> Function() apply,
    bool applied = false,
  }) async {
    final envelope = await ItemEnvelope.seal(
      key: key,
      entity: snapshot.entity,
      entityId: snapshot.id,
      rev: snapshot.rev,
      plaintext: snapshot.toCanonicalBytes(),
    );
    final row = await _db.into(_db.oplogs).insertReturning(
          OplogsCompanion.insert(
            hlc: snapshot.hlc,
            deviceId: deviceId,
            entity: snapshot.entity,
            entityId: snapshot.id,
            op: op.code,
            payload: Value<Uint8List>(envelope.encode()),
            applied: Value<int>(applied ? 1 : 0),
            createdAt: snapshot.updatedAt,
          ),
        );
    await apply();
    await _persistClock();
    return TaxonomyWriteResult(
      snapshot: snapshot,
      oplogSeq: row.seq,
      changed: true,
    );
  }

  Future<TaxonomyWriteResult> _noopTaxonomy(String entity, String id) async {
    final prev = await _latestTaxonomy(entity, id);
    return TaxonomyWriteResult(
      snapshot: prev ?? TaxonomySnapshot(
        entity: entity,
        id: id,
        rev: 0,
        hlc: '',
        updatedAt: _now(),
        deleted: false,
        fields: const <String, Object?>{},
      ),
      oplogSeq: -1,
      changed: false,
    );
  }

  Future<TaxonomySnapshot?> _latestTaxonomy(String entity, String id) async {
    final row = await (_db.select(_db.oplogs)
          ..where((t) => t.entity.equals(entity) & t.entityId.equals(id))
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.desc(t.seq),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (row == null || row.payload == null) return null;
    return readTaxonomySnapshot(row);
  }

  /// 版本号只从 oplog 递增，重启 / 重建本地库都不会倒退。
  Future<int> _nextRev(String entity, String id) async {
    final last = await _latestTaxonomy(entity, id);
    return (last?.rev ?? 0) + 1;
  }

  String _validName(String? raw) {
    final name = normalizeTaxonomyName(raw ?? '');
    if (name.isEmpty) {
      throw const WriteException('invalid', '名称不能为空');
    }
    return name;
  }

  Future<CategoryRow?> _categoryRow(String id) =>
      (_db.select(_db.categories)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<TagRow?> _tagRow(String id) =>
      (_db.select(_db.tags)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<bool> _siblingNameExists(
    String name,
    String? parentId, {
    required String? excludeId,
  }) async {
    final rows = await (_db.select(_db.categories)
          ..where((t) => t.deleted.equals(0) & t.name.equals(name)))
        .get();
    final key = taxonomyNameKey(name);
    for (final row in rows) {
      if (row.id == excludeId) continue;
      if (row.parentId == parentId && taxonomyNameKey(row.name) == key) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _tagNameExists(String name, {required String? excludeId}) async {
    final rows = await (_db.select(_db.tags)
          ..where((t) => t.deleted.equals(0)))
        .get();
    final key = taxonomyNameKey(name);
    return rows.any((TagRow row) =>
        row.id != excludeId && taxonomyNameKey(row.name) == key);
  }

  Future<List<String>> _entriesForTag(String tagId) async {
    final rows = await _db.customSelect(
      'SELECT entry_id FROM entry_tag WHERE tag_id = ?;',
      variables: <Variable<Object>>[Variable<String>(tagId)],
    ).get();
    return <String>[for (final r in rows) r.read<String>('entry_id')];
  }

  Future<void> _rebuildEntriesForTag(String tagId) async {
    for (final entryId in await _entriesForTag(tagId)) {
      await _rebuildEntrySearch(entryId);
    }
  }

  /// 标签改名 / 删除 / 合并后重建该条目的 FTS 文档。
  /// 分类不进 FTS（文档 11 §5），所以这里只处理标签。
  Future<void> _rebuildEntrySearch(String entryId) async {
    final row = await _loadEntry(entryId);
    if (row == null || row.deleted != 0) {
      await _db.removeSearchDocument(entryId);
      return;
    }
    await _db.putSearchDocument(
      entryId: entryId,
      title: _segmenter(row.title ?? ''),
      body: _segmenter(row.body ?? ''),
      tags: _segmenter(await _tagText(entryId)),
    );
  }

  Future<int> _tagUsage(String tagId) async {
    final row = await _db
        .customSelect(
          'SELECT count(*) AS c FROM entry_tag et '
          'JOIN entry e ON e.id = et.entry_id '
          'WHERE et.tag_id = ? AND e.deleted = 0;',
          variables: <Variable<Object>>[Variable<String>(tagId)],
        )
        .getSingle();
    return row.read<int>('c');
  }

  Future<void> _recountTags(Iterable<String> ids) async {
    for (final id in ids.toSet()) {
      await _db.customStatement(
        'UPDATE tag SET usage_count = ('
        '  SELECT count(*) FROM entry_tag et '
        '  JOIN entry e ON e.id = et.entry_id '
        '  WHERE et.tag_id = ? AND e.deleted = 0'
        ') WHERE id = ?;',
        <Object?>[id, id],
      );
    }
  }

  /// 只统计**直接**挂在该分类下的条目（不含子分类）。
  /// 两级树里父子是并列展示的，把子级算进父级会让 UI 数字对不上。
  Future<void> _recountCategories(Iterable<String> ids) async {
    for (final id in ids.toSet()) {
      await _db.customStatement(
        'UPDATE category SET entry_count = ('
        '  SELECT count(*) FROM entry_category ec '
        '  JOIN entry e ON e.id = ec.entry_id '
        '  WHERE ec.category_id = ? AND e.deleted = 0'
        ') WHERE id = ?;',
        <Object?>[id, id],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 同步结果落库（唯一写入口）
  // ---------------------------------------------------------------------------

  /// 把一次 `SyncEngine` 的结果原子落库。
  ///
  /// 实体写入、历史、回收站、FTS、oplog、sync_state、device_watermark、
  /// sync_log 和隔离区都在同一个事务里。任何一条快照校验失败都会整体回滚，
  /// 不会出现「entry 改了但 oplog 没写」这种同步最害怕的半写状态。
  Future<void> applySyncRun(
    SyncRunResult result, {
    String trigger = 'manual',
  }) {
    return _db.transaction(() async {
      await _ensureQuarantineTable();
      final key = await _keys.item();
      final snapshots = result.entries.values.toList(growable: false);
      for (final snapshot in snapshots) {
        _validateEntrySnapshot(snapshot);
      }

      for (final snapshot in snapshots) {
        _observeSnapshotHlc(snapshot.hlc);
        final existing = await _loadEntry(snapshot.id);
        final previous =
            existing == null ? null : EntrySnapshot.fromRow(existing);
        if (previous != null && _sameEntrySnapshot(previous, snapshot)) {
          continue;
        }
        await _commit(
          snapshot: snapshot,
          op: _remoteEntryOp(previous, snapshot),
          baseRev: previous?.rev,
          key: key,
          previous: previous,
          toTrash: previous != null && !previous.deleted && snapshot.deleted,
          fromTrash: previous != null && previous.deleted && !snapshot.deleted,
          applied: result.cloudAppliedEntryIds.contains(snapshot.id),
        );
      }

      await _replaceSyncState(result.syncState);
      await _markAppliedOps(result.appliedOps);
      await _writeQuarantinePayloads(result.quarantinePayloads);
      if (result.watermarkPublished) {
        await _persistPublishedWatermark(result.nextHlc);
      }
      await _writeSyncLogRecord(
        trigger: trigger,
        outcome: result.isFailed
            ? 'failed'
            : (result.isBackoff || result.budgetExceeded || result.skipped
                ? 'partial'
                : 'ok'),
        pulled: result.diff.pullCount,
        pushed: result.pushedPaths.length,
        conflicts: result.conflicts,
        requestCount: result.requestCount,
        errorCode: result.state.error?.name,
        errorMsg: result.isFailed || result.isBackoff ? result.reason : null,
      );
    });
  }

  /// taxonomy 独立通道推送成功后，把 oplog 与远端 ETag 一起落库。
  Future<void> recordEntityPushes(
    Iterable<SyncedOplogPush> pushes, {
    String trigger = 'entity_push',
  }) {
    return _db.transaction(() async {
      final list = pushes.toList(growable: false);
      for (final push in list) {
        await (_db.update(_db.oplogs)..where((t) => t.seq.equals(push.oplogSeq)))
            .write(const OplogsCompanion(applied: Value<int>(1)));
        await _upsertSyncState(push.path, push.etag);
      }
      await _writeSyncLogRecord(
        trigger: trigger,
        outcome: 'ok',
        pushed: list.length,
        requestCount: list.length,
      );
    });
  }

  /// 应用远端 taxonomy 信封。
  ///
  /// 每次实体变更仍走 [_commitTaxonomy]，不会绕过 oplog；远端已经确认，
  /// 所以这些新 oplog 直接标为 `applied=1`，下次同步不会重复推送。
  Future<void> applyRemoteTaxonomySnapshots(
    Iterable<RemoteTaxonomyFile> files, {
    String trigger = 'entity_pull',
  }) {
    return _db.transaction(() async {
      await _ensureQuarantineTable();
      final key = await _keys.item();
      var applied = 0;
      for (final file in files) {
        final snapshot = file.snapshot;
        if (!_isTaxonomyEntity(snapshot.entity)) {
          throw WriteException(
            'invalid',
            '远端 taxonomy 实体 ${snapshot.entity} 不在白名单内',
          );
        }
        _observeSnapshotHlc(snapshot.hlc);
        final latest = await _latestTaxonomy(snapshot.entity, snapshot.id);
        if (latest != null && latest.rev >= snapshot.rev) {
          await _upsertSyncState(file.path, file.etag);
          continue;
        }
        await _commitTaxonomy(
          snapshot: snapshot,
          op: _taxonomyOp(latest, snapshot),
          key: key,
          apply: () => _applyTaxonomySnapshot(snapshot),
          applied: true,
        );
        await _upsertSyncState(file.path, file.etag);
        applied++;
      }
      await _writeSyncLogRecord(
        trigger: trigger,
        outcome: 'ok',
        pulled: applied,
        requestCount: files.length,
      );
    });
  }

  /// 隔离区记录。表用原生 SQL 创建，避免为了诊断表做一次 drift codegen。
  Future<List<SyncQuarantineRecord>> quarantine() async {
    await _ensureQuarantineTable();
    final rows = await _db
        .customSelect(
          'SELECT path, payload, reason, created_at FROM sync_quarantine '
          'ORDER BY created_at DESC, path;',
        )
        .get();
    return <SyncQuarantineRecord>[
      for (final row in rows)
        SyncQuarantineRecord(
          path: row.read<String>('path'),
          bytes: Uint8List.fromList(row.read<Uint8List>('payload')),
          reason: row.read<String>('reason'),
          createdAt: row.read<int>('created_at'),
        ),
    ];
  }

  Future<void> _ensureQuarantineTable() => _db.customStatement(
        'CREATE TABLE IF NOT EXISTS sync_quarantine ('
        ' path TEXT PRIMARY KEY,'
        ' payload BLOB NOT NULL,'
        ' reason TEXT NOT NULL,'
        ' created_at INTEGER NOT NULL'
        ');',
      );

  Future<void> _writeQuarantinePayloads(
    Map<String, List<int>> payloads,
  ) async {
    for (final entry in payloads.entries) {
      await _db.customStatement(
        'INSERT OR REPLACE INTO sync_quarantine'
        '(path, payload, reason, created_at) VALUES (?, ?, ?, ?);',
        <Object?>[
          entry.key,
          Uint8List.fromList(entry.value),
          'E_CORRUPT：解密或 content_hash 校验失败，不覆盖本地',
          _now(),
        ],
      );
    }
  }

  Future<void> _replaceSyncState(Map<String, String?> syncState) async {
    await (_db.delete(_db.syncStates)).go();
    for (final entry in syncState.entries) {
      await _db.into(_db.syncStates).insert(
            SyncStatesCompanion.insert(
              path: entry.key,
              etag: Value<String?>(entry.value),
              updatedAt: Value<int?>(_now()),
            ),
          );
    }
  }

  Future<void> _upsertSyncState(String path, String? etag) =>
      _db.into(_db.syncStates).insertOnConflictUpdate(
            SyncStatesCompanion.insert(
              path: path,
              etag: Value<String?>(etag),
              updatedAt: Value<int?>(_now()),
            ),
          );

  Future<void> _markAppliedOps(Iterable<String> appliedOps) async {
    for (final id in appliedOps) {
      if (!id.startsWith('oplog:')) continue;
      final seq = int.tryParse(id.substring('oplog:'.length));
      if (seq == null) continue;
      await (_db.update(_db.oplogs)..where((t) => t.seq.equals(seq)))
          .write(const OplogsCompanion(applied: Value<int>(1)));
    }
  }

  Future<void> _persistPublishedWatermark(String nextHlc) async {
    final parsed = Hlc.tryParse(nextHlc);
    if (parsed != null) _clock.observe(parsed);
    await _persistClock();
  }

  Future<void> _writeSyncLogRecord({
    required String trigger,
    required String outcome,
    int pulled = 0,
    int pushed = 0,
    int conflicts = 0,
    int requestCount = 0,
    String? errorCode,
    String? errorMsg,
  }) {
    return _db.into(_db.syncLogs).insert(
          SyncLogsCompanion.insert(
            startedAt: Value<int?>(_now()),
            finishedAt: Value<int?>(_now()),
            trigger: Value<String?>(trigger),
            result: Value<String?>(outcome),
            pulled: Value<int?>(pulled),
            pushed: Value<int?>(pushed),
            conflicts: Value<int?>(conflicts),
            errorCode: Value<String?>(errorCode),
            errorMsg: Value<String?>(errorMsg),
            requestCount: Value<int?>(requestCount),
          ),
        );
  }

  void _validateEntrySnapshot(EntrySnapshot snapshot) {
    final expected = EntrySnapshot.computeContentHash(
      kind: snapshot.kind,
      title: snapshot.title,
      body: snapshot.body,
      meta: snapshot.meta,
    );
    if (snapshot.contentHash != expected) {
      throw WriteException(
        'invalid',
        '同步快照 ${snapshot.id} 的 content_hash 不匹配，整次落库回滚',
      );
    }
  }

  void _observeSnapshotHlc(String encoded) {
    final parsed = Hlc.tryParse(encoded);
    if (parsed != null) _clock.observe(parsed);
  }

  bool _sameEntrySnapshot(EntrySnapshot a, EntrySnapshot b) =>
      a.id == b.id &&
      a.kind == b.kind &&
      a.title == b.title &&
      a.body == b.body &&
      a.meta == b.meta &&
      a.createdAt == b.createdAt &&
      a.updatedAt == b.updatedAt &&
      a.hlc == b.hlc &&
      a.rev == b.rev &&
      a.contentHash == b.contentHash &&
      a.deleted == b.deleted &&
      a.deletedAt == b.deletedAt;

  OplogOp _remoteEntryOp(EntrySnapshot? previous, EntrySnapshot next) {
    if (previous == null) return OplogOp.create;
    if (next.deleted && !previous.deleted) return OplogOp.delete;
    if (!next.deleted && previous.deleted) return OplogOp.restore;
    return OplogOp.update;
  }

  OplogOp _taxonomyOp(TaxonomySnapshot? previous, TaxonomySnapshot next) {
    if (previous == null) return OplogOp.create;
    if (next.deleted && !previous.deleted) return OplogOp.delete;
    if (!next.deleted && previous.deleted) return OplogOp.restore;
    return OplogOp.update;
  }

  bool _isTaxonomyEntity(String entity) =>
      entity == SyncEntity.category ||
      entity == SyncEntity.tag ||
      entity == SyncEntity.entryTaxonomy;

  Future<void> _applyTaxonomySnapshot(TaxonomySnapshot snapshot) async {
    switch (snapshot.entity) {
      case SyncEntity.category:
        await _applyCategorySnapshot(snapshot);
        return;
      case SyncEntity.tag:
        await _applyTagSnapshot(snapshot);
        return;
      case SyncEntity.entryTaxonomy:
        await _applyEntryTaxonomySnapshot(snapshot);
        return;
      default:
        throw WriteException('invalid', '不支持的 taxonomy 实体 ${snapshot.entity}');
    }
  }

  Future<void> _applyCategorySnapshot(TaxonomySnapshot snapshot) async {
    final name = _stringField(snapshot.fields, 'name') ?? '';
    final kind = _intField(snapshot.fields, 'kind', EntryKind.note.code);
    final parentId = _stringField(snapshot.fields, 'parent_id');
    final sortOrder = _intField(snapshot.fields, 'sort_order', 0);
    await _db.into(_db.categories).insertOnConflictUpdate(
          CategoriesCompanion(
            id: Value<String>(snapshot.id),
            kind: Value<int>(kind),
            parentId: Value<String?>(parentId),
            name: Value<String>(name),
            sortOrder: Value<int>(sortOrder),
            createdAt: Value<int?>(snapshot.updatedAt),
            updatedAt: Value<int?>(snapshot.updatedAt),
            hlc: Value<String>(snapshot.hlc),
            deleted: Value<int>(snapshot.deleted ? 1 : 0),
          ),
        );
    if (!snapshot.deleted) return;

    final affected = await _db.customSelect(
      'SELECT entry_id FROM entry_category WHERE category_id = ?;',
      variables: <Variable<Object>>[Variable<String>(snapshot.id)],
    ).get();
    await (_db.delete(_db.entryCategories)
          ..where((t) => t.categoryId.equals(snapshot.id)))
        .go();
    for (final row in affected) {
      await _rebuildEntrySearch(row.read<String>('entry_id'));
    }
  }

  Future<void> _applyTagSnapshot(TaxonomySnapshot snapshot) async {
    final name = _stringField(snapshot.fields, 'name') ?? '';
    await _db.into(_db.tags).insertOnConflictUpdate(
          TagsCompanion(
            id: Value<String>(snapshot.id),
            name: Value<String>(name),
            createdAt: Value<int?>(snapshot.updatedAt),
            updatedAt: Value<int?>(snapshot.updatedAt),
            hlc: Value<String>(snapshot.hlc),
            deleted: Value<int>(snapshot.deleted ? 1 : 0),
          ),
        );
    if (!snapshot.deleted) {
      await _rebuildEntriesForTag(snapshot.id);
      return;
    }
    final affected = await _entriesForTag(snapshot.id);
    await (_db.delete(_db.entryTags)..where((t) => t.tagId.equals(snapshot.id)))
        .go();
    await _recountTags(<String>{snapshot.id});
    for (final entryId in affected) {
      await _rebuildEntrySearch(entryId);
    }
  }

  Future<void> _applyEntryTaxonomySnapshot(
    TaxonomySnapshot snapshot,
  ) async {
    final entryId = snapshot.id;
    final oldTagRows = await (_db.select(_db.entryTags)
          ..where((t) => t.entryId.equals(entryId)))
        .get();
    final oldCatRows = await (_db.select(_db.entryCategories)
          ..where((t) => t.entryId.equals(entryId)))
        .get();
    final oldTagIds = <String>{for (final row in oldTagRows) row.tagId};
    final oldCategoryIds = <String>{
      for (final row in oldCatRows) row.categoryId,
    };

    final rawTags = snapshot.fields['tag_ids'];
    final nextTagIds = rawTags is List
        ? rawTags.whereType<String>().toList(growable: false)
        : const <String>[];
    final categoryId = snapshot.deleted
        ? null
        : _stringField(snapshot.fields, 'category_id');

    await (_db.delete(_db.entryCategories)
          ..where((t) => t.entryId.equals(entryId)))
        .go();
    await (_db.delete(_db.entryTags)..where((t) => t.entryId.equals(entryId)))
        .go();
    if (!snapshot.deleted && categoryId != null) {
      await _db.into(_db.entryCategories).insert(
            EntryCategoriesCompanion.insert(
              entryId: entryId,
              categoryId: categoryId,
            ),
          );
    }
    if (!snapshot.deleted) {
      for (final tagId in nextTagIds) {
        await _db.into(_db.entryTags).insert(
              EntryTagsCompanion.insert(entryId: entryId, tagId: tagId),
            );
      }
    }
    await _recountTags(<String>{...oldTagIds, ...nextTagIds});
    await _recountCategories(<String>{
      ...oldCategoryIds,
      ?categoryId,
    });
    await _rebuildEntrySearch(entryId);
  }

  String? _stringField(Map<String, Object?> fields, String key) {
    final value = fields[key];
    return value is String ? value : null;
  }

  int _intField(Map<String, Object?> fields, String key, int fallback) {
    final value = fields[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static Map<String, Object?> _decodeJson(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('条目快照顶层不是对象');
    }
    return decoded;
  }
}
