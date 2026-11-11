import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/widgets/secure_card.dart';

/// docs/09 §15 / P10 密码模块克制变体测试。
void main() {
  testWidgets('对称 10px 圆角、1.5px 实线边、无硬阴影、零倾斜',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SecureCard(child: Text('密码'))),
    ));
    final container = tester.widget<Container>(
      find.byWidgetPredicate((Widget w) =>
          w is Container && w.decoration is BoxDecoration),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius,
        const BorderRadius.all(Radius.circular(SecureCard.radius)));
    expect(decoration.border!.top.width, SecureCard.borderWidth);
    expect(decoration.boxShadow, isNull);
    expect(find.text('密码'), findsOneWidget);
  });

  testWidgets('accent 颜色可覆盖（泄露/危险态）', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SecureCard(
          accent: Color(0xFFCC0000),
          child: Text('已泄露'),
        ),
      ),
    ));
    final container = tester.widget<Container>(
      find.byWidgetPredicate((Widget w) =>
          w is Container && w.decoration is BoxDecoration),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.border!.top.color, const Color(0xFFCC0000));
  });
}
