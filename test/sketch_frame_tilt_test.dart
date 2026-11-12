import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_metrics.dart';
import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/core/widgets/sketch_frame.dart';

/// docs/10 §2 ④ / U5「正文永远不倾斜，只倾斜容器」。
void main() {
  testWidgets('倾斜卡片里正文没有 Transform 祖先', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: SketchTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 120,
            child: SketchFrame(
              tilt: SketchTilt.left,
              child: const Text('正文必须水平'),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // 绘制层仍有一个 Transform.rotate（歪的是纸片）。
    expect(find.byWidgetPredicate(
      (Widget w) => w is Transform && w.transform != Matrix4.identity(),
    ), findsWidgets);
    // 正文所在子树里没有任何旋转 Transform 祖先。
    final textElement = tester.element(find.text('正文必须水平'));
    var foundRotation = false;
    textElement.visitAncestorElements((Element ancestor) {
      if (ancestor.widget is Transform) foundRotation = true;
      return true;
    });
    expect(foundRotation, isFalse,
        reason: 'U5：正文不能被父级 Transform.rotate 带着歪');
  });
}
