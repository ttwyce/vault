import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/taxonomy/taxonomy_repository.dart';
import '../../data/taxonomy/taxonomy_repository_provider.dart';
import '../../data/write/write_gateway.dart';
import '../history/history_page.dart';

/// 回收站。
///
/// 只提供「恢复」与「看历史」，**不提供永久删除**：30 天到期清理由
/// 后台任务负责，UI 上放一个"彻底删除"按钮只会让用户误触后无法挽回。
class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage> {
  Future<List<TrashItem>> _items =
      Future<List<TrashItem>>.value(const <TrashItem>[]);
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    // 先取 Future 再 setState：箭头闭包返回 Future 会被 Flutter 断言拦下。
    final next = ref.read(taxonomyRepositoryProvider).trash();
    setState(() {
      _items = next;
      _error = null;
    });
  }

  Future<void> _restore(String id) async {
    try {
      await ref.read(writeGatewayProvider).writeEntry(
            EntryWrite.restore(id: id),
          );
      _refresh();
    } on WriteException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '回收站',
        subtitle: '删除的内容保留 30 天',
        showSettings: false,
        leading: SketchIconButton(
          glyph: SketchGlyph.close,
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        child: FutureBuilder<List<TrashItem>>(
          future: _items,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<TrashItem>> snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator(color: p.red));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '读取回收站失败：${snapshot.error}',
                  style: TextStyle(fontSize: 12, color: p.red),
                ),
              );
            }
            final items = snapshot.data ?? const <TrashItem>[];
            if (items.isEmpty) {
              return Center(
                child: Text(
                  '回收站是空的',
                  style: TextStyle(fontSize: 12.5, height: 1.6, color: p.muted),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                SketchSpace.lg,
                SketchSpace.sm,
                SketchSpace.lg,
                SketchSpace.xxl,
              ),
              itemCount: items.length + ( _error == null ? 0 : 1 ),
              separatorBuilder: (_, _) => const SketchDivider(),
              itemBuilder: (BuildContext context, int index) {
                if (_error != null && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: SketchSpace.sm),
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 12, color: p.red),
                    ),
                  );
                }
                final item = items[index - (_error == null ? 0 : 1)];
                return _TrashTile(
                  item: item,
                  onRestore: () => _restore(item.id),
                  onHistory: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => HistoryPage(entryId: item.id),
                      ),
                    );
                    // 历史页可能回滚了内容，回到列表时刷新一次
                    _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.item,
    required this.onRestore,
    required this.onHistory,
  });

  final TrashItem item;
  final VoidCallback onRestore;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final deleted = item.deletedAt == 0
        ? '时间未知'
        : fmt.format(DateTime.fromMillisecondsSinceEpoch(item.deletedAt));
    final expire = item.expireAt == null
        ? '到期时间未知'
        : DateFormat('yyyy-MM-dd')
            .format(DateTime.fromMillisecondsSinceEpoch(item.expireAt!));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SketchSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: p.ink,
            ),
          ),
          if (item.snippet.isNotEmpty) ...<Widget>[
            const SizedBox(height: SketchSpace.xs),
            Text(
              item.snippet,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.6, color: p.muted),
            ),
          ],
          const SizedBox(height: SketchSpace.sm),
          Text(
            '$deleted 删除 · $expire 到期',
            style: context.typography.monoStyle(size: 10, color: p.muted),
          ),
          const SizedBox(height: SketchSpace.sm),
          Row(
            children: <Widget>[
              SketchButton(
                label: '恢复',
                tone: SketchTone.primary,
                dense: true,
                onPressed: onRestore,
              ),
              const SizedBox(width: SketchSpace.sm),
              SketchButton(
                label: '历史版本',
                tone: SketchTone.ghost,
                dense: true,
                onPressed: onHistory,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
