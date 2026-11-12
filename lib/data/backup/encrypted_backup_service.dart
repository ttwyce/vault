/// 加密备份的**真实打包与 WebDAV 上传**（docs/03 §10）。
///
/// 不引入 archive/zip 第三方包：容器格式 = 4 字节 magic `VLT1`
/// + uint32 大端长度 + `ItemEnvelope.encode()` 字节。
/// 明文 = `BackupManifest` JSON + 未删除条目的真实正文；用 K_item
/// 加密（AAD 绑定 entity/id/rev），经真实 [WebDavBackend] 条件 PUT
/// 到 `/backup/`（与 `/vault/` 隔离）。本地 HttpServer 即可完整验证。
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../core/crypto/vault_keys.dart';
import '../../core/sync/webdav_backend.dart';
import '../db/vault_database.dart';
import '../write/entry_snapshot.dart';
import '../write/item_envelope.dart';
import 'backup_models.dart';

const List<int> kBackupMagic = <int>[0x56, 0x4C, 0x54, 0x31]; // 'VLT1'

class BackupUploadResult {
  const BackupUploadResult({
    required this.ok,
    required this.fileName,
    required this.etag,
    required this.bytes,
    required this.hint,
  });

  final bool ok;
  final String fileName;
  final String? etag;
  final int bytes;
  final String hint;
}

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.ok,
    required this.manifest,
    required this.hint,
  });

  final bool ok;
  final BackupManifest? manifest;
  final String hint;
}

/// 上传入口抽象：便于页面测试注入，不强制构造 DB / Key / WebDAV。
abstract class BackupUploader {
  Future<BackupUploadResult> upload({
    required String fileName,
    required String vaultId,
    required int nowMs,
    String? ifMatchEtag,
  });
}

class EncryptedBackupService implements BackupUploader {
  const EncryptedBackupService({
    required this.db,
    required this.backend,
    required this.keys,
  });

  final VaultDatabase db;
  final WebDavBackend backend;
  final VaultKeys keys;

  /// 构造真实 manifest：entry id → content_hash，blob sha256 → bytes，
  /// 模型列表留空（模型文件不进备份，见 docs/06 §5.3）。
  Future<BackupManifest> buildManifest({
    required String vaultId,
    required int nowMs,
  }) async {
    final rows = await (db.select(db.entries)
          ..where((t) => t.deleted.equals(0)))
        .get();
    final blobs = await db.select(db.blobRefs).get();
    return BackupManifest(
      schema: 1,
      vaultId: vaultId,
      createdAt: nowMs,
      entries: <String, String>{
        for (final row in rows)
          row.id: EntrySnapshot.computeContentHash(
            kind: row.kind,
            title: row.title,
            body: row.body,
            meta: row.meta,
          ),
      },
      blobs: <String, int>{
        for (final blob in blobs) blob.blobHash: blob.bytes,
      },
      models: const <String>[],
    );
  }

  /// 打包：manifest + 正文用 K_item 加密成单信封，套上长度前缀容器。
  Future<Uint8List> sealBackup(BackupManifest manifest) async {
    final rows = await (db.select(db.entries)
          ..where((t) => t.deleted.equals(0)))
        .get();
    final payload = <String, Object?>{
      'manifest': manifest.toJson(),
      'entries': <Object?>[
        for (final row in rows)
          <String, Object?>{
            'id': row.id,
            'kind': row.kind,
            'title': row.title,
            'body': row.body,
            'meta': row.meta,
          },
      ],
    };
    final key = await keys.item();
    final envelope = await ItemEnvelope.seal(
      key: key,
      entity: 'backup',
      entityId: manifest.vaultId,
      rev: 1,
      plaintext: utf8.encode(jsonEncode(payload)),
    );
    final body = envelope.encode();
    final out = BytesBuilder(copy: false)
      ..add(kBackupMagic)
      ..add(<int>[
        (body.length >> 24) & 0xff,
        (body.length >> 16) & 0xff,
        (body.length >> 8) & 0xff,
        body.length & 0xff,
      ])
      ..add(body);
    return out.takeBytes();
  }

  /// 条件上传到 /backup/。绝不无条件 PUT。
  @override
  Future<BackupUploadResult> upload({
    required String fileName,
    required String vaultId,
    required int nowMs,
    String? ifMatchEtag,
  }) async {
    final String path;
    try {
      path = backupPath(fileName);
    } on FormatException {
      return BackupUploadResult(
        ok: false,
        fileName: fileName,
        etag: null,
        bytes: 0,
        hint: '备份文件名不合法，拒绝上传',
      );
    }
    if (!isBackupPath(path)) {
      return BackupUploadResult(
        ok: false,
        fileName: fileName,
        etag: null,
        bytes: 0,
        hint: '备份路径必须在 /backup/ 下',
      );
    }
    final manifest = await buildManifest(vaultId: vaultId, nowMs: nowMs);
    final bytes = await sealBackup(manifest);
    final condition = ifMatchEtag == null
        ? const WebDavCondition.createOnly()
        : WebDavCondition.ifMatch(ifMatchEtag);
    try {
      final result = await backend.put(path, bytes, condition: condition);
      return BackupUploadResult(
        ok: true,
        fileName: fileName,
        etag: result.etag,
        bytes: bytes.length,
        hint: '已加密上传到 $path（${bytes.length} 字节）',
      );
    } on WebDavException catch (e) {
      return BackupUploadResult(
        ok: false,
        fileName: fileName,
        etag: null,
        bytes: bytes.length,
        hint: '上传 $path 失败（${e.statusCode}），本地未清除',
      );
    }
  }

  /// 从 /backup/ 拉取并解密校验容器 / 信封 / manifest。
  Future<BackupRestoreResult> restore(String fileName) async {
    final String path;
    try {
      path = backupPath(fileName);
    } on FormatException {
      return const BackupRestoreResult(
        ok: false,
        manifest: null,
        hint: '备份文件名不合法，拒绝读取',
      );
    }
    if (!isBackupPath(path)) {
      return const BackupRestoreResult(
        ok: false,
        manifest: null,
        hint: '拒绝从 /backup/ 之外读取',
      );
    }
    try {
      final got = await backend.get(path);
      final bytes = got.bytes;
      if (bytes.length < 8) {
        return const BackupRestoreResult(
          ok: false,
          manifest: null,
          hint: '备份容器过短',
        );
      }
      for (var i = 0; i < kBackupMagic.length; i++) {
        if (bytes[i] != kBackupMagic[i]) {
          return const BackupRestoreResult(
            ok: false,
            manifest: null,
            hint: '备份容器 magic 不符',
          );
        }
      }
      final size = (bytes[4] << 24) | (bytes[5] << 16) |
          (bytes[6] << 8) | bytes[7];
      if (size <= 0 || 8 + size > bytes.length) {
        return const BackupRestoreResult(
          ok: false,
          manifest: null,
          hint: '备份容器长度不合法',
        );
      }
      final envelope = ItemEnvelope.parse(
        Uint8List.fromList(bytes.sublist(8, 8 + size)),
      );
      if (envelope.entity != 'backup') {
        return const BackupRestoreResult(
          ok: false,
          manifest: null,
          hint: '信封实体不是 backup',
        );
      }
      final key = await keys.item();
      final plain = await envelope.open(key: key);
      final decoded = jsonDecode(utf8.decode(plain));
      if (decoded is! Map || decoded['manifest'] == null) {
        return const BackupRestoreResult(
          ok: false,
          manifest: null,
          hint: '备份内容缺少 manifest',
        );
      }
      final manifest = BackupManifest.fromJson(decoded['manifest']);
      return BackupRestoreResult(
        ok: true,
        manifest: manifest,
        hint: '备份解密成功：${manifest.entries.length} 条条目',
      );
    } on WebDavException catch (e) {
      return BackupRestoreResult(
        ok: false,
        manifest: null,
        hint: '拉取 $path 失败（${e.statusCode}）',
      );
    } on Object {
      return const BackupRestoreResult(
        ok: false,
        manifest: null,
        hint: '备份解密或校验失败（密钥 / 篡改 / 坏结构）',
      );
    }
  }
}
