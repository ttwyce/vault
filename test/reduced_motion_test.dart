import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_metrics.dart';
import 'package:vault/core/widgets/sketch_controls.dart';

/// docs/10 §10 / U8 减少动效测试。
void main() {
  Widget wrap({required bool disable, required Widget child}) => MediaQuery(
        data: MediaQueryData(disableAnimations: disable),
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('SketchMotion.of 在减少动效时返回 Duration.zero',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      disable: true,
      child: Builder(
        builder: (BuildContext context) => Text(
          SketchMotion.of(context, SketchMotion.hover).inMilliseconds
              .toString(),
        ),
      ),
    ));
    expect(find.text('0'), findsOneWidget);

    await tester.pumpWidget(wrap(
      disable: false,
      child: Builder(
        builder: (BuildContext context) => Text(
          SketchMotion.of(context, SketchMotion.hover).inMilliseconds
              .toString(),
        ),
      ),
    ));
    expect(find.text('0'), findsNothing);
  });

  testWidgets('U8：减少动效时按钮仍可点击且无布局位移', (WidgetTester tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(
      disable: true,
      child: Center(
        child: SketchButton(
          label: '测试',
          onPressed: () => taps++,
        ),
      ),
    ));
    final before = tester.getRect(find.text('测试'));
    await tester.tap(find.text('测试'));
    await tester.pump();
    expect(taps, 1);
    final after = tester.getRect(find.text('测试'));
    expect(after, before, reason: 'Tween 用 transform 不用 size，不产生布局位移');
  });
}
