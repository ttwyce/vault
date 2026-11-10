import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/widgets/sketch_controls.dart';
import 'package:vault/features/editor/editor_page.dart';
import 'package:vault/features/editor/markdown_insert.dart';

import 'support/test_harness.dart';

/// Markdown 工具栏：纯函数测边界，widget 测「点了真的改变正文」。
void main() {
  group('applyMarkdownAction', () {
    test('标题前缀加到行首，而不是光标位置', () {
      final edit = applyMarkdownAction(
        text: '甲乙丙',
        selectionStart: 2,
        selectionEnd: 2,
        action: MarkdownAction.heading,
      );
      expect(edit.text, '## 甲乙丙');
      // 光标要停在原来那个字后面（原 offset 2 + 前缀长度 3），
      // 而不是被甩到行尾 —— 否则用户接着打字会打到错位置。
      expect(edit.cursor, 5);
      expect(edit.text.substring(0, edit.cursor), '## 甲乙');
    });

    test('选区跨行时每一行都加前缀', () {
      final edit = applyMarkdownAction(
        text: '甲\n乙\n丙',
        selectionStart: 0,
        selectionEnd: 3,
        action: MarkdownAction.bullet,
      );
      expect(edit.text, '- 甲\n- 乙\n丙');
    });

    test('任务清单前缀', () {
      final edit = applyMarkdownAction(
        text: '买牛奶',
        selectionStart: 0,
        selectionEnd: 0,
        action: MarkdownAction.task,
      );
      expect(edit.text, '- [ ] 买牛奶');
    });

    test('代码围栏保留选中内容，光标落在围栏内部', () {
      final edit = applyMarkdownAction(
        text: 'abc',
        selectionStart: 0,
        selectionEnd: 3,
        action: MarkdownAction.code,
      );
      expect(edit.text, '```\nabc\n```');
      expect(edit.cursor, 7); // '```\n' 4 + 'abc' 3
    });

    test('图片语法光标停在括号里，可直接粘 URL', () {
      final edit = applyMarkdownAction(
        text: '',
        selectionStart: 0,
        selectionEnd: 0,
        action: MarkdownAction.image,
      );
      expect(edit.text, '![]()');
      expect(edit.cursor, 4); // '![](' 之后
    });

    test('未获取焦点（selection = -1）时按文末处理', () {
      final edit = applyMarkdownAction(
        text: 'abc',
        selectionStart: -1,
        selectionEnd: -1,
        action: MarkdownAction.task,
      );
      expect(edit.text, '- [ ] abc');
    });

    test('旧选区越界被 clamp，不会抛 RangeError', () {
      final edit = applyMarkdownAction(
        text: 'a',
        selectionStart: 99,
        selectionEnd: 120,
        action: MarkdownAction.heading,
      );
      expect(edit.text, '## a');
    });

    test('工具栏标签互不相同', () {
      final labels = MarkdownAction.values.map((MarkdownAction a) => a.label);
      expect(labels.toSet(), hasLength(MarkdownAction.values.length));
    });
  });

  group('编辑器工具栏', () {
    late TestApp app;

    setUp(() async {
      app = await TestApp.create();
    });

    tearDown(() async {
      await app.dispose();
    });

    testWidgets('点 H2 后正文变成 Markdown 标题且不落库',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: app.container,
        child: const MaterialApp(home: EditorPage()),
      ));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      // 第一个 TextField 是标题，第二个是正文。
      await tester.enterText(find.byType(TextField).at(1), '第一行');
      await tester.pump();

      await tester.tap(find.widgetWithText(SketchTag, 'H2'));
      await tester.pump();

      final body = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(body.controller!.text, '## 第一行');
      // 工具栏只改 controller，不该产生任何条目或 oplog。
      expect(await app.repo.list(), isEmpty);
      expect(await app.gateway.pending(), isEmpty);
    });
  });
}
