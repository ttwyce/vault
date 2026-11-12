/// 内容变更重抓的**真实链路**（docs/05 §6.2）。
///
/// 用 [HttpArchiveFetcher] 重抓 L1 → [computeSimhash] 算指纹 →
/// [planContentChange] 比对上次 `link_check.simhash`；有实质变化时
/// 经唯一写入口 `WriteGateway.writeEntry(update)` 更新正文与 meta
/// （网关自动把旧快照写进 `entry_history`，可对比查看），并落证据。
/// 不新增依赖；本地 HttpServer 即可完整验证。
library;

import 'dart:convert';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import '../write/write_gateway.dart';
import 'archive_body_meta.dart';
import 'archive_meta.dart';
import 'content_change_policy.dart';
import 'http_archive_fetcher.dart';
import 'simhash.dart';

class ContentCheckResult {
  const ContentCheckResult({
    required this.ok,
    required this.plan,
    required this.simhash,
    required this.hint,
  });

  final bool ok;
  final ContentChangePlan? plan;
  final String? simhash;
  final String hint;
}

class ContentChangeService {
  const ContentChangeService({
    required this.db,
    required this.gateway,
    required this.fetcher,
  });

  final VaultDatabase db;
  final WriteGateway gateway;
  final HttpArchiveFetcher fetcher;

  Future<String?> lastSimhash(String entryId) async {
    final rows = await (db.select(db.linkChecks)
          ..where((t) => t.entryId.equals(entryId)))
        .get();
    final withHash = rows
        .where((LinkCheckRow r) => r.simhash != null && r.simhash!.isNotEmpty)
        .toList()
      ..sort((LinkCheckRow a, LinkCheckRow b) =>
          b.checkedAt.compareTo(a.checkedAt));
    return withHash.isEmpty ? null : withHash.first.simhash;
  }

  Future<ContentCheckResult> checkAndApply({
    required String entryId,
    required int nowMs,
  }) async {
    final row = await (db.select(db.entries)
          ..where((t) => t.id.equals(entryId)))
        .getSingleOrNull();
    if (row == null || row.deleted != 0 ||
        row.kind != EntryKind.bookmark.code) {
      return const ContentCheckResult(
        ok: false,
        plan: null,
        simhash: null,
        hint: '归档条目不存在或已删除',
      );
    }
    final ArchiveMeta meta;
    try {
      meta = ArchiveMeta.fromJson(
        row.meta == null ? null : jsonDecode(row.meta!),
      );
    } on Object {
      return const ContentCheckResult(
        ok: false,
        plan: null,
        simhash: null,
        hint: '归档 meta 无法解析，拒绝覆盖',
      );
    }
    final fetched = await fetcher.fetch(Uri.parse(meta.url));
    if (!fetched.ok || fetched.body == null) {
      return ContentCheckResult(
        ok: false,
        plan: null,
        simhash: null,
        hint: fetched.hint,
      );
    }
    final hash = computeSimhash(fetched.body!);
    final plan = planContentChange(
      previousSimhash: await lastSimhash(entryId),
      newSimhash: hash,
    );
    await gateway.recordLinkCheck(
      entryId: entryId,
      checkedAt: nowMs,
      result: plan.action == ContentChangeAction.promptChange
          ? 'changed'
          : 'ok',
      httpStatus: fetched.statusCode,
      simhash: hash,
    );
    if (plan.action == ContentChangeAction.promptChange) {
      // update 会把旧正文写进 entry_history，保留旧版可对比。
      final derived = planArchiveBodyMeta(fetched.body!);
      final next = meta.copyWith(
        changed: true,
        excerpt: derived.excerpt,
        readingTimeMin: derived.readingTimeMin,
        title: fetched.title,
      );
      await gateway.writeEntry(EntryWrite.update(
        id: entryId,
        title: row.title,
        body: fetched.body,
        meta: next.toJsonString(),
      ));
    }
    return ContentCheckResult(
      ok: true,
      plan: plan,
      simhash: hash,
      hint: plan.hint,
    );
  }
}
