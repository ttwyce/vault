/// L2 PDF 分页与降级（docs/05 §8）。
///
/// 不渲染、不加依赖：只按 A4 比例算页数 / 每页 canvas 平移量，
/// 并定义「平台原生 → pdf 包 → 仅 L1+L3」三级降级状态。
library;

/// A4 @72dpi（docs/05 §8 Android 分页要点）。
const double kA4WidthPt = 595.0;
const double kA4HeightPt = 842.0;

class PdfPaginationPlan {
  const PdfPaginationPlan({
    required this.pageCount,
    required this.translates,
    required this.contentHeightPt,
  });

  final int pageCount;
  final List<double> translates;
  final double contentHeightPt;

  Map<String, Object?> toJson() => <String, Object?>{
        'page_count': pageCount,
        'translates': translates,
        'content_height_pt': contentHeightPt,
      };
}

/// 按内容高度分页；contentHeight ≤0 时返回 0 页（不假装生成了 PDF）。
PdfPaginationPlan planPdfPagination(
  double contentHeightPt, {
  double pageHeightPt = kA4HeightPt,
  int maxPages = 200,
}) {
  if (contentHeightPt <= 0 || pageHeightPt <= 0) {
    return PdfPaginationPlan(
      pageCount: 0,
      translates: const <double>[],
      contentHeightPt: contentHeightPt <= 0 ? 0 : contentHeightPt,
    );
  }
  final pages = (contentHeightPt / pageHeightPt).ceil();
  final bounded = pages > maxPages ? maxPages : pages;
  return PdfPaginationPlan(
    pageCount: bounded,
    translates: List<double>.unmodifiable(<double>[
      for (var i = 0; i < bounded; i++) -(pageHeightPt * i),
    ]),
    contentHeightPt: contentHeightPt,
  );
}

enum PdfFallbackStage { native, dartPdf, textOnly }

class PdfFallbackPlan {
  const PdfFallbackPlan({
    required this.stage,
    required this.archiveStatus,
    required this.hint,
  });

  final PdfFallbackStage stage;
  final String archiveStatus;
  final String hint;
}

/// 三级降级：任一步失败就往下降，最终只保留 L1+L3 并标 text。
PdfFallbackPlan planPdfFallback({
  required bool nativeOk,
  required bool dartPdfOk,
}) {
  if (nativeOk) {
    return const PdfFallbackPlan(
      stage: PdfFallbackStage.native,
      archiveStatus: 'full',
      hint: '平台原生 PDF 生成成功，L1+L2+L3 完整快照',
    );
  }
  if (dartPdfOk) {
    return const PdfFallbackPlan(
      stage: PdfFallbackStage.dartPdf,
      archiveStatus: 'full',
      hint: '原生 PDF 失败，已用简易 Markdown PDF（不保真但可用）',
    );
  }
  return const PdfFallbackPlan(
    stage: PdfFallbackStage.textOnly,
    archiveStatus: 'text',
    hint: '未能生成完整快照，只保留 L1 + L3 并提示用户',
  );
}
