import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_content_gate.dart';

/// docs/05 §4.1 反爬 / 付费墙判定测试。
void main() {
  final normalBody = '正常正文' * 40;

  test('反爬 / JS 验证特征优先判 blocked，只存元数据', () {
    final result = detectContentGate(
      title: '页面',
      text: '请开启 JavaScript 后继续访问 $normalBody',
    );
    expect(result.gate, ContentGate.blocked);
    expect(result.matchedSignals, contains('请开启 javascript'));
    expect(result.reason, contains('只存元数据'));
    expect(result.toJson()['gate'], 'blocked');
  });

  test('付费墙类名 / 文案判 paywalled，正文过短单独说明', () {
    final byClass = detectContentGate(
      title: '深度报道',
      text: normalBody,
      htmlClasses: 'article premium-content',
    );
    expect(byClass.gate, ContentGate.paywalled);
    expect(byClass.matchedSignals, contains('class:premium-content'));

    final byText = detectContentGate(
      title: '付费文章',
      text: '订阅后阅读',
      htmlClasses: 'paywall',
    );
    expect(byText.gate, ContentGate.paywalled);
    expect(byText.reason, contains('正文过短'));
  });

  test('正文过短但无特征词也按加载失败处理；正常正文放行', () {
    expect(
      detectContentGate(title: '标题', text: '太短').gate,
      ContentGate.blocked,
    );
    final ok = detectContentGate(
      title: '同步机制',
      text: normalBody,
      htmlClasses: 'article',
    );
    expect(ok.gate, ContentGate.ok);
    expect(ok.matchedSignals, isEmpty);
  });
}
