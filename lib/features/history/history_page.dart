import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/entry/entry_repository_provider.dart';
import '../../data/taxonomy/taxonomy_repository.dart';
import '../../data/taxonomy/taxonomy_repository_provider.dart';
import '../../data/write/write_gateway.dart';

/// 一次加载的结果。
typedef HistoryData = ({List<HistoryVersion> versions, bool deleted});

/// 某条条目的历史版本列表。
///
/// **回滚不是把 rev 倒回去**：恢复某个版本等于做一次新的编辑，
/// rev 继续递增。所以在 UI 上文案写「恢复此版本」而不是「回到 r2」，
/// 免得用户以为旧版本会被删掉。
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  late Future<HistoryData> _data;
  int? _busyRev;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<HistoryData> _load() async {
    final versions = await ref
        .read(taxonomyRepositoryProvider)
        .history(widget.entryId);
    final row =
        await ref.read(entryRepositoryProvider).getRow(widget.entryId);
    return (versions: versions, deleted: row == null || row.deleted != 0);
  }

  void _refresh() {
    if (!mounted) return;
    final next = _load();
    setState(() {
      _data = next;
      _error = null;
    });
  }

  Future<void> _restore(int rev) async {
    if (_busyRev != null) return;
    setState(() {
      _busyRev = rev;
      _error = null;
    });
    try {
      await ref.read(writeGatewayProvider).restoreVersion(
            entryId: widget.entryId,
            rev: rev,
          );
      if (!mounted) return;
      setState(() => _busyRev = null);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('已恢复 r$rev 的内容（生成了新版本）')),
      );
      _refresh();
    } on WriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _busyRev = null;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '历史版本',
        subtitle: '保留最近 ${WriteGateway.historyDepth} 个旧版本',
        showSettings: false,
        leading: SketchIconButton(
          glyph: SketchGlyph.close,
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        child: FutureBuilder<HistoryData>(
          future: _data,
          builder: (
            BuildContext context,
            AsyncSnapshot<HistoryData> snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator(color: p.red));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '读取历史失败：${snapshot.error}',
                  style: TextStyle(fontSize: 12, color: p.red),
                ),
              );
            }
            final data = snapshot.data;
            final versions = data?.versions ?? const <HistoryVersion>[];
            final alreadyDeleted = data?.deleted ?? false;

            if (versions.isEmpty) {
              return Center(
                child: Text(
                  '还没有历史版本，编辑一次后就会出现',
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
              itemCount: versions.length + 1,
              separatorBuilder: (_, _) => const SketchDivider(),
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return _buildNotice(p, alreadyDeleted);
                }
                final version = versions[index - 1];
                return _HistoryTile(
                  version: version,
                  enabled: !alreadyDeleted && _busyRev == null,
                  busy: _busyRev == version.rev,
                  onRestore: () => _restore(version.rev),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotice(SketchPalette p, bool alreadyDeleted) {
    if (!alreadyDeleted && _error == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: SketchSpace.sm),
        child: Text(
          '恢复旧版本会生成一条新版本，现有内容会先自动存档。',
          style: TextStyle(fontSize: 11.5, height: 1.6, color: p.muted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: SketchSpace.sm),
      child: SketchFrame(
        radius: SketchRadii.c,
        fill: p.surface,
        borderColor: p.red,
        padding: const EdgeInsets.all(SketchSpace.md),
        tilt: SketchTilt.left,
        child: Text(
          alreadyDeleted
              ? '这条内容在回收站里，请先恢复条目再回滚版本。'
              : _error!,
          style: TextStyle(fontSize: 12, height: 1.7, color: p.ink),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.version,
    required this.enabled,
    required this.busy,
    required this.onRestore,
  });

  final HistoryVersion version;
  final bool enabled;
  final bool busy;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final time = DateFormat('yyyy-MM-dd HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(version.createdAt),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SketchSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SketchTag('r${version.rev}', tone: SketchTone.blue, dense: true),
              const SizedBox(width: SketchSpace.sm),
              Text(
                time,
                style: context.typography.monoStyle(size: 10, color: p.muted),
              ),
            ],
          ),
          const SizedBox(height: SketchSpace.sm),
          Text(
            version.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: p.ink,
            ),
          ),
          if (version.snippet.isNotEmpty) ...<Widget>[
            const SizedBox(height: SketchSpace.xs),
            Text(
              version.snippet,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.6, color: p.muted),
            ),
          ],
          const SizedBox(height: SketchSpace.sm),
          SketchButton(
            label: busy ? '恢复中…' : '恢复此版本',
            tone: SketchTone.primary,
            dense: true,
            onPressed: enabled ? onRestore : null,
          ),
        ],
      ),
    );
  }
}
