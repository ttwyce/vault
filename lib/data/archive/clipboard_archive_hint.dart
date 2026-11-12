/// 剪贴板 URL 自动识别提示（docs/05 §3）。
///
/// 不读系统剪贴板、不弹 UI：只判定「这段文本要不要提示归档」，
/// 避免用户复制同一次链接回到前台时被反复打扰。
library;

import 'share_intent_parser.dart' show extractShareUrls;

enum ClipboardHintAction { none, askArchive, openBatch }

class ClipboardHintDecision {
  const ClipboardHintDecision({
    required this.action,
    required this.urls,
    required this.reason,
  });

  final ClipboardHintAction action;
  final List<String> urls;
  final String reason;

  bool get shouldPrompt => action != ClipboardHintAction.none;
}

/// [lastPrompted] 是上次已提示过的剪贴板文本；相同则不重复提示。
/// 单个 URL → 弹「是否归档该链接？」；多个 → 走批量入口不弹气泡。
ClipboardHintDecision decideClipboardArchiveHint(
  String clipboardText, {
  String? lastPrompted,
  required bool appInForeground,
  required bool userAllowedClipboard,
}) {
  if (!appInForeground || !userAllowedClipboard) {
    return const ClipboardHintDecision(
      action: ClipboardHintAction.none,
      urls: <String>[],
      reason: '后台 / 未授权剪贴板，不提示',
    );
  }
  final text = clipboardText.trim();
  if (text.isEmpty || text == lastPrompted) {
    return const ClipboardHintDecision(
      action: ClipboardHintAction.none,
      urls: <String>[],
      reason: '空内容或已提示过，不重复打扰',
    );
  }
  final urls = extractShareUrls(text);
  if (urls.isEmpty) {
    return const ClipboardHintDecision(
      action: ClipboardHintAction.none,
      urls: <String>[],
      reason: '不是 URL，不提示归档',
    );
  }
  if (urls.length == 1) {
    return ClipboardHintDecision(
      action: ClipboardHintAction.askArchive,
      urls: urls,
      reason: '前台检测到单个链接，询问是否归档（不自动抓取）',
    );
  }
  return ClipboardHintDecision(
    action: ClipboardHintAction.openBatch,
    urls: urls,
    reason: '多个链接，走批量剪藏入口，不弹单条气泡',
  );
}
