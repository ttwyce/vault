/// 归档正文图片过滤（docs/05 §4.1）。
///
/// 不下载、不解析完整 DOM：只按 `<img>` 标签里的 width/height/src
/// 判定「保留本地化 / 丢弃小图 / 下载失败保留原 URL 并标注」。
library;

enum ArchiveImageAction { keepLocal, dropSmall, keepRemoteAnnotated }

class ArchiveImagePlan {
  const ArchiveImagePlan({
    required this.src,
    required this.action,
    required this.reason,
  });

  final String src;
  final ArchiveImageAction action;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
        'src': src,
        'action': action.name,
        'reason': reason,
      };
}

const int kMinArchiveImageEdge = 200;

int? _dimension(String tag, String name) {
  final match = RegExp(
    "$name\\s*=\\s*[\"']?(\\d+)",
    caseSensitive: false,
  ).firstMatch(tag);
  return match == null ? null : int.tryParse(match.group(1)!);
}

String? _src(String tag) {
  final match = RegExp(
    "src\\s*=\\s*[\"']([^\"']+)[\"']",
    caseSensitive: false,
  ).firstMatch(tag);
  return match?.group(1);
}

/// 单张 `<img>` 判定。[downloadFailed] 由平台层下载后回填。
ArchiveImagePlan planArchiveImage(
  String imgTag, {
  bool downloadFailed = false,
}) {
  final src = _src(imgTag) ?? '';
  if (src.isEmpty) {
    return const ArchiveImagePlan(
      src: '',
      action: ArchiveImageAction.dropSmall,
      reason: '没有 src，丢弃',
    );
  }
  final width = _dimension(imgTag, 'width');
  final height = _dimension(imgTag, 'height');
  final bigEnough = (width != null && width >= kMinArchiveImageEdge) ||
      (height != null && height >= kMinArchiveImageEdge);
  if (!bigEnough && width != null && height != null) {
    return ArchiveImagePlan(
      src: src,
      action: ArchiveImageAction.dropSmall,
      reason: '$width×$height 小于 $kMinArchiveImageEdge' 'px 阈值',
    );
  }
  if (downloadFailed) {
    return ArchiveImagePlan(
      src: src,
      action: ArchiveImageAction.keepRemoteAnnotated,
      reason: '下载失败，保留原 URL 并标注（不假装已本地化）',
    );
  }
  return ArchiveImagePlan(
    src: src,
    action: ArchiveImageAction.keepLocal,
    reason: width == null && height == null
        ? '未声明尺寸，按保守规则保留并转本地引用'
        : '尺寸达标，下载并改写为本地引用',
  );
}

/// 批量：从一段 HTML 里抽出 `<img>` 标签并逐张判定。
List<ArchiveImagePlan> planArchiveImages(
  String html, {
  Set<String> failedSrcs = const <String>{},
}) =>
    <ArchiveImagePlan>[
      for (final match in RegExp(r'<img\b[^>]*>', caseSensitive: false)
          .allMatches(html))
        planArchiveImage(
          match.group(0)!,
          downloadFailed: failedSrcs.contains(_src(match.group(0)!)),
        ),
    ];
