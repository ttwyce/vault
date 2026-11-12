import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/pdf_pagination.dart';

/// docs/05 §8 PDF 分页与降级测试。
void main() {
  test('A4 尺寸常量；按内容高度向上取整页数', () {
    expect(kA4WidthPt, 595.0);
    expect(kA4HeightPt, 842.0);
    final plan = planPdfPagination(kA4HeightPt * 2 + 1);
    expect(plan.pageCount, 3);
    expect(plan.translates, <double>[0.0, -842.0, -1684.0]);
    expect(plan.toJson()['content_height_pt'], 1685.0);
  });

  test('内容高度 0/负 返回 0 页；超 maxPages 截断', () {
    expect(planPdfPagination(0).pageCount, 0);
    expect(planPdfPagination(-10).pageCount, 0);
    final capped = planPdfPagination(842 * 500, maxPages: 10);
    expect(capped.pageCount, 10);
    expect(capped.translates, hasLength(10));
  });

  test('三级降级：原生 / 简易 PDF / 只保留 L1+L3', () {
    expect(
      planPdfFallback(nativeOk: true, dartPdfOk: false).stage,
      PdfFallbackStage.native,
    );
    final fallback = planPdfFallback(nativeOk: false, dartPdfOk: true);
    expect(fallback.stage, PdfFallbackStage.dartPdf);
    expect(fallback.archiveStatus, 'full');
    expect(fallback.hint, contains('不保真'));

    final textOnly = planPdfFallback(nativeOk: false, dartPdfOk: false);
    expect(textOnly.stage, PdfFallbackStage.textOnly);
    expect(textOnly.archiveStatus, 'text');
    expect(textOnly.hint, contains('只保留 L1 + L3'));
  });
}
