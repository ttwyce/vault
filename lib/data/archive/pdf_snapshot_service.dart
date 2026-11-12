/// L2 PDF 快照的**真实生成与登记**（docs/05 §8 二级降级）。
///
/// 用 [buildSimplePdf] 从 L1 正文生成 PDF 字节，按 [planPdfFallback]
/// 判定降级阶段；成功后经 `WriteGateway.recordArchiveBlob` 登记
/// `blob_ref(kind=2, local=1)` 并用 `writeEntry(update)` 把
/// `snapshotBytes` / `status=full` 写回 kind=5 meta。
/// 失败只保留 L1+L3 并标 text，绝不假装生成了完整快照。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import '../write/write_gateway.dart';
import 'archive_meta.dart';
import 'pdf_pagination.dart';
import 'simple_pdf.dart';

class PdfSnapshotResult {
  const PdfSnapshotResult({
    required this.ok,
    required this.stage,
    required this.blobHash,
    required this.bytes,
    required this.pageCount,
    required this.hint,
  });

  final bool ok;
  final PdfFallbackStage stage;
  final String? blobHash;
  final int bytes;
  final int pageCount;
  final String hint;
}

class PdfSnapshotService {
  const PdfSnapshotService({
    required this.db,
    required this.gateway,
  });

  final VaultDatabase db;
  final WriteGateway gateway;

  /// [nativeOk] 预留给平台原生 WebView PDF；这里实现 dartPdf 降级路径。
  Future<PdfSnapshotResult> generate({
    required String entryId,
    bool nativeOk = false,
  }) async {
    if (nativeOk) {
      return const PdfSnapshotResult(
        ok: false,
        stage: PdfFallbackStage.native,
        blobHash: null,
        bytes: 0,
        pageCount: 0,
        hint: '原生 PDF 路径由平台层提供，本服务只负责 Dart 降级',
      );
    }
    final row = await (db.select(db.entries)
          ..where((t) => t.id.equals(entryId)))
        .getSingleOrNull();
    if (row == null || row.deleted != 0 ||
        row.kind != EntryKind.bookmark.code) {
      return const PdfSnapshotResult(
        ok: false,
        stage: PdfFallbackStage.textOnly,
        blobHash: null,
        bytes: 0,
        pageCount: 0,
        hint: '归档条目不存在或已删除',
      );
    }
    final body = row.body ?? '';
    final pdf = buildSimplePdf(body);
    final plan = planPdfFallback(nativeOk: false, dartPdfOk: pdf.ok);
    if (!pdf.ok) {
      return PdfSnapshotResult(
        ok: false,
        stage: plan.stage,
        blobHash: null,
        bytes: 0,
        pageCount: 0,
        hint: plan.hint,
      );
    }
    final bytes = pdf.bytes;
    final hash = sha256.convert(bytes).toString();
    await gateway.recordArchiveBlob(
      entryId: entryId,
      blobHash: hash,
      kind: 2,
      bytes: bytes.length,
      local: true,
    );
    final ArchiveMeta meta;
    try {
      meta = ArchiveMeta.fromJson(
        row.meta == null ? null : jsonDecode(row.meta!),
      );
    } on Object {
      return PdfSnapshotResult(
        ok: false,
        stage: PdfFallbackStage.textOnly,
        blobHash: hash,
        bytes: bytes.length,
        pageCount: pdf.pageCount,
        hint: '归档 meta 无法解析，拒绝覆盖',
      );
    }
    final next = meta.copyWith(
      status: ArchiveStatus.full,
      snapshotBytes: bytes.length,
    );
    await gateway.writeEntry(EntryWrite.update(
      id: entryId,
      title: row.title,
      body: row.body,
      meta: next.toJsonString(),
    ));
    return PdfSnapshotResult(
      ok: true,
      stage: PdfFallbackStage.dartPdf,
      blobHash: hash,
      bytes: bytes.length,
      pageCount: pdf.pageCount,
      hint: '${plan.hint}（${pdf.pageCount} 页）',
    );
  }
}
