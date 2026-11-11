import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/features/agent/widgets/privacy_authorization_sheet.dart';

/// docs/07 §4.2 L2/L1 逐次授权测试。
void main() {
  testWidgets('弹窗显示条数 / 字数 / 模型名与仅本次提示',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PrivacyAuthorizationSheet(
            level: 'L2 全量',
            modelName: '云端模型',
            entryCount: 3,
            outgoingChars: 512,
            onApprove: () {},
            onDeny: () {},
          ),
        ),
      ),
    ));
    expect(find.textContaining('3 条内容'), findsOneWidget);
    expect(find.textContaining('512 字片段'), findsOneWidget);
    expect(find.textContaining('云端模型'), findsOneWidget);
    expect(find.textContaining('仅授权这一次'), findsOneWidget);
    expect(find.textContaining('密码 / TOTP / 日记正文'), findsOneWidget);
  });

  testWidgets('拒绝返回 false；批准返回 true，且不落任何设置',
      (WidgetTester tester) async {
    Future<bool>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () {
              result = requestPrivacyAuthorization(
                context: context,
                level: 'L1 脱敏',
                modelName: '云端模型',
                entryCount: 2,
                outgoingChars: 256,
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('拒绝'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await result!, isFalse);

    await tester.tap(find.text('打开'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('仅本次允许'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await result!, isTrue);
  });

  test('授权摘要只给计数，不含内容本体', () {
    final summary = authorizationSummary(
      level: 'L2 全量',
      modelName: '云端模型',
      entryCount: 4,
      outgoingChars: 1024,
    );
    expect(summary, contains('仅本次'));
    expect(summary, contains('4 条 / 1024 字'));
    expect(summary, isNot(contains('正文')));
  });
}
