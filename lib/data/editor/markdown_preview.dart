/// Markdown 轻量预览的**纯判定层**（docs/09 §4：M2 剩余项）。
///
/// 不引入 markdown 渲染包、不解析 HTML：只把文本逐行归类成可渲染的块，
/// UI 用 Flutter 内置 Text 显示。够用于「实时预览写的是不是 Markdown」，
/// 不追求完整 CommonMark 兼容。
library;

enum PreviewBlockKind {
  heading1,
  heading2,
  heading3,
  bullet,
  task,
  quote,
  codeFence,
  image,
  paragraph,
}

class PreviewBlock {
  const PreviewBlock({
    required this.kind,
    required this.text,
    this.checked = false,
  });

  final PreviewBlockKind kind;
  final String text;
  final bool checked;

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind.name,
        'text': text,
        'checked': checked,
      };
}

/// 逐行解析。代码围栏内的行原样保留，不做二次解析。
List<PreviewBlock> parseMarkdownPreview(String source) {
  final out = <PreviewBlock>[];
  var inFence = false;
  final fence = StringBuffer();
  for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trimRight();
    if (line.trimLeft().startsWith('```')) {
      if (inFence) {
        out.add(PreviewBlock(
          kind: PreviewBlockKind.codeFence,
          text: fence.toString().trimRight(),
        ));
        fence.clear();
        inFence = false;
      } else {
        inFence = true;
      }
      continue;
    }
    if (inFence) {
      fence.writeln(line);
      continue;
    }
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty) {
      out.add(const PreviewBlock(
          kind: PreviewBlockKind.paragraph, text: ''));
      continue;
    }
    if (trimmed.startsWith('### ')) {
      out.add(PreviewBlock(
          kind: PreviewBlockKind.heading3, text: trimmed.substring(4)));
    } else if (trimmed.startsWith('## ')) {
      out.add(PreviewBlock(
          kind: PreviewBlockKind.heading2, text: trimmed.substring(3)));
    } else if (trimmed.startsWith('# ')) {
      out.add(PreviewBlock(
          kind: PreviewBlockKind.heading1, text: trimmed.substring(2)));
    } else if (trimmed.startsWith('- [ ] ') ||
        trimmed.startsWith('- [x] ') ||
        trimmed.startsWith('- [X] ')) {
      out.add(PreviewBlock(
        kind: PreviewBlockKind.task,
        text: trimmed.substring(6),
        checked: trimmed[3].toLowerCase() == 'x',
      ));
    } else if (trimmed.startsWith('- ')) {
      out.add(PreviewBlock(
          kind: PreviewBlockKind.bullet, text: trimmed.substring(2)));
    } else if (trimmed.startsWith('> ')) {
      out.add(PreviewBlock(
          kind: PreviewBlockKind.quote, text: trimmed.substring(2)));
    } else if (RegExp(r'^!\[[^\]]*\]\([^)]+\)').hasMatch(trimmed)) {
      out.add(PreviewBlock(
          kind: PreviewBlockKind.image, text: trimmed));
    } else {
      out.add(PreviewBlock(
          kind: PreviewBlockKind.paragraph, text: trimmed));
    }
  }
  if (inFence && fence.isNotEmpty) {
    out.add(PreviewBlock(
      kind: PreviewBlockKind.codeFence,
      text: fence.toString().trimRight(),
    ));
  }
  return List<PreviewBlock>.unmodifiable(out);
}

/// 预览摘要（给列表/搜索用，去掉 Markdown 标记）。
String previewPlainText(String source) => parseMarkdownPreview(source)
    .where((PreviewBlock b) => b.text.trim().isNotEmpty)
    .map((PreviewBlock b) => b.text)
    .join(' ')
    .trim();
