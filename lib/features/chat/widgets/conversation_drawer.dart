import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/sketch_metrics.dart';
import '../../../app/theme/sketch_theme.dart';
import '../../../core/widgets/sketch_controls.dart';
import '../../../core/widgets/sketch_frame.dart';
import '../../../data/chat/conversation_models.dart';
import '../../../data/chat/conversation_repository_provider.dart';

/// 对话抽屉（docs/12 §3 / §5）。
///
/// 由聊天页用 `Stack` overlay 承载，主区布局不变；这里只画抽屉内容：
/// 搜索框、分组列表、当前会话高亮、新建对话。
class ConversationDrawer extends ConsumerStatefulWidget {
  const ConversationDrawer({
    super.key,
    required this.currentId,
    required this.onSelect,
    required this.onNewDraft,
    required this.onClose,
  });

  final String? currentId;
  final void Function(String id) onSelect;
  final VoidCallback onNewDraft;
  final VoidCallback onClose;

  @override
  ConsumerState<ConversationDrawer> createState() =>
      _ConversationDrawerState();
}

class _ConversationDrawerState
    extends ConsumerState<ConversationDrawer> {
  String _query = '';
  late Future<List<ConversationGroup>> _groups;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _groups = ref
        .read(conversationRepositoryProvider)
        .groups(nowMs: DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
      child: SketchFrame(
        radius: SketchRadii.c,
        fill: p.surface,
        shadowOffset: SketchShadowOffset.panel,
        padding: const EdgeInsets.all(SketchSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '对话',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                ),
                SketchButton(
                  label: '新对话',
                  dense: true,
                  onPressed: widget.onNewDraft,
                ),
              ],
            ),
            const SizedBox(height: SketchSpace.sm),
            TextField(
              decoration: const InputDecoration(
                hintText: '搜索对话…',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) =>
                  setState(() => _query = value.trim()),
            ),
            const SizedBox(height: SketchSpace.md),
            Expanded(
              child: FutureBuilder<List<ConversationGroup>>(
                future: _groups,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<ConversationGroup>> snapshot,
                ) {
                  final groups = snapshot.data ??
                      const <ConversationGroup>[];
                  final visible = <ConversationGroup>[
                    for (final group in groups)
                      ConversationGroup(
                        key: group.key,
                        label: group.label,
                        conversations: group.conversations
                            .where((ConversationSummary c) =>
                                _query.isEmpty ||
                                (c.title ?? '新对话').contains(_query))
                            .toList(),
                      ),
                  ].where((ConversationGroup g) =>
                      g.conversations.isNotEmpty).toList();
                  if (visible.isEmpty) {
                    return Text(
                      snapshot.connectionState == ConnectionState.waiting
                          ? '加载中…'
                          : '还没有对话',
                      style: TextStyle(fontSize: 12, color: p.muted),
                    );
                  }
                  return ListView(
                    children: <Widget>[
                      for (final group in visible) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: SketchSpace.sm,
                            bottom: SketchSpace.xs,
                          ),
                          child: Text(
                            group.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: p.muted,
                            ),
                          ),
                        ),
                        for (final conversation in group.conversations)
                          _ConversationTile(
                            conversation: conversation,
                            isCurrent:
                                conversation.id == widget.currentId,
                            onTap: () => widget.onSelect(conversation.id),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: SketchSpace.sm),
            GestureDetector(
              onTap: widget.onClose,
              child: Text(
                '收起抽屉',
                style: TextStyle(fontSize: 11, color: p.blue),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.isCurrent,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Padding(
      padding: const EdgeInsets.only(bottom: SketchSpace.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Transform.rotate(
          // docs/12 §5 ⑤：当前项比其他项多歪一点。
          angle: isCurrent ? SketchTilt.leftStrong : SketchTilt.none,
          child: Container(
            decoration: BoxDecoration(
              color: isCurrent ? p.note : null,
              border: isCurrent
                  ? Border(left: BorderSide(color: p.red, width: 3))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: SketchSpace.sm,
              vertical: SketchSpace.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    deriveConversationTitle(
                        conversation.title, null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: p.ink),
                  ),
                ),
                Text(
                  '${conversation.messageCount}',
                  style: context.typography.monoStyle(
                    size: 10.5,
                    color: p.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
