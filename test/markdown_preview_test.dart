import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/editor/markdown_preview.dart';

/// docs/09 §4 Markdown 轻量预览判定层测试。
void main() {
  test('标题 / 列表 / 任务 / 引用 / 图片 / 段落逐行归类', () {
    final blocks = parseMarkdownPreview(
      '# 一级\n## 二级\n### 三级\n'
      '- 普通项\n- [ ] 待办\n- [x] 完成\n'
      '> 引用\n![图](https://x/y.png)\n正文',
    );
    expect(blocks.map((PreviewBlock b) => b.kind).toList(), <PreviewBlockKind>[
      PreviewBlockKind.heading1,
      PreviewBlockKind.heading2,
      PreviewBlockKind.heading3,
      PreviewBlockKind.bullet,
      PreviewBlockKind.task,
      PreviewBlockKind.task,
      PreviewBlockKind.quote,
      PreviewBlockKind.image,
      PreviewBlockKind.paragraph,
    ]);
    expect(blocks[4].checked, isFalse);
    expect(blocks[5].checked, isTrue);
    expect(blocks[0].text, '一级');
  });

  test('代码围栏内不二次解析，未闭合围栏也保留内容', () {
    final closed = parseMarkdownPreview('```\n# 不是标题\n- 不是列表\n```');
    expect(closed, hasLength(1));
    expect(closed.single.kind, PreviewBlockKind.codeFence);
    expect(closed.single.text, contains('# 不是标题'));

    final open = parseMarkdownPreview('```\n# 不是标题');
    expect(open.single.kind, PreviewBlockKind.codeFence);
  });

  test('空行保留为段落，预览摘要去掉 Markdown 标记', () {
    final blocks = parseMarkdownPreview('# 标题\n\n正文');
    expect(blocks[1].kind, PreviewBlockKind.paragraph);
    expect(blocks[1].text, isEmpty);
    expect(previewPlainText('# 标题\n\n- 项目'), '标题 项目');
  });

  test('toJson 带 kind / text / checked', () {
    final json = const PreviewBlock(
      kind: PreviewBlockKind.task,
      text: '待办',
      checked: true,
    ).toJson();
    expect(json['kind'], 'task');
    expect(json['checked'], isTrue);
  });
}
