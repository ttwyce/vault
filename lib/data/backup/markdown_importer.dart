/// Markdown 文件夹的**真实导入**（docs/03 §10 无冲突合并）。
///
/// 扫描 `<root>/<kind>/*.md`，解析导出时的 frontmatter，按
/// [decideImport] 用 content_hash 判定：同 id 同 hash → 跳过，
/// 同 id 不同 hash → 生成冲突副本（新 id，绝不覆盖），无本地记录 →
/// 原样插入。所有写入都经 [WriteGateway]（唯一写入口）。
/// 目录可注入，测试用临时目录；不新增依赖。
library;

import 'dart:io';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import '../write/entry_snapshot.dart';
import '../write/write_gateway.dart';
import 'backup_models.dart';

class MarkdownImportResult {
  const MarkdownImportResult({
    required this.inserted,
    required this.skipped,
    required this.conflictCopies,
    required this.failed,
    required this.hints,
  });

  final List<String> inserted;
  final List<String> skipped;
  final List<String> conflictCopies;
  final List<String> failed;
  final List<String> hints;

  int get total => inserted.length + skipped.length +
      conflictCopies.length + failed.length;
}

class ParsedMarkdown {
  const ParsedMarkdown({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.meta,
  });

  final String id;
  final EntryKind kind;
  final String? title;
  final String body;
  final String? meta;
}

class MarkdownImporter {
  const MarkdownImporter({
    required this.db,
    required this.gateway,
    required this.root,
  });

  final VaultDatabase db;
  final WriteGateway gateway;
  final Directory root;

  static final RegExp _frontmatter = RegExp(
    r'^---\s*\n([\s\S]*?)\n---\s*\n([\s\S]*)$',
  );

  static ParsedMarkdown? parse(String raw, String fallbackId) {
    final match = _frontmatter.firstMatch(raw.trim());
    if (match == null) return null;
    final fields = <String, String>{};
    for (final line in match.group(1)!.split('\n')) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      fields[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
    }
    var id = fields['id'] ?? fallbackId;
    if (id.isEmpty) id = fallbackId;
    final kind = switch (fields['kind']) {
      'note' => EntryKind.note,
      'thought' => EntryKind.thought,
      'diary' => EntryKind.diary,
      'aiDiary' => EntryKind.aiDiary,
      'bookmark' => EntryKind.bookmark,
      'credential' => EntryKind.credential,
      _ => EntryKind.note,
    };
    // 密码条目绝不从明文导入（导出时也不写）。
    if (kind == EntryKind.credential) return null;
    var content = match.group(2)!;
    String? title;
    if (content.startsWith('# ')) {
      final end = content.indexOf('\n');
      title = (end < 0 ? content : content.substring(0, end))
          .substring(2)
          .trim();
      content = end < 0 ? '' : content.substring(end + 1);
    }
    String? meta;
    final metaMarker = RegExp(r'<!-- meta: ([\s\S]*?) -->');
    final metaMatch = metaMarker.firstMatch(content);
    if (metaMatch != null) {
      meta = metaMatch.group(1);
      content = content.replaceAll(metaMatch.group(0)!, '').trimRight();
    }
    return ParsedMarkdown(
      id: id,
      kind: kind,
      title: title,
      body: content.trim(),
      meta: meta,
    );
  }

  Future<MarkdownImportResult> importFolder() async {
    if (!await root.exists()) {
      return const MarkdownImportResult(
        inserted: <String>[],
        skipped: <String>[],
        conflictCopies: <String>[],
        failed: <String>[],
        hints: <String>['导入目录不存在'],
      );
    }
    final inserted = <String>[];
    final skipped = <String>[];
    final conflictCopies = <String>[];
    final failed = <String>[];
    final hints = <String>[];
    final files = <File>[
      for (final entity in root.listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.md') &&
            !entity.path.endsWith('README.md'))
          entity,
    ]..sort((File a, File b) => a.path.compareTo(b.path));
    for (final file in files) {
      try {
        final raw = await file.readAsString();
        final fallback = file.uri.pathSegments.last.replaceAll('.md', '');
        final parsed = parse(raw, fallback);
        if (parsed == null) {
          failed.add(file.path);
          hints.add('${file.path}：不是合法导出文件或属于密码占位');
          continue;
        }
        final hash = EntrySnapshot.computeContentHash(
          kind: parsed.kind.code,
          title: parsed.title,
          body: parsed.body,
          meta: parsed.meta,
        );
        final local = await (db.select(db.entries)
              ..where((t) => t.id.equals(parsed.id)))
            .getSingleOrNull();
        final action = decideImport(hash, local?.contentHash);
        switch (action) {
          case ImportAction.skip:
            skipped.add(parsed.id);
          case ImportAction.insert:
            final result = await gateway.writeEntry(EntryWrite.create(
              id: parsed.id,
              kind: parsed.kind,
              title: parsed.title,
              body: parsed.body,
              meta: parsed.meta,
            ));
            if (result.changed) inserted.add(parsed.id);
          case ImportAction.conflictCopy:
            // 新 id 由网关生成，标题标注冲突副本；绝不覆盖本地。
            final result = await gateway.writeEntry(EntryWrite.create(
              kind: parsed.kind,
              title: '${parsed.title ?? '(无标题)'} · 冲突副本',
              body: parsed.body,
              meta: parsed.meta,
            ));
            conflictCopies.add(result.snapshot.id);
        }
      } on Object catch (e) {
        failed.add(file.path);
        hints.add('${file.path}：导入失败（$e）');
      }
    }
    return MarkdownImportResult(
      inserted: List<String>.unmodifiable(inserted),
      skipped: List<String>.unmodifiable(skipped),
      conflictCopies: List<String>.unmodifiable(conflictCopies),
      failed: List<String>.unmodifiable(failed),
      hints: List<String>.unmodifiable(hints),
    );
  }
}
