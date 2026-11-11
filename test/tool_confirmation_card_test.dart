import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/agent_policy.dart';
import 'package:vault/features/agent/widgets/tool_confirmation_card.dart';

/// docs/07 §4.1 确认卡片测试。
void main() {
  const pending = PolicyDecision(
    PolicyAction.requireConfirm,
    <String>['需要用户确认'],
    '将要新建一条笔记\n内容预览：正文\n数据仅在本设备内处理',
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    bool dataLeavesDevice = false,
    String toolName = 'create_note',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ToolConfirmationCard(
            toolName: toolName,
            decision: pending,
            humanAction: '新建一条笔记「同步方案」',
            contentPreview: '一级标题：同步方案\n正文：增量同步与退避策略',
            dataLeavesDevice: dataLeavesDevice,
            modelName: '端侧模型',
            onConfirm: onConfirm ?? () {},
            onCancel: onCancel ?? () {},
          ),
        ),
      ),
    ));
  }

  testWidgets('人话操作 / 完整内容预览 / 数据流向三段都可见',
      (WidgetTester tester) async {
    await pumpCard(tester);
    expect(find.text('将要执行'), findsOneWidget);
    expect(find.text('新建一条笔记「同步方案」'), findsOneWidget);
    expect(find.text('完整内容预览'), findsOneWidget);
    expect(find.textContaining('增量同步与退避策略'), findsOneWidget);
    expect(find.text('数据流向'), findsOneWidget);
    expect(find.text('数据仅在本设备内处理'), findsOneWidget);
  });

  testWidgets('数据离开设备时明确显示模型名，且需二次确认勾选',
      (WidgetTester tester) async {
    var confirmed = 0;
    await pumpCard(
      tester,
      dataLeavesDevice: true,
      onConfirm: () => confirmed++,
    );
    expect(find.textContaining('发送给 端侧模型'), findsOneWidget);
    expect(find.textContaining('我已了解数据流向'), findsOneWidget);

    // 未勾选时确认按钮禁用。
    await tester.tap(find.text('确认执行'), warnIfMissed: false);
    await tester.pump();
    expect(confirmed, 0);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('确认执行'));
    await tester.pump();
    expect(confirmed, 1);
  });

  testWidgets('showToolConfirmation 取消返回 false、确认返回 true',
      (WidgetTester tester) async {
    Future<bool?>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () {
              result = showToolConfirmation(
                context: context,
                toolName: 'create_note',
                decision: pending,
                humanAction: '新建笔记',
                contentPreview: '正文',
                dataLeavesDevice: false,
                modelName: '端侧模型',
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('取消'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await result!, isFalse);

    await tester.tap(find.text('打开'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('确认执行'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await result!, isTrue);
  });
}
