/// 归档抓取的内容闸门（docs/05 §4.1）。
///
/// 不联网、不跑 WebView：从已拿到的标题 / 正文片段 / HTML 类名与特征词
/// 判定 `blocked`（反爬）/ `paywalled`（付费墙）/ `ok`，
/// 让「只存元数据」有可测依据，而不是靠抓取器随手写 status。
library;

enum ContentGate { ok, blocked, paywalled }

class ContentGateResult {
  const ContentGateResult({
    required this.gate,
    required this.reason,
    required this.matchedSignals,
  });

  final ContentGate gate;
  final String reason;
  final List<String> matchedSignals;

  Map<String, Object?> toJson() => <String, Object?>{
        'gate': gate.name,
        'reason': reason,
        'signals': matchedSignals,
      };
}

const List<String> kBlockedTextSignals = <String>[
  '请开启 javascript',
  '请启用 javascript',
  'enable javascript',
  '验证中',
  '人机验证',
  'access denied',
  'captcha',
];

const List<String> kPaywallClassSignals = <String>[
  'paywall',
  'premium-content',
  'subscriber-only',
  'article-paid',
  '会员专属',
];

const List<String> kPaywallTextSignals = <String>[
  '订阅后阅读',
  '开通会员',
  'subscribe to continue reading',
  'this article is for subscribers',
];

ContentGateResult detectContentGate({
  required String title,
  required String text,
  String htmlClasses = '',
  int minBodyChars = 120,
}) {
  final haystack = '$title $text'.toLowerCase();
  final classes = htmlClasses.toLowerCase();
  final signals = <String>[];

  for (final signal in kBlockedTextSignals) {
    if (haystack.contains(signal)) signals.add(signal);
  }
  if (signals.isNotEmpty) {
    return ContentGateResult(
      gate: ContentGate.blocked,
      reason: '检测到反爬 / JS 验证特征，只存元数据，不渲染正文',
      matchedSignals: List<String>.unmodifiable(signals),
    );
  }

  for (final signal in kPaywallClassSignals) {
    if (classes.contains(signal)) signals.add('class:$signal');
  }
  for (final signal in kPaywallTextSignals) {
    if (haystack.contains(signal)) signals.add(signal);
  }
  // 正文极短且有付费墙类名，也按 paywalled 处理（不把空白当正文）。
  final tooShort = text.trim().length < minBodyChars;
  if (signals.isNotEmpty) {
    return ContentGateResult(
      gate: ContentGate.paywalled,
      reason: tooShort
          ? '检测到付费墙且正文过短，只存元数据并提示用户'
          : '检测到付费墙，只存可见部分与元数据',
      matchedSignals: List<String>.unmodifiable(signals),
    );
  }
  if (tooShort) {
    return ContentGateResult(
      gate: ContentGate.blocked,
      reason: '正文不足 $minBodyChars 字，疑似加载失败，只存元数据',
      matchedSignals: const <String>['body_too_short'],
    );
  }
  return const ContentGateResult(
    gate: ContentGate.ok,
    reason: '未检测到反爬 / 付费墙特征，可继续提取正文',
    matchedSignals: <String>[],
  );
}
