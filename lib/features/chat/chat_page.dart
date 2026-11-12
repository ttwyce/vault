import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../core/identity/uuid_v7.dart';
import '../../core/sync/hlc.dart';
import '../../data/chat/conversation_models.dart';
import '../../data/chat/conversation_repository.dart';
import '../../data/vault/credential_models.dart';
import '../../data/vault/credential_repository_provider.dart';
import '../../data/chat/conversation_repository_provider.dart';
import '../../data/agent/model_availability_provider.dart';
import '../../data/agent/model_status.dart';
import '../../data/chat/conversation_retention.dart';
import '../../data/chat/conversation_scroll.dart';
import '../../data/chat/conversation_writer.dart';
import '../editor/editor_page.dart';
import 'widgets/conversation_drawer.dart';

/// 聊天首页。
///
/// 定位见 docs/12：首页是「会话列表 + 当前会话」的聊天骨架，
/// 不是分类目录。左上三横杠用独立 Overlay 路由打开会话抽屉（主区零重排），
/// 右上「开启新对话」进入草稿态（T26：首条消息前不落库）。
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  ConversationDraftState _draft = ConversationDraftState.initial;
  Future<List<ConversationMessageView>> _messages =
      Future<List<ConversationMessageView>>.value(
    const <ConversationMessageView>[],
  );

  /// 抽屉用 OverlayEntry 挂在根 Overlay 上：不进 PageScaffold 的布局树，
  /// 因此不会改变主区尺寸，也不会与 Expanded / ListView 的高度约束打架。
  bool _drawerOpen = false;
  bool _pendingScrollToLatest = false;

  void _openDrawer() {
    if (_drawerOpen) return;
    _drawerOpen = true;
    // 用独立路由而不是把抽屉塞进 PageScaffold 的布局树：
    // 主区布局零变化，且路由自带 Material 祖先（TextField 不会报错）。
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭对话抽屉',
      barrierColor: context.sketch.scrim,
      pageBuilder: (
        BuildContext dialogContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) =>
          Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 320,
          child: ConversationDrawer(
            currentId: _draft.currentId,
            onSelect: _selectConversation,
            onNewDraft: _startDraft,
            onClose: _closeDrawer,
          ),
        ),
      ),
    ).whenComplete(() => _drawerOpen = false);
  }

  void _closeDrawer() {
    if (!_drawerOpen) return;
    _drawerOpen = false;
    if (context.mounted) Navigator.of(context).maybePop();
  }

  /// 切换会话时重置消息 Future 与滚动位置（docs/12 §5 ③）。
  void _switchTo(ConversationDraftState next) {
    setState(() {
      _draft = next;
      _messages = next.currentId == null
          ? Future<List<ConversationMessageView>>.value(
              const <ConversationMessageView>[])
          : ref
              .read(conversationRepositoryProvider)
              .messages(next.currentId!, plan: MessagePagePlan.latest());
      _pendingScrollToLatest = next.currentId != null;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _startDraft() {
    _input.clear();
    _switchTo(_draft.startDraft());
    _closeDrawer();
  }

  void _selectConversation(String id) {
    _switchTo(_draft.selectExisting(id));
    _closeDrawer();
  }

  /// 首条用户消息才真正创建会话（T26），消息 append-only 写入。
  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    // docs/07 §4.3 密码绝对边界：用户把已存密码 / TOTP / secret 字段的
    // 明文贴进聊天框时，在写库之前就拒绝，绝不让它进任何模型上下文。
    final secrets = await ref
        .read(credentialRepositoryProvider)
        .knownSecretValues();
    if (CredentialGuard.containsSecret(trimmed, secrets)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('消息里含有本机已存的密码或密钥，已阻止发送'),
          ),
        );
      }
      return;
    }
    final writer = ConversationWriter(
      db: ref.read(vaultDatabaseProvider),
      clock: HlcClock(node: 'devA', now: () => DateTime.now().millisecondsSinceEpoch),
      uuid: UuidV7(),
      deviceId: 'devA',
    );
    final next = await writer.append(
      draft: _draft,
      role: 1,
      content: trimmed,
    );
    if (!mounted) return;
    _switchTo(next);
    _input.clear();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.sketch;
    final status = resolveModelStatus(
      availability: ref.watch(modelAvailabilityProvider),
    );

    return PageScaffold(
      title: '聊天',
      subtitle: status.subtitle,
      leading: SketchIconButton(
        glyph: SketchGlyph.menu,
        tooltip: '对话列表',
        onPressed: _openDrawer,
      ),
      actions: <Widget>[
        SketchButton(
          label: '开启新对话',
          glyph: SketchGlyph.plus,
          tone: SketchTone.primary,
          dense: true,
          onPressed: _startDraft,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CurrentConversationBar(
            label: _draft.hasDraft
                ? '新草稿会话'
                : (_draft.currentId ?? '未选择会话'),
            modelLabel: status.subtitle,
            currentId: _draft.currentId,
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                SketchSpace.lg,
                SketchSpace.lg,
                SketchSpace.lg,
                SketchSpace.lg,
              ),
              children: <Widget>[
                FutureBuilder<List<ConversationMessageView>>(
                  future: _messages,
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<ConversationMessageView>> snap,
                  ) {
                    final messages = snap.data ??
                        const <ConversationMessageView>[];
                    if (_pendingScrollToLatest && messages.isNotEmpty) {
                      _pendingScrollToLatest = false;
                      final plan = planConversationScroll(
                        conversationId: _draft.currentId,
                        messageCount: messages.length,
                        isDraft: _draft.hasDraft,
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted || !_scroll.hasClients) return;
                        _scroll.jumpTo(scrollOffsetFor(
                          plan,
                          maxExtent: _scroll.position.maxScrollExtent,
                          hasMessages: messages.isNotEmpty,
                        ));
                      });
                    }
                    if (messages.isEmpty) {
                      // docs/07 §10.3：首次进入显示 3 个示例问题，点击即填入
                      // 输入框（不自动发送，端侧模型未接入前不假装有回复）。
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: SketchSpace.xl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _draft.hasDraft
                                  ? '新的草稿会话，发出第一条消息后才会保存。'
                                  : '还没有消息，说点什么吧。',
                              style: TextStyle(
                                  fontSize: 12, color: palette.muted),
                            ),
                            if (status.guidance.isNotEmpty) ...<Widget>[
                              const SizedBox(height: SketchSpace.sm),
                              Text(
                                status.guidance,
                                style: TextStyle(
                                    fontSize: 11, color: palette.blue),
                              ),
                            ],
                            const SizedBox(height: SketchSpace.md),
                            for (final question in kExampleQuestions)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: SketchSpace.sm,
                                ),
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _input.text = question,
                                  ),
                                  child: SketchTag(
                                    question,
                                    tone: SketchTone.plain,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final message in messages) ...<Widget>[
                          if (message.role == 3)
                            _ToolCallCard(content: message.content)
                          else if (message.isUser)
                            _UserMessage(text: message.content)
                          else
                            _AiMessage(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    message.content,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: palette.ink,
                                    ),
                                  ),
                                  if (message.citations.isNotEmpty)
                                    _CitationChips(ids: message.citations),
                                ],
                              ),
                            ),
                          const SizedBox(height: SketchSpace.lg),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: SketchSpace.xxl),
              ],
            ),
          ),
          _InputBar(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _CurrentConversationBar extends StatelessWidget {
  const _CurrentConversationBar({
    required this.label,
    required this.modelLabel,
    this.currentId,
  });

  final String label;
  final String modelLabel;
  final String? currentId;

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
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ),
          if (currentId != null)
            Flexible(
              child: Consumer(
                builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                    FutureBuilder<String>(
                  future: _conversationMeta(ref, currentId!),
                  builder: (BuildContext context, AsyncSnapshot<String> snap) {
                    final meta = snap.data ?? '';
                    return Text(
                      meta.isEmpty ? '' : '$meta · ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: p.muted),
                    );
                  },
                ),
              ),
            ),
          Text(modelLabel,
              style: TextStyle(fontSize: 10.5, color: p.muted)),
        ],
      ),
    );
  }

  /// 当前会话的时间 + 引用数（docs/12 §3.1），从真实库异步读。
  static Future<String> _conversationMeta(
      WidgetRef ref, String currentId) async {
    final repo = ref.read(conversationRepositoryProvider);
    final summaries = await repo.list();
    final updatedAt = summaries
        .where((ConversationSummary c) => c.id == currentId)
        .firstOrNull
        ?.updatedAt;
    final messages = await repo.messages(currentId);
    final citations = <String>{
      for (final message in messages) ...message.citations,
    }.length;
    final time = updatedAt == null
        ? ''
        : _formatTime(DateTime.fromMillisecondsSinceEpoch(updatedAt));
    return citations > 0 ? '$time · 引用 $citations 条' : time;
  }

  static String _formatTime(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
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

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final void Function(String text) onSend;

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
                onSubmitted: onSend,
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
              onPressed: () => onSend(controller.text),
            ),
          ],
        ),
      ),
    );
  }
}


/// docs/07 §10.3 空状态示例问题。
const List<String> kExampleQuestions = <String>[
  '我上个月记过关于同步冲突的内容吗？',
  '帮我看看这周都做了什么',
  '有哪些网页已经打不开了？',
];


/// docs/07 §10.1：工具调用折叠卡，默认收起。
class _ToolCallCard extends StatefulWidget {
  const _ToolCallCard({required this.content});

  final String content;

  @override
  State<_ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<_ToolCallCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: SketchTag(
        _expanded ? '🔍 ${widget.content}' : '🔍 工具调用 · 点击展开',
        tone: SketchTone.plain,
      ),
    );
  }
}

/// 引用以卡片形式嵌在回答里，点击直达条目详情（docs/07 §10.1）。
class _CitationChips extends StatelessWidget {
  const _CitationChips({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SketchSpace.sm),
      child: Wrap(
        spacing: SketchSpace.sm,
        runSpacing: SketchSpace.sm,
        children: <Widget>[
          for (final id in ids)
            GestureDetector(
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => EditorPage(entryId: id),
                ),
              ),
              child: SketchTag('见：$id', tone: SketchTone.blue),
            ),
        ],
      ),
    );
  }
}
