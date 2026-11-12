/// 明文 Markdown 文件夹**真实导出**（docs/03 §10）。
///
/// 把真实未删除的正文类条目写成 `<root>/<kind>/<id>.md`；
/// kind=6 密码条目**绝不导出**（只导出占位说明，不含任何字段值）。
/// 导出前必须走 [advancePlaintextExport] 两道确认，且用
/// [scanForPlaintextLeaks] 扫描已知敏感值：命中即拒绝整个导出。
/// 目录可注入，测试用临时目录；不新增依赖。
library;

import 'dart:io';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import '../vault/credential_models.dart' show CredentialGuard;
import 'backup_models.dart';
import 'security_audit.dart';

class MarkdownExportResult {
  const MarkdownExportResult({
    required this.ok,
    required this.stage,
    required this.writtenFiles,
    required this.hint,
    required this.leaks,
  });

  final bool ok;
  final PlaintextExportStage stage;
  final List<String> writtenFiles;
  final String hint;
  final List<LeakFinding> leaks;
}

class MarkdownExporter {
  const MarkdownExporter({
    required this.db,
    required this.root,
  });

  final VaultDatabase db;
  final Directory root;

  static String _kindDir(EntryKind kind) => switch (kind) {
        EntryKind.note => 'notes',
        EntryKind.thought => 'thoughts',
        EntryKind.diary => 'diary',
        EntryKind.aiDiary => 'ai-diary',
        EntryKind.bookmark => 'archive',
        EntryKind.credential => 'credentials',
      };

  /// [stage] 由调用方 UI 推进；只有 confirmed/done 才允许写盘。
  Future<MarkdownExportResult> export({
    required PlaintextExportStage stage,
    required Iterable<String> knownSecrets,
    Iterable<String> diaryBodies = const <String>[],
  }) async {
    if (stage != PlaintextExportStage.confirmed &&
        stage != PlaintextExportStage.done) {
      return MarkdownExportResult(
        ok: false,
        stage: stage,
        writtenFiles: const <String>[],
        hint: '明文导出需先完成两次确认',
        leaks: const <LeakFinding>[],
      );
    }
    final rows = await (db.select(db.entries)
          ..where((t) => t.deleted.equals(0)))
        .get();
    final exportable = rows
        .where((EntryRow r) =>
            EntryKind.fromCode(r.kind) != EntryKind.credential)
        .toList();
    // 先把所有待写文本拼起来做一次泄露扫描，命中则一个文件都不写。
    final buffer = StringBuffer();
    for (final row in exportable) {
      buffer.writeln(row.title ?? '');
      buffer.writeln(row.body ?? '');
      buffer.writeln(row.meta ?? '');
    }
    final leaks = scanForPlaintextLeaks(AuditInput(
      text: buffer.toString(),
      secrets: knownSecrets,
      diaryBodies: diaryBodies,
    ));
    if (leaks.isNotEmpty) {
      return MarkdownExportResult(
        ok: false,
        stage: stage,
        writtenFiles: const <String>[],
        hint: '检测到 ${leaks.length} 处明文泄露风险，已拒绝导出',
        leaks: leaks,
      );
    }
    final written = <String>[];
    for (final row in exportable) {
      final kind = EntryKind.fromCode(row.kind);
      if (kind == null) continue;
      final dir = Directory('${root.path}/${_kindDir(kind)}');
      if (!await dir.exists()) await dir.create(recursive: true);
      final safeId = row.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${dir.path}/$safeId.md');
      final frontmatter = <String>[
        '---',
        'id: ${row.id}',
        'kind: ${kind.name}',
        'created_at: ${row.createdAt}',
        'updated_at: ${row.updatedAt}',
        '---',
        '',
        '# ${row.title ?? '(无标题)'}',
        '',
        row.body ?? '',
        if (row.meta != null && row.meta!.trim().isNotEmpty) ...<String>[
          '',
          '<!-- meta: ${row.meta} -->',
        ],
      ].join('\n');
      await file.writeAsString(frontmatter);
      written.add(file.path);
    }
    // 密码条目只写一个说明文件，绝不写任何字段值。
    final credDir = Directory('${root.path}/credentials');
    if (!await credDir.exists()) await credDir.create(recursive: true);
    final note = File('${credDir.path}/README.md');
    await note.writeAsString(
      '# 密码条目未导出\n\n'
      '按安全边界（docs/11 §4.3），密码 / TOTP / secret 字段'
      '永不进入任何明文导出或模型上下文。请使用加密备份。\n',
    );
    written.add(note.path);
    return MarkdownExportResult(
      ok: true,
      stage: PlaintextExportStage.done,
      writtenFiles: List<String>.unmodifiable(written),
      hint: '已导出 ${exportable.length} 条正文条目（密码条目仅占位说明）',
      leaks: const <LeakFinding>[],
    );
  }
}

/// 便于调用方确认：待导出文本里是否含已存密码明文。
bool containsKnownSecret(String text, Iterable<String> secrets) =>
    CredentialGuard.containsSecret(text, secrets);
