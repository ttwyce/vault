import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';

/// 聊天首页。
///
/// 定位见 docs/12：首页是「会话列表 + 当前会话」的聊天骨架，
/// 不是分类目录。左上三横杠打开会话抽屉（待实现），
/// 右上「开启新对话」进入空白草稿会话（待实现）。
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;

    return PageScaffold(
      title: '聊天',
      subtitle: '端侧模型 · 就绪',
      leading: SketchIconButton(
        glyph: SketchGlyph.menu,
        tooltip: '对话列表',
        onPressed: () {
          // TODO(M7): 打开会话抽屉
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('会话抽屉将在 M7 实现')),
          );
        },
      ),
      actions: <Widget>[
        SketchButton(
          label: '开启新对话',
          glyph: SketchGlyph.plus,
          tone: SketchTone.primary,
          dense: true,
          onPressed: () {
            // TODO(M7): 进入草稿态会话
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('新建草稿会话将在 M7 实现')),
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _CurrentConversationBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SketchSpace.lg,
                SketchSpace.lg,
                SketchSpace.lg,
                SketchSpace.lg,
              ),
              children: <Widget>[
                _AiMessage(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '早上好。昨天你存了 3 条跟 WebDAV 限流有关的东西，'
                        '其中一条还只是半句话 —— 要我合成一篇吗？',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.7,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: SketchSpace.md),
                      Wrap(
                        spacing: SketchSpace.sm,
                        runSpacing: SketchSpace.sm,
                        children: const <Widget>[
                          SketchTag('合成一篇', tone: SketchTone.primary),
                          SketchTag('先看原文'),
                          SketchTag('不用'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SketchSpace.lg),
                _UserMessage(
                  text: '把 example.com/rfc-6578 收进来，跟之前那条合并',
                ),
                const SizedBox(height: SketchSpace.lg),
                _ToolCard(),
                const SizedBox(height: SketchSpace.lg),
                _AiMessage(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '收进来了。它跟你 8 月 11 日那条讲的是同一件事，'
                        '我把两边的要点并到了一起：',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.7,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: SketchSpace.md),
                      _CitationCard(
                        title: 'RFC 6578 增量同步',
                        meta: '08-11 · 归档 · 有快照',
                        variant: 2,
                      ),
                      const SizedBox(height: SketchSpace.sm),
                      _CitationCard(
                        title: '增量同步的请求预算',
                        meta: '08-10 · 笔记',
                        variant: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SketchSpace.xxl),
              ],
            ),
          ),
          _InputBar(controller: _input),
        ],
      ),
    );
  }
}

class _CurrentConversationBar extends StatelessWidget {
  const _CurrentConversationBar();

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SketchSpace.lg,
        vertical: SketchSpace.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.lineSoft, width: 1)),
      ),
      child: Row(
        children: <Widget>[
          Text('当前对话', style: TextStyle(fontSize: 10.5, color: p.muted)),
          const SizedBox(width: SketchSpace.sm),
          Expanded(
            child: Text(
              '把 RFC 6578 收进来',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ),
          Text('14:02 · 引用 3 条',
              style: TextStyle(fontSize: 10.5, color: p.muted)),
        ],
      ),
    );
  }
}

class _AiMessage extends StatelessWidget {
  const _AiMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SketchFrame(
          radius: SketchRadii.c,
          fill: p.red,
          borderColor: p.red,
          shadowOffset: SketchShadowOffset.card,
          padding: const EdgeInsets.all(7),
          child: SketchIcon(SketchGlyph.chat, size: 15, color: Colors.white),
        ),
        const SizedBox(width: SketchSpace.md),
        Flexible(
          child: SketchCard(
            variant: 1,
            padding: const EdgeInsets.all(SketchSpace.md),
            tilt: SketchTilt.none,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Flexible(
          child: SketchFrame(
            radius: SketchRadii.d,
            fill: p.note,
            borderColor: p.lineSoft,
            shadowOffset: SketchShadowOffset.card,
            tilt: SketchTilt.right,
            padding: const EdgeInsets.symmetric(
              horizontal: SketchSpace.md,
              vertical: SketchSpace.sm,
            ),
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.6, color: p.ink),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard();

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    const steps = <(String, String, bool)>[
      ('抓取正文', '4,182 字', true),
      ('判定类型', '网页归档', true),
      ('找到 2 条相关旧记录', '', true),
      ('归档快照', '生成 PDF…', false),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(width: 34),
        Flexible(
          child: SketchCard(
            variant: 0,
            tilt: SketchTilt.none,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '正在处理这个链接',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ),
                    Text('2.1s',
                        style: TextStyle(fontSize: 10.5, color: p.muted)),
                  ],
                ),
                const SizedBox(height: SketchSpace.sm),
                for (final (label, value, done) in steps)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: <Widget>[
                        Text(
                          done ? '✓' : '◐',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: done ? p.green : p.red,
                          ),
                        ),
                        const SizedBox(width: SketchSpace.sm),
                        Text(label,
                            style: TextStyle(fontSize: 12, color: p.ink)),
                        const Spacer(),
                        Text(value,
                            style: TextStyle(fontSize: 10.5, color: p.muted)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CitationCard extends StatelessWidget {
  const _CitationCard({
    required this.title,
    required this.meta,
    required this.variant,
  });

  final String title;
  final String meta;
  final int variant;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return SketchCard(
      variant: variant,
      tilt: variant.isEven ? SketchTilt.left : SketchTilt.right,
      padding: const EdgeInsets.symmetric(
        horizontal: SketchSpace.md,
        vertical: SketchSpace.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(meta,
                    style: TextStyle(fontSize: 10.5, color: p.muted)),
              ],
            ),
          ),
          Text('点开 →',
              style: TextStyle(fontSize: 10.5, color: p.blue)),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SketchSpace.lg,
        SketchSpace.sm,
        SketchSpace.lg,
        SketchSpace.lg,
      ),
      child: SketchFrame(
        radius: SketchRadii.b,
        fill: p.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: SketchSpace.md,
          vertical: SketchSpace.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                style: TextStyle(fontSize: 13, color: p.ink),
                cursorColor: p.red,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '说点什么，或者把链接、截图丢进来…',
                  hintStyle: TextStyle(fontSize: 13, color: p.muted),
                ),
              ),
            ),
            const SizedBox(width: SketchSpace.sm),
            SketchButton(
              label: '发送',
              tone: SketchTone.primary,
              dense: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
