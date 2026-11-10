/// Markdown 正文插入的纯函数。
///
/// 编辑器不解析 Markdown、不做所见即所得 —— M2 只要「输入无延迟」，
/// 工具栏本质是在光标处塞语法字符。把这段逻辑抽成纯函数有两个理由：
/// 1. 光标 / 选区 / 多行的边界情况能直接单测，不必搭 widget 环境；
/// 2. 它不碰 `WriteGateway`，插入动作和保存动作彻底分开，
///    误点工具栏不会写出半条内容。
library;

/// 一次插入的结果：新正文 + 新光标位置。
typedef MarkdownEdit = ({String text, int cursor});

enum MarkdownAction { heading, bullet, task, code, image }

extension MarkdownActionLabel on MarkdownAction {
  String get label => switch (this) {
        MarkdownAction.heading => 'H2',
        MarkdownAction.bullet => '列表',
        MarkdownAction.task => '任务',
        MarkdownAction.code => '代码',
        MarkdownAction.image => '图片',
      };
}

/// 在光标所在行（或选区覆盖的每一行）行首插入 [prefix]。
MarkdownEdit _prefixLines(String text, int start, int end, String prefix) {
  final lineStart =
      start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final selected = text.substring(lineStart, end);
  final inserted = selected
      .split('\n')
      .map((String line) => '$prefix$line')
      .join('\n');
  return (
    text: text.replaceRange(lineStart, end, inserted),
    cursor: lineStart + inserted.length,
  );
}

/// 用 [before] / [after] 包住选区，光标停在 after 之前。
///
/// 有选区时把选中的文字留在中间（代码围栏、链接都该这样）；
/// 没有选区时就是一个空壳，光标正好落在可输入的位置。
MarkdownEdit _insertBlock(
  String text,
  int start,
  int end,
  String before,
  String after,
) {
  final selected = text.substring(start, end);
  final inserted = '$before$selected$after';
  return (
    text: text.replaceRange(start, end, inserted),
    cursor: start + before.length + selected.length,
  );
}

/// 应用一次工具栏动作。
///
/// `selectionStart` / `selectionEnd` 允许传 -1（新控制器还没获得焦点时
/// `TextEditingController.selection` 就是 -1），统一当作「光标在文末」。
/// 越界值也做 clamp —— 异步回填正文时旧选区可能比新文本还长。
MarkdownEdit applyMarkdownAction({
  required String text,
  required int selectionStart,
  required int selectionEnd,
  required MarkdownAction action,
}) {
  int clamp(int value) => value < 0
      ? text.length
      : (value > text.length ? text.length : value);

  final start = clamp(selectionStart);
  final end = selectionEnd < 0 ? start : clamp(selectionEnd);
  final lo = start <= end ? start : end;
  final hi = start <= end ? end : start;

  return switch (action) {
    MarkdownAction.heading => _prefixLines(text, lo, hi, '## '),
    MarkdownAction.bullet => _prefixLines(text, lo, hi, '- '),
    MarkdownAction.task => _prefixLines(text, lo, hi, '- [ ] '),
    MarkdownAction.code => _insertBlock(text, lo, hi, '```\n', '\n```'),
    MarkdownAction.image => _insertBlock(text, lo, hi, '![](', ')'),
  };
}
