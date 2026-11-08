// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_database.dart';

// ignore_for_file: type=lint
class $EntriesTable extends Entries with TableInfo<$EntriesTable, EntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
    'meta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revMeta = const VerificationMeta('rev');
  @override
  late final GeneratedColumn<int> rev = GeneratedColumn<int>(
    'rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    title,
    body,
    meta,
    createdAt,
    updatedAt,
    hlc,
    rev,
    contentHash,
    deleted,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('meta')) {
      context.handle(
        _metaMeta,
        meta.isAcceptableOrUnknown(data['meta']!, _metaMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('rev')) {
      context.handle(
        _revMeta,
        rev.isAcceptableOrUnknown(data['rev']!, _revMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      meta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      rev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rev'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class EntryRow extends DataClass implements Insertable<EntryRow> {
  final String id;

  /// 1 笔记 / 2 想法 / 3 日记 / 4 AI 日记 / 5 书签 / 6 密码
  final int kind;
  final String? title;

  /// Markdown 正文
  final String? body;

  /// 按 kind 区分的扩展字段 JSON（见 docs/13 §3）。
  /// **扩展字段一律进 meta，不给本表加列** —— 加列就要迁移，而 meta 是 JSON。
  final String? meta;
  final int createdAt;
  final int updatedAt;

  /// 混合逻辑时钟，格式 `0000018F2A3B4C5D:0003:devA`
  final String hlc;
  final int rev;

  /// sha256(canonical)，合并后必须校验一致
  final String contentHash;
  final int deleted;
  final int? deletedAt;
  const EntryRow({
    required this.id,
    required this.kind,
    this.title,
    this.body,
    this.meta,
    required this.createdAt,
    required this.updatedAt,
    required this.hlc,
    required this.rev,
    required this.contentHash,
    required this.deleted,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<int>(kind);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || meta != null) {
      map['meta'] = Variable<String>(meta);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['hlc'] = Variable<String>(hlc);
    map['rev'] = Variable<int>(rev);
    map['content_hash'] = Variable<String>(contentHash);
    map['deleted'] = Variable<int>(deleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      meta: meta == null && nullToAbsent ? const Value.absent() : Value(meta),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      hlc: Value(hlc),
      rev: Value(rev),
      contentHash: Value(contentHash),
      deleted: Value(deleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory EntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<int>(json['kind']),
      title: serializer.fromJson<String?>(json['title']),
      body: serializer.fromJson<String?>(json['body']),
      meta: serializer.fromJson<String?>(json['meta']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      hlc: serializer.fromJson<String>(json['hlc']),
      rev: serializer.fromJson<int>(json['rev']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      deleted: serializer.fromJson<int>(json['deleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<int>(kind),
      'title': serializer.toJson<String?>(title),
      'body': serializer.toJson<String?>(body),
      'meta': serializer.toJson<String?>(meta),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'hlc': serializer.toJson<String>(hlc),
      'rev': serializer.toJson<int>(rev),
      'contentHash': serializer.toJson<String>(contentHash),
      'deleted': serializer.toJson<int>(deleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  EntryRow copyWith({
    String? id,
    int? kind,
    Value<String?> title = const Value.absent(),
    Value<String?> body = const Value.absent(),
    Value<String?> meta = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    String? hlc,
    int? rev,
    String? contentHash,
    int? deleted,
    Value<int?> deletedAt = const Value.absent(),
  }) => EntryRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title.present ? title.value : this.title,
    body: body.present ? body.value : this.body,
    meta: meta.present ? meta.value : this.meta,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    hlc: hlc ?? this.hlc,
    rev: rev ?? this.rev,
    contentHash: contentHash ?? this.contentHash,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  EntryRow copyWithCompanion(EntriesCompanion data) {
    return EntryRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      meta: data.meta.present ? data.meta.value : this.meta,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      rev: data.rev.present ? data.rev.value : this.rev,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('meta: $meta, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hlc: $hlc, ')
          ..write('rev: $rev, ')
          ..write('contentHash: $contentHash, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    body,
    meta,
    createdAt,
    updatedAt,
    hlc,
    rev,
    contentHash,
    deleted,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.body == this.body &&
          other.meta == this.meta &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.hlc == this.hlc &&
          other.rev == this.rev &&
          other.contentHash == this.contentHash &&
          other.deleted == this.deleted &&
          other.deletedAt == this.deletedAt);
}

class EntriesCompanion extends UpdateCompanion<EntryRow> {
  final Value<String> id;
  final Value<int> kind;
  final Value<String?> title;
  final Value<String?> body;
  final Value<String?> meta;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> hlc;
  final Value<int> rev;
  final Value<String> contentHash;
  final Value<int> deleted;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.meta = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rev = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required int kind,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.meta = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    required String hlc,
    this.rev = const Value.absent(),
    required String contentHash,
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       hlc = Value(hlc),
       contentHash = Value(contentHash);
  static Insertable<EntryRow> custom({
    Expression<String>? id,
    Expression<int>? kind,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? meta,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? hlc,
    Expression<int>? rev,
    Expression<String>? contentHash,
    Expression<int>? deleted,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (meta != null) 'meta': meta,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (hlc != null) 'hlc': hlc,
      if (rev != null) 'rev': rev,
      if (contentHash != null) 'content_hash': contentHash,
      if (deleted != null) 'deleted': deleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<int>? kind,
    Value<String?>? title,
    Value<String?>? body,
    Value<String?>? meta,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? hlc,
    Value<int>? rev,
    Value<String>? contentHash,
    Value<int>? deleted,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      meta: meta ?? this.meta,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hlc: hlc ?? this.hlc,
      rev: rev ?? this.rev,
      contentHash: contentHash ?? this.contentHash,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (rev.present) {
      map['rev'] = Variable<int>(rev.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('meta: $meta, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hlc: $hlc, ')
          ..write('rev: $rev, ')
          ..write('contentHash: $contentHash, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntryHistoryTable extends EntryHistory
    with TableInfo<$EntryHistoryTable, EntryHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revMeta = const VerificationMeta('rev');
  @override
  late final GeneratedColumn<int> rev = GeneratedColumn<int>(
    'rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, rev, payload, hlc, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('rev')) {
      context.handle(
        _revMeta,
        rev.isAcceptableOrUnknown(data['rev']!, _revMeta),
      );
    } else if (isInserting) {
      context.missing(_revMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, rev};
  @override
  EntryHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryHistoryRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      rev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rev'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}payload'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EntryHistoryTable createAlias(String alias) {
    return $EntryHistoryTable(attachedDatabase, alias);
  }
}

class EntryHistoryRow extends DataClass implements Insertable<EntryHistoryRow> {
  final String entryId;
  final int rev;
  final Uint8List payload;
  final String hlc;
  final int createdAt;
  const EntryHistoryRow({
    required this.entryId,
    required this.rev,
    required this.payload,
    required this.hlc,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['rev'] = Variable<int>(rev);
    map['payload'] = Variable<Uint8List>(payload);
    map['hlc'] = Variable<String>(hlc);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  EntryHistoryCompanion toCompanion(bool nullToAbsent) {
    return EntryHistoryCompanion(
      entryId: Value(entryId),
      rev: Value(rev),
      payload: Value(payload),
      hlc: Value(hlc),
      createdAt: Value(createdAt),
    );
  }

  factory EntryHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryHistoryRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      rev: serializer.fromJson<int>(json['rev']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
      hlc: serializer.fromJson<String>(json['hlc']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'rev': serializer.toJson<int>(rev),
      'payload': serializer.toJson<Uint8List>(payload),
      'hlc': serializer.toJson<String>(hlc),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  EntryHistoryRow copyWith({
    String? entryId,
    int? rev,
    Uint8List? payload,
    String? hlc,
    int? createdAt,
  }) => EntryHistoryRow(
    entryId: entryId ?? this.entryId,
    rev: rev ?? this.rev,
    payload: payload ?? this.payload,
    hlc: hlc ?? this.hlc,
    createdAt: createdAt ?? this.createdAt,
  );
  EntryHistoryRow copyWithCompanion(EntryHistoryCompanion data) {
    return EntryHistoryRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      rev: data.rev.present ? data.rev.value : this.rev,
      payload: data.payload.present ? data.payload.value : this.payload,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryHistoryRow(')
          ..write('entryId: $entryId, ')
          ..write('rev: $rev, ')
          ..write('payload: $payload, ')
          ..write('hlc: $hlc, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entryId,
    rev,
    $driftBlobEquality.hash(payload),
    hlc,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryHistoryRow &&
          other.entryId == this.entryId &&
          other.rev == this.rev &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.hlc == this.hlc &&
          other.createdAt == this.createdAt);
}

class EntryHistoryCompanion extends UpdateCompanion<EntryHistoryRow> {
  final Value<String> entryId;
  final Value<int> rev;
  final Value<Uint8List> payload;
  final Value<String> hlc;
  final Value<int> createdAt;
  final Value<int> rowid;
  const EntryHistoryCompanion({
    this.entryId = const Value.absent(),
    this.rev = const Value.absent(),
    this.payload = const Value.absent(),
    this.hlc = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntryHistoryCompanion.insert({
    required String entryId,
    required int rev,
    required Uint8List payload,
    required String hlc,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       rev = Value(rev),
       payload = Value(payload),
       hlc = Value(hlc),
       createdAt = Value(createdAt);
  static Insertable<EntryHistoryRow> custom({
    Expression<String>? entryId,
    Expression<int>? rev,
    Expression<Uint8List>? payload,
    Expression<String>? hlc,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (rev != null) 'rev': rev,
      if (payload != null) 'payload': payload,
      if (hlc != null) 'hlc': hlc,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntryHistoryCompanion copyWith({
    Value<String>? entryId,
    Value<int>? rev,
    Value<Uint8List>? payload,
    Value<String>? hlc,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return EntryHistoryCompanion(
      entryId: entryId ?? this.entryId,
      rev: rev ?? this.rev,
      payload: payload ?? this.payload,
      hlc: hlc ?? this.hlc,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (rev.present) {
      map['rev'] = Variable<int>(rev.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryHistoryCompanion(')
          ..write('entryId: $entryId, ')
          ..write('rev: $rev, ')
          ..write('payload: $payload, ')
          ..write('hlc: $hlc, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrashRowsTable extends TrashRows
    with TableInfo<$TrashRowsTable, TrashRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrashRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expireAtMeta = const VerificationMeta(
    'expireAt',
  );
  @override
  late final GeneratedColumn<int> expireAt = GeneratedColumn<int>(
    'expire_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, payload, deletedAt, expireAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trash';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrashRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    if (data.containsKey('expire_at')) {
      context.handle(
        _expireAtMeta,
        expireAt.isAcceptableOrUnknown(data['expire_at']!, _expireAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expireAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId};
  @override
  TrashRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrashRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}payload'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      )!,
      expireAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expire_at'],
      )!,
    );
  }

  @override
  $TrashRowsTable createAlias(String alias) {
    return $TrashRowsTable(attachedDatabase, alias);
  }
}

class TrashRow extends DataClass implements Insertable<TrashRow> {
  final String entryId;
  final Uint8List payload;
  final int deletedAt;

  /// 默认 deletedAt + 30 天
  final int expireAt;
  const TrashRow({
    required this.entryId,
    required this.payload,
    required this.deletedAt,
    required this.expireAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['payload'] = Variable<Uint8List>(payload);
    map['deleted_at'] = Variable<int>(deletedAt);
    map['expire_at'] = Variable<int>(expireAt);
    return map;
  }

  TrashRowsCompanion toCompanion(bool nullToAbsent) {
    return TrashRowsCompanion(
      entryId: Value(entryId),
      payload: Value(payload),
      deletedAt: Value(deletedAt),
      expireAt: Value(expireAt),
    );
  }

  factory TrashRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrashRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
      deletedAt: serializer.fromJson<int>(json['deletedAt']),
      expireAt: serializer.fromJson<int>(json['expireAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'payload': serializer.toJson<Uint8List>(payload),
      'deletedAt': serializer.toJson<int>(deletedAt),
      'expireAt': serializer.toJson<int>(expireAt),
    };
  }

  TrashRow copyWith({
    String? entryId,
    Uint8List? payload,
    int? deletedAt,
    int? expireAt,
  }) => TrashRow(
    entryId: entryId ?? this.entryId,
    payload: payload ?? this.payload,
    deletedAt: deletedAt ?? this.deletedAt,
    expireAt: expireAt ?? this.expireAt,
  );
  TrashRow copyWithCompanion(TrashRowsCompanion data) {
    return TrashRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      payload: data.payload.present ? data.payload.value : this.payload,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      expireAt: data.expireAt.present ? data.expireAt.value : this.expireAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrashRow(')
          ..write('entryId: $entryId, ')
          ..write('payload: $payload, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('expireAt: $expireAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entryId,
    $driftBlobEquality.hash(payload),
    deletedAt,
    expireAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrashRow &&
          other.entryId == this.entryId &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.deletedAt == this.deletedAt &&
          other.expireAt == this.expireAt);
}

class TrashRowsCompanion extends UpdateCompanion<TrashRow> {
  final Value<String> entryId;
  final Value<Uint8List> payload;
  final Value<int> deletedAt;
  final Value<int> expireAt;
  final Value<int> rowid;
  const TrashRowsCompanion({
    this.entryId = const Value.absent(),
    this.payload = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.expireAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrashRowsCompanion.insert({
    required String entryId,
    required Uint8List payload,
    required int deletedAt,
    required int expireAt,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       payload = Value(payload),
       deletedAt = Value(deletedAt),
       expireAt = Value(expireAt);
  static Insertable<TrashRow> custom({
    Expression<String>? entryId,
    Expression<Uint8List>? payload,
    Expression<int>? deletedAt,
    Expression<int>? expireAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (payload != null) 'payload': payload,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (expireAt != null) 'expire_at': expireAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrashRowsCompanion copyWith({
    Value<String>? entryId,
    Value<Uint8List>? payload,
    Value<int>? deletedAt,
    Value<int>? expireAt,
    Value<int>? rowid,
  }) {
    return TrashRowsCompanion(
      entryId: entryId ?? this.entryId,
      payload: payload ?? this.payload,
      deletedAt: deletedAt ?? this.deletedAt,
      expireAt: expireAt ?? this.expireAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (expireAt.present) {
      map['expire_at'] = Variable<int>(expireAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrashRowsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('payload: $payload, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('expireAt: $expireAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _entryCountMeta = const VerificationMeta(
    'entryCount',
  );
  @override
  late final GeneratedColumn<int> entryCount = GeneratedColumn<int>(
    'entry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    parentId,
    name,
    color,
    icon,
    sortOrder,
    entryCount,
    createdAt,
    updatedAt,
    hlc,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('entry_count')) {
      context.handle(
        _entryCountMeta,
        entryCount.isAcceptableOrUnknown(data['entry_count']!, _entryCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      entryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String id;

  /// 归属类型，与 entry.kind 对齐
  final int kind;

  /// null = 一级；非空 = 二级
  final String? parentId;
  final String name;
  final String? color;
  final String? icon;
  final int sortOrder;

  /// 冗余计数，异步更新（为了列表页不用 count(*) 扫全表）
  final int entryCount;
  final int? createdAt;
  final int? updatedAt;
  final String hlc;
  final int deleted;
  const CategoryRow({
    required this.id,
    required this.kind,
    this.parentId,
    required this.name,
    this.color,
    this.icon,
    required this.sortOrder,
    required this.entryCount,
    this.createdAt,
    this.updatedAt,
    required this.hlc,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<int>(kind);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['entry_count'] = Variable<int>(entryCount);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<int>(deleted);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      kind: Value(kind),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      sortOrder: Value(sortOrder),
      entryCount: Value(entryCount),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      hlc: Value(hlc),
      deleted: Value(deleted),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<int>(json['kind']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      icon: serializer.fromJson<String?>(json['icon']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      entryCount: serializer.fromJson<int>(json['entryCount']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<int>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<int>(kind),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'icon': serializer.toJson<String?>(icon),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'entryCount': serializer.toJson<int>(entryCount),
      'createdAt': serializer.toJson<int?>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<int>(deleted),
    };
  }

  CategoryRow copyWith({
    String? id,
    int? kind,
    Value<String?> parentId = const Value.absent(),
    String? name,
    Value<String?> color = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    int? sortOrder,
    int? entryCount,
    Value<int?> createdAt = const Value.absent(),
    Value<int?> updatedAt = const Value.absent(),
    String? hlc,
    int? deleted,
  }) => CategoryRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    icon: icon.present ? icon.value : this.icon,
    sortOrder: sortOrder ?? this.sortOrder,
    entryCount: entryCount ?? this.entryCount,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      icon: data.icon.present ? data.icon.value : this.icon,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      entryCount: data.entryCount.present
          ? data.entryCount.value
          : this.entryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('entryCount: $entryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    parentId,
    name,
    color,
    icon,
    sortOrder,
    entryCount,
    createdAt,
    updatedAt,
    hlc,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.color == this.color &&
          other.icon == this.icon &&
          other.sortOrder == this.sortOrder &&
          other.entryCount == this.entryCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<int> kind;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<String?> color;
  final Value<String?> icon;
  final Value<int> sortOrder;
  final Value<int> entryCount;
  final Value<int?> createdAt;
  final Value<int?> updatedAt;
  final Value<String> hlc;
  final Value<int> deleted;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.entryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required int kind,
    this.parentId = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.entryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required String hlc,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       name = Value(name),
       hlc = Value(hlc);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<int>? kind,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<String>? color,
    Expression<String>? icon,
    Expression<int>? sortOrder,
    Expression<int>? entryCount,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? hlc,
    Expression<int>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (entryCount != null) 'entry_count': entryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<int>? kind,
    Value<String?>? parentId,
    Value<String>? name,
    Value<String?>? color,
    Value<String?>? icon,
    Value<int>? sortOrder,
    Value<int>? entryCount,
    Value<int?>? createdAt,
    Value<int?>? updatedAt,
    Value<String>? hlc,
    Value<int>? deleted,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      entryCount: entryCount ?? this.entryCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (entryCount.present) {
      map['entry_count'] = Variable<int>(entryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('entryCount: $entryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usageCountMeta = const VerificationMeta(
    'usageCount',
  );
  @override
  late final GeneratedColumn<int> usageCount = GeneratedColumn<int>(
    'usage_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    usageCount,
    createdAt,
    updatedAt,
    hlc,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('usage_count')) {
      context.handle(
        _usageCountMeta,
        usageCount.isAcceptableOrUnknown(data['usage_count']!, _usageCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      usageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}usage_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class TagRow extends DataClass implements Insertable<TagRow> {
  final String id;
  final String name;
  final String? color;
  final int usageCount;
  final int? createdAt;
  final int? updatedAt;
  final String hlc;
  final int deleted;
  const TagRow({
    required this.id,
    required this.name,
    this.color,
    required this.usageCount,
    this.createdAt,
    this.updatedAt,
    required this.hlc,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['usage_count'] = Variable<int>(usageCount);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<int>(deleted);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      usageCount: Value(usageCount),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      hlc: Value(hlc),
      deleted: Value(deleted),
    );
  }

  factory TagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      usageCount: serializer.fromJson<int>(json['usageCount']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<int>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'usageCount': serializer.toJson<int>(usageCount),
      'createdAt': serializer.toJson<int?>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<int>(deleted),
    };
  }

  TagRow copyWith({
    String? id,
    String? name,
    Value<String?> color = const Value.absent(),
    int? usageCount,
    Value<int?> createdAt = const Value.absent(),
    Value<int?> updatedAt = const Value.absent(),
    String? hlc,
    int? deleted,
  }) => TagRow(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    usageCount: usageCount ?? this.usageCount,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
  );
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      usageCount: data.usageCount.present
          ? data.usageCount.value
          : this.usageCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('usageCount: $usageCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    color,
    usageCount,
    createdAt,
    updatedAt,
    hlc,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.usageCount == this.usageCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> color;
  final Value<int> usageCount;
  final Value<int?> createdAt;
  final Value<int?> updatedAt;
  final Value<String> hlc;
  final Value<int> deleted;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.usageCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    this.usageCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required String hlc,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       hlc = Value(hlc);
  static Insertable<TagRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? usageCount,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? hlc,
    Expression<int>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (usageCount != null) 'usage_count': usageCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? color,
    Value<int>? usageCount,
    Value<int?>? createdAt,
    Value<int?>? updatedAt,
    Value<String>? hlc,
    Value<int>? deleted,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (usageCount.present) {
      map['usage_count'] = Variable<int>(usageCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('usageCount: $usageCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntryCategoriesTable extends EntryCategories
    with TableInfo<$EntryCategoriesTable, EntryCategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, categoryId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_category';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryCategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, categoryId};
  @override
  EntryCategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryCategoryRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
    );
  }

  @override
  $EntryCategoriesTable createAlias(String alias) {
    return $EntryCategoriesTable(attachedDatabase, alias);
  }
}

class EntryCategoryRow extends DataClass
    implements Insertable<EntryCategoryRow> {
  final String entryId;
  final String categoryId;
  const EntryCategoryRow({required this.entryId, required this.categoryId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['category_id'] = Variable<String>(categoryId);
    return map;
  }

  EntryCategoriesCompanion toCompanion(bool nullToAbsent) {
    return EntryCategoriesCompanion(
      entryId: Value(entryId),
      categoryId: Value(categoryId),
    );
  }

  factory EntryCategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryCategoryRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'categoryId': serializer.toJson<String>(categoryId),
    };
  }

  EntryCategoryRow copyWith({String? entryId, String? categoryId}) =>
      EntryCategoryRow(
        entryId: entryId ?? this.entryId,
        categoryId: categoryId ?? this.categoryId,
      );
  EntryCategoryRow copyWithCompanion(EntryCategoriesCompanion data) {
    return EntryCategoryRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryCategoryRow(')
          ..write('entryId: $entryId, ')
          ..write('categoryId: $categoryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryId, categoryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryCategoryRow &&
          other.entryId == this.entryId &&
          other.categoryId == this.categoryId);
}

class EntryCategoriesCompanion extends UpdateCompanion<EntryCategoryRow> {
  final Value<String> entryId;
  final Value<String> categoryId;
  final Value<int> rowid;
  const EntryCategoriesCompanion({
    this.entryId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntryCategoriesCompanion.insert({
    required String entryId,
    required String categoryId,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       categoryId = Value(categoryId);
  static Insertable<EntryCategoryRow> custom({
    Expression<String>? entryId,
    Expression<String>? categoryId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (categoryId != null) 'category_id': categoryId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntryCategoriesCompanion copyWith({
    Value<String>? entryId,
    Value<String>? categoryId,
    Value<int>? rowid,
  }) {
    return EntryCategoriesCompanion(
      entryId: entryId ?? this.entryId,
      categoryId: categoryId ?? this.categoryId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryCategoriesCompanion(')
          ..write('entryId: $entryId, ')
          ..write('categoryId: $categoryId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntryTagsTable extends EntryTags
    with TableInfo<$EntryTagsTable, EntryTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_tag';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, tagId};
  @override
  EntryTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryTagRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $EntryTagsTable createAlias(String alias) {
    return $EntryTagsTable(attachedDatabase, alias);
  }
}

class EntryTagRow extends DataClass implements Insertable<EntryTagRow> {
  final String entryId;
  final String tagId;
  const EntryTagRow({required this.entryId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  EntryTagsCompanion toCompanion(bool nullToAbsent) {
    return EntryTagsCompanion(entryId: Value(entryId), tagId: Value(tagId));
  }

  factory EntryTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryTagRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  EntryTagRow copyWith({String? entryId, String? tagId}) =>
      EntryTagRow(entryId: entryId ?? this.entryId, tagId: tagId ?? this.tagId);
  EntryTagRow copyWithCompanion(EntryTagsCompanion data) {
    return EntryTagRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryTagRow(')
          ..write('entryId: $entryId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryTagRow &&
          other.entryId == this.entryId &&
          other.tagId == this.tagId);
}

class EntryTagsCompanion extends UpdateCompanion<EntryTagRow> {
  final Value<String> entryId;
  final Value<String> tagId;
  final Value<int> rowid;
  const EntryTagsCompanion({
    this.entryId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntryTagsCompanion.insert({
    required String entryId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       tagId = Value(tagId);
  static Insertable<EntryTagRow> custom({
    Expression<String>? entryId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntryTagsCompanion copyWith({
    Value<String>? entryId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return EntryTagsCompanion(
      entryId: entryId ?? this.entryId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryTagsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryFieldTemplatesTable extends CategoryFieldTemplates
    with TableInfo<$CategoryFieldTemplatesTable, CategoryFieldTemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryFieldTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _secretMeta = const VerificationMeta('secret');
  @override
  late final GeneratedColumn<int> secret = GeneratedColumn<int>(
    'secret',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    label,
    type,
    secret,
    sortOrder,
    hlc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_field_template';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryFieldTemplateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('secret')) {
      context.handle(
        _secretMeta,
        secret.isAcceptableOrUnknown(data['secret']!, _secretMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryFieldTemplateRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryFieldTemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      secret: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}secret'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
    );
  }

  @override
  $CategoryFieldTemplatesTable createAlias(String alias) {
    return $CategoryFieldTemplatesTable(attachedDatabase, alias);
  }
}

class CategoryFieldTemplateRow extends DataClass
    implements Insertable<CategoryFieldTemplateRow> {
  final String id;
  final String categoryId;
  final String label;

  /// text / url / number / secret
  final String type;

  /// 模板本身不带值，只带"建号时要加这个字段"
  final int secret;
  final int sortOrder;
  final String hlc;
  const CategoryFieldTemplateRow({
    required this.id,
    required this.categoryId,
    required this.label,
    required this.type,
    required this.secret,
    required this.sortOrder,
    required this.hlc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['label'] = Variable<String>(label);
    map['type'] = Variable<String>(type);
    map['secret'] = Variable<int>(secret);
    map['sort_order'] = Variable<int>(sortOrder);
    map['hlc'] = Variable<String>(hlc);
    return map;
  }

  CategoryFieldTemplatesCompanion toCompanion(bool nullToAbsent) {
    return CategoryFieldTemplatesCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      label: Value(label),
      type: Value(type),
      secret: Value(secret),
      sortOrder: Value(sortOrder),
      hlc: Value(hlc),
    );
  }

  factory CategoryFieldTemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryFieldTemplateRow(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      label: serializer.fromJson<String>(json['label']),
      type: serializer.fromJson<String>(json['type']),
      secret: serializer.fromJson<int>(json['secret']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      hlc: serializer.fromJson<String>(json['hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String>(categoryId),
      'label': serializer.toJson<String>(label),
      'type': serializer.toJson<String>(type),
      'secret': serializer.toJson<int>(secret),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'hlc': serializer.toJson<String>(hlc),
    };
  }

  CategoryFieldTemplateRow copyWith({
    String? id,
    String? categoryId,
    String? label,
    String? type,
    int? secret,
    int? sortOrder,
    String? hlc,
  }) => CategoryFieldTemplateRow(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    label: label ?? this.label,
    type: type ?? this.type,
    secret: secret ?? this.secret,
    sortOrder: sortOrder ?? this.sortOrder,
    hlc: hlc ?? this.hlc,
  );
  CategoryFieldTemplateRow copyWithCompanion(
    CategoryFieldTemplatesCompanion data,
  ) {
    return CategoryFieldTemplateRow(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      label: data.label.present ? data.label.value : this.label,
      type: data.type.present ? data.type.value : this.type,
      secret: data.secret.present ? data.secret.value : this.secret,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryFieldTemplateRow(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('label: $label, ')
          ..write('type: $type, ')
          ..write('secret: $secret, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('hlc: $hlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, categoryId, label, type, secret, sortOrder, hlc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryFieldTemplateRow &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.label == this.label &&
          other.type == this.type &&
          other.secret == this.secret &&
          other.sortOrder == this.sortOrder &&
          other.hlc == this.hlc);
}

class CategoryFieldTemplatesCompanion
    extends UpdateCompanion<CategoryFieldTemplateRow> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> label;
  final Value<String> type;
  final Value<int> secret;
  final Value<int> sortOrder;
  final Value<String> hlc;
  final Value<int> rowid;
  const CategoryFieldTemplatesCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.label = const Value.absent(),
    this.type = const Value.absent(),
    this.secret = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryFieldTemplatesCompanion.insert({
    required String id,
    required String categoryId,
    required String label,
    this.type = const Value.absent(),
    this.secret = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required String hlc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       categoryId = Value(categoryId),
       label = Value(label),
       hlc = Value(hlc);
  static Insertable<CategoryFieldTemplateRow> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? label,
    Expression<String>? type,
    Expression<int>? secret,
    Expression<int>? sortOrder,
    Expression<String>? hlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (label != null) 'label': label,
      if (type != null) 'type': type,
      if (secret != null) 'secret': secret,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (hlc != null) 'hlc': hlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryFieldTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? categoryId,
    Value<String>? label,
    Value<String>? type,
    Value<int>? secret,
    Value<int>? sortOrder,
    Value<String>? hlc,
    Value<int>? rowid,
  }) {
    return CategoryFieldTemplatesCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      label: label ?? this.label,
      type: type ?? this.type,
      secret: secret ?? this.secret,
      sortOrder: sortOrder ?? this.sortOrder,
      hlc: hlc ?? this.hlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (secret.present) {
      map['secret'] = Variable<int>(secret.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryFieldTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('label: $label, ')
          ..write('type: $type, ')
          ..write('secret: $secret, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('hlc: $hlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CredentialsTable extends Credentials
    with TableInfo<$CredentialsTable, CredentialRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CredentialsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passwordMeta = const VerificationMeta(
    'password',
  );
  @override
  late final GeneratedColumn<String> password = GeneratedColumn<String>(
    'password',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totpSecretMeta = const VerificationMeta(
    'totpSecret',
  );
  @override
  late final GeneratedColumn<String> totpSecret = GeneratedColumn<String>(
    'totp_secret',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customFieldsMeta = const VerificationMeta(
    'customFields',
  );
  @override
  late final GeneratedColumn<String> customFields = GeneratedColumn<String>(
    'custom_fields',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passwordChangedAtMeta = const VerificationMeta(
    'passwordChangedAt',
  );
  @override
  late final GeneratedColumn<int> passwordChangedAt = GeneratedColumn<int>(
    'password_changed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _breachedMeta = const VerificationMeta(
    'breached',
  );
  @override
  late final GeneratedColumn<int> breached = GeneratedColumn<int>(
    'breached',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    username,
    password,
    totpSecret,
    url,
    notes,
    customFields,
    passwordChangedAt,
    breached,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'credential';
  @override
  VerificationContext validateIntegrity(
    Insertable<CredentialRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('password')) {
      context.handle(
        _passwordMeta,
        password.isAcceptableOrUnknown(data['password']!, _passwordMeta),
      );
    }
    if (data.containsKey('totp_secret')) {
      context.handle(
        _totpSecretMeta,
        totpSecret.isAcceptableOrUnknown(data['totp_secret']!, _totpSecretMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('custom_fields')) {
      context.handle(
        _customFieldsMeta,
        customFields.isAcceptableOrUnknown(
          data['custom_fields']!,
          _customFieldsMeta,
        ),
      );
    }
    if (data.containsKey('password_changed_at')) {
      context.handle(
        _passwordChangedAtMeta,
        passwordChangedAt.isAcceptableOrUnknown(
          data['password_changed_at']!,
          _passwordChangedAtMeta,
        ),
      );
    }
    if (data.containsKey('breached')) {
      context.handle(
        _breachedMeta,
        breached.isAcceptableOrUnknown(data['breached']!, _breachedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CredentialRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CredentialRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      password: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password'],
      ),
      totpSecret: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}totp_secret'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      customFields: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_fields'],
      ),
      passwordChangedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}password_changed_at'],
      ),
      breached: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}breached'],
      )!,
    );
  }

  @override
  $CredentialsTable createAlias(String alias) {
    return $CredentialsTable(attachedDatabase, alias);
  }
}

class CredentialRow extends DataClass implements Insertable<CredentialRow> {
  /// = entry.id
  final String id;
  final String? username;
  final String? password;

  /// Base32 TOTP secret。有值即表示这条带 2FA。
  final String? totpSecret;
  final String? url;

  /// 自由备注。允许 AI 读，但默认 L0 端侧，云端需逐次授权。
  final String? notes;

  /// 自定义字段 JSON 数组，见 docs/13 §4。
  /// `secret:true` 的项与 password 同级加密。
  final String? customFields;

  /// 密码最后一次修改时间，健康报告用它算"超期未改"
  final int? passwordChangedAt;

  /// 是否已泄露（HIBP k-anonymity 结果缓存：0 未知 / 1 安全 / 2 泄露）
  final int breached;
  const CredentialRow({
    required this.id,
    this.username,
    this.password,
    this.totpSecret,
    this.url,
    this.notes,
    this.customFields,
    this.passwordChangedAt,
    required this.breached,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || password != null) {
      map['password'] = Variable<String>(password);
    }
    if (!nullToAbsent || totpSecret != null) {
      map['totp_secret'] = Variable<String>(totpSecret);
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || customFields != null) {
      map['custom_fields'] = Variable<String>(customFields);
    }
    if (!nullToAbsent || passwordChangedAt != null) {
      map['password_changed_at'] = Variable<int>(passwordChangedAt);
    }
    map['breached'] = Variable<int>(breached);
    return map;
  }

  CredentialsCompanion toCompanion(bool nullToAbsent) {
    return CredentialsCompanion(
      id: Value(id),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      password: password == null && nullToAbsent
          ? const Value.absent()
          : Value(password),
      totpSecret: totpSecret == null && nullToAbsent
          ? const Value.absent()
          : Value(totpSecret),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      customFields: customFields == null && nullToAbsent
          ? const Value.absent()
          : Value(customFields),
      passwordChangedAt: passwordChangedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(passwordChangedAt),
      breached: Value(breached),
    );
  }

  factory CredentialRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CredentialRow(
      id: serializer.fromJson<String>(json['id']),
      username: serializer.fromJson<String?>(json['username']),
      password: serializer.fromJson<String?>(json['password']),
      totpSecret: serializer.fromJson<String?>(json['totpSecret']),
      url: serializer.fromJson<String?>(json['url']),
      notes: serializer.fromJson<String?>(json['notes']),
      customFields: serializer.fromJson<String?>(json['customFields']),
      passwordChangedAt: serializer.fromJson<int?>(json['passwordChangedAt']),
      breached: serializer.fromJson<int>(json['breached']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'username': serializer.toJson<String?>(username),
      'password': serializer.toJson<String?>(password),
      'totpSecret': serializer.toJson<String?>(totpSecret),
      'url': serializer.toJson<String?>(url),
      'notes': serializer.toJson<String?>(notes),
      'customFields': serializer.toJson<String?>(customFields),
      'passwordChangedAt': serializer.toJson<int?>(passwordChangedAt),
      'breached': serializer.toJson<int>(breached),
    };
  }

  CredentialRow copyWith({
    String? id,
    Value<String?> username = const Value.absent(),
    Value<String?> password = const Value.absent(),
    Value<String?> totpSecret = const Value.absent(),
    Value<String?> url = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> customFields = const Value.absent(),
    Value<int?> passwordChangedAt = const Value.absent(),
    int? breached,
  }) => CredentialRow(
    id: id ?? this.id,
    username: username.present ? username.value : this.username,
    password: password.present ? password.value : this.password,
    totpSecret: totpSecret.present ? totpSecret.value : this.totpSecret,
    url: url.present ? url.value : this.url,
    notes: notes.present ? notes.value : this.notes,
    customFields: customFields.present ? customFields.value : this.customFields,
    passwordChangedAt: passwordChangedAt.present
        ? passwordChangedAt.value
        : this.passwordChangedAt,
    breached: breached ?? this.breached,
  );
  CredentialRow copyWithCompanion(CredentialsCompanion data) {
    return CredentialRow(
      id: data.id.present ? data.id.value : this.id,
      username: data.username.present ? data.username.value : this.username,
      password: data.password.present ? data.password.value : this.password,
      totpSecret: data.totpSecret.present
          ? data.totpSecret.value
          : this.totpSecret,
      url: data.url.present ? data.url.value : this.url,
      notes: data.notes.present ? data.notes.value : this.notes,
      customFields: data.customFields.present
          ? data.customFields.value
          : this.customFields,
      passwordChangedAt: data.passwordChangedAt.present
          ? data.passwordChangedAt.value
          : this.passwordChangedAt,
      breached: data.breached.present ? data.breached.value : this.breached,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CredentialRow(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('password: $password, ')
          ..write('totpSecret: $totpSecret, ')
          ..write('url: $url, ')
          ..write('notes: $notes, ')
          ..write('customFields: $customFields, ')
          ..write('passwordChangedAt: $passwordChangedAt, ')
          ..write('breached: $breached')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    username,
    password,
    totpSecret,
    url,
    notes,
    customFields,
    passwordChangedAt,
    breached,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CredentialRow &&
          other.id == this.id &&
          other.username == this.username &&
          other.password == this.password &&
          other.totpSecret == this.totpSecret &&
          other.url == this.url &&
          other.notes == this.notes &&
          other.customFields == this.customFields &&
          other.passwordChangedAt == this.passwordChangedAt &&
          other.breached == this.breached);
}

class CredentialsCompanion extends UpdateCompanion<CredentialRow> {
  final Value<String> id;
  final Value<String?> username;
  final Value<String?> password;
  final Value<String?> totpSecret;
  final Value<String?> url;
  final Value<String?> notes;
  final Value<String?> customFields;
  final Value<int?> passwordChangedAt;
  final Value<int> breached;
  final Value<int> rowid;
  const CredentialsCompanion({
    this.id = const Value.absent(),
    this.username = const Value.absent(),
    this.password = const Value.absent(),
    this.totpSecret = const Value.absent(),
    this.url = const Value.absent(),
    this.notes = const Value.absent(),
    this.customFields = const Value.absent(),
    this.passwordChangedAt = const Value.absent(),
    this.breached = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CredentialsCompanion.insert({
    required String id,
    this.username = const Value.absent(),
    this.password = const Value.absent(),
    this.totpSecret = const Value.absent(),
    this.url = const Value.absent(),
    this.notes = const Value.absent(),
    this.customFields = const Value.absent(),
    this.passwordChangedAt = const Value.absent(),
    this.breached = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<CredentialRow> custom({
    Expression<String>? id,
    Expression<String>? username,
    Expression<String>? password,
    Expression<String>? totpSecret,
    Expression<String>? url,
    Expression<String>? notes,
    Expression<String>? customFields,
    Expression<int>? passwordChangedAt,
    Expression<int>? breached,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (totpSecret != null) 'totp_secret': totpSecret,
      if (url != null) 'url': url,
      if (notes != null) 'notes': notes,
      if (customFields != null) 'custom_fields': customFields,
      if (passwordChangedAt != null) 'password_changed_at': passwordChangedAt,
      if (breached != null) 'breached': breached,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CredentialsCompanion copyWith({
    Value<String>? id,
    Value<String?>? username,
    Value<String?>? password,
    Value<String?>? totpSecret,
    Value<String?>? url,
    Value<String?>? notes,
    Value<String?>? customFields,
    Value<int?>? passwordChangedAt,
    Value<int>? breached,
    Value<int>? rowid,
  }) {
    return CredentialsCompanion(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      totpSecret: totpSecret ?? this.totpSecret,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      customFields: customFields ?? this.customFields,
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
      breached: breached ?? this.breached,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (password.present) {
      map['password'] = Variable<String>(password.value);
    }
    if (totpSecret.present) {
      map['totp_secret'] = Variable<String>(totpSecret.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (customFields.present) {
      map['custom_fields'] = Variable<String>(customFields.value);
    }
    if (passwordChangedAt.present) {
      map['password_changed_at'] = Variable<int>(passwordChangedAt.value);
    }
    if (breached.present) {
      map['breached'] = Variable<int>(breached.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CredentialsCompanion(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('password: $password, ')
          ..write('totpSecret: $totpSecret, ')
          ..write('url: $url, ')
          ..write('notes: $notes, ')
          ..write('customFields: $customFields, ')
          ..write('passwordChangedAt: $passwordChangedAt, ')
          ..write('breached: $breached, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, ConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageCountMeta = const VerificationMeta(
    'messageCount',
  );
  @override
  late final GeneratedColumn<int> messageCount = GeneratedColumn<int>(
    'message_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    groupId,
    createdAt,
    updatedAt,
    hlc,
    messageCount,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('message_count')) {
      context.handle(
        _messageCountMeta,
        messageCount.isAcceptableOrUnknown(
          data['message_count']!,
          _messageCountMeta,
        ),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      messageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_count'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class ConversationRow extends DataClass implements Insertable<ConversationRow> {
  final String id;

  /// 默认取首条消息前 20 字
  final String? title;

  /// 可空；空则按日期自动分组
  final String? groupId;
  final int? createdAt;
  final int? updatedAt;
  final String hlc;
  final int messageCount;
  final int deleted;
  const ConversationRow({
    required this.id,
    this.title,
    this.groupId,
    this.createdAt,
    this.updatedAt,
    required this.hlc,
    required this.messageCount,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    map['hlc'] = Variable<String>(hlc);
    map['message_count'] = Variable<int>(messageCount);
    map['deleted'] = Variable<int>(deleted);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      hlc: Value(hlc),
      messageCount: Value(messageCount),
      deleted: Value(deleted),
    );
  }

  factory ConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String?>(json['title']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
      hlc: serializer.fromJson<String>(json['hlc']),
      messageCount: serializer.fromJson<int>(json['messageCount']),
      deleted: serializer.fromJson<int>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String?>(title),
      'groupId': serializer.toJson<String?>(groupId),
      'createdAt': serializer.toJson<int?>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
      'hlc': serializer.toJson<String>(hlc),
      'messageCount': serializer.toJson<int>(messageCount),
      'deleted': serializer.toJson<int>(deleted),
    };
  }

  ConversationRow copyWith({
    String? id,
    Value<String?> title = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
    Value<int?> createdAt = const Value.absent(),
    Value<int?> updatedAt = const Value.absent(),
    String? hlc,
    int? messageCount,
    int? deleted,
  }) => ConversationRow(
    id: id ?? this.id,
    title: title.present ? title.value : this.title,
    groupId: groupId.present ? groupId.value : this.groupId,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    hlc: hlc ?? this.hlc,
    messageCount: messageCount ?? this.messageCount,
    deleted: deleted ?? this.deleted,
  );
  ConversationRow copyWithCompanion(ConversationsCompanion data) {
    return ConversationRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      messageCount: data.messageCount.present
          ? data.messageCount.value
          : this.messageCount,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('groupId: $groupId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hlc: $hlc, ')
          ..write('messageCount: $messageCount, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    groupId,
    createdAt,
    updatedAt,
    hlc,
    messageCount,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.groupId == this.groupId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.hlc == this.hlc &&
          other.messageCount == this.messageCount &&
          other.deleted == this.deleted);
}

class ConversationsCompanion extends UpdateCompanion<ConversationRow> {
  final Value<String> id;
  final Value<String?> title;
  final Value<String?> groupId;
  final Value<int?> createdAt;
  final Value<int?> updatedAt;
  final Value<String> hlc;
  final Value<int> messageCount;
  final Value<int> deleted;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.groupId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.hlc = const Value.absent(),
    this.messageCount = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.groupId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required String hlc,
    this.messageCount = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       hlc = Value(hlc);
  static Insertable<ConversationRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? groupId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? hlc,
    Expression<int>? messageCount,
    Expression<int>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (groupId != null) 'group_id': groupId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (hlc != null) 'hlc': hlc,
      if (messageCount != null) 'message_count': messageCount,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String?>? title,
    Value<String?>? groupId,
    Value<int?>? createdAt,
    Value<int?>? updatedAt,
    Value<String>? hlc,
    Value<int>? messageCount,
    Value<int>? deleted,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hlc: hlc ?? this.hlc,
      messageCount: messageCount ?? this.messageCount,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (messageCount.present) {
      map['message_count'] = Variable<int>(messageCount.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('groupId: $groupId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hlc: $hlc, ')
          ..write('messageCount: $messageCount, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<int> role = GeneratedColumn<int>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toolCallsMeta = const VerificationMeta(
    'toolCalls',
  );
  @override
  late final GeneratedColumn<String> toolCalls = GeneratedColumn<String>(
    'tool_calls',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _citationsMeta = const VerificationMeta(
    'citations',
  );
  @override
  late final GeneratedColumn<String> citations = GeneratedColumn<String>(
    'citations',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    role,
    content,
    toolCalls,
    citations,
    createdAt,
    hlc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('tool_calls')) {
      context.handle(
        _toolCallsMeta,
        toolCalls.isAcceptableOrUnknown(data['tool_calls']!, _toolCallsMeta),
      );
    }
    if (data.containsKey('citations')) {
      context.handle(
        _citationsMeta,
        citations.isAcceptableOrUnknown(data['citations']!, _citationsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      toolCalls: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_calls'],
      ),
      citations: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}citations'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String id;
  final String conversationId;

  /// 1 user / 2 assistant / 3 tool
  final int role;
  final String? content;

  /// JSON：工具调用与结果
  final String? toolCalls;

  /// JSON：entry id 数组，用于"每条结论可点开溯源"
  final String? citations;
  final int? createdAt;
  final String hlc;
  const MessageRow({
    required this.id,
    required this.conversationId,
    required this.role,
    this.content,
    this.toolCalls,
    this.citations,
    this.createdAt,
    required this.hlc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['role'] = Variable<int>(role);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || toolCalls != null) {
      map['tool_calls'] = Variable<String>(toolCalls);
    }
    if (!nullToAbsent || citations != null) {
      map['citations'] = Variable<String>(citations);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    map['hlc'] = Variable<String>(hlc);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      role: Value(role),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      toolCalls: toolCalls == null && nullToAbsent
          ? const Value.absent()
          : Value(toolCalls),
      citations: citations == null && nullToAbsent
          ? const Value.absent()
          : Value(citations),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      hlc: Value(hlc),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      role: serializer.fromJson<int>(json['role']),
      content: serializer.fromJson<String?>(json['content']),
      toolCalls: serializer.fromJson<String?>(json['toolCalls']),
      citations: serializer.fromJson<String?>(json['citations']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      hlc: serializer.fromJson<String>(json['hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'role': serializer.toJson<int>(role),
      'content': serializer.toJson<String?>(content),
      'toolCalls': serializer.toJson<String?>(toolCalls),
      'citations': serializer.toJson<String?>(citations),
      'createdAt': serializer.toJson<int?>(createdAt),
      'hlc': serializer.toJson<String>(hlc),
    };
  }

  MessageRow copyWith({
    String? id,
    String? conversationId,
    int? role,
    Value<String?> content = const Value.absent(),
    Value<String?> toolCalls = const Value.absent(),
    Value<String?> citations = const Value.absent(),
    Value<int?> createdAt = const Value.absent(),
    String? hlc,
  }) => MessageRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    role: role ?? this.role,
    content: content.present ? content.value : this.content,
    toolCalls: toolCalls.present ? toolCalls.value : this.toolCalls,
    citations: citations.present ? citations.value : this.citations,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    hlc: hlc ?? this.hlc,
  );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      toolCalls: data.toolCalls.present ? data.toolCalls.value : this.toolCalls,
      citations: data.citations.present ? data.citations.value : this.citations,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('toolCalls: $toolCalls, ')
          ..write('citations: $citations, ')
          ..write('createdAt: $createdAt, ')
          ..write('hlc: $hlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    role,
    content,
    toolCalls,
    citations,
    createdAt,
    hlc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.toolCalls == this.toolCalls &&
          other.citations == this.citations &&
          other.createdAt == this.createdAt &&
          other.hlc == this.hlc);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<int> role;
  final Value<String?> content;
  final Value<String?> toolCalls;
  final Value<String?> citations;
  final Value<int?> createdAt;
  final Value<String> hlc;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.toolCalls = const Value.absent(),
    this.citations = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String conversationId,
    required int role,
    this.content = const Value.absent(),
    this.toolCalls = const Value.absent(),
    this.citations = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String hlc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       role = Value(role),
       hlc = Value(hlc);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<int>? role,
    Expression<String>? content,
    Expression<String>? toolCalls,
    Expression<String>? citations,
    Expression<int>? createdAt,
    Expression<String>? hlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (toolCalls != null) 'tool_calls': toolCalls,
      if (citations != null) 'citations': citations,
      if (createdAt != null) 'created_at': createdAt,
      if (hlc != null) 'hlc': hlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<int>? role,
    Value<String?>? content,
    Value<String?>? toolCalls,
    Value<String?>? citations,
    Value<int?>? createdAt,
    Value<String>? hlc,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      toolCalls: toolCalls ?? this.toolCalls,
      citations: citations ?? this.citations,
      createdAt: createdAt ?? this.createdAt,
      hlc: hlc ?? this.hlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<int>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (toolCalls.present) {
      map['tool_calls'] = Variable<String>(toolCalls.value);
    }
    if (citations.present) {
      map['citations'] = Variable<String>(citations.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('toolCalls: $toolCalls, ')
          ..write('citations: $citations, ')
          ..write('createdAt: $createdAt, ')
          ..write('hlc: $hlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OplogsTable extends Oplogs with TableInfo<$OplogsTable, OplogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OplogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<int> op = GeneratedColumn<int>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseRevMeta = const VerificationMeta(
    'baseRev',
  );
  @override
  late final GeneratedColumn<int> baseRev = GeneratedColumn<int>(
    'base_rev',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _appliedMeta = const VerificationMeta(
    'applied',
  );
  @override
  late final GeneratedColumn<int> applied = GeneratedColumn<int>(
    'applied',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    hlc,
    deviceId,
    entity,
    entityId,
    op,
    payload,
    baseRev,
    applied,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'oplog';
  @override
  VerificationContext validateIntegrity(
    Insertable<OplogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('base_rev')) {
      context.handle(
        _baseRevMeta,
        baseRev.isAcceptableOrUnknown(data['base_rev']!, _baseRevMeta),
      );
    }
    if (data.containsKey('applied')) {
      context.handle(
        _appliedMeta,
        applied.isAcceptableOrUnknown(data['applied']!, _appliedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  OplogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OplogRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}op'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}payload'],
      ),
      baseRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_rev'],
      ),
      applied: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}applied'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OplogsTable createAlias(String alias) {
    return $OplogsTable(attachedDatabase, alias);
  }
}

class OplogRow extends DataClass implements Insertable<OplogRow> {
  final int seq;
  final String hlc;
  final String deviceId;

  /// entry / category / tag / credential / conversation / message / blob / meta
  final String entity;
  final String entityId;

  /// 1 create / 2 update / 3 delete / 4 restore / 5 merge
  final int op;

  /// 加密后的完整快照
  final Uint8List? payload;

  /// 合并用的基准版本号
  final int? baseRev;

  /// 0 = 待推送，1 = 已推送
  final int applied;
  final int createdAt;
  const OplogRow({
    required this.seq,
    required this.hlc,
    required this.deviceId,
    required this.entity,
    required this.entityId,
    required this.op,
    this.payload,
    this.baseRev,
    required this.applied,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['hlc'] = Variable<String>(hlc);
    map['device_id'] = Variable<String>(deviceId);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['op'] = Variable<int>(op);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<Uint8List>(payload);
    }
    if (!nullToAbsent || baseRev != null) {
      map['base_rev'] = Variable<int>(baseRev);
    }
    map['applied'] = Variable<int>(applied);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  OplogsCompanion toCompanion(bool nullToAbsent) {
    return OplogsCompanion(
      seq: Value(seq),
      hlc: Value(hlc),
      deviceId: Value(deviceId),
      entity: Value(entity),
      entityId: Value(entityId),
      op: Value(op),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      baseRev: baseRev == null && nullToAbsent
          ? const Value.absent()
          : Value(baseRev),
      applied: Value(applied),
      createdAt: Value(createdAt),
    );
  }

  factory OplogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OplogRow(
      seq: serializer.fromJson<int>(json['seq']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      op: serializer.fromJson<int>(json['op']),
      payload: serializer.fromJson<Uint8List?>(json['payload']),
      baseRev: serializer.fromJson<int?>(json['baseRev']),
      applied: serializer.fromJson<int>(json['applied']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'hlc': serializer.toJson<String>(hlc),
      'deviceId': serializer.toJson<String>(deviceId),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'op': serializer.toJson<int>(op),
      'payload': serializer.toJson<Uint8List?>(payload),
      'baseRev': serializer.toJson<int?>(baseRev),
      'applied': serializer.toJson<int>(applied),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  OplogRow copyWith({
    int? seq,
    String? hlc,
    String? deviceId,
    String? entity,
    String? entityId,
    int? op,
    Value<Uint8List?> payload = const Value.absent(),
    Value<int?> baseRev = const Value.absent(),
    int? applied,
    int? createdAt,
  }) => OplogRow(
    seq: seq ?? this.seq,
    hlc: hlc ?? this.hlc,
    deviceId: deviceId ?? this.deviceId,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    op: op ?? this.op,
    payload: payload.present ? payload.value : this.payload,
    baseRev: baseRev.present ? baseRev.value : this.baseRev,
    applied: applied ?? this.applied,
    createdAt: createdAt ?? this.createdAt,
  );
  OplogRow copyWithCompanion(OplogsCompanion data) {
    return OplogRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      op: data.op.present ? data.op.value : this.op,
      payload: data.payload.present ? data.payload.value : this.payload,
      baseRev: data.baseRev.present ? data.baseRev.value : this.baseRev,
      applied: data.applied.present ? data.applied.value : this.applied,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OplogRow(')
          ..write('seq: $seq, ')
          ..write('hlc: $hlc, ')
          ..write('deviceId: $deviceId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('baseRev: $baseRev, ')
          ..write('applied: $applied, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    hlc,
    deviceId,
    entity,
    entityId,
    op,
    $driftBlobEquality.hash(payload),
    baseRev,
    applied,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OplogRow &&
          other.seq == this.seq &&
          other.hlc == this.hlc &&
          other.deviceId == this.deviceId &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.op == this.op &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.baseRev == this.baseRev &&
          other.applied == this.applied &&
          other.createdAt == this.createdAt);
}

class OplogsCompanion extends UpdateCompanion<OplogRow> {
  final Value<int> seq;
  final Value<String> hlc;
  final Value<String> deviceId;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<int> op;
  final Value<Uint8List?> payload;
  final Value<int?> baseRev;
  final Value<int> applied;
  final Value<int> createdAt;
  const OplogsCompanion({
    this.seq = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.op = const Value.absent(),
    this.payload = const Value.absent(),
    this.baseRev = const Value.absent(),
    this.applied = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OplogsCompanion.insert({
    this.seq = const Value.absent(),
    required String hlc,
    required String deviceId,
    required String entity,
    required String entityId,
    required int op,
    this.payload = const Value.absent(),
    this.baseRev = const Value.absent(),
    this.applied = const Value.absent(),
    required int createdAt,
  }) : hlc = Value(hlc),
       deviceId = Value(deviceId),
       entity = Value(entity),
       entityId = Value(entityId),
       op = Value(op),
       createdAt = Value(createdAt);
  static Insertable<OplogRow> custom({
    Expression<int>? seq,
    Expression<String>? hlc,
    Expression<String>? deviceId,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<int>? op,
    Expression<Uint8List>? payload,
    Expression<int>? baseRev,
    Expression<int>? applied,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (hlc != null) 'hlc': hlc,
      if (deviceId != null) 'device_id': deviceId,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (op != null) 'op': op,
      if (payload != null) 'payload': payload,
      if (baseRev != null) 'base_rev': baseRev,
      if (applied != null) 'applied': applied,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OplogsCompanion copyWith({
    Value<int>? seq,
    Value<String>? hlc,
    Value<String>? deviceId,
    Value<String>? entity,
    Value<String>? entityId,
    Value<int>? op,
    Value<Uint8List?>? payload,
    Value<int?>? baseRev,
    Value<int>? applied,
    Value<int>? createdAt,
  }) {
    return OplogsCompanion(
      seq: seq ?? this.seq,
      hlc: hlc ?? this.hlc,
      deviceId: deviceId ?? this.deviceId,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      op: op ?? this.op,
      payload: payload ?? this.payload,
      baseRev: baseRev ?? this.baseRev,
      applied: applied ?? this.applied,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (op.present) {
      map['op'] = Variable<int>(op.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (baseRev.present) {
      map['base_rev'] = Variable<int>(baseRev.value);
    }
    if (applied.present) {
      map['applied'] = Variable<int>(applied.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OplogsCompanion(')
          ..write('seq: $seq, ')
          ..write('hlc: $hlc, ')
          ..write('deviceId: $deviceId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('baseRev: $baseRev, ')
          ..write('applied: $applied, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ActivitiesTable extends Activities
    with TableInfo<$ActivitiesTable, ActivityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dwellMsMeta = const VerificationMeta(
    'dwellMs',
  );
  @override
  late final GeneratedColumn<int> dwellMs = GeneratedColumn<int>(
    'dwell_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extraMeta = const VerificationMeta('extra');
  @override
  late final GeneratedColumn<String> extra = GeneratedColumn<String>(
    'extra',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ts,
    kind,
    entryId,
    dwellMs,
    query,
    extra,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    }
    if (data.containsKey('dwell_ms')) {
      context.handle(
        _dwellMsMeta,
        dwellMs.isAcceptableOrUnknown(data['dwell_ms']!, _dwellMsMeta),
      );
    }
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    }
    if (data.containsKey('extra')) {
      context.handle(
        _extraMeta,
        extra.isAcceptableOrUnknown(data['extra']!, _extraMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ts'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      ),
      dwellMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dwell_ms'],
      ),
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      ),
      extra: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra'],
      ),
    );
  }

  @override
  $ActivitiesTable createAlias(String alias) {
    return $ActivitiesTable(attachedDatabase, alias);
  }
}

class ActivityRow extends DataClass implements Insertable<ActivityRow> {
  final int id;

  /// UTC 毫秒
  final int ts;

  /// 1 view / 2 create / 3 edit / 4 search / 5 clip / 6 archive_view
  final int kind;
  final String? entryId;

  /// 停留时长，用于区分"扫了一眼"和"读了五分钟"
  final int? dwellMs;

  /// 搜索词。**注意这是敏感数据**，日总结只用它做聚类，不外发。
  final String? query;

  /// 其它维度 JSON（来源入口、设备、是否离线等）
  final String? extra;
  const ActivityRow({
    required this.id,
    required this.ts,
    required this.kind,
    this.entryId,
    this.dwellMs,
    this.query,
    this.extra,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ts'] = Variable<int>(ts);
    map['kind'] = Variable<int>(kind);
    if (!nullToAbsent || entryId != null) {
      map['entry_id'] = Variable<String>(entryId);
    }
    if (!nullToAbsent || dwellMs != null) {
      map['dwell_ms'] = Variable<int>(dwellMs);
    }
    if (!nullToAbsent || query != null) {
      map['query'] = Variable<String>(query);
    }
    if (!nullToAbsent || extra != null) {
      map['extra'] = Variable<String>(extra);
    }
    return map;
  }

  ActivitiesCompanion toCompanion(bool nullToAbsent) {
    return ActivitiesCompanion(
      id: Value(id),
      ts: Value(ts),
      kind: Value(kind),
      entryId: entryId == null && nullToAbsent
          ? const Value.absent()
          : Value(entryId),
      dwellMs: dwellMs == null && nullToAbsent
          ? const Value.absent()
          : Value(dwellMs),
      query: query == null && nullToAbsent
          ? const Value.absent()
          : Value(query),
      extra: extra == null && nullToAbsent
          ? const Value.absent()
          : Value(extra),
    );
  }

  factory ActivityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityRow(
      id: serializer.fromJson<int>(json['id']),
      ts: serializer.fromJson<int>(json['ts']),
      kind: serializer.fromJson<int>(json['kind']),
      entryId: serializer.fromJson<String?>(json['entryId']),
      dwellMs: serializer.fromJson<int?>(json['dwellMs']),
      query: serializer.fromJson<String?>(json['query']),
      extra: serializer.fromJson<String?>(json['extra']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ts': serializer.toJson<int>(ts),
      'kind': serializer.toJson<int>(kind),
      'entryId': serializer.toJson<String?>(entryId),
      'dwellMs': serializer.toJson<int?>(dwellMs),
      'query': serializer.toJson<String?>(query),
      'extra': serializer.toJson<String?>(extra),
    };
  }

  ActivityRow copyWith({
    int? id,
    int? ts,
    int? kind,
    Value<String?> entryId = const Value.absent(),
    Value<int?> dwellMs = const Value.absent(),
    Value<String?> query = const Value.absent(),
    Value<String?> extra = const Value.absent(),
  }) => ActivityRow(
    id: id ?? this.id,
    ts: ts ?? this.ts,
    kind: kind ?? this.kind,
    entryId: entryId.present ? entryId.value : this.entryId,
    dwellMs: dwellMs.present ? dwellMs.value : this.dwellMs,
    query: query.present ? query.value : this.query,
    extra: extra.present ? extra.value : this.extra,
  );
  ActivityRow copyWithCompanion(ActivitiesCompanion data) {
    return ActivityRow(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      kind: data.kind.present ? data.kind.value : this.kind,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      dwellMs: data.dwellMs.present ? data.dwellMs.value : this.dwellMs,
      query: data.query.present ? data.query.value : this.query,
      extra: data.extra.present ? data.extra.value : this.extra,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityRow(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('kind: $kind, ')
          ..write('entryId: $entryId, ')
          ..write('dwellMs: $dwellMs, ')
          ..write('query: $query, ')
          ..write('extra: $extra')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ts, kind, entryId, dwellMs, query, extra);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityRow &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.kind == this.kind &&
          other.entryId == this.entryId &&
          other.dwellMs == this.dwellMs &&
          other.query == this.query &&
          other.extra == this.extra);
}

class ActivitiesCompanion extends UpdateCompanion<ActivityRow> {
  final Value<int> id;
  final Value<int> ts;
  final Value<int> kind;
  final Value<String?> entryId;
  final Value<int?> dwellMs;
  final Value<String?> query;
  final Value<String?> extra;
  const ActivitiesCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.kind = const Value.absent(),
    this.entryId = const Value.absent(),
    this.dwellMs = const Value.absent(),
    this.query = const Value.absent(),
    this.extra = const Value.absent(),
  });
  ActivitiesCompanion.insert({
    this.id = const Value.absent(),
    required int ts,
    required int kind,
    this.entryId = const Value.absent(),
    this.dwellMs = const Value.absent(),
    this.query = const Value.absent(),
    this.extra = const Value.absent(),
  }) : ts = Value(ts),
       kind = Value(kind);
  static Insertable<ActivityRow> custom({
    Expression<int>? id,
    Expression<int>? ts,
    Expression<int>? kind,
    Expression<String>? entryId,
    Expression<int>? dwellMs,
    Expression<String>? query,
    Expression<String>? extra,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (kind != null) 'kind': kind,
      if (entryId != null) 'entry_id': entryId,
      if (dwellMs != null) 'dwell_ms': dwellMs,
      if (query != null) 'query': query,
      if (extra != null) 'extra': extra,
    });
  }

  ActivitiesCompanion copyWith({
    Value<int>? id,
    Value<int>? ts,
    Value<int>? kind,
    Value<String?>? entryId,
    Value<int?>? dwellMs,
    Value<String?>? query,
    Value<String?>? extra,
  }) {
    return ActivitiesCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      kind: kind ?? this.kind,
      entryId: entryId ?? this.entryId,
      dwellMs: dwellMs ?? this.dwellMs,
      query: query ?? this.query,
      extra: extra ?? this.extra,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (dwellMs.present) {
      map['dwell_ms'] = Variable<int>(dwellMs.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (extra.present) {
      map['extra'] = Variable<String>(extra.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitiesCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('kind: $kind, ')
          ..write('entryId: $entryId, ')
          ..write('dwellMs: $dwellMs, ')
          ..write('query: $query, ')
          ..write('extra: $extra')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [path, etag, size, hlc, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      ),
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  /// 云端相对路径，如 `items/a/3f9c....enc`
  final String path;
  final String? etag;
  final int? size;

  /// 本地见到的该文件最大 hlc
  final String? hlc;
  final int? updatedAt;
  const SyncStateRow({
    required this.path,
    this.etag,
    this.size,
    this.hlc,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    if (!nullToAbsent || hlc != null) {
      map['hlc'] = Variable<String>(hlc);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      path: Value(path),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      hlc: hlc == null && nullToAbsent ? const Value.absent() : Value(hlc),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      path: serializer.fromJson<String>(json['path']),
      etag: serializer.fromJson<String?>(json['etag']),
      size: serializer.fromJson<int?>(json['size']),
      hlc: serializer.fromJson<String?>(json['hlc']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'etag': serializer.toJson<String?>(etag),
      'size': serializer.toJson<int?>(size),
      'hlc': serializer.toJson<String?>(hlc),
      'updatedAt': serializer.toJson<int?>(updatedAt),
    };
  }

  SyncStateRow copyWith({
    String? path,
    Value<String?> etag = const Value.absent(),
    Value<int?> size = const Value.absent(),
    Value<String?> hlc = const Value.absent(),
    Value<int?> updatedAt = const Value.absent(),
  }) => SyncStateRow(
    path: path ?? this.path,
    etag: etag.present ? etag.value : this.etag,
    size: size.present ? size.value : this.size,
    hlc: hlc.present ? hlc.value : this.hlc,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  SyncStateRow copyWithCompanion(SyncStatesCompanion data) {
    return SyncStateRow(
      path: data.path.present ? data.path.value : this.path,
      etag: data.etag.present ? data.etag.value : this.etag,
      size: data.size.present ? data.size.value : this.size,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('path: $path, ')
          ..write('etag: $etag, ')
          ..write('size: $size, ')
          ..write('hlc: $hlc, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, etag, size, hlc, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.path == this.path &&
          other.etag == this.etag &&
          other.size == this.size &&
          other.hlc == this.hlc &&
          other.updatedAt == this.updatedAt);
}

class SyncStatesCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> path;
  final Value<String?> etag;
  final Value<int?> size;
  final Value<String?> hlc;
  final Value<int?> updatedAt;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.path = const Value.absent(),
    this.etag = const Value.absent(),
    this.size = const Value.absent(),
    this.hlc = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String path,
    this.etag = const Value.absent(),
    this.size = const Value.absent(),
    this.hlc = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path);
  static Insertable<SyncStateRow> custom({
    Expression<String>? path,
    Expression<String>? etag,
    Expression<int>? size,
    Expression<String>? hlc,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (etag != null) 'etag': etag,
      if (size != null) 'size': size,
      if (hlc != null) 'hlc': hlc,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? path,
    Value<String?>? etag,
    Value<int?>? size,
    Value<String?>? hlc,
    Value<int?>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      path: path ?? this.path,
      etag: etag ?? this.etag,
      size: size ?? this.size,
      hlc: hlc ?? this.hlc,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('path: $path, ')
          ..write('etag: $etag, ')
          ..write('size: $size, ')
          ..write('hlc: $hlc, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceWatermarksTable extends DeviceWatermarks
    with TableInfo<$DeviceWatermarksTable, DeviceWatermarkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceWatermarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxHlcMeta = const VerificationMeta('maxHlc');
  @override
  late final GeneratedColumn<String> maxHlc = GeneratedColumn<String>(
    'max_hlc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<int> lastSeen = GeneratedColumn<int>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _appVersionMeta = const VerificationMeta(
    'appVersion',
  );
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
    'app_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    maxHlc,
    lastSeen,
    platform,
    appVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_watermark';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceWatermarkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('max_hlc')) {
      context.handle(
        _maxHlcMeta,
        maxHlc.isAcceptableOrUnknown(data['max_hlc']!, _maxHlcMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    }
    if (data.containsKey('app_version')) {
      context.handle(
        _appVersionMeta,
        appVersion.isAcceptableOrUnknown(data['app_version']!, _appVersionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  DeviceWatermarkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceWatermarkRow(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      maxHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}max_hlc'],
      ),
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen'],
      ),
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      ),
      appVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_version'],
      ),
    );
  }

  @override
  $DeviceWatermarksTable createAlias(String alias) {
    return $DeviceWatermarksTable(attachedDatabase, alias);
  }
}

class DeviceWatermarkRow extends DataClass
    implements Insertable<DeviceWatermarkRow> {
  final String deviceId;
  final String? maxHlc;
  final int? lastSeen;
  final String? platform;
  final String? appVersion;
  const DeviceWatermarkRow({
    required this.deviceId,
    this.maxHlc,
    this.lastSeen,
    this.platform,
    this.appVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || maxHlc != null) {
      map['max_hlc'] = Variable<String>(maxHlc);
    }
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<int>(lastSeen);
    }
    if (!nullToAbsent || platform != null) {
      map['platform'] = Variable<String>(platform);
    }
    if (!nullToAbsent || appVersion != null) {
      map['app_version'] = Variable<String>(appVersion);
    }
    return map;
  }

  DeviceWatermarksCompanion toCompanion(bool nullToAbsent) {
    return DeviceWatermarksCompanion(
      deviceId: Value(deviceId),
      maxHlc: maxHlc == null && nullToAbsent
          ? const Value.absent()
          : Value(maxHlc),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
      platform: platform == null && nullToAbsent
          ? const Value.absent()
          : Value(platform),
      appVersion: appVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(appVersion),
    );
  }

  factory DeviceWatermarkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceWatermarkRow(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      maxHlc: serializer.fromJson<String?>(json['maxHlc']),
      lastSeen: serializer.fromJson<int?>(json['lastSeen']),
      platform: serializer.fromJson<String?>(json['platform']),
      appVersion: serializer.fromJson<String?>(json['appVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'maxHlc': serializer.toJson<String?>(maxHlc),
      'lastSeen': serializer.toJson<int?>(lastSeen),
      'platform': serializer.toJson<String?>(platform),
      'appVersion': serializer.toJson<String?>(appVersion),
    };
  }

  DeviceWatermarkRow copyWith({
    String? deviceId,
    Value<String?> maxHlc = const Value.absent(),
    Value<int?> lastSeen = const Value.absent(),
    Value<String?> platform = const Value.absent(),
    Value<String?> appVersion = const Value.absent(),
  }) => DeviceWatermarkRow(
    deviceId: deviceId ?? this.deviceId,
    maxHlc: maxHlc.present ? maxHlc.value : this.maxHlc,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
    platform: platform.present ? platform.value : this.platform,
    appVersion: appVersion.present ? appVersion.value : this.appVersion,
  );
  DeviceWatermarkRow copyWithCompanion(DeviceWatermarksCompanion data) {
    return DeviceWatermarkRow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      maxHlc: data.maxHlc.present ? data.maxHlc.value : this.maxHlc,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      platform: data.platform.present ? data.platform.value : this.platform,
      appVersion: data.appVersion.present
          ? data.appVersion.value
          : this.appVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceWatermarkRow(')
          ..write('deviceId: $deviceId, ')
          ..write('maxHlc: $maxHlc, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('platform: $platform, ')
          ..write('appVersion: $appVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(deviceId, maxHlc, lastSeen, platform, appVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceWatermarkRow &&
          other.deviceId == this.deviceId &&
          other.maxHlc == this.maxHlc &&
          other.lastSeen == this.lastSeen &&
          other.platform == this.platform &&
          other.appVersion == this.appVersion);
}

class DeviceWatermarksCompanion extends UpdateCompanion<DeviceWatermarkRow> {
  final Value<String> deviceId;
  final Value<String?> maxHlc;
  final Value<int?> lastSeen;
  final Value<String?> platform;
  final Value<String?> appVersion;
  final Value<int> rowid;
  const DeviceWatermarksCompanion({
    this.deviceId = const Value.absent(),
    this.maxHlc = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.platform = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceWatermarksCompanion.insert({
    required String deviceId,
    this.maxHlc = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.platform = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId);
  static Insertable<DeviceWatermarkRow> custom({
    Expression<String>? deviceId,
    Expression<String>? maxHlc,
    Expression<int>? lastSeen,
    Expression<String>? platform,
    Expression<String>? appVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (maxHlc != null) 'max_hlc': maxHlc,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (platform != null) 'platform': platform,
      if (appVersion != null) 'app_version': appVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceWatermarksCompanion copyWith({
    Value<String>? deviceId,
    Value<String?>? maxHlc,
    Value<int?>? lastSeen,
    Value<String?>? platform,
    Value<String?>? appVersion,
    Value<int>? rowid,
  }) {
    return DeviceWatermarksCompanion(
      deviceId: deviceId ?? this.deviceId,
      maxHlc: maxHlc ?? this.maxHlc,
      lastSeen: lastSeen ?? this.lastSeen,
      platform: platform ?? this.platform,
      appVersion: appVersion ?? this.appVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (maxHlc.present) {
      map['max_hlc'] = Variable<String>(maxHlc.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<int>(lastSeen.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceWatermarksCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('maxHlc: $maxHlc, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('platform: $platform, ')
          ..write('appVersion: $appVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncLogsTable extends SyncLogs
    with TableInfo<$SyncLogsTable, SyncLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<int> finishedAt = GeneratedColumn<int>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _triggerMeta = const VerificationMeta(
    'trigger',
  );
  @override
  late final GeneratedColumn<String> trigger = GeneratedColumn<String>(
    'trigger',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pulledMeta = const VerificationMeta('pulled');
  @override
  late final GeneratedColumn<int> pulled = GeneratedColumn<int>(
    'pulled',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pushedMeta = const VerificationMeta('pushed');
  @override
  late final GeneratedColumn<int> pushed = GeneratedColumn<int>(
    'pushed',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conflictsMeta = const VerificationMeta(
    'conflicts',
  );
  @override
  late final GeneratedColumn<int> conflicts = GeneratedColumn<int>(
    'conflicts',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMsgMeta = const VerificationMeta(
    'errorMsg',
  );
  @override
  late final GeneratedColumn<String> errorMsg = GeneratedColumn<String>(
    'error_msg',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestCountMeta = const VerificationMeta(
    'requestCount',
  );
  @override
  late final GeneratedColumn<int> requestCount = GeneratedColumn<int>(
    'request_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    finishedAt,
    trigger,
    result,
    pulled,
    pushed,
    conflicts,
    errorCode,
    errorMsg,
    requestCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('trigger')) {
      context.handle(
        _triggerMeta,
        trigger.isAcceptableOrUnknown(data['trigger']!, _triggerMeta),
      );
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    if (data.containsKey('pulled')) {
      context.handle(
        _pulledMeta,
        pulled.isAcceptableOrUnknown(data['pulled']!, _pulledMeta),
      );
    }
    if (data.containsKey('pushed')) {
      context.handle(
        _pushedMeta,
        pushed.isAcceptableOrUnknown(data['pushed']!, _pushedMeta),
      );
    }
    if (data.containsKey('conflicts')) {
      context.handle(
        _conflictsMeta,
        conflicts.isAcceptableOrUnknown(data['conflicts']!, _conflictsMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_msg')) {
      context.handle(
        _errorMsgMeta,
        errorMsg.isAcceptableOrUnknown(data['error_msg']!, _errorMsgMeta),
      );
    }
    if (data.containsKey('request_count')) {
      context.handle(
        _requestCountMeta,
        requestCount.isAcceptableOrUnknown(
          data['request_count']!,
          _requestCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finished_at'],
      ),
      trigger: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger'],
      ),
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      ),
      pulled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pulled'],
      ),
      pushed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pushed'],
      ),
      conflicts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}conflicts'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMsg: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_msg'],
      ),
      requestCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}request_count'],
      ),
    );
  }

  @override
  $SyncLogsTable createAlias(String alias) {
    return $SyncLogsTable(attachedDatabase, alias);
  }
}

class SyncLogRow extends DataClass implements Insertable<SyncLogRow> {
  final int id;
  final int? startedAt;
  final int? finishedAt;

  /// manual / foreground / debounce / timer / background
  final String? trigger;

  /// ok / partial / failed / cancelled
  final String? result;
  final int? pulled;
  final int? pushed;
  final int? conflicts;
  final String? errorCode;
  final String? errorMsg;
  final int? requestCount;
  const SyncLogRow({
    required this.id,
    this.startedAt,
    this.finishedAt,
    this.trigger,
    this.result,
    this.pulled,
    this.pushed,
    this.conflicts,
    this.errorCode,
    this.errorMsg,
    this.requestCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<int>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<int>(finishedAt);
    }
    if (!nullToAbsent || trigger != null) {
      map['trigger'] = Variable<String>(trigger);
    }
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    if (!nullToAbsent || pulled != null) {
      map['pulled'] = Variable<int>(pulled);
    }
    if (!nullToAbsent || pushed != null) {
      map['pushed'] = Variable<int>(pushed);
    }
    if (!nullToAbsent || conflicts != null) {
      map['conflicts'] = Variable<int>(conflicts);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMsg != null) {
      map['error_msg'] = Variable<String>(errorMsg);
    }
    if (!nullToAbsent || requestCount != null) {
      map['request_count'] = Variable<int>(requestCount);
    }
    return map;
  }

  SyncLogsCompanion toCompanion(bool nullToAbsent) {
    return SyncLogsCompanion(
      id: Value(id),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      trigger: trigger == null && nullToAbsent
          ? const Value.absent()
          : Value(trigger),
      result: result == null && nullToAbsent
          ? const Value.absent()
          : Value(result),
      pulled: pulled == null && nullToAbsent
          ? const Value.absent()
          : Value(pulled),
      pushed: pushed == null && nullToAbsent
          ? const Value.absent()
          : Value(pushed),
      conflicts: conflicts == null && nullToAbsent
          ? const Value.absent()
          : Value(conflicts),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMsg: errorMsg == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMsg),
      requestCount: requestCount == null && nullToAbsent
          ? const Value.absent()
          : Value(requestCount),
    );
  }

  factory SyncLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncLogRow(
      id: serializer.fromJson<int>(json['id']),
      startedAt: serializer.fromJson<int?>(json['startedAt']),
      finishedAt: serializer.fromJson<int?>(json['finishedAt']),
      trigger: serializer.fromJson<String?>(json['trigger']),
      result: serializer.fromJson<String?>(json['result']),
      pulled: serializer.fromJson<int?>(json['pulled']),
      pushed: serializer.fromJson<int?>(json['pushed']),
      conflicts: serializer.fromJson<int?>(json['conflicts']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMsg: serializer.fromJson<String?>(json['errorMsg']),
      requestCount: serializer.fromJson<int?>(json['requestCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAt': serializer.toJson<int?>(startedAt),
      'finishedAt': serializer.toJson<int?>(finishedAt),
      'trigger': serializer.toJson<String?>(trigger),
      'result': serializer.toJson<String?>(result),
      'pulled': serializer.toJson<int?>(pulled),
      'pushed': serializer.toJson<int?>(pushed),
      'conflicts': serializer.toJson<int?>(conflicts),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMsg': serializer.toJson<String?>(errorMsg),
      'requestCount': serializer.toJson<int?>(requestCount),
    };
  }

  SyncLogRow copyWith({
    int? id,
    Value<int?> startedAt = const Value.absent(),
    Value<int?> finishedAt = const Value.absent(),
    Value<String?> trigger = const Value.absent(),
    Value<String?> result = const Value.absent(),
    Value<int?> pulled = const Value.absent(),
    Value<int?> pushed = const Value.absent(),
    Value<int?> conflicts = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMsg = const Value.absent(),
    Value<int?> requestCount = const Value.absent(),
  }) => SyncLogRow(
    id: id ?? this.id,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    trigger: trigger.present ? trigger.value : this.trigger,
    result: result.present ? result.value : this.result,
    pulled: pulled.present ? pulled.value : this.pulled,
    pushed: pushed.present ? pushed.value : this.pushed,
    conflicts: conflicts.present ? conflicts.value : this.conflicts,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMsg: errorMsg.present ? errorMsg.value : this.errorMsg,
    requestCount: requestCount.present ? requestCount.value : this.requestCount,
  );
  SyncLogRow copyWithCompanion(SyncLogsCompanion data) {
    return SyncLogRow(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      trigger: data.trigger.present ? data.trigger.value : this.trigger,
      result: data.result.present ? data.result.value : this.result,
      pulled: data.pulled.present ? data.pulled.value : this.pulled,
      pushed: data.pushed.present ? data.pushed.value : this.pushed,
      conflicts: data.conflicts.present ? data.conflicts.value : this.conflicts,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMsg: data.errorMsg.present ? data.errorMsg.value : this.errorMsg,
      requestCount: data.requestCount.present
          ? data.requestCount.value
          : this.requestCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogRow(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('trigger: $trigger, ')
          ..write('result: $result, ')
          ..write('pulled: $pulled, ')
          ..write('pushed: $pushed, ')
          ..write('conflicts: $conflicts, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMsg: $errorMsg, ')
          ..write('requestCount: $requestCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    finishedAt,
    trigger,
    result,
    pulled,
    pushed,
    conflicts,
    errorCode,
    errorMsg,
    requestCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncLogRow &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.trigger == this.trigger &&
          other.result == this.result &&
          other.pulled == this.pulled &&
          other.pushed == this.pushed &&
          other.conflicts == this.conflicts &&
          other.errorCode == this.errorCode &&
          other.errorMsg == this.errorMsg &&
          other.requestCount == this.requestCount);
}

class SyncLogsCompanion extends UpdateCompanion<SyncLogRow> {
  final Value<int> id;
  final Value<int?> startedAt;
  final Value<int?> finishedAt;
  final Value<String?> trigger;
  final Value<String?> result;
  final Value<int?> pulled;
  final Value<int?> pushed;
  final Value<int?> conflicts;
  final Value<String?> errorCode;
  final Value<String?> errorMsg;
  final Value<int?> requestCount;
  const SyncLogsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.trigger = const Value.absent(),
    this.result = const Value.absent(),
    this.pulled = const Value.absent(),
    this.pushed = const Value.absent(),
    this.conflicts = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMsg = const Value.absent(),
    this.requestCount = const Value.absent(),
  });
  SyncLogsCompanion.insert({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.trigger = const Value.absent(),
    this.result = const Value.absent(),
    this.pulled = const Value.absent(),
    this.pushed = const Value.absent(),
    this.conflicts = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMsg = const Value.absent(),
    this.requestCount = const Value.absent(),
  });
  static Insertable<SyncLogRow> custom({
    Expression<int>? id,
    Expression<int>? startedAt,
    Expression<int>? finishedAt,
    Expression<String>? trigger,
    Expression<String>? result,
    Expression<int>? pulled,
    Expression<int>? pushed,
    Expression<int>? conflicts,
    Expression<String>? errorCode,
    Expression<String>? errorMsg,
    Expression<int>? requestCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (trigger != null) 'trigger': trigger,
      if (result != null) 'result': result,
      if (pulled != null) 'pulled': pulled,
      if (pushed != null) 'pushed': pushed,
      if (conflicts != null) 'conflicts': conflicts,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMsg != null) 'error_msg': errorMsg,
      if (requestCount != null) 'request_count': requestCount,
    });
  }

  SyncLogsCompanion copyWith({
    Value<int>? id,
    Value<int?>? startedAt,
    Value<int?>? finishedAt,
    Value<String?>? trigger,
    Value<String?>? result,
    Value<int?>? pulled,
    Value<int?>? pushed,
    Value<int?>? conflicts,
    Value<String?>? errorCode,
    Value<String?>? errorMsg,
    Value<int?>? requestCount,
  }) {
    return SyncLogsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      trigger: trigger ?? this.trigger,
      result: result ?? this.result,
      pulled: pulled ?? this.pulled,
      pushed: pushed ?? this.pushed,
      conflicts: conflicts ?? this.conflicts,
      errorCode: errorCode ?? this.errorCode,
      errorMsg: errorMsg ?? this.errorMsg,
      requestCount: requestCount ?? this.requestCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<int>(finishedAt.value);
    }
    if (trigger.present) {
      map['trigger'] = Variable<String>(trigger.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (pulled.present) {
      map['pulled'] = Variable<int>(pulled.value);
    }
    if (pushed.present) {
      map['pushed'] = Variable<int>(pushed.value);
    }
    if (conflicts.present) {
      map['conflicts'] = Variable<int>(conflicts.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMsg.present) {
      map['error_msg'] = Variable<String>(errorMsg.value);
    }
    if (requestCount.present) {
      map['request_count'] = Variable<int>(requestCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('trigger: $trigger, ')
          ..write('result: $result, ')
          ..write('pulled: $pulled, ')
          ..write('pushed: $pushed, ')
          ..write('conflicts: $conflicts, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMsg: $errorMsg, ')
          ..write('requestCount: $requestCount')
          ..write(')'))
        .toString();
  }
}

class $DiaryIndexesTable extends DiaryIndexes
    with TableInfo<$DiaryIndexesTable, DiaryIndexRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryIndexesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userEntryIdMeta = const VerificationMeta(
    'userEntryId',
  );
  @override
  late final GeneratedColumn<String> userEntryId = GeneratedColumn<String>(
    'user_entry_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiEntryIdMeta = const VerificationMeta(
    'aiEntryId',
  );
  @override
  late final GeneratedColumn<String> aiEntryId = GeneratedColumn<String>(
    'ai_entry_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hasMoodMeta = const VerificationMeta(
    'hasMood',
  );
  @override
  late final GeneratedColumn<int> hasMood = GeneratedColumn<int>(
    'has_mood',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    userEntryId,
    aiEntryId,
    wordCount,
    hasMood,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_index';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryIndexRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('user_entry_id')) {
      context.handle(
        _userEntryIdMeta,
        userEntryId.isAcceptableOrUnknown(
          data['user_entry_id']!,
          _userEntryIdMeta,
        ),
      );
    }
    if (data.containsKey('ai_entry_id')) {
      context.handle(
        _aiEntryIdMeta,
        aiEntryId.isAcceptableOrUnknown(data['ai_entry_id']!, _aiEntryIdMeta),
      );
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('has_mood')) {
      context.handle(
        _hasMoodMeta,
        hasMood.isAcceptableOrUnknown(data['has_mood']!, _hasMoodMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  DiaryIndexRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryIndexRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      userEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_entry_id'],
      ),
      aiEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_entry_id'],
      ),
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      hasMood: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}has_mood'],
      )!,
    );
  }

  @override
  $DiaryIndexesTable createAlias(String alias) {
    return $DiaryIndexesTable(attachedDatabase, alias);
  }
}

class DiaryIndexRow extends DataClass implements Insertable<DiaryIndexRow> {
  /// YYYY-MM-DD（本地时区）。**不能用 created_at 推** ——
  /// 补写、跨时区、"凌晨两点写的算前一天"都要求日期是显式字段。
  final String date;

  /// kind=3
  final String? userEntryId;

  /// kind=4
  final String? aiEntryId;
  final int wordCount;
  final int hasMood;
  const DiaryIndexRow({
    required this.date,
    this.userEntryId,
    this.aiEntryId,
    required this.wordCount,
    required this.hasMood,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || userEntryId != null) {
      map['user_entry_id'] = Variable<String>(userEntryId);
    }
    if (!nullToAbsent || aiEntryId != null) {
      map['ai_entry_id'] = Variable<String>(aiEntryId);
    }
    map['word_count'] = Variable<int>(wordCount);
    map['has_mood'] = Variable<int>(hasMood);
    return map;
  }

  DiaryIndexesCompanion toCompanion(bool nullToAbsent) {
    return DiaryIndexesCompanion(
      date: Value(date),
      userEntryId: userEntryId == null && nullToAbsent
          ? const Value.absent()
          : Value(userEntryId),
      aiEntryId: aiEntryId == null && nullToAbsent
          ? const Value.absent()
          : Value(aiEntryId),
      wordCount: Value(wordCount),
      hasMood: Value(hasMood),
    );
  }

  factory DiaryIndexRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryIndexRow(
      date: serializer.fromJson<String>(json['date']),
      userEntryId: serializer.fromJson<String?>(json['userEntryId']),
      aiEntryId: serializer.fromJson<String?>(json['aiEntryId']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      hasMood: serializer.fromJson<int>(json['hasMood']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'userEntryId': serializer.toJson<String?>(userEntryId),
      'aiEntryId': serializer.toJson<String?>(aiEntryId),
      'wordCount': serializer.toJson<int>(wordCount),
      'hasMood': serializer.toJson<int>(hasMood),
    };
  }

  DiaryIndexRow copyWith({
    String? date,
    Value<String?> userEntryId = const Value.absent(),
    Value<String?> aiEntryId = const Value.absent(),
    int? wordCount,
    int? hasMood,
  }) => DiaryIndexRow(
    date: date ?? this.date,
    userEntryId: userEntryId.present ? userEntryId.value : this.userEntryId,
    aiEntryId: aiEntryId.present ? aiEntryId.value : this.aiEntryId,
    wordCount: wordCount ?? this.wordCount,
    hasMood: hasMood ?? this.hasMood,
  );
  DiaryIndexRow copyWithCompanion(DiaryIndexesCompanion data) {
    return DiaryIndexRow(
      date: data.date.present ? data.date.value : this.date,
      userEntryId: data.userEntryId.present
          ? data.userEntryId.value
          : this.userEntryId,
      aiEntryId: data.aiEntryId.present ? data.aiEntryId.value : this.aiEntryId,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      hasMood: data.hasMood.present ? data.hasMood.value : this.hasMood,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryIndexRow(')
          ..write('date: $date, ')
          ..write('userEntryId: $userEntryId, ')
          ..write('aiEntryId: $aiEntryId, ')
          ..write('wordCount: $wordCount, ')
          ..write('hasMood: $hasMood')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(date, userEntryId, aiEntryId, wordCount, hasMood);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryIndexRow &&
          other.date == this.date &&
          other.userEntryId == this.userEntryId &&
          other.aiEntryId == this.aiEntryId &&
          other.wordCount == this.wordCount &&
          other.hasMood == this.hasMood);
}

class DiaryIndexesCompanion extends UpdateCompanion<DiaryIndexRow> {
  final Value<String> date;
  final Value<String?> userEntryId;
  final Value<String?> aiEntryId;
  final Value<int> wordCount;
  final Value<int> hasMood;
  final Value<int> rowid;
  const DiaryIndexesCompanion({
    this.date = const Value.absent(),
    this.userEntryId = const Value.absent(),
    this.aiEntryId = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.hasMood = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryIndexesCompanion.insert({
    required String date,
    this.userEntryId = const Value.absent(),
    this.aiEntryId = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.hasMood = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date);
  static Insertable<DiaryIndexRow> custom({
    Expression<String>? date,
    Expression<String>? userEntryId,
    Expression<String>? aiEntryId,
    Expression<int>? wordCount,
    Expression<int>? hasMood,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (userEntryId != null) 'user_entry_id': userEntryId,
      if (aiEntryId != null) 'ai_entry_id': aiEntryId,
      if (wordCount != null) 'word_count': wordCount,
      if (hasMood != null) 'has_mood': hasMood,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryIndexesCompanion copyWith({
    Value<String>? date,
    Value<String?>? userEntryId,
    Value<String?>? aiEntryId,
    Value<int>? wordCount,
    Value<int>? hasMood,
    Value<int>? rowid,
  }) {
    return DiaryIndexesCompanion(
      date: date ?? this.date,
      userEntryId: userEntryId ?? this.userEntryId,
      aiEntryId: aiEntryId ?? this.aiEntryId,
      wordCount: wordCount ?? this.wordCount,
      hasMood: hasMood ?? this.hasMood,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (userEntryId.present) {
      map['user_entry_id'] = Variable<String>(userEntryId.value);
    }
    if (aiEntryId.present) {
      map['ai_entry_id'] = Variable<String>(aiEntryId.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (hasMood.present) {
      map['has_mood'] = Variable<int>(hasMood.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryIndexesCompanion(')
          ..write('date: $date, ')
          ..write('userEntryId: $userEntryId, ')
          ..write('aiEntryId: $aiEntryId, ')
          ..write('wordCount: $wordCount, ')
          ..write('hasMood: $hasMood, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntryVecsTable extends EntryVecs
    with TableInfo<$EntryVecsTable, EntryVecRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryVecsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chunkIdxMeta = const VerificationMeta(
    'chunkIdx',
  );
  @override
  late final GeneratedColumn<int> chunkIdx = GeneratedColumn<int>(
    'chunk_idx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimMeta = const VerificationMeta('dim');
  @override
  late final GeneratedColumn<int> dim = GeneratedColumn<int>(
    'dim',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vecMeta = const VerificationMeta('vec');
  @override
  late final GeneratedColumn<Uint8List> vec = GeneratedColumn<Uint8List>(
    'vec',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _computedAtMeta = const VerificationMeta(
    'computedAt',
  );
  @override
  late final GeneratedColumn<int> computedAt = GeneratedColumn<int>(
    'computed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    chunkIdx,
    modelId,
    dim,
    vec,
    computedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_vec';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryVecRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('chunk_idx')) {
      context.handle(
        _chunkIdxMeta,
        chunkIdx.isAcceptableOrUnknown(data['chunk_idx']!, _chunkIdxMeta),
      );
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('dim')) {
      context.handle(
        _dimMeta,
        dim.isAcceptableOrUnknown(data['dim']!, _dimMeta),
      );
    } else if (isInserting) {
      context.missing(_dimMeta);
    }
    if (data.containsKey('vec')) {
      context.handle(
        _vecMeta,
        vec.isAcceptableOrUnknown(data['vec']!, _vecMeta),
      );
    } else if (isInserting) {
      context.missing(_vecMeta);
    }
    if (data.containsKey('computed_at')) {
      context.handle(
        _computedAtMeta,
        computedAt.isAcceptableOrUnknown(data['computed_at']!, _computedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_computedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, chunkIdx};
  @override
  EntryVecRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryVecRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      chunkIdx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_idx'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      dim: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dim'],
      )!,
      vec: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}vec'],
      )!,
      computedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}computed_at'],
      )!,
    );
  }

  @override
  $EntryVecsTable createAlias(String alias) {
    return $EntryVecsTable(attachedDatabase, alias);
  }
}

class EntryVecRow extends DataClass implements Insertable<EntryVecRow> {
  final String entryId;

  /// 长文分块序号
  final int chunkIdx;
  final String modelId;
  final int dim;

  /// int8 量化。768 维 × 1 字节 = 768B/条
  final Uint8List vec;
  final int computedAt;
  const EntryVecRow({
    required this.entryId,
    required this.chunkIdx,
    required this.modelId,
    required this.dim,
    required this.vec,
    required this.computedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['chunk_idx'] = Variable<int>(chunkIdx);
    map['model_id'] = Variable<String>(modelId);
    map['dim'] = Variable<int>(dim);
    map['vec'] = Variable<Uint8List>(vec);
    map['computed_at'] = Variable<int>(computedAt);
    return map;
  }

  EntryVecsCompanion toCompanion(bool nullToAbsent) {
    return EntryVecsCompanion(
      entryId: Value(entryId),
      chunkIdx: Value(chunkIdx),
      modelId: Value(modelId),
      dim: Value(dim),
      vec: Value(vec),
      computedAt: Value(computedAt),
    );
  }

  factory EntryVecRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryVecRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      chunkIdx: serializer.fromJson<int>(json['chunkIdx']),
      modelId: serializer.fromJson<String>(json['modelId']),
      dim: serializer.fromJson<int>(json['dim']),
      vec: serializer.fromJson<Uint8List>(json['vec']),
      computedAt: serializer.fromJson<int>(json['computedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'chunkIdx': serializer.toJson<int>(chunkIdx),
      'modelId': serializer.toJson<String>(modelId),
      'dim': serializer.toJson<int>(dim),
      'vec': serializer.toJson<Uint8List>(vec),
      'computedAt': serializer.toJson<int>(computedAt),
    };
  }

  EntryVecRow copyWith({
    String? entryId,
    int? chunkIdx,
    String? modelId,
    int? dim,
    Uint8List? vec,
    int? computedAt,
  }) => EntryVecRow(
    entryId: entryId ?? this.entryId,
    chunkIdx: chunkIdx ?? this.chunkIdx,
    modelId: modelId ?? this.modelId,
    dim: dim ?? this.dim,
    vec: vec ?? this.vec,
    computedAt: computedAt ?? this.computedAt,
  );
  EntryVecRow copyWithCompanion(EntryVecsCompanion data) {
    return EntryVecRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      chunkIdx: data.chunkIdx.present ? data.chunkIdx.value : this.chunkIdx,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      dim: data.dim.present ? data.dim.value : this.dim,
      vec: data.vec.present ? data.vec.value : this.vec,
      computedAt: data.computedAt.present
          ? data.computedAt.value
          : this.computedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryVecRow(')
          ..write('entryId: $entryId, ')
          ..write('chunkIdx: $chunkIdx, ')
          ..write('modelId: $modelId, ')
          ..write('dim: $dim, ')
          ..write('vec: $vec, ')
          ..write('computedAt: $computedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entryId,
    chunkIdx,
    modelId,
    dim,
    $driftBlobEquality.hash(vec),
    computedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryVecRow &&
          other.entryId == this.entryId &&
          other.chunkIdx == this.chunkIdx &&
          other.modelId == this.modelId &&
          other.dim == this.dim &&
          $driftBlobEquality.equals(other.vec, this.vec) &&
          other.computedAt == this.computedAt);
}

class EntryVecsCompanion extends UpdateCompanion<EntryVecRow> {
  final Value<String> entryId;
  final Value<int> chunkIdx;
  final Value<String> modelId;
  final Value<int> dim;
  final Value<Uint8List> vec;
  final Value<int> computedAt;
  final Value<int> rowid;
  const EntryVecsCompanion({
    this.entryId = const Value.absent(),
    this.chunkIdx = const Value.absent(),
    this.modelId = const Value.absent(),
    this.dim = const Value.absent(),
    this.vec = const Value.absent(),
    this.computedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntryVecsCompanion.insert({
    required String entryId,
    this.chunkIdx = const Value.absent(),
    required String modelId,
    required int dim,
    required Uint8List vec,
    required int computedAt,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       modelId = Value(modelId),
       dim = Value(dim),
       vec = Value(vec),
       computedAt = Value(computedAt);
  static Insertable<EntryVecRow> custom({
    Expression<String>? entryId,
    Expression<int>? chunkIdx,
    Expression<String>? modelId,
    Expression<int>? dim,
    Expression<Uint8List>? vec,
    Expression<int>? computedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (chunkIdx != null) 'chunk_idx': chunkIdx,
      if (modelId != null) 'model_id': modelId,
      if (dim != null) 'dim': dim,
      if (vec != null) 'vec': vec,
      if (computedAt != null) 'computed_at': computedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntryVecsCompanion copyWith({
    Value<String>? entryId,
    Value<int>? chunkIdx,
    Value<String>? modelId,
    Value<int>? dim,
    Value<Uint8List>? vec,
    Value<int>? computedAt,
    Value<int>? rowid,
  }) {
    return EntryVecsCompanion(
      entryId: entryId ?? this.entryId,
      chunkIdx: chunkIdx ?? this.chunkIdx,
      modelId: modelId ?? this.modelId,
      dim: dim ?? this.dim,
      vec: vec ?? this.vec,
      computedAt: computedAt ?? this.computedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (chunkIdx.present) {
      map['chunk_idx'] = Variable<int>(chunkIdx.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (dim.present) {
      map['dim'] = Variable<int>(dim.value);
    }
    if (vec.present) {
      map['vec'] = Variable<Uint8List>(vec.value);
    }
    if (computedAt.present) {
      map['computed_at'] = Variable<int>(computedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryVecsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('chunkIdx: $chunkIdx, ')
          ..write('modelId: $modelId, ')
          ..write('dim: $dim, ')
          ..write('vec: $vec, ')
          ..write('computedAt: $computedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmbeddingModelsTable extends EmbeddingModels
    with TableInfo<$EmbeddingModelsTable, EmbeddingModelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmbeddingModelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyMeta = const VerificationMeta('family');
  @override
  late final GeneratedColumn<String> family = GeneratedColumn<String>(
    'family',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dimMeta = const VerificationMeta('dim');
  @override
  late final GeneratedColumn<int> dim = GeneratedColumn<int>(
    'dim',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mrlMeta = const VerificationMeta('mrl');
  @override
  late final GeneratedColumn<String> mrl = GeneratedColumn<String>(
    'mrl',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ctxMeta = const VerificationMeta('ctx');
  @override
  late final GeneratedColumn<int> ctx = GeneratedColumn<int>(
    'ctx',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantMeta = const VerificationMeta('quant');
  @override
  late final GeneratedColumn<String> quant = GeneratedColumn<String>(
    'quant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<int> state = GeneratedColumn<int>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<int> installedAt = GeneratedColumn<int>(
    'installed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    family,
    dim,
    mrl,
    ctx,
    quant,
    sha256,
    path,
    state,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'embedding_model';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmbeddingModelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family')) {
      context.handle(
        _familyMeta,
        family.isAcceptableOrUnknown(data['family']!, _familyMeta),
      );
    }
    if (data.containsKey('dim')) {
      context.handle(
        _dimMeta,
        dim.isAcceptableOrUnknown(data['dim']!, _dimMeta),
      );
    }
    if (data.containsKey('mrl')) {
      context.handle(
        _mrlMeta,
        mrl.isAcceptableOrUnknown(data['mrl']!, _mrlMeta),
      );
    }
    if (data.containsKey('ctx')) {
      context.handle(
        _ctxMeta,
        ctx.isAcceptableOrUnknown(data['ctx']!, _ctxMeta),
      );
    }
    if (data.containsKey('quant')) {
      context.handle(
        _quantMeta,
        quant.isAcceptableOrUnknown(data['quant']!, _quantMeta),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EmbeddingModelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmbeddingModelRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      family: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family'],
      ),
      dim: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dim'],
      ),
      mrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mrl'],
      ),
      ctx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ctx'],
      ),
      quant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quant'],
      ),
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}state'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}installed_at'],
      ),
    );
  }

  @override
  $EmbeddingModelsTable createAlias(String alias) {
    return $EmbeddingModelsTable(attachedDatabase, alias);
  }
}

class EmbeddingModelRow extends DataClass
    implements Insertable<EmbeddingModelRow> {
  final String id;
  final String? family;
  final int? dim;

  /// 可裁剪维度列表，逗号分隔（MRL）
  final String? mrl;
  final int? ctx;
  final String? quant;
  final String? sha256;
  final String? path;

  /// 0 未下载 / 1 下载中 / 2 就绪 / 3 损坏
  final int state;
  final int? installedAt;
  const EmbeddingModelRow({
    required this.id,
    this.family,
    this.dim,
    this.mrl,
    this.ctx,
    this.quant,
    this.sha256,
    this.path,
    required this.state,
    this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || family != null) {
      map['family'] = Variable<String>(family);
    }
    if (!nullToAbsent || dim != null) {
      map['dim'] = Variable<int>(dim);
    }
    if (!nullToAbsent || mrl != null) {
      map['mrl'] = Variable<String>(mrl);
    }
    if (!nullToAbsent || ctx != null) {
      map['ctx'] = Variable<int>(ctx);
    }
    if (!nullToAbsent || quant != null) {
      map['quant'] = Variable<String>(quant);
    }
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    map['state'] = Variable<int>(state);
    if (!nullToAbsent || installedAt != null) {
      map['installed_at'] = Variable<int>(installedAt);
    }
    return map;
  }

  EmbeddingModelsCompanion toCompanion(bool nullToAbsent) {
    return EmbeddingModelsCompanion(
      id: Value(id),
      family: family == null && nullToAbsent
          ? const Value.absent()
          : Value(family),
      dim: dim == null && nullToAbsent ? const Value.absent() : Value(dim),
      mrl: mrl == null && nullToAbsent ? const Value.absent() : Value(mrl),
      ctx: ctx == null && nullToAbsent ? const Value.absent() : Value(ctx),
      quant: quant == null && nullToAbsent
          ? const Value.absent()
          : Value(quant),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      state: Value(state),
      installedAt: installedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(installedAt),
    );
  }

  factory EmbeddingModelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmbeddingModelRow(
      id: serializer.fromJson<String>(json['id']),
      family: serializer.fromJson<String?>(json['family']),
      dim: serializer.fromJson<int?>(json['dim']),
      mrl: serializer.fromJson<String?>(json['mrl']),
      ctx: serializer.fromJson<int?>(json['ctx']),
      quant: serializer.fromJson<String?>(json['quant']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      path: serializer.fromJson<String?>(json['path']),
      state: serializer.fromJson<int>(json['state']),
      installedAt: serializer.fromJson<int?>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'family': serializer.toJson<String?>(family),
      'dim': serializer.toJson<int?>(dim),
      'mrl': serializer.toJson<String?>(mrl),
      'ctx': serializer.toJson<int?>(ctx),
      'quant': serializer.toJson<String?>(quant),
      'sha256': serializer.toJson<String?>(sha256),
      'path': serializer.toJson<String?>(path),
      'state': serializer.toJson<int>(state),
      'installedAt': serializer.toJson<int?>(installedAt),
    };
  }

  EmbeddingModelRow copyWith({
    String? id,
    Value<String?> family = const Value.absent(),
    Value<int?> dim = const Value.absent(),
    Value<String?> mrl = const Value.absent(),
    Value<int?> ctx = const Value.absent(),
    Value<String?> quant = const Value.absent(),
    Value<String?> sha256 = const Value.absent(),
    Value<String?> path = const Value.absent(),
    int? state,
    Value<int?> installedAt = const Value.absent(),
  }) => EmbeddingModelRow(
    id: id ?? this.id,
    family: family.present ? family.value : this.family,
    dim: dim.present ? dim.value : this.dim,
    mrl: mrl.present ? mrl.value : this.mrl,
    ctx: ctx.present ? ctx.value : this.ctx,
    quant: quant.present ? quant.value : this.quant,
    sha256: sha256.present ? sha256.value : this.sha256,
    path: path.present ? path.value : this.path,
    state: state ?? this.state,
    installedAt: installedAt.present ? installedAt.value : this.installedAt,
  );
  EmbeddingModelRow copyWithCompanion(EmbeddingModelsCompanion data) {
    return EmbeddingModelRow(
      id: data.id.present ? data.id.value : this.id,
      family: data.family.present ? data.family.value : this.family,
      dim: data.dim.present ? data.dim.value : this.dim,
      mrl: data.mrl.present ? data.mrl.value : this.mrl,
      ctx: data.ctx.present ? data.ctx.value : this.ctx,
      quant: data.quant.present ? data.quant.value : this.quant,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      path: data.path.present ? data.path.value : this.path,
      state: data.state.present ? data.state.value : this.state,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingModelRow(')
          ..write('id: $id, ')
          ..write('family: $family, ')
          ..write('dim: $dim, ')
          ..write('mrl: $mrl, ')
          ..write('ctx: $ctx, ')
          ..write('quant: $quant, ')
          ..write('sha256: $sha256, ')
          ..write('path: $path, ')
          ..write('state: $state, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    family,
    dim,
    mrl,
    ctx,
    quant,
    sha256,
    path,
    state,
    installedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmbeddingModelRow &&
          other.id == this.id &&
          other.family == this.family &&
          other.dim == this.dim &&
          other.mrl == this.mrl &&
          other.ctx == this.ctx &&
          other.quant == this.quant &&
          other.sha256 == this.sha256 &&
          other.path == this.path &&
          other.state == this.state &&
          other.installedAt == this.installedAt);
}

class EmbeddingModelsCompanion extends UpdateCompanion<EmbeddingModelRow> {
  final Value<String> id;
  final Value<String?> family;
  final Value<int?> dim;
  final Value<String?> mrl;
  final Value<int?> ctx;
  final Value<String?> quant;
  final Value<String?> sha256;
  final Value<String?> path;
  final Value<int> state;
  final Value<int?> installedAt;
  final Value<int> rowid;
  const EmbeddingModelsCompanion({
    this.id = const Value.absent(),
    this.family = const Value.absent(),
    this.dim = const Value.absent(),
    this.mrl = const Value.absent(),
    this.ctx = const Value.absent(),
    this.quant = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.path = const Value.absent(),
    this.state = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmbeddingModelsCompanion.insert({
    required String id,
    this.family = const Value.absent(),
    this.dim = const Value.absent(),
    this.mrl = const Value.absent(),
    this.ctx = const Value.absent(),
    this.quant = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.path = const Value.absent(),
    this.state = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<EmbeddingModelRow> custom({
    Expression<String>? id,
    Expression<String>? family,
    Expression<int>? dim,
    Expression<String>? mrl,
    Expression<int>? ctx,
    Expression<String>? quant,
    Expression<String>? sha256,
    Expression<String>? path,
    Expression<int>? state,
    Expression<int>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (family != null) 'family': family,
      if (dim != null) 'dim': dim,
      if (mrl != null) 'mrl': mrl,
      if (ctx != null) 'ctx': ctx,
      if (quant != null) 'quant': quant,
      if (sha256 != null) 'sha256': sha256,
      if (path != null) 'path': path,
      if (state != null) 'state': state,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmbeddingModelsCompanion copyWith({
    Value<String>? id,
    Value<String?>? family,
    Value<int?>? dim,
    Value<String?>? mrl,
    Value<int?>? ctx,
    Value<String?>? quant,
    Value<String?>? sha256,
    Value<String?>? path,
    Value<int>? state,
    Value<int?>? installedAt,
    Value<int>? rowid,
  }) {
    return EmbeddingModelsCompanion(
      id: id ?? this.id,
      family: family ?? this.family,
      dim: dim ?? this.dim,
      mrl: mrl ?? this.mrl,
      ctx: ctx ?? this.ctx,
      quant: quant ?? this.quant,
      sha256: sha256 ?? this.sha256,
      path: path ?? this.path,
      state: state ?? this.state,
      installedAt: installedAt ?? this.installedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (family.present) {
      map['family'] = Variable<String>(family.value);
    }
    if (dim.present) {
      map['dim'] = Variable<int>(dim.value);
    }
    if (mrl.present) {
      map['mrl'] = Variable<String>(mrl.value);
    }
    if (ctx.present) {
      map['ctx'] = Variable<int>(ctx.value);
    }
    if (quant.present) {
      map['quant'] = Variable<String>(quant.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (state.present) {
      map['state'] = Variable<int>(state.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<int>(installedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingModelsCompanion(')
          ..write('id: $id, ')
          ..write('family: $family, ')
          ..write('dim: $dim, ')
          ..write('mrl: $mrl, ')
          ..write('ctx: $ctx, ')
          ..write('quant: $quant, ')
          ..write('sha256: $sha256, ')
          ..write('path: $path, ')
          ..write('state: $state, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlobRefsTable extends BlobRefs
    with TableInfo<$BlobRefsTable, BlobRefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlobRefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blobHashMeta = const VerificationMeta(
    'blobHash',
  );
  @override
  late final GeneratedColumn<String> blobHash = GeneratedColumn<String>(
    'blob_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localMeta = const VerificationMeta('local');
  @override
  late final GeneratedColumn<int> local = GeneratedColumn<int>(
    'local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    blobHash,
    kind,
    bytes,
    local,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blob_ref';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlobRefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('blob_hash')) {
      context.handle(
        _blobHashMeta,
        blobHash.isAcceptableOrUnknown(data['blob_hash']!, _blobHashMeta),
      );
    } else if (isInserting) {
      context.missing(_blobHashMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('local')) {
      context.handle(
        _localMeta,
        local.isAcceptableOrUnknown(data['local']!, _localMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, blobHash};
  @override
  BlobRefRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlobRefRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      blobHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_hash'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      local: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BlobRefsTable createAlias(String alias) {
    return $BlobRefsTable(attachedDatabase, alias);
  }
}

class BlobRefRow extends DataClass implements Insertable<BlobRefRow> {
  final String entryId;

  /// sha256，内容寻址
  final String blobHash;

  /// 1 text / 2 pdf / 3 html / 4 image / 5 favicon
  final int kind;
  final int bytes;

  /// 0 仅云端 / 1 本地已有
  final int local;
  final int createdAt;
  const BlobRefRow({
    required this.entryId,
    required this.blobHash,
    required this.kind,
    required this.bytes,
    required this.local,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['blob_hash'] = Variable<String>(blobHash);
    map['kind'] = Variable<int>(kind);
    map['bytes'] = Variable<int>(bytes);
    map['local'] = Variable<int>(local);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  BlobRefsCompanion toCompanion(bool nullToAbsent) {
    return BlobRefsCompanion(
      entryId: Value(entryId),
      blobHash: Value(blobHash),
      kind: Value(kind),
      bytes: Value(bytes),
      local: Value(local),
      createdAt: Value(createdAt),
    );
  }

  factory BlobRefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlobRefRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      blobHash: serializer.fromJson<String>(json['blobHash']),
      kind: serializer.fromJson<int>(json['kind']),
      bytes: serializer.fromJson<int>(json['bytes']),
      local: serializer.fromJson<int>(json['local']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'blobHash': serializer.toJson<String>(blobHash),
      'kind': serializer.toJson<int>(kind),
      'bytes': serializer.toJson<int>(bytes),
      'local': serializer.toJson<int>(local),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  BlobRefRow copyWith({
    String? entryId,
    String? blobHash,
    int? kind,
    int? bytes,
    int? local,
    int? createdAt,
  }) => BlobRefRow(
    entryId: entryId ?? this.entryId,
    blobHash: blobHash ?? this.blobHash,
    kind: kind ?? this.kind,
    bytes: bytes ?? this.bytes,
    local: local ?? this.local,
    createdAt: createdAt ?? this.createdAt,
  );
  BlobRefRow copyWithCompanion(BlobRefsCompanion data) {
    return BlobRefRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      blobHash: data.blobHash.present ? data.blobHash.value : this.blobHash,
      kind: data.kind.present ? data.kind.value : this.kind,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      local: data.local.present ? data.local.value : this.local,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlobRefRow(')
          ..write('entryId: $entryId, ')
          ..write('blobHash: $blobHash, ')
          ..write('kind: $kind, ')
          ..write('bytes: $bytes, ')
          ..write('local: $local, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(entryId, blobHash, kind, bytes, local, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlobRefRow &&
          other.entryId == this.entryId &&
          other.blobHash == this.blobHash &&
          other.kind == this.kind &&
          other.bytes == this.bytes &&
          other.local == this.local &&
          other.createdAt == this.createdAt);
}

class BlobRefsCompanion extends UpdateCompanion<BlobRefRow> {
  final Value<String> entryId;
  final Value<String> blobHash;
  final Value<int> kind;
  final Value<int> bytes;
  final Value<int> local;
  final Value<int> createdAt;
  final Value<int> rowid;
  const BlobRefsCompanion({
    this.entryId = const Value.absent(),
    this.blobHash = const Value.absent(),
    this.kind = const Value.absent(),
    this.bytes = const Value.absent(),
    this.local = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlobRefsCompanion.insert({
    required String entryId,
    required String blobHash,
    required int kind,
    required int bytes,
    this.local = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       blobHash = Value(blobHash),
       kind = Value(kind),
       bytes = Value(bytes),
       createdAt = Value(createdAt);
  static Insertable<BlobRefRow> custom({
    Expression<String>? entryId,
    Expression<String>? blobHash,
    Expression<int>? kind,
    Expression<int>? bytes,
    Expression<int>? local,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (blobHash != null) 'blob_hash': blobHash,
      if (kind != null) 'kind': kind,
      if (bytes != null) 'bytes': bytes,
      if (local != null) 'local': local,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlobRefsCompanion copyWith({
    Value<String>? entryId,
    Value<String>? blobHash,
    Value<int>? kind,
    Value<int>? bytes,
    Value<int>? local,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return BlobRefsCompanion(
      entryId: entryId ?? this.entryId,
      blobHash: blobHash ?? this.blobHash,
      kind: kind ?? this.kind,
      bytes: bytes ?? this.bytes,
      local: local ?? this.local,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (blobHash.present) {
      map['blob_hash'] = Variable<String>(blobHash.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (local.present) {
      map['local'] = Variable<int>(local.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlobRefsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('blobHash: $blobHash, ')
          ..write('kind: $kind, ')
          ..write('bytes: $bytes, ')
          ..write('local: $local, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LinkChecksTable extends LinkChecks
    with TableInfo<$LinkChecksTable, LinkCheckRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LinkChecksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<int> checkedAt = GeneratedColumn<int>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _httpStatusMeta = const VerificationMeta(
    'httpStatus',
  );
  @override
  late final GeneratedColumn<int> httpStatus = GeneratedColumn<int>(
    'http_status',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finalUrlMeta = const VerificationMeta(
    'finalUrl',
  );
  @override
  late final GeneratedColumn<String> finalUrl = GeneratedColumn<String>(
    'final_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _simhashMeta = const VerificationMeta(
    'simhash',
  );
  @override
  late final GeneratedColumn<String> simhash = GeneratedColumn<String>(
    'simhash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    checkedAt,
    httpStatus,
    result,
    finalUrl,
    simhash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'link_check';
  @override
  VerificationContext validateIntegrity(
    Insertable<LinkCheckRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    if (data.containsKey('http_status')) {
      context.handle(
        _httpStatusMeta,
        httpStatus.isAcceptableOrUnknown(data['http_status']!, _httpStatusMeta),
      );
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('final_url')) {
      context.handle(
        _finalUrlMeta,
        finalUrl.isAcceptableOrUnknown(data['final_url']!, _finalUrlMeta),
      );
    }
    if (data.containsKey('simhash')) {
      context.handle(
        _simhashMeta,
        simhash.isAcceptableOrUnknown(data['simhash']!, _simhashMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, checkedAt};
  @override
  LinkCheckRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LinkCheckRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checked_at'],
      )!,
      httpStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}http_status'],
      ),
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      finalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_url'],
      ),
      simhash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}simhash'],
      ),
    );
  }

  @override
  $LinkChecksTable createAlias(String alias) {
    return $LinkChecksTable(attachedDatabase, alias);
  }
}

class LinkCheckRow extends DataClass implements Insertable<LinkCheckRow> {
  final String entryId;
  final int checkedAt;
  final int? httpStatus;

  /// ok / dead / restricted / unreachable / changed
  final String result;
  final String? finalUrl;
  final String? simhash;
  const LinkCheckRow({
    required this.entryId,
    required this.checkedAt,
    this.httpStatus,
    required this.result,
    this.finalUrl,
    this.simhash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['checked_at'] = Variable<int>(checkedAt);
    if (!nullToAbsent || httpStatus != null) {
      map['http_status'] = Variable<int>(httpStatus);
    }
    map['result'] = Variable<String>(result);
    if (!nullToAbsent || finalUrl != null) {
      map['final_url'] = Variable<String>(finalUrl);
    }
    if (!nullToAbsent || simhash != null) {
      map['simhash'] = Variable<String>(simhash);
    }
    return map;
  }

  LinkChecksCompanion toCompanion(bool nullToAbsent) {
    return LinkChecksCompanion(
      entryId: Value(entryId),
      checkedAt: Value(checkedAt),
      httpStatus: httpStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(httpStatus),
      result: Value(result),
      finalUrl: finalUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(finalUrl),
      simhash: simhash == null && nullToAbsent
          ? const Value.absent()
          : Value(simhash),
    );
  }

  factory LinkCheckRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LinkCheckRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      checkedAt: serializer.fromJson<int>(json['checkedAt']),
      httpStatus: serializer.fromJson<int?>(json['httpStatus']),
      result: serializer.fromJson<String>(json['result']),
      finalUrl: serializer.fromJson<String?>(json['finalUrl']),
      simhash: serializer.fromJson<String?>(json['simhash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'checkedAt': serializer.toJson<int>(checkedAt),
      'httpStatus': serializer.toJson<int?>(httpStatus),
      'result': serializer.toJson<String>(result),
      'finalUrl': serializer.toJson<String?>(finalUrl),
      'simhash': serializer.toJson<String?>(simhash),
    };
  }

  LinkCheckRow copyWith({
    String? entryId,
    int? checkedAt,
    Value<int?> httpStatus = const Value.absent(),
    String? result,
    Value<String?> finalUrl = const Value.absent(),
    Value<String?> simhash = const Value.absent(),
  }) => LinkCheckRow(
    entryId: entryId ?? this.entryId,
    checkedAt: checkedAt ?? this.checkedAt,
    httpStatus: httpStatus.present ? httpStatus.value : this.httpStatus,
    result: result ?? this.result,
    finalUrl: finalUrl.present ? finalUrl.value : this.finalUrl,
    simhash: simhash.present ? simhash.value : this.simhash,
  );
  LinkCheckRow copyWithCompanion(LinkChecksCompanion data) {
    return LinkCheckRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
      httpStatus: data.httpStatus.present
          ? data.httpStatus.value
          : this.httpStatus,
      result: data.result.present ? data.result.value : this.result,
      finalUrl: data.finalUrl.present ? data.finalUrl.value : this.finalUrl,
      simhash: data.simhash.present ? data.simhash.value : this.simhash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LinkCheckRow(')
          ..write('entryId: $entryId, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('httpStatus: $httpStatus, ')
          ..write('result: $result, ')
          ..write('finalUrl: $finalUrl, ')
          ..write('simhash: $simhash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(entryId, checkedAt, httpStatus, result, finalUrl, simhash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LinkCheckRow &&
          other.entryId == this.entryId &&
          other.checkedAt == this.checkedAt &&
          other.httpStatus == this.httpStatus &&
          other.result == this.result &&
          other.finalUrl == this.finalUrl &&
          other.simhash == this.simhash);
}

class LinkChecksCompanion extends UpdateCompanion<LinkCheckRow> {
  final Value<String> entryId;
  final Value<int> checkedAt;
  final Value<int?> httpStatus;
  final Value<String> result;
  final Value<String?> finalUrl;
  final Value<String?> simhash;
  final Value<int> rowid;
  const LinkChecksCompanion({
    this.entryId = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.httpStatus = const Value.absent(),
    this.result = const Value.absent(),
    this.finalUrl = const Value.absent(),
    this.simhash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LinkChecksCompanion.insert({
    required String entryId,
    required int checkedAt,
    this.httpStatus = const Value.absent(),
    required String result,
    this.finalUrl = const Value.absent(),
    this.simhash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       checkedAt = Value(checkedAt),
       result = Value(result);
  static Insertable<LinkCheckRow> custom({
    Expression<String>? entryId,
    Expression<int>? checkedAt,
    Expression<int>? httpStatus,
    Expression<String>? result,
    Expression<String>? finalUrl,
    Expression<String>? simhash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (httpStatus != null) 'http_status': httpStatus,
      if (result != null) 'result': result,
      if (finalUrl != null) 'final_url': finalUrl,
      if (simhash != null) 'simhash': simhash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LinkChecksCompanion copyWith({
    Value<String>? entryId,
    Value<int>? checkedAt,
    Value<int?>? httpStatus,
    Value<String>? result,
    Value<String?>? finalUrl,
    Value<String?>? simhash,
    Value<int>? rowid,
  }) {
    return LinkChecksCompanion(
      entryId: entryId ?? this.entryId,
      checkedAt: checkedAt ?? this.checkedAt,
      httpStatus: httpStatus ?? this.httpStatus,
      result: result ?? this.result,
      finalUrl: finalUrl ?? this.finalUrl,
      simhash: simhash ?? this.simhash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<int>(checkedAt.value);
    }
    if (httpStatus.present) {
      map['http_status'] = Variable<int>(httpStatus.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (finalUrl.present) {
      map['final_url'] = Variable<String>(finalUrl.value);
    }
    if (simhash.present) {
      map['simhash'] = Variable<String>(simhash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LinkChecksCompanion(')
          ..write('entryId: $entryId, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('httpStatus: $httpStatus, ')
          ..write('result: $result, ')
          ..write('finalUrl: $finalUrl, ')
          ..write('simhash: $simhash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JobQueuesTable extends JobQueues
    with TableInfo<$JobQueuesTable, JobQueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JobQueuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<int> state = GeneratedColumn<int>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRunAtMeta = const VerificationMeta(
    'nextRunAt',
  );
  @override
  late final GeneratedColumn<int> nextRunAt = GeneratedColumn<int>(
    'next_run_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    payload,
    state,
    attempts,
    nextRunAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'job_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<JobQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_run_at')) {
      context.handle(
        _nextRunAtMeta,
        nextRunAt.isAcceptableOrUnknown(data['next_run_at']!, _nextRunAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JobQueueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JobQueueRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextRunAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_run_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $JobQueuesTable createAlias(String alias) {
    return $JobQueuesTable(attachedDatabase, alias);
  }
}

class JobQueueRow extends DataClass implements Insertable<JobQueueRow> {
  final int id;

  /// embed / archive / reembed_all / deadlink / compact_oplog / purge_trash
  final String type;
  final String? payload;

  /// 0 pending / 1 running / 2 done / 3 failed
  final int state;
  final int attempts;
  final int nextRunAt;
  final int createdAt;
  const JobQueueRow({
    required this.id,
    required this.type,
    this.payload,
    required this.state,
    required this.attempts,
    required this.nextRunAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['state'] = Variable<int>(state);
    map['attempts'] = Variable<int>(attempts);
    map['next_run_at'] = Variable<int>(nextRunAt);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  JobQueuesCompanion toCompanion(bool nullToAbsent) {
    return JobQueuesCompanion(
      id: Value(id),
      type: Value(type),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      state: Value(state),
      attempts: Value(attempts),
      nextRunAt: Value(nextRunAt),
      createdAt: Value(createdAt),
    );
  }

  factory JobQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JobQueueRow(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      payload: serializer.fromJson<String?>(json['payload']),
      state: serializer.fromJson<int>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextRunAt: serializer.fromJson<int>(json['nextRunAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'payload': serializer.toJson<String?>(payload),
      'state': serializer.toJson<int>(state),
      'attempts': serializer.toJson<int>(attempts),
      'nextRunAt': serializer.toJson<int>(nextRunAt),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  JobQueueRow copyWith({
    int? id,
    String? type,
    Value<String?> payload = const Value.absent(),
    int? state,
    int? attempts,
    int? nextRunAt,
    int? createdAt,
  }) => JobQueueRow(
    id: id ?? this.id,
    type: type ?? this.type,
    payload: payload.present ? payload.value : this.payload,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    nextRunAt: nextRunAt ?? this.nextRunAt,
    createdAt: createdAt ?? this.createdAt,
  );
  JobQueueRow copyWithCompanion(JobQueuesCompanion data) {
    return JobQueueRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      payload: data.payload.present ? data.payload.value : this.payload,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextRunAt: data.nextRunAt.present ? data.nextRunAt.value : this.nextRunAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JobQueueRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('nextRunAt: $nextRunAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, type, payload, state, attempts, nextRunAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JobQueueRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.payload == this.payload &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.nextRunAt == this.nextRunAt &&
          other.createdAt == this.createdAt);
}

class JobQueuesCompanion extends UpdateCompanion<JobQueueRow> {
  final Value<int> id;
  final Value<String> type;
  final Value<String?> payload;
  final Value<int> state;
  final Value<int> attempts;
  final Value<int> nextRunAt;
  final Value<int> createdAt;
  const JobQueuesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.payload = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRunAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  JobQueuesCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    this.payload = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRunAt = const Value.absent(),
    required int createdAt,
  }) : type = Value(type),
       createdAt = Value(createdAt);
  static Insertable<JobQueueRow> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? payload,
    Expression<int>? state,
    Expression<int>? attempts,
    Expression<int>? nextRunAt,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (payload != null) 'payload': payload,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (nextRunAt != null) 'next_run_at': nextRunAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  JobQueuesCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<String?>? payload,
    Value<int>? state,
    Value<int>? attempts,
    Value<int>? nextRunAt,
    Value<int>? createdAt,
  }) {
    return JobQueuesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (state.present) {
      map['state'] = Variable<int>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextRunAt.present) {
      map['next_run_at'] = Variable<int>(nextRunAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JobQueuesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('nextRunAt: $nextRunAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$VaultDatabase extends GeneratedDatabase {
  _$VaultDatabase(QueryExecutor e) : super(e);
  $VaultDatabaseManager get managers => $VaultDatabaseManager(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $EntryHistoryTable entryHistory = $EntryHistoryTable(this);
  late final $TrashRowsTable trashRows = $TrashRowsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $EntryCategoriesTable entryCategories = $EntryCategoriesTable(
    this,
  );
  late final $EntryTagsTable entryTags = $EntryTagsTable(this);
  late final $CategoryFieldTemplatesTable categoryFieldTemplates =
      $CategoryFieldTemplatesTable(this);
  late final $CredentialsTable credentials = $CredentialsTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $OplogsTable oplogs = $OplogsTable(this);
  late final $ActivitiesTable activities = $ActivitiesTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $DeviceWatermarksTable deviceWatermarks = $DeviceWatermarksTable(
    this,
  );
  late final $SyncLogsTable syncLogs = $SyncLogsTable(this);
  late final $DiaryIndexesTable diaryIndexes = $DiaryIndexesTable(this);
  late final $EntryVecsTable entryVecs = $EntryVecsTable(this);
  late final $EmbeddingModelsTable embeddingModels = $EmbeddingModelsTable(
    this,
  );
  late final $BlobRefsTable blobRefs = $BlobRefsTable(this);
  late final $LinkChecksTable linkChecks = $LinkChecksTable(this);
  late final $JobQueuesTable jobQueues = $JobQueuesTable(this);
  late final Index idxEntryKindTime = Index(
    'idx_entry_kind_time',
    'CREATE INDEX idx_entry_kind_time ON entry (kind, deleted, updated_at)',
  );
  late final Index idxEntryHlc = Index(
    'idx_entry_hlc',
    'CREATE INDEX idx_entry_hlc ON entry (hlc)',
  );
  late final Index idxCatKind = Index(
    'idx_cat_kind',
    'CREATE INDEX idx_cat_kind ON category (kind, parent_id, sort_order)',
  );
  late final Index idxTagName = Index(
    'idx_tag_name',
    'CREATE INDEX idx_tag_name ON tag (name)',
  );
  late final Index idxTemplateCat = Index(
    'idx_template_cat',
    'CREATE INDEX idx_template_cat ON category_field_template (category_id, sort_order)',
  );
  late final Index idxConvTime = Index(
    'idx_conv_time',
    'CREATE INDEX idx_conv_time ON conversation (deleted, updated_at)',
  );
  late final Index idxMsgConv = Index(
    'idx_msg_conv',
    'CREATE INDEX idx_msg_conv ON message (conversation_id, created_at)',
  );
  late final Index idxOplogPending = Index(
    'idx_oplog_pending',
    'CREATE INDEX idx_oplog_pending ON oplog (applied, seq)',
  );
  late final Index idxOplogEntity = Index(
    'idx_oplog_entity',
    'CREATE INDEX idx_oplog_entity ON oplog (entity, entity_id)',
  );
  late final Index idxActivityTs = Index(
    'idx_activity_ts',
    'CREATE INDEX idx_activity_ts ON activity (ts)',
  );
  late final Index idxActivityKindTs = Index(
    'idx_activity_kind_ts',
    'CREATE INDEX idx_activity_kind_ts ON activity (kind, ts)',
  );
  late final Index idxVecModel = Index(
    'idx_vec_model',
    'CREATE INDEX idx_vec_model ON entry_vec (model_id)',
  );
  late final Index idxBlobLocal = Index(
    'idx_blob_local',
    'CREATE INDEX idx_blob_local ON blob_ref (local, bytes)',
  );
  late final Index idxJobReady = Index(
    'idx_job_ready',
    'CREATE INDEX idx_job_ready ON job_queue (state, next_run_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    entries,
    entryHistory,
    trashRows,
    categories,
    tags,
    entryCategories,
    entryTags,
    categoryFieldTemplates,
    credentials,
    conversations,
    messages,
    oplogs,
    activities,
    syncStates,
    deviceWatermarks,
    syncLogs,
    diaryIndexes,
    entryVecs,
    embeddingModels,
    blobRefs,
    linkChecks,
    jobQueues,
    idxEntryKindTime,
    idxEntryHlc,
    idxCatKind,
    idxTagName,
    idxTemplateCat,
    idxConvTime,
    idxMsgConv,
    idxOplogPending,
    idxOplogEntity,
    idxActivityTs,
    idxActivityKindTs,
    idxVecModel,
    idxBlobLocal,
    idxJobReady,
  ];
}

typedef $$EntriesTableCreateCompanionBuilder = EntriesCompanion Function({
  required String id,
  required int kind,
  Value<String?> title,
  Value<String?> body,
  Value<String?> meta,
  required int createdAt,
  required int updatedAt,
  required String hlc,
  Value<int> rev,
  required String contentHash,
  Value<int> deleted,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$EntriesTableUpdateCompanionBuilder = EntriesCompanion Function({
  Value<String> id,
  Value<int> kind,
  Value<String?> title,
  Value<String?> body,
  Value<String?> meta,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String> hlc,
  Value<int> rev,
  Value<String> contentHash,
  Value<int> deleted,
  Value<int?> deletedAt,
  Value<int> rowid,
});

class $$EntriesTableFilterComposer
    extends Composer<_$VaultDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntriesTableOrderingComposer
    extends Composer<_$VaultDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$VaultDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<int> get rev =>
      $composableBuilder(column: $table.rev, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $EntriesTable,
          EntryRow,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (EntryRow, BaseReferences<_$VaultDatabase, $EntriesTable, EntryRow>),
          EntryRow,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$VaultDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> meta = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rev = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int> deleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                kind: kind,
                title: title,
                body: body,
                meta: meta,
                createdAt: createdAt,
                updatedAt: updatedAt,
                hlc: hlc,
                rev: rev,
                contentHash: contentHash,
                deleted: deleted,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int kind,
                Value<String?> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> meta = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                required String hlc,
                Value<int> rev = const Value.absent(),
                required String contentHash,
                Value<int> deleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                kind: kind,
                title: title,
                body: body,
                meta: meta,
                createdAt: createdAt,
                updatedAt: updatedAt,
                hlc: hlc,
                rev: rev,
                contentHash: contentHash,
                deleted: deleted,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntriesTable, EntryRow>(table),
                  BaseReferences<_$VaultDatabase, $EntriesTable, EntryRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $EntriesTable,
      EntryRow,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (EntryRow, BaseReferences<_$VaultDatabase, $EntriesTable, EntryRow>),
      EntryRow,
      PrefetchHooks Function()
    >;
typedef $$EntryHistoryTableCreateCompanionBuilder =
    EntryHistoryCompanion Function({
      required String entryId,
      required int rev,
      required Uint8List payload,
      required String hlc,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$EntryHistoryTableUpdateCompanionBuilder =
    EntryHistoryCompanion Function({
      Value<String> entryId,
      Value<int> rev,
      Value<Uint8List> payload,
      Value<String> hlc,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$EntryHistoryTableFilterComposer
    extends Composer<_$VaultDatabase, $EntryHistoryTable> {
  $$EntryHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntryHistoryTableOrderingComposer
    extends Composer<_$VaultDatabase, $EntryHistoryTable> {
  $$EntryHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntryHistoryTableAnnotationComposer
    extends Composer<_$VaultDatabase, $EntryHistoryTable> {
  $$EntryHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<int> get rev =>
      $composableBuilder(column: $table.rev, builder: (column) => column);

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EntryHistoryTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $EntryHistoryTable,
          EntryHistoryRow,
          $$EntryHistoryTableFilterComposer,
          $$EntryHistoryTableOrderingComposer,
          $$EntryHistoryTableAnnotationComposer,
          $$EntryHistoryTableCreateCompanionBuilder,
          $$EntryHistoryTableUpdateCompanionBuilder,
          (
            EntryHistoryRow,
            BaseReferences<
              _$VaultDatabase,
              $EntryHistoryTable,
              EntryHistoryRow
            >,
          ),
          EntryHistoryRow,
          PrefetchHooks Function()
        > {
  $$EntryHistoryTableTableManager(_$VaultDatabase db, $EntryHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<int> rev = const Value.absent(),
                Value<Uint8List> payload = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntryHistoryCompanion(
                entryId: entryId,
                rev: rev,
                payload: payload,
                hlc: hlc,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required int rev,
                required Uint8List payload,
                required String hlc,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => EntryHistoryCompanion.insert(
                entryId: entryId,
                rev: rev,
                payload: payload,
                hlc: hlc,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntryHistoryTable, EntryHistoryRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $EntryHistoryTable,
                    EntryHistoryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntryHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $EntryHistoryTable,
      EntryHistoryRow,
      $$EntryHistoryTableFilterComposer,
      $$EntryHistoryTableOrderingComposer,
      $$EntryHistoryTableAnnotationComposer,
      $$EntryHistoryTableCreateCompanionBuilder,
      $$EntryHistoryTableUpdateCompanionBuilder,
      (
        EntryHistoryRow,
        BaseReferences<_$VaultDatabase, $EntryHistoryTable, EntryHistoryRow>,
      ),
      EntryHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$TrashRowsTableCreateCompanionBuilder = TrashRowsCompanion Function({
  required String entryId,
  required Uint8List payload,
  required int deletedAt,
  required int expireAt,
  Value<int> rowid,
});
typedef $$TrashRowsTableUpdateCompanionBuilder = TrashRowsCompanion Function({
  Value<String> entryId,
  Value<Uint8List> payload,
  Value<int> deletedAt,
  Value<int> expireAt,
  Value<int> rowid,
});

class $$TrashRowsTableFilterComposer
    extends Composer<_$VaultDatabase, $TrashRowsTable> {
  $$TrashRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expireAt => $composableBuilder(
    column: $table.expireAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrashRowsTableOrderingComposer
    extends Composer<_$VaultDatabase, $TrashRowsTable> {
  $$TrashRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expireAt => $composableBuilder(
    column: $table.expireAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrashRowsTableAnnotationComposer
    extends Composer<_$VaultDatabase, $TrashRowsTable> {
  $$TrashRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get expireAt =>
      $composableBuilder(column: $table.expireAt, builder: (column) => column);
}

class $$TrashRowsTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $TrashRowsTable,
          TrashRow,
          $$TrashRowsTableFilterComposer,
          $$TrashRowsTableOrderingComposer,
          $$TrashRowsTableAnnotationComposer,
          $$TrashRowsTableCreateCompanionBuilder,
          $$TrashRowsTableUpdateCompanionBuilder,
          (
            TrashRow,
            BaseReferences<_$VaultDatabase, $TrashRowsTable, TrashRow>,
          ),
          TrashRow,
          PrefetchHooks Function()
        > {
  $$TrashRowsTableTableManager(_$VaultDatabase db, $TrashRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrashRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrashRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrashRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<Uint8List> payload = const Value.absent(),
                Value<int> deletedAt = const Value.absent(),
                Value<int> expireAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrashRowsCompanion(
                entryId: entryId,
                payload: payload,
                deletedAt: deletedAt,
                expireAt: expireAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required Uint8List payload,
                required int deletedAt,
                required int expireAt,
                Value<int> rowid = const Value.absent(),
              }) => TrashRowsCompanion.insert(
                entryId: entryId,
                payload: payload,
                deletedAt: deletedAt,
                expireAt: expireAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrashRowsTable, TrashRow>(table),
                  BaseReferences<_$VaultDatabase, $TrashRowsTable, TrashRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrashRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $TrashRowsTable,
      TrashRow,
      $$TrashRowsTableFilterComposer,
      $$TrashRowsTableOrderingComposer,
      $$TrashRowsTableAnnotationComposer,
      $$TrashRowsTableCreateCompanionBuilder,
      $$TrashRowsTableUpdateCompanionBuilder,
      (TrashRow, BaseReferences<_$VaultDatabase, $TrashRowsTable, TrashRow>),
      TrashRow,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required int kind,
  Value<String?> parentId,
  required String name,
  Value<String?> color,
  Value<String?> icon,
  Value<int> sortOrder,
  Value<int> entryCount,
  Value<int?> createdAt,
  Value<int?> updatedAt,
  required String hlc,
  Value<int> deleted,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<int> kind,
  Value<String?> parentId,
  Value<String> name,
  Value<String?> color,
  Value<String?> icon,
  Value<int> sortOrder,
  Value<int> entryCount,
  Value<int?> createdAt,
  Value<int?> updatedAt,
  Value<String> hlc,
  Value<int> deleted,
  Value<int> rowid,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$VaultDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$VaultDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$VaultDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<int> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (
            CategoryRow,
            BaseReferences<_$VaultDatabase, $CategoriesTable, CategoryRow>,
          ),
          CategoryRow,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$VaultDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> entryCount = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                kind: kind,
                parentId: parentId,
                name: name,
                color: color,
                icon: icon,
                sortOrder: sortOrder,
                entryCount: entryCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                hlc: hlc,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int kind,
                Value<String?> parentId = const Value.absent(),
                required String name,
                Value<String?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> entryCount = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                required String hlc,
                Value<int> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                kind: kind,
                parentId: parentId,
                name: name,
                color: color,
                icon: icon,
                sortOrder: sortOrder,
                entryCount: entryCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                hlc: hlc,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, CategoryRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $CategoriesTable,
                    CategoryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (
        CategoryRow,
        BaseReferences<_$VaultDatabase, $CategoriesTable, CategoryRow>,
      ),
      CategoryRow,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  required String id,
  required String name,
  Value<String?> color,
  Value<int> usageCount,
  Value<int?> createdAt,
  Value<int?> updatedAt,
  required String hlc,
  Value<int> deleted,
  Value<int> rowid,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> color,
  Value<int> usageCount,
  Value<int?> createdAt,
  Value<int?> updatedAt,
  Value<String> hlc,
  Value<int> deleted,
  Value<int> rowid,
});

class $$TagsTableFilterComposer extends Composer<_$VaultDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer
    extends Composer<_$VaultDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$VaultDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<int> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $TagsTable,
          TagRow,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (TagRow, BaseReferences<_$VaultDatabase, $TagsTable, TagRow>),
          TagRow,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$VaultDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> usageCount = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                color: color,
                usageCount: usageCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                hlc: hlc,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> color = const Value.absent(),
                Value<int> usageCount = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                required String hlc,
                Value<int> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                color: color,
                usageCount: usageCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                hlc: hlc,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, TagRow>(table),
                  BaseReferences<_$VaultDatabase, $TagsTable, TagRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $TagsTable,
      TagRow,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (TagRow, BaseReferences<_$VaultDatabase, $TagsTable, TagRow>),
      TagRow,
      PrefetchHooks Function()
    >;
typedef $$EntryCategoriesTableCreateCompanionBuilder =
    EntryCategoriesCompanion Function({
      required String entryId,
      required String categoryId,
      Value<int> rowid,
    });
typedef $$EntryCategoriesTableUpdateCompanionBuilder =
    EntryCategoriesCompanion Function({
      Value<String> entryId,
      Value<String> categoryId,
      Value<int> rowid,
    });

class $$EntryCategoriesTableFilterComposer
    extends Composer<_$VaultDatabase, $EntryCategoriesTable> {
  $$EntryCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntryCategoriesTableOrderingComposer
    extends Composer<_$VaultDatabase, $EntryCategoriesTable> {
  $$EntryCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntryCategoriesTableAnnotationComposer
    extends Composer<_$VaultDatabase, $EntryCategoriesTable> {
  $$EntryCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );
}

class $$EntryCategoriesTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $EntryCategoriesTable,
          EntryCategoryRow,
          $$EntryCategoriesTableFilterComposer,
          $$EntryCategoriesTableOrderingComposer,
          $$EntryCategoriesTableAnnotationComposer,
          $$EntryCategoriesTableCreateCompanionBuilder,
          $$EntryCategoriesTableUpdateCompanionBuilder,
          (
            EntryCategoryRow,
            BaseReferences<
              _$VaultDatabase,
              $EntryCategoriesTable,
              EntryCategoryRow
            >,
          ),
          EntryCategoryRow,
          PrefetchHooks Function()
        > {
  $$EntryCategoriesTableTableManager(
    _$VaultDatabase db,
    $EntryCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntryCategoriesCompanion(
                entryId: entryId,
                categoryId: categoryId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String categoryId,
                Value<int> rowid = const Value.absent(),
              }) => EntryCategoriesCompanion.insert(
                entryId: entryId,
                categoryId: categoryId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntryCategoriesTable, EntryCategoryRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $EntryCategoriesTable,
                    EntryCategoryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntryCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $EntryCategoriesTable,
      EntryCategoryRow,
      $$EntryCategoriesTableFilterComposer,
      $$EntryCategoriesTableOrderingComposer,
      $$EntryCategoriesTableAnnotationComposer,
      $$EntryCategoriesTableCreateCompanionBuilder,
      $$EntryCategoriesTableUpdateCompanionBuilder,
      (
        EntryCategoryRow,
        BaseReferences<
          _$VaultDatabase,
          $EntryCategoriesTable,
          EntryCategoryRow
        >,
      ),
      EntryCategoryRow,
      PrefetchHooks Function()
    >;
typedef $$EntryTagsTableCreateCompanionBuilder = EntryTagsCompanion Function({
  required String entryId,
  required String tagId,
  Value<int> rowid,
});
typedef $$EntryTagsTableUpdateCompanionBuilder = EntryTagsCompanion Function({
  Value<String> entryId,
  Value<String> tagId,
  Value<int> rowid,
});

class $$EntryTagsTableFilterComposer
    extends Composer<_$VaultDatabase, $EntryTagsTable> {
  $$EntryTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntryTagsTableOrderingComposer
    extends Composer<_$VaultDatabase, $EntryTagsTable> {
  $$EntryTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntryTagsTableAnnotationComposer
    extends Composer<_$VaultDatabase, $EntryTagsTable> {
  $$EntryTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$EntryTagsTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $EntryTagsTable,
          EntryTagRow,
          $$EntryTagsTableFilterComposer,
          $$EntryTagsTableOrderingComposer,
          $$EntryTagsTableAnnotationComposer,
          $$EntryTagsTableCreateCompanionBuilder,
          $$EntryTagsTableUpdateCompanionBuilder,
          (
            EntryTagRow,
            BaseReferences<_$VaultDatabase, $EntryTagsTable, EntryTagRow>,
          ),
          EntryTagRow,
          PrefetchHooks Function()
        > {
  $$EntryTagsTableTableManager(_$VaultDatabase db, $EntryTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntryTagsCompanion(
                entryId: entryId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => EntryTagsCompanion.insert(
                entryId: entryId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntryTagsTable, EntryTagRow>(table),
                  BaseReferences<_$VaultDatabase, $EntryTagsTable, EntryTagRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntryTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $EntryTagsTable,
      EntryTagRow,
      $$EntryTagsTableFilterComposer,
      $$EntryTagsTableOrderingComposer,
      $$EntryTagsTableAnnotationComposer,
      $$EntryTagsTableCreateCompanionBuilder,
      $$EntryTagsTableUpdateCompanionBuilder,
      (
        EntryTagRow,
        BaseReferences<_$VaultDatabase, $EntryTagsTable, EntryTagRow>,
      ),
      EntryTagRow,
      PrefetchHooks Function()
    >;
typedef $$CategoryFieldTemplatesTableCreateCompanionBuilder =
    CategoryFieldTemplatesCompanion Function({
      required String id,
      required String categoryId,
      required String label,
      Value<String> type,
      Value<int> secret,
      Value<int> sortOrder,
      required String hlc,
      Value<int> rowid,
    });
typedef $$CategoryFieldTemplatesTableUpdateCompanionBuilder =
    CategoryFieldTemplatesCompanion Function({
      Value<String> id,
      Value<String> categoryId,
      Value<String> label,
      Value<String> type,
      Value<int> secret,
      Value<int> sortOrder,
      Value<String> hlc,
      Value<int> rowid,
    });

class $$CategoryFieldTemplatesTableFilterComposer
    extends Composer<_$VaultDatabase, $CategoryFieldTemplatesTable> {
  $$CategoryFieldTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get secret => $composableBuilder(
    column: $table.secret,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoryFieldTemplatesTableOrderingComposer
    extends Composer<_$VaultDatabase, $CategoryFieldTemplatesTable> {
  $$CategoryFieldTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get secret => $composableBuilder(
    column: $table.secret,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoryFieldTemplatesTableAnnotationComposer
    extends Composer<_$VaultDatabase, $CategoryFieldTemplatesTable> {
  $$CategoryFieldTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get secret =>
      $composableBuilder(column: $table.secret, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);
}

class $$CategoryFieldTemplatesTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $CategoryFieldTemplatesTable,
          CategoryFieldTemplateRow,
          $$CategoryFieldTemplatesTableFilterComposer,
          $$CategoryFieldTemplatesTableOrderingComposer,
          $$CategoryFieldTemplatesTableAnnotationComposer,
          $$CategoryFieldTemplatesTableCreateCompanionBuilder,
          $$CategoryFieldTemplatesTableUpdateCompanionBuilder,
          (
            CategoryFieldTemplateRow,
            BaseReferences<
              _$VaultDatabase,
              $CategoryFieldTemplatesTable,
              CategoryFieldTemplateRow
            >,
          ),
          CategoryFieldTemplateRow,
          PrefetchHooks Function()
        > {
  $$CategoryFieldTemplatesTableTableManager(
    _$VaultDatabase db,
    $CategoryFieldTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryFieldTemplatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CategoryFieldTemplatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CategoryFieldTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> secret = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryFieldTemplatesCompanion(
                id: id,
                categoryId: categoryId,
                label: label,
                type: type,
                secret: secret,
                sortOrder: sortOrder,
                hlc: hlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String categoryId,
                required String label,
                Value<String> type = const Value.absent(),
                Value<int> secret = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required String hlc,
                Value<int> rowid = const Value.absent(),
              }) => CategoryFieldTemplatesCompanion.insert(
                id: id,
                categoryId: categoryId,
                label: label,
                type: type,
                secret: secret,
                sortOrder: sortOrder,
                hlc: hlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $CategoryFieldTemplatesTable,
                    CategoryFieldTemplateRow
                  >(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $CategoryFieldTemplatesTable,
                    CategoryFieldTemplateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoryFieldTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $CategoryFieldTemplatesTable,
      CategoryFieldTemplateRow,
      $$CategoryFieldTemplatesTableFilterComposer,
      $$CategoryFieldTemplatesTableOrderingComposer,
      $$CategoryFieldTemplatesTableAnnotationComposer,
      $$CategoryFieldTemplatesTableCreateCompanionBuilder,
      $$CategoryFieldTemplatesTableUpdateCompanionBuilder,
      (
        CategoryFieldTemplateRow,
        BaseReferences<
          _$VaultDatabase,
          $CategoryFieldTemplatesTable,
          CategoryFieldTemplateRow
        >,
      ),
      CategoryFieldTemplateRow,
      PrefetchHooks Function()
    >;
typedef $$CredentialsTableCreateCompanionBuilder =
    CredentialsCompanion Function({
      required String id,
      Value<String?> username,
      Value<String?> password,
      Value<String?> totpSecret,
      Value<String?> url,
      Value<String?> notes,
      Value<String?> customFields,
      Value<int?> passwordChangedAt,
      Value<int> breached,
      Value<int> rowid,
    });
typedef $$CredentialsTableUpdateCompanionBuilder =
    CredentialsCompanion Function({
      Value<String> id,
      Value<String?> username,
      Value<String?> password,
      Value<String?> totpSecret,
      Value<String?> url,
      Value<String?> notes,
      Value<String?> customFields,
      Value<int?> passwordChangedAt,
      Value<int> breached,
      Value<int> rowid,
    });

class $$CredentialsTableFilterComposer
    extends Composer<_$VaultDatabase, $CredentialsTable> {
  $$CredentialsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get password => $composableBuilder(
    column: $table.password,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get totpSecret => $composableBuilder(
    column: $table.totpSecret,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customFields => $composableBuilder(
    column: $table.customFields,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get passwordChangedAt => $composableBuilder(
    column: $table.passwordChangedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get breached => $composableBuilder(
    column: $table.breached,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CredentialsTableOrderingComposer
    extends Composer<_$VaultDatabase, $CredentialsTable> {
  $$CredentialsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get password => $composableBuilder(
    column: $table.password,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totpSecret => $composableBuilder(
    column: $table.totpSecret,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customFields => $composableBuilder(
    column: $table.customFields,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get passwordChangedAt => $composableBuilder(
    column: $table.passwordChangedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get breached => $composableBuilder(
    column: $table.breached,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CredentialsTableAnnotationComposer
    extends Composer<_$VaultDatabase, $CredentialsTable> {
  $$CredentialsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get password =>
      $composableBuilder(column: $table.password, builder: (column) => column);

  GeneratedColumn<String> get totpSecret => $composableBuilder(
    column: $table.totpSecret,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get customFields => $composableBuilder(
    column: $table.customFields,
    builder: (column) => column,
  );

  GeneratedColumn<int> get passwordChangedAt => $composableBuilder(
    column: $table.passwordChangedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get breached =>
      $composableBuilder(column: $table.breached, builder: (column) => column);
}

class $$CredentialsTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $CredentialsTable,
          CredentialRow,
          $$CredentialsTableFilterComposer,
          $$CredentialsTableOrderingComposer,
          $$CredentialsTableAnnotationComposer,
          $$CredentialsTableCreateCompanionBuilder,
          $$CredentialsTableUpdateCompanionBuilder,
          (
            CredentialRow,
            BaseReferences<_$VaultDatabase, $CredentialsTable, CredentialRow>,
          ),
          CredentialRow,
          PrefetchHooks Function()
        > {
  $$CredentialsTableTableManager(_$VaultDatabase db, $CredentialsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CredentialsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CredentialsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CredentialsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> password = const Value.absent(),
                Value<String?> totpSecret = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> customFields = const Value.absent(),
                Value<int?> passwordChangedAt = const Value.absent(),
                Value<int> breached = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CredentialsCompanion(
                id: id,
                username: username,
                password: password,
                totpSecret: totpSecret,
                url: url,
                notes: notes,
                customFields: customFields,
                passwordChangedAt: passwordChangedAt,
                breached: breached,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> username = const Value.absent(),
                Value<String?> password = const Value.absent(),
                Value<String?> totpSecret = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> customFields = const Value.absent(),
                Value<int?> passwordChangedAt = const Value.absent(),
                Value<int> breached = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CredentialsCompanion.insert(
                id: id,
                username: username,
                password: password,
                totpSecret: totpSecret,
                url: url,
                notes: notes,
                customFields: customFields,
                passwordChangedAt: passwordChangedAt,
                breached: breached,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CredentialsTable, CredentialRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $CredentialsTable,
                    CredentialRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CredentialsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $CredentialsTable,
      CredentialRow,
      $$CredentialsTableFilterComposer,
      $$CredentialsTableOrderingComposer,
      $$CredentialsTableAnnotationComposer,
      $$CredentialsTableCreateCompanionBuilder,
      $$CredentialsTableUpdateCompanionBuilder,
      (
        CredentialRow,
        BaseReferences<_$VaultDatabase, $CredentialsTable, CredentialRow>,
      ),
      CredentialRow,
      PrefetchHooks Function()
    >;
typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      Value<String?> title,
      Value<String?> groupId,
      Value<int?> createdAt,
      Value<int?> updatedAt,
      required String hlc,
      Value<int> messageCount,
      Value<int> deleted,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String?> title,
      Value<String?> groupId,
      Value<int?> createdAt,
      Value<int?> updatedAt,
      Value<String> hlc,
      Value<int> messageCount,
      Value<int> deleted,
      Value<int> rowid,
    });

class $$ConversationsTableFilterComposer
    extends Composer<_$VaultDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$VaultDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$VaultDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $ConversationsTable,
          ConversationRow,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (
            ConversationRow,
            BaseReferences<
              _$VaultDatabase,
              $ConversationsTable,
              ConversationRow
            >,
          ),
          ConversationRow,
          PrefetchHooks Function()
        > {
  $$ConversationsTableTableManager(
    _$VaultDatabase db,
    $ConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> messageCount = const Value.absent(),
                Value<int> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                title: title,
                groupId: groupId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                hlc: hlc,
                messageCount: messageCount,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> title = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                required String hlc,
                Value<int> messageCount = const Value.absent(),
                Value<int> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                title: title,
                groupId: groupId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                hlc: hlc,
                messageCount: messageCount,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConversationsTable, ConversationRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $ConversationsTable,
                    ConversationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $ConversationsTable,
      ConversationRow,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (
        ConversationRow,
        BaseReferences<_$VaultDatabase, $ConversationsTable, ConversationRow>,
      ),
      ConversationRow,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  required String id,
  required String conversationId,
  required int role,
  Value<String?> content,
  Value<String?> toolCalls,
  Value<String?> citations,
  Value<int?> createdAt,
  required String hlc,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<String> id,
  Value<String> conversationId,
  Value<int> role,
  Value<String?> content,
  Value<String?> toolCalls,
  Value<String?> citations,
  Value<int?> createdAt,
  Value<String> hlc,
  Value<int> rowid,
});

class $$MessagesTableFilterComposer
    extends Composer<_$VaultDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolCalls => $composableBuilder(
    column: $table.toolCalls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get citations => $composableBuilder(
    column: $table.citations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$VaultDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolCalls => $composableBuilder(
    column: $table.toolCalls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get citations => $composableBuilder(
    column: $table.citations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$VaultDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get toolCalls =>
      $composableBuilder(column: $table.toolCalls, builder: (column) => column);

  GeneratedColumn<String> get citations =>
      $composableBuilder(column: $table.citations, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $MessagesTable,
          MessageRow,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (
            MessageRow,
            BaseReferences<_$VaultDatabase, $MessagesTable, MessageRow>,
          ),
          MessageRow,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$VaultDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<int> role = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> toolCalls = const Value.absent(),
                Value<String?> citations = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                conversationId: conversationId,
                role: role,
                content: content,
                toolCalls: toolCalls,
                citations: citations,
                createdAt: createdAt,
                hlc: hlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required int role,
                Value<String?> content = const Value.absent(),
                Value<String?> toolCalls = const Value.absent(),
                Value<String?> citations = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                required String hlc,
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                role: role,
                content: content,
                toolCalls: toolCalls,
                citations: citations,
                createdAt: createdAt,
                hlc: hlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessagesTable, MessageRow>(table),
                  BaseReferences<_$VaultDatabase, $MessagesTable, MessageRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $MessagesTable,
      MessageRow,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (MessageRow, BaseReferences<_$VaultDatabase, $MessagesTable, MessageRow>),
      MessageRow,
      PrefetchHooks Function()
    >;
typedef $$OplogsTableCreateCompanionBuilder = OplogsCompanion Function({
  Value<int> seq,
  required String hlc,
  required String deviceId,
  required String entity,
  required String entityId,
  required int op,
  Value<Uint8List?> payload,
  Value<int?> baseRev,
  Value<int> applied,
  required int createdAt,
});
typedef $$OplogsTableUpdateCompanionBuilder = OplogsCompanion Function({
  Value<int> seq,
  Value<String> hlc,
  Value<String> deviceId,
  Value<String> entity,
  Value<String> entityId,
  Value<int> op,
  Value<Uint8List?> payload,
  Value<int?> baseRev,
  Value<int> applied,
  Value<int> createdAt,
});

class $$OplogsTableFilterComposer
    extends Composer<_$VaultDatabase, $OplogsTable> {
  $$OplogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRev => $composableBuilder(
    column: $table.baseRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get applied => $composableBuilder(
    column: $table.applied,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OplogsTableOrderingComposer
    extends Composer<_$VaultDatabase, $OplogsTable> {
  $$OplogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRev => $composableBuilder(
    column: $table.baseRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get applied => $composableBuilder(
    column: $table.applied,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OplogsTableAnnotationComposer
    extends Composer<_$VaultDatabase, $OplogsTable> {
  $$OplogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get baseRev =>
      $composableBuilder(column: $table.baseRev, builder: (column) => column);

  GeneratedColumn<int> get applied =>
      $composableBuilder(column: $table.applied, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OplogsTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $OplogsTable,
          OplogRow,
          $$OplogsTableFilterComposer,
          $$OplogsTableOrderingComposer,
          $$OplogsTableAnnotationComposer,
          $$OplogsTableCreateCompanionBuilder,
          $$OplogsTableUpdateCompanionBuilder,
          (OplogRow, BaseReferences<_$VaultDatabase, $OplogsTable, OplogRow>),
          OplogRow,
          PrefetchHooks Function()
        > {
  $$OplogsTableTableManager(_$VaultDatabase db, $OplogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OplogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OplogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OplogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> op = const Value.absent(),
                Value<Uint8List?> payload = const Value.absent(),
                Value<int?> baseRev = const Value.absent(),
                Value<int> applied = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => OplogsCompanion(
                seq: seq,
                hlc: hlc,
                deviceId: deviceId,
                entity: entity,
                entityId: entityId,
                op: op,
                payload: payload,
                baseRev: baseRev,
                applied: applied,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String hlc,
                required String deviceId,
                required String entity,
                required String entityId,
                required int op,
                Value<Uint8List?> payload = const Value.absent(),
                Value<int?> baseRev = const Value.absent(),
                Value<int> applied = const Value.absent(),
                required int createdAt,
              }) => OplogsCompanion.insert(
                seq: seq,
                hlc: hlc,
                deviceId: deviceId,
                entity: entity,
                entityId: entityId,
                op: op,
                payload: payload,
                baseRev: baseRev,
                applied: applied,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OplogsTable, OplogRow>(table),
                  BaseReferences<_$VaultDatabase, $OplogsTable, OplogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OplogsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $OplogsTable,
      OplogRow,
      $$OplogsTableFilterComposer,
      $$OplogsTableOrderingComposer,
      $$OplogsTableAnnotationComposer,
      $$OplogsTableCreateCompanionBuilder,
      $$OplogsTableUpdateCompanionBuilder,
      (OplogRow, BaseReferences<_$VaultDatabase, $OplogsTable, OplogRow>),
      OplogRow,
      PrefetchHooks Function()
    >;
typedef $$ActivitiesTableCreateCompanionBuilder = ActivitiesCompanion Function({
  Value<int> id,
  required int ts,
  required int kind,
  Value<String?> entryId,
  Value<int?> dwellMs,
  Value<String?> query,
  Value<String?> extra,
});
typedef $$ActivitiesTableUpdateCompanionBuilder = ActivitiesCompanion Function({
  Value<int> id,
  Value<int> ts,
  Value<int> kind,
  Value<String?> entryId,
  Value<int?> dwellMs,
  Value<String?> query,
  Value<String?> extra,
});

class $$ActivitiesTableFilterComposer
    extends Composer<_$VaultDatabase, $ActivitiesTable> {
  $$ActivitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dwellMs => $composableBuilder(
    column: $table.dwellMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivitiesTableOrderingComposer
    extends Composer<_$VaultDatabase, $ActivitiesTable> {
  $$ActivitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dwellMs => $composableBuilder(
    column: $table.dwellMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivitiesTableAnnotationComposer
    extends Composer<_$VaultDatabase, $ActivitiesTable> {
  $$ActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<int> get dwellMs =>
      $composableBuilder(column: $table.dwellMs, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get extra =>
      $composableBuilder(column: $table.extra, builder: (column) => column);
}

class $$ActivitiesTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $ActivitiesTable,
          ActivityRow,
          $$ActivitiesTableFilterComposer,
          $$ActivitiesTableOrderingComposer,
          $$ActivitiesTableAnnotationComposer,
          $$ActivitiesTableCreateCompanionBuilder,
          $$ActivitiesTableUpdateCompanionBuilder,
          (
            ActivityRow,
            BaseReferences<_$VaultDatabase, $ActivitiesTable, ActivityRow>,
          ),
          ActivityRow,
          PrefetchHooks Function()
        > {
  $$ActivitiesTableTableManager(_$VaultDatabase db, $ActivitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ts = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String?> entryId = const Value.absent(),
                Value<int?> dwellMs = const Value.absent(),
                Value<String?> query = const Value.absent(),
                Value<String?> extra = const Value.absent(),
              }) => ActivitiesCompanion(
                id: id,
                ts: ts,
                kind: kind,
                entryId: entryId,
                dwellMs: dwellMs,
                query: query,
                extra: extra,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ts,
                required int kind,
                Value<String?> entryId = const Value.absent(),
                Value<int?> dwellMs = const Value.absent(),
                Value<String?> query = const Value.absent(),
                Value<String?> extra = const Value.absent(),
              }) => ActivitiesCompanion.insert(
                id: id,
                ts: ts,
                kind: kind,
                entryId: entryId,
                dwellMs: dwellMs,
                query: query,
                extra: extra,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActivitiesTable, ActivityRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $ActivitiesTable,
                    ActivityRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $ActivitiesTable,
      ActivityRow,
      $$ActivitiesTableFilterComposer,
      $$ActivitiesTableOrderingComposer,
      $$ActivitiesTableAnnotationComposer,
      $$ActivitiesTableCreateCompanionBuilder,
      $$ActivitiesTableUpdateCompanionBuilder,
      (
        ActivityRow,
        BaseReferences<_$VaultDatabase, $ActivitiesTable, ActivityRow>,
      ),
      ActivityRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder = SyncStatesCompanion Function({
  required String path,
  Value<String?> etag,
  Value<int?> size,
  Value<String?> hlc,
  Value<int?> updatedAt,
  Value<int> rowid,
});
typedef $$SyncStatesTableUpdateCompanionBuilder = SyncStatesCompanion Function({
  Value<String> path,
  Value<String?> etag,
  Value<int?> size,
  Value<String?> hlc,
  Value<int?> updatedAt,
  Value<int> rowid,
});

class $$SyncStatesTableFilterComposer
    extends Composer<_$VaultDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$VaultDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$VaultDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $SyncStatesTable,
          SyncStateRow,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$VaultDatabase, $SyncStatesTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$VaultDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<String?> hlc = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(
                path: path,
                etag: etag,
                size: size,
                hlc: hlc,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                Value<String?> etag = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<String?> hlc = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                path: path,
                etag: etag,
                size: size,
                hlc: hlc,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStatesTable, SyncStateRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $SyncStatesTable,
                    SyncStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $SyncStatesTable,
      SyncStateRow,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$VaultDatabase, $SyncStatesTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$DeviceWatermarksTableCreateCompanionBuilder =
    DeviceWatermarksCompanion Function({
      required String deviceId,
      Value<String?> maxHlc,
      Value<int?> lastSeen,
      Value<String?> platform,
      Value<String?> appVersion,
      Value<int> rowid,
    });
typedef $$DeviceWatermarksTableUpdateCompanionBuilder =
    DeviceWatermarksCompanion Function({
      Value<String> deviceId,
      Value<String?> maxHlc,
      Value<int?> lastSeen,
      Value<String?> platform,
      Value<String?> appVersion,
      Value<int> rowid,
    });

class $$DeviceWatermarksTableFilterComposer
    extends Composer<_$VaultDatabase, $DeviceWatermarksTable> {
  $$DeviceWatermarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get maxHlc => $composableBuilder(
    column: $table.maxHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceWatermarksTableOrderingComposer
    extends Composer<_$VaultDatabase, $DeviceWatermarksTable> {
  $$DeviceWatermarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get maxHlc => $composableBuilder(
    column: $table.maxHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceWatermarksTableAnnotationComposer
    extends Composer<_$VaultDatabase, $DeviceWatermarksTable> {
  $$DeviceWatermarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get maxHlc =>
      $composableBuilder(column: $table.maxHlc, builder: (column) => column);

  GeneratedColumn<int> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => column,
  );
}

class $$DeviceWatermarksTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $DeviceWatermarksTable,
          DeviceWatermarkRow,
          $$DeviceWatermarksTableFilterComposer,
          $$DeviceWatermarksTableOrderingComposer,
          $$DeviceWatermarksTableAnnotationComposer,
          $$DeviceWatermarksTableCreateCompanionBuilder,
          $$DeviceWatermarksTableUpdateCompanionBuilder,
          (
            DeviceWatermarkRow,
            BaseReferences<
              _$VaultDatabase,
              $DeviceWatermarksTable,
              DeviceWatermarkRow
            >,
          ),
          DeviceWatermarkRow,
          PrefetchHooks Function()
        > {
  $$DeviceWatermarksTableTableManager(
    _$VaultDatabase db,
    $DeviceWatermarksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceWatermarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceWatermarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceWatermarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String?> maxHlc = const Value.absent(),
                Value<int?> lastSeen = const Value.absent(),
                Value<String?> platform = const Value.absent(),
                Value<String?> appVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceWatermarksCompanion(
                deviceId: deviceId,
                maxHlc: maxHlc,
                lastSeen: lastSeen,
                platform: platform,
                appVersion: appVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                Value<String?> maxHlc = const Value.absent(),
                Value<int?> lastSeen = const Value.absent(),
                Value<String?> platform = const Value.absent(),
                Value<String?> appVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceWatermarksCompanion.insert(
                deviceId: deviceId,
                maxHlc: maxHlc,
                lastSeen: lastSeen,
                platform: platform,
                appVersion: appVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeviceWatermarksTable, DeviceWatermarkRow>(
                    table,
                  ),
                  BaseReferences<
                    _$VaultDatabase,
                    $DeviceWatermarksTable,
                    DeviceWatermarkRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceWatermarksTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $DeviceWatermarksTable,
      DeviceWatermarkRow,
      $$DeviceWatermarksTableFilterComposer,
      $$DeviceWatermarksTableOrderingComposer,
      $$DeviceWatermarksTableAnnotationComposer,
      $$DeviceWatermarksTableCreateCompanionBuilder,
      $$DeviceWatermarksTableUpdateCompanionBuilder,
      (
        DeviceWatermarkRow,
        BaseReferences<
          _$VaultDatabase,
          $DeviceWatermarksTable,
          DeviceWatermarkRow
        >,
      ),
      DeviceWatermarkRow,
      PrefetchHooks Function()
    >;
typedef $$SyncLogsTableCreateCompanionBuilder = SyncLogsCompanion Function({
  Value<int> id,
  Value<int?> startedAt,
  Value<int?> finishedAt,
  Value<String?> trigger,
  Value<String?> result,
  Value<int?> pulled,
  Value<int?> pushed,
  Value<int?> conflicts,
  Value<String?> errorCode,
  Value<String?> errorMsg,
  Value<int?> requestCount,
});
typedef $$SyncLogsTableUpdateCompanionBuilder = SyncLogsCompanion Function({
  Value<int> id,
  Value<int?> startedAt,
  Value<int?> finishedAt,
  Value<String?> trigger,
  Value<String?> result,
  Value<int?> pulled,
  Value<int?> pushed,
  Value<int?> conflicts,
  Value<String?> errorCode,
  Value<String?> errorMsg,
  Value<int?> requestCount,
});

class $$SyncLogsTableFilterComposer
    extends Composer<_$VaultDatabase, $SyncLogsTable> {
  $$SyncLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pulled => $composableBuilder(
    column: $table.pulled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pushed => $composableBuilder(
    column: $table.pushed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get conflicts => $composableBuilder(
    column: $table.conflicts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMsg => $composableBuilder(
    column: $table.errorMsg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requestCount => $composableBuilder(
    column: $table.requestCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncLogsTableOrderingComposer
    extends Composer<_$VaultDatabase, $SyncLogsTable> {
  $$SyncLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pulled => $composableBuilder(
    column: $table.pulled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pushed => $composableBuilder(
    column: $table.pushed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get conflicts => $composableBuilder(
    column: $table.conflicts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMsg => $composableBuilder(
    column: $table.errorMsg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requestCount => $composableBuilder(
    column: $table.requestCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncLogsTableAnnotationComposer
    extends Composer<_$VaultDatabase, $SyncLogsTable> {
  $$SyncLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trigger =>
      $composableBuilder(column: $table.trigger, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<int> get pulled =>
      $composableBuilder(column: $table.pulled, builder: (column) => column);

  GeneratedColumn<int> get pushed =>
      $composableBuilder(column: $table.pushed, builder: (column) => column);

  GeneratedColumn<int> get conflicts =>
      $composableBuilder(column: $table.conflicts, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMsg =>
      $composableBuilder(column: $table.errorMsg, builder: (column) => column);

  GeneratedColumn<int> get requestCount => $composableBuilder(
    column: $table.requestCount,
    builder: (column) => column,
  );
}

class $$SyncLogsTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $SyncLogsTable,
          SyncLogRow,
          $$SyncLogsTableFilterComposer,
          $$SyncLogsTableOrderingComposer,
          $$SyncLogsTableAnnotationComposer,
          $$SyncLogsTableCreateCompanionBuilder,
          $$SyncLogsTableUpdateCompanionBuilder,
          (
            SyncLogRow,
            BaseReferences<_$VaultDatabase, $SyncLogsTable, SyncLogRow>,
          ),
          SyncLogRow,
          PrefetchHooks Function()
        > {
  $$SyncLogsTableTableManager(_$VaultDatabase db, $SyncLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<String?> trigger = const Value.absent(),
                Value<String?> result = const Value.absent(),
                Value<int?> pulled = const Value.absent(),
                Value<int?> pushed = const Value.absent(),
                Value<int?> conflicts = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMsg = const Value.absent(),
                Value<int?> requestCount = const Value.absent(),
              }) => SyncLogsCompanion(
                id: id,
                startedAt: startedAt,
                finishedAt: finishedAt,
                trigger: trigger,
                result: result,
                pulled: pulled,
                pushed: pushed,
                conflicts: conflicts,
                errorCode: errorCode,
                errorMsg: errorMsg,
                requestCount: requestCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<String?> trigger = const Value.absent(),
                Value<String?> result = const Value.absent(),
                Value<int?> pulled = const Value.absent(),
                Value<int?> pushed = const Value.absent(),
                Value<int?> conflicts = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMsg = const Value.absent(),
                Value<int?> requestCount = const Value.absent(),
              }) => SyncLogsCompanion.insert(
                id: id,
                startedAt: startedAt,
                finishedAt: finishedAt,
                trigger: trigger,
                result: result,
                pulled: pulled,
                pushed: pushed,
                conflicts: conflicts,
                errorCode: errorCode,
                errorMsg: errorMsg,
                requestCount: requestCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncLogsTable, SyncLogRow>(table),
                  BaseReferences<_$VaultDatabase, $SyncLogsTable, SyncLogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $SyncLogsTable,
      SyncLogRow,
      $$SyncLogsTableFilterComposer,
      $$SyncLogsTableOrderingComposer,
      $$SyncLogsTableAnnotationComposer,
      $$SyncLogsTableCreateCompanionBuilder,
      $$SyncLogsTableUpdateCompanionBuilder,
      (SyncLogRow, BaseReferences<_$VaultDatabase, $SyncLogsTable, SyncLogRow>),
      SyncLogRow,
      PrefetchHooks Function()
    >;
typedef $$DiaryIndexesTableCreateCompanionBuilder =
    DiaryIndexesCompanion Function({
      required String date,
      Value<String?> userEntryId,
      Value<String?> aiEntryId,
      Value<int> wordCount,
      Value<int> hasMood,
      Value<int> rowid,
    });
typedef $$DiaryIndexesTableUpdateCompanionBuilder =
    DiaryIndexesCompanion Function({
      Value<String> date,
      Value<String?> userEntryId,
      Value<String?> aiEntryId,
      Value<int> wordCount,
      Value<int> hasMood,
      Value<int> rowid,
    });

class $$DiaryIndexesTableFilterComposer
    extends Composer<_$VaultDatabase, $DiaryIndexesTable> {
  $$DiaryIndexesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userEntryId => $composableBuilder(
    column: $table.userEntryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiEntryId => $composableBuilder(
    column: $table.aiEntryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hasMood => $composableBuilder(
    column: $table.hasMood,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiaryIndexesTableOrderingComposer
    extends Composer<_$VaultDatabase, $DiaryIndexesTable> {
  $$DiaryIndexesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userEntryId => $composableBuilder(
    column: $table.userEntryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiEntryId => $composableBuilder(
    column: $table.aiEntryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hasMood => $composableBuilder(
    column: $table.hasMood,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiaryIndexesTableAnnotationComposer
    extends Composer<_$VaultDatabase, $DiaryIndexesTable> {
  $$DiaryIndexesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get userEntryId => $composableBuilder(
    column: $table.userEntryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiEntryId =>
      $composableBuilder(column: $table.aiEntryId, builder: (column) => column);

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<int> get hasMood =>
      $composableBuilder(column: $table.hasMood, builder: (column) => column);
}

class $$DiaryIndexesTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $DiaryIndexesTable,
          DiaryIndexRow,
          $$DiaryIndexesTableFilterComposer,
          $$DiaryIndexesTableOrderingComposer,
          $$DiaryIndexesTableAnnotationComposer,
          $$DiaryIndexesTableCreateCompanionBuilder,
          $$DiaryIndexesTableUpdateCompanionBuilder,
          (
            DiaryIndexRow,
            BaseReferences<_$VaultDatabase, $DiaryIndexesTable, DiaryIndexRow>,
          ),
          DiaryIndexRow,
          PrefetchHooks Function()
        > {
  $$DiaryIndexesTableTableManager(_$VaultDatabase db, $DiaryIndexesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryIndexesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryIndexesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryIndexesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<String?> userEntryId = const Value.absent(),
                Value<String?> aiEntryId = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<int> hasMood = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryIndexesCompanion(
                date: date,
                userEntryId: userEntryId,
                aiEntryId: aiEntryId,
                wordCount: wordCount,
                hasMood: hasMood,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                Value<String?> userEntryId = const Value.absent(),
                Value<String?> aiEntryId = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<int> hasMood = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryIndexesCompanion.insert(
                date: date,
                userEntryId: userEntryId,
                aiEntryId: aiEntryId,
                wordCount: wordCount,
                hasMood: hasMood,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryIndexesTable, DiaryIndexRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $DiaryIndexesTable,
                    DiaryIndexRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiaryIndexesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $DiaryIndexesTable,
      DiaryIndexRow,
      $$DiaryIndexesTableFilterComposer,
      $$DiaryIndexesTableOrderingComposer,
      $$DiaryIndexesTableAnnotationComposer,
      $$DiaryIndexesTableCreateCompanionBuilder,
      $$DiaryIndexesTableUpdateCompanionBuilder,
      (
        DiaryIndexRow,
        BaseReferences<_$VaultDatabase, $DiaryIndexesTable, DiaryIndexRow>,
      ),
      DiaryIndexRow,
      PrefetchHooks Function()
    >;
typedef $$EntryVecsTableCreateCompanionBuilder = EntryVecsCompanion Function({
  required String entryId,
  Value<int> chunkIdx,
  required String modelId,
  required int dim,
  required Uint8List vec,
  required int computedAt,
  Value<int> rowid,
});
typedef $$EntryVecsTableUpdateCompanionBuilder = EntryVecsCompanion Function({
  Value<String> entryId,
  Value<int> chunkIdx,
  Value<String> modelId,
  Value<int> dim,
  Value<Uint8List> vec,
  Value<int> computedAt,
  Value<int> rowid,
});

class $$EntryVecsTableFilterComposer
    extends Composer<_$VaultDatabase, $EntryVecsTable> {
  $$EntryVecsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkIdx => $composableBuilder(
    column: $table.chunkIdx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dim => $composableBuilder(
    column: $table.dim,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get vec => $composableBuilder(
    column: $table.vec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntryVecsTableOrderingComposer
    extends Composer<_$VaultDatabase, $EntryVecsTable> {
  $$EntryVecsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkIdx => $composableBuilder(
    column: $table.chunkIdx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dim => $composableBuilder(
    column: $table.dim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get vec => $composableBuilder(
    column: $table.vec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntryVecsTableAnnotationComposer
    extends Composer<_$VaultDatabase, $EntryVecsTable> {
  $$EntryVecsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<int> get chunkIdx =>
      $composableBuilder(column: $table.chunkIdx, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<int> get dim =>
      $composableBuilder(column: $table.dim, builder: (column) => column);

  GeneratedColumn<Uint8List> get vec =>
      $composableBuilder(column: $table.vec, builder: (column) => column);

  GeneratedColumn<int> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => column,
  );
}

class $$EntryVecsTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $EntryVecsTable,
          EntryVecRow,
          $$EntryVecsTableFilterComposer,
          $$EntryVecsTableOrderingComposer,
          $$EntryVecsTableAnnotationComposer,
          $$EntryVecsTableCreateCompanionBuilder,
          $$EntryVecsTableUpdateCompanionBuilder,
          (
            EntryVecRow,
            BaseReferences<_$VaultDatabase, $EntryVecsTable, EntryVecRow>,
          ),
          EntryVecRow,
          PrefetchHooks Function()
        > {
  $$EntryVecsTableTableManager(_$VaultDatabase db, $EntryVecsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryVecsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryVecsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryVecsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<int> chunkIdx = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<int> dim = const Value.absent(),
                Value<Uint8List> vec = const Value.absent(),
                Value<int> computedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntryVecsCompanion(
                entryId: entryId,
                chunkIdx: chunkIdx,
                modelId: modelId,
                dim: dim,
                vec: vec,
                computedAt: computedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                Value<int> chunkIdx = const Value.absent(),
                required String modelId,
                required int dim,
                required Uint8List vec,
                required int computedAt,
                Value<int> rowid = const Value.absent(),
              }) => EntryVecsCompanion.insert(
                entryId: entryId,
                chunkIdx: chunkIdx,
                modelId: modelId,
                dim: dim,
                vec: vec,
                computedAt: computedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntryVecsTable, EntryVecRow>(table),
                  BaseReferences<_$VaultDatabase, $EntryVecsTable, EntryVecRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntryVecsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $EntryVecsTable,
      EntryVecRow,
      $$EntryVecsTableFilterComposer,
      $$EntryVecsTableOrderingComposer,
      $$EntryVecsTableAnnotationComposer,
      $$EntryVecsTableCreateCompanionBuilder,
      $$EntryVecsTableUpdateCompanionBuilder,
      (
        EntryVecRow,
        BaseReferences<_$VaultDatabase, $EntryVecsTable, EntryVecRow>,
      ),
      EntryVecRow,
      PrefetchHooks Function()
    >;
typedef $$EmbeddingModelsTableCreateCompanionBuilder =
    EmbeddingModelsCompanion Function({
      required String id,
      Value<String?> family,
      Value<int?> dim,
      Value<String?> mrl,
      Value<int?> ctx,
      Value<String?> quant,
      Value<String?> sha256,
      Value<String?> path,
      Value<int> state,
      Value<int?> installedAt,
      Value<int> rowid,
    });
typedef $$EmbeddingModelsTableUpdateCompanionBuilder =
    EmbeddingModelsCompanion Function({
      Value<String> id,
      Value<String?> family,
      Value<int?> dim,
      Value<String?> mrl,
      Value<int?> ctx,
      Value<String?> quant,
      Value<String?> sha256,
      Value<String?> path,
      Value<int> state,
      Value<int?> installedAt,
      Value<int> rowid,
    });

class $$EmbeddingModelsTableFilterComposer
    extends Composer<_$VaultDatabase, $EmbeddingModelsTable> {
  $$EmbeddingModelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dim => $composableBuilder(
    column: $table.dim,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mrl => $composableBuilder(
    column: $table.mrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ctx => $composableBuilder(
    column: $table.ctx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quant => $composableBuilder(
    column: $table.quant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmbeddingModelsTableOrderingComposer
    extends Composer<_$VaultDatabase, $EmbeddingModelsTable> {
  $$EmbeddingModelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dim => $composableBuilder(
    column: $table.dim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mrl => $composableBuilder(
    column: $table.mrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ctx => $composableBuilder(
    column: $table.ctx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quant => $composableBuilder(
    column: $table.quant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmbeddingModelsTableAnnotationComposer
    extends Composer<_$VaultDatabase, $EmbeddingModelsTable> {
  $$EmbeddingModelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get family =>
      $composableBuilder(column: $table.family, builder: (column) => column);

  GeneratedColumn<int> get dim =>
      $composableBuilder(column: $table.dim, builder: (column) => column);

  GeneratedColumn<String> get mrl =>
      $composableBuilder(column: $table.mrl, builder: (column) => column);

  GeneratedColumn<int> get ctx =>
      $composableBuilder(column: $table.ctx, builder: (column) => column);

  GeneratedColumn<String> get quant =>
      $composableBuilder(column: $table.quant, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );
}

class $$EmbeddingModelsTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $EmbeddingModelsTable,
          EmbeddingModelRow,
          $$EmbeddingModelsTableFilterComposer,
          $$EmbeddingModelsTableOrderingComposer,
          $$EmbeddingModelsTableAnnotationComposer,
          $$EmbeddingModelsTableCreateCompanionBuilder,
          $$EmbeddingModelsTableUpdateCompanionBuilder,
          (
            EmbeddingModelRow,
            BaseReferences<
              _$VaultDatabase,
              $EmbeddingModelsTable,
              EmbeddingModelRow
            >,
          ),
          EmbeddingModelRow,
          PrefetchHooks Function()
        > {
  $$EmbeddingModelsTableTableManager(
    _$VaultDatabase db,
    $EmbeddingModelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmbeddingModelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmbeddingModelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmbeddingModelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> family = const Value.absent(),
                Value<int?> dim = const Value.absent(),
                Value<String?> mrl = const Value.absent(),
                Value<int?> ctx = const Value.absent(),
                Value<String?> quant = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<int> state = const Value.absent(),
                Value<int?> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmbeddingModelsCompanion(
                id: id,
                family: family,
                dim: dim,
                mrl: mrl,
                ctx: ctx,
                quant: quant,
                sha256: sha256,
                path: path,
                state: state,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> family = const Value.absent(),
                Value<int?> dim = const Value.absent(),
                Value<String?> mrl = const Value.absent(),
                Value<int?> ctx = const Value.absent(),
                Value<String?> quant = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<int> state = const Value.absent(),
                Value<int?> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmbeddingModelsCompanion.insert(
                id: id,
                family: family,
                dim: dim,
                mrl: mrl,
                ctx: ctx,
                quant: quant,
                sha256: sha256,
                path: path,
                state: state,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EmbeddingModelsTable, EmbeddingModelRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $EmbeddingModelsTable,
                    EmbeddingModelRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmbeddingModelsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $EmbeddingModelsTable,
      EmbeddingModelRow,
      $$EmbeddingModelsTableFilterComposer,
      $$EmbeddingModelsTableOrderingComposer,
      $$EmbeddingModelsTableAnnotationComposer,
      $$EmbeddingModelsTableCreateCompanionBuilder,
      $$EmbeddingModelsTableUpdateCompanionBuilder,
      (
        EmbeddingModelRow,
        BaseReferences<
          _$VaultDatabase,
          $EmbeddingModelsTable,
          EmbeddingModelRow
        >,
      ),
      EmbeddingModelRow,
      PrefetchHooks Function()
    >;
typedef $$BlobRefsTableCreateCompanionBuilder = BlobRefsCompanion Function({
  required String entryId,
  required String blobHash,
  required int kind,
  required int bytes,
  Value<int> local,
  required int createdAt,
  Value<int> rowid,
});
typedef $$BlobRefsTableUpdateCompanionBuilder = BlobRefsCompanion Function({
  Value<String> entryId,
  Value<String> blobHash,
  Value<int> kind,
  Value<int> bytes,
  Value<int> local,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$BlobRefsTableFilterComposer
    extends Composer<_$VaultDatabase, $BlobRefsTable> {
  $$BlobRefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobHash => $composableBuilder(
    column: $table.blobHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get local => $composableBuilder(
    column: $table.local,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlobRefsTableOrderingComposer
    extends Composer<_$VaultDatabase, $BlobRefsTable> {
  $$BlobRefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobHash => $composableBuilder(
    column: $table.blobHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get local => $composableBuilder(
    column: $table.local,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlobRefsTableAnnotationComposer
    extends Composer<_$VaultDatabase, $BlobRefsTable> {
  $$BlobRefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get blobHash =>
      $composableBuilder(column: $table.blobHash, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<int> get local =>
      $composableBuilder(column: $table.local, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BlobRefsTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $BlobRefsTable,
          BlobRefRow,
          $$BlobRefsTableFilterComposer,
          $$BlobRefsTableOrderingComposer,
          $$BlobRefsTableAnnotationComposer,
          $$BlobRefsTableCreateCompanionBuilder,
          $$BlobRefsTableUpdateCompanionBuilder,
          (
            BlobRefRow,
            BaseReferences<_$VaultDatabase, $BlobRefsTable, BlobRefRow>,
          ),
          BlobRefRow,
          PrefetchHooks Function()
        > {
  $$BlobRefsTableTableManager(_$VaultDatabase db, $BlobRefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlobRefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlobRefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlobRefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> blobHash = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<int> local = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlobRefsCompanion(
                entryId: entryId,
                blobHash: blobHash,
                kind: kind,
                bytes: bytes,
                local: local,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String blobHash,
                required int kind,
                required int bytes,
                Value<int> local = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BlobRefsCompanion.insert(
                entryId: entryId,
                blobHash: blobHash,
                kind: kind,
                bytes: bytes,
                local: local,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BlobRefsTable, BlobRefRow>(table),
                  BaseReferences<_$VaultDatabase, $BlobRefsTable, BlobRefRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlobRefsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $BlobRefsTable,
      BlobRefRow,
      $$BlobRefsTableFilterComposer,
      $$BlobRefsTableOrderingComposer,
      $$BlobRefsTableAnnotationComposer,
      $$BlobRefsTableCreateCompanionBuilder,
      $$BlobRefsTableUpdateCompanionBuilder,
      (BlobRefRow, BaseReferences<_$VaultDatabase, $BlobRefsTable, BlobRefRow>),
      BlobRefRow,
      PrefetchHooks Function()
    >;
typedef $$LinkChecksTableCreateCompanionBuilder = LinkChecksCompanion Function({
  required String entryId,
  required int checkedAt,
  Value<int?> httpStatus,
  required String result,
  Value<String?> finalUrl,
  Value<String?> simhash,
  Value<int> rowid,
});
typedef $$LinkChecksTableUpdateCompanionBuilder = LinkChecksCompanion Function({
  Value<String> entryId,
  Value<int> checkedAt,
  Value<int?> httpStatus,
  Value<String> result,
  Value<String?> finalUrl,
  Value<String?> simhash,
  Value<int> rowid,
});

class $$LinkChecksTableFilterComposer
    extends Composer<_$VaultDatabase, $LinkChecksTable> {
  $$LinkChecksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get httpStatus => $composableBuilder(
    column: $table.httpStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalUrl => $composableBuilder(
    column: $table.finalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get simhash => $composableBuilder(
    column: $table.simhash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LinkChecksTableOrderingComposer
    extends Composer<_$VaultDatabase, $LinkChecksTable> {
  $$LinkChecksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get httpStatus => $composableBuilder(
    column: $table.httpStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalUrl => $composableBuilder(
    column: $table.finalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get simhash => $composableBuilder(
    column: $table.simhash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LinkChecksTableAnnotationComposer
    extends Composer<_$VaultDatabase, $LinkChecksTable> {
  $$LinkChecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<int> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);

  GeneratedColumn<int> get httpStatus => $composableBuilder(
    column: $table.httpStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get finalUrl =>
      $composableBuilder(column: $table.finalUrl, builder: (column) => column);

  GeneratedColumn<String> get simhash =>
      $composableBuilder(column: $table.simhash, builder: (column) => column);
}

class $$LinkChecksTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $LinkChecksTable,
          LinkCheckRow,
          $$LinkChecksTableFilterComposer,
          $$LinkChecksTableOrderingComposer,
          $$LinkChecksTableAnnotationComposer,
          $$LinkChecksTableCreateCompanionBuilder,
          $$LinkChecksTableUpdateCompanionBuilder,
          (
            LinkCheckRow,
            BaseReferences<_$VaultDatabase, $LinkChecksTable, LinkCheckRow>,
          ),
          LinkCheckRow,
          PrefetchHooks Function()
        > {
  $$LinkChecksTableTableManager(_$VaultDatabase db, $LinkChecksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LinkChecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LinkChecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LinkChecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<int> checkedAt = const Value.absent(),
                Value<int?> httpStatus = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String?> finalUrl = const Value.absent(),
                Value<String?> simhash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LinkChecksCompanion(
                entryId: entryId,
                checkedAt: checkedAt,
                httpStatus: httpStatus,
                result: result,
                finalUrl: finalUrl,
                simhash: simhash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required int checkedAt,
                Value<int?> httpStatus = const Value.absent(),
                required String result,
                Value<String?> finalUrl = const Value.absent(),
                Value<String?> simhash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LinkChecksCompanion.insert(
                entryId: entryId,
                checkedAt: checkedAt,
                httpStatus: httpStatus,
                result: result,
                finalUrl: finalUrl,
                simhash: simhash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LinkChecksTable, LinkCheckRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $LinkChecksTable,
                    LinkCheckRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LinkChecksTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $LinkChecksTable,
      LinkCheckRow,
      $$LinkChecksTableFilterComposer,
      $$LinkChecksTableOrderingComposer,
      $$LinkChecksTableAnnotationComposer,
      $$LinkChecksTableCreateCompanionBuilder,
      $$LinkChecksTableUpdateCompanionBuilder,
      (
        LinkCheckRow,
        BaseReferences<_$VaultDatabase, $LinkChecksTable, LinkCheckRow>,
      ),
      LinkCheckRow,
      PrefetchHooks Function()
    >;
typedef $$JobQueuesTableCreateCompanionBuilder = JobQueuesCompanion Function({
  Value<int> id,
  required String type,
  Value<String?> payload,
  Value<int> state,
  Value<int> attempts,
  Value<int> nextRunAt,
  required int createdAt,
});
typedef $$JobQueuesTableUpdateCompanionBuilder = JobQueuesCompanion Function({
  Value<int> id,
  Value<String> type,
  Value<String?> payload,
  Value<int> state,
  Value<int> attempts,
  Value<int> nextRunAt,
  Value<int> createdAt,
});

class $$JobQueuesTableFilterComposer
    extends Composer<_$VaultDatabase, $JobQueuesTable> {
  $$JobQueuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextRunAt => $composableBuilder(
    column: $table.nextRunAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JobQueuesTableOrderingComposer
    extends Composer<_$VaultDatabase, $JobQueuesTable> {
  $$JobQueuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextRunAt => $composableBuilder(
    column: $table.nextRunAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JobQueuesTableAnnotationComposer
    extends Composer<_$VaultDatabase, $JobQueuesTable> {
  $$JobQueuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get nextRunAt =>
      $composableBuilder(column: $table.nextRunAt, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$JobQueuesTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $JobQueuesTable,
          JobQueueRow,
          $$JobQueuesTableFilterComposer,
          $$JobQueuesTableOrderingComposer,
          $$JobQueuesTableAnnotationComposer,
          $$JobQueuesTableCreateCompanionBuilder,
          $$JobQueuesTableUpdateCompanionBuilder,
          (
            JobQueueRow,
            BaseReferences<_$VaultDatabase, $JobQueuesTable, JobQueueRow>,
          ),
          JobQueueRow,
          PrefetchHooks Function()
        > {
  $$JobQueuesTableTableManager(_$VaultDatabase db, $JobQueuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JobQueuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JobQueuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JobQueuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<int> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> nextRunAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => JobQueuesCompanion(
                id: id,
                type: type,
                payload: payload,
                state: state,
                attempts: attempts,
                nextRunAt: nextRunAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                Value<String?> payload = const Value.absent(),
                Value<int> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> nextRunAt = const Value.absent(),
                required int createdAt,
              }) => JobQueuesCompanion.insert(
                id: id,
                type: type,
                payload: payload,
                state: state,
                attempts: attempts,
                nextRunAt: nextRunAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JobQueuesTable, JobQueueRow>(table),
                  BaseReferences<_$VaultDatabase, $JobQueuesTable, JobQueueRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JobQueuesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $JobQueuesTable,
      JobQueueRow,
      $$JobQueuesTableFilterComposer,
      $$JobQueuesTableOrderingComposer,
      $$JobQueuesTableAnnotationComposer,
      $$JobQueuesTableCreateCompanionBuilder,
      $$JobQueuesTableUpdateCompanionBuilder,
      (
        JobQueueRow,
        BaseReferences<_$VaultDatabase, $JobQueuesTable, JobQueueRow>,
      ),
      JobQueueRow,
      PrefetchHooks Function()
    >;

class $VaultDatabaseManager {
  final _$VaultDatabase _db;
  $VaultDatabaseManager(this._db);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$EntryHistoryTableTableManager get entryHistory =>
      $$EntryHistoryTableTableManager(_db, _db.entryHistory);
  $$TrashRowsTableTableManager get trashRows =>
      $$TrashRowsTableTableManager(_db, _db.trashRows);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$EntryCategoriesTableTableManager get entryCategories =>
      $$EntryCategoriesTableTableManager(_db, _db.entryCategories);
  $$EntryTagsTableTableManager get entryTags =>
      $$EntryTagsTableTableManager(_db, _db.entryTags);
  $$CategoryFieldTemplatesTableTableManager get categoryFieldTemplates =>
      $$CategoryFieldTemplatesTableTableManager(
        _db,
        _db.categoryFieldTemplates,
      );
  $$CredentialsTableTableManager get credentials =>
      $$CredentialsTableTableManager(_db, _db.credentials);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$OplogsTableTableManager get oplogs =>
      $$OplogsTableTableManager(_db, _db.oplogs);
  $$ActivitiesTableTableManager get activities =>
      $$ActivitiesTableTableManager(_db, _db.activities);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$DeviceWatermarksTableTableManager get deviceWatermarks =>
      $$DeviceWatermarksTableTableManager(_db, _db.deviceWatermarks);
  $$SyncLogsTableTableManager get syncLogs =>
      $$SyncLogsTableTableManager(_db, _db.syncLogs);
  $$DiaryIndexesTableTableManager get diaryIndexes =>
      $$DiaryIndexesTableTableManager(_db, _db.diaryIndexes);
  $$EntryVecsTableTableManager get entryVecs =>
      $$EntryVecsTableTableManager(_db, _db.entryVecs);
  $$EmbeddingModelsTableTableManager get embeddingModels =>
      $$EmbeddingModelsTableTableManager(_db, _db.embeddingModels);
  $$BlobRefsTableTableManager get blobRefs =>
      $$BlobRefsTableTableManager(_db, _db.blobRefs);
  $$LinkChecksTableTableManager get linkChecks =>
      $$LinkChecksTableTableManager(_db, _db.linkChecks);
  $$JobQueuesTableTableManager get jobQueues =>
      $$JobQueuesTableTableManager(_db, _db.jobQueues);
}
