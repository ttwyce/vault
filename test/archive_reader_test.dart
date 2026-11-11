import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/archive/archive_reader.dart';

/// docs/05 §9 阅读器判定层测试。
void main() {
  ArchiveMeta meta({
    ArchiveStatus status = ArchiveStatus.full,
    bool changed = false,
  }) =>
      ArchiveMeta(
        url: 'https://example.com/p',
        site: 'example.com',
        status: status,
        changed: changed,
        lastCheckedAt: 1731052800000,
      );

  test('full + PDF 本地 + 有旧版：三种模式都可用', () {
    final availability = resolveReaderModes(
      meta: meta(changed: true),
      pdfLocal: true,
      hasPreviousTextVersion: true,
    );
    expect(availability.modes, <ReaderMode>[
      ReaderMode.clean,
      ReaderMode.original,
      ReaderMode.compare,
    ]);
    expect(availability.reasons, isEmpty);
  });

  test('PDF 仅在云端时原貌模式不可点，明确提示按需下载', () {
    final availability = resolveReaderModes(
      meta: meta(),
      pdfLocal: false,
      hasPreviousTextVersion: false,
    );
    expect(availability.can(ReaderMode.clean), isTrue);
    expect(availability.can(ReaderMode.original), isFalse);
    expect(availability.reasons.single, contains('按需下载'));
  });

  test('没有正文层时只剩元数据，fallback 不落到空白页', () {
    final availability = resolveReaderModes(
      meta: meta(status: ArchiveStatus.metadata),
      pdfLocal: false,
      hasPreviousTextVersion: false,
    );
    expect(availability.modes, isEmpty);
    expect(fallbackReaderMode(availability), ReaderMode.clean);
    expect(availability.reasons.first, contains('L1 正文'));
  });

  test('内容变更但无旧版正文时不给对比模式；死链给回退提示', () {
    final changed = resolveReaderModes(
      meta: meta(changed: true),
      pdfLocal: false,
      hasPreviousTextVersion: false,
    );
    expect(changed.can(ReaderMode.compare), isFalse);
    expect(changed.reasons.any((String r) => r.contains('上一版正文')), isTrue);

    final dead = resolveReaderModes(
      meta: meta(status: ArchiveStatus.dead),
      pdfLocal: false,
      hasPreviousTextVersion: false,
    );
    expect(dead.can(ReaderMode.clean), isTrue,
        reason: '死链仍要能读已保存的 L1 正文');
    expect(dead.reasons.any((String r) => r.contains('Wayback')), isTrue);
  });

  test('底部状态条按原站状态区分，不误把 blocked 说成存活', () {
    String line(ArchiveStatus status) => readerStatusLine(
          meta: meta(status: status),
          archivedAtMs: 1731052800000,
          formatDate: (int _) => '2026-11-08',
        );
    expect(line(ArchiveStatus.full), contains('原站存活'));
    expect(line(ArchiveStatus.dead), contains('原站已失效'));
    expect(line(ArchiveStatus.blocked), contains('访问受限'));
    expect(line(ArchiveStatus.paywalled), contains('访问受限'));
  });

  test('高亮合并：重叠与相邻合成一段，不重叠各自保留', () {
    final merged = mergeHighlights(<ArchiveHighlight>[
      const ArchiveHighlight(text: '同步', offset: 10),
      const ArchiveHighlight(text: '引擎', offset: 12, note: '重点'),
      const ArchiveHighlight(text: '冲突', offset: 40),
      const ArchiveHighlight(text: 'x', offset: -1),
    ]);
    expect(merged, hasLength(2));
    expect(merged.first.offset, 10);
    expect(merged.first.note, '重点');
    expect(merged.last.offset, 40);
  });

  test('划词问 AI：2 字起、上限 2000 字、空白串拒绝', () {
    expect(canAskAiAboutSelection('同步'), isTrue);
    expect(canAskAiAboutSelection('  '), isFalse);
    expect(canAskAiAboutSelection('x'), isFalse);
    expect(canAskAiAboutSelection('a' * 2001), isFalse);
  });
}
