/// 年度 PDF 手账导出（docs/11 §1.5）。
///
/// 复用归档纯 Dart PDF 生成器，不新增依赖；内容只包含年度聚合统计
/// 与月份摘要，不含日记正文、密码或恢复码。导出目录由装配层提供。
library;

import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;

import '../../data/archive/simple_pdf.dart';
import '../../data/diary/diary_review.dart';

class DiaryHandbookResult {
  const DiaryHandbookResult({
    required this.ok,
    required this.path,
    required this.bytes,
    required this.pageCount,
    required this.hint,
  });

  final bool ok;
  final String? path;
  final int bytes;
  final int pageCount;
  final String hint;
}

String buildDiaryHandbookText(DiaryYearReview review) {
  final lines = <String>[
    '# ${review.year} 年度回顾',
    '',
    review.hint,
    '补写 ${review.backfilled} 篇 · 活跃 ${review.activeDays} 天',
    '',
    '## 每月记录',
    for (final month in review.months)
      '${month.month.toString().padLeft(2, '0')} 月 · '
          '${month.entries} 篇 · ${month.words} 字 · '
          '平均 ${month.averageWords} 字',
    '',
    '## 心情分布',
    if (review.moods.isEmpty)
      '今年还没有记录心情'
    else
      for (final entry in review.moods.entries)
        '${entry.key} · ${entry.value} 次',
    '',
    '说明：本 PDF 只包含聚合统计，不含日记正文与密钥材料。',
  ];
  return lines.join('\n');
}

Future<DiaryHandbookResult> exportDiaryHandbook({
  required DiaryYearReview review,
  required Directory root,
  required bool confirmed,
}) async {
  if (!confirmed) {
    return const DiaryHandbookResult(
      ok: false,
      path: null,
      bytes: 0,
      pageCount: 0,
      hint: '导出 PDF 手账需要二次确认',
    );
  }
  final text = buildDiaryHandbookText(review);
  final pdf = buildSimplePdf(text);
  if (!pdf.ok) {
    return DiaryHandbookResult(
      ok: false,
      path: null,
      bytes: 0,
      pageCount: 0,
      hint: pdf.hint,
    );
  }
  if (!await root.exists()) await root.create(recursive: true);
  final hash = sha256.convert(pdf.bytes).toString().substring(0, 12);
  final file = File('${root.path}/diary-${review.year}-$hash.pdf');
  await file.writeAsBytes(pdf.bytes, flush: true);
  return DiaryHandbookResult(
    ok: true,
    path: file.path,
    bytes: pdf.bytes.length,
    pageCount: pdf.pageCount,
    hint: '已导出 ${pdf.pageCount} 页 PDF 手账（仅聚合统计）',
  );
}
