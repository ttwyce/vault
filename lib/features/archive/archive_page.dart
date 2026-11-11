import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/archive/archive_meta.dart';
import '../../data/archive/archive_policy.dart';
import '../../data/archive/archive_repository.dart';
import '../../data/archive/archive_repository_provider.dart';

/// 归档网站总览（docs/11 §3.2）。
///
/// 数据来自 `ArchiveRepository`（真实 `entry(kind=5)` 的 meta），
/// 筛选 / 站点聚合 / 存储汇总全走 [archive_policy.dart] 的纯函数。
/// 这里只展示事实：状态、站点、摘要、快照大小、下次检查时间。
class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({super.key});

  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  ArchiveFilter _filter = ArchiveFilter.all;
  String? _site;
  String _query = '';
  final TextEditingController _search = TextEditingController();
  Future<_ArchiveData>? _future;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // FutureBuilder 的 future 必须稳定：每次 build 重新 _load() 会让
    // 点筛选时又回到 waiting，列表闪一下甚至断言落空。
    _future ??= _load(ref.read(archiveRepositoryProvider));
  }

  static const List<(String, ArchiveFilter)> _filters =
      <(String, ArchiveFilter)>[
    ('全部', ArchiveFilter.all),
    ('存活', ArchiveFilter.alive),
    ('失效', ArchiveFilter.dead),
    ('待重抓', ArchiveFilter.pendingRecheck),
    ('仅元数据', ArchiveFilter.metadataOnly),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return FutureBuilder<_ArchiveData>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<_ArchiveData> snapshot) {
        final data = snapshot.data ??
            const _ArchiveData(
              entries: <ArchiveEntry>[],
              sites: <ArchiveSiteGroupCount>[],
            );
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final filtered = filterArchives(
          data.entries.map((ArchiveEntry e) => e.meta),
          filter: _site == null ? _filter : ArchiveFilter.site,
          nowMs: nowMs,
          site: _site,
        );
        final visibleKeys = filtered
            .map((ArchiveMeta m) => m.toJsonString())
            .toSet();
        final query = _query.trim().toLowerCase();
        final visible = data.entries
            .where((ArchiveEntry e) =>
                visibleKeys.contains(e.meta.toJsonString()))
            .where((ArchiveEntry e) {
              if (query.isEmpty) return true;
              final haystack = <Object?>[
                e.title,
                e.meta.title,
                e.meta.site,
                e.meta.excerpt,
                e.meta.url,
              ].whereType<String>().join(' ').toLowerCase();
              return haystack.contains(query);
            })
            .toList(growable: false);
        final summary = summarizeStorage(
          data.entries.map((ArchiveEntry e) => e.meta),
        );
        final sites = groupBySite(
          data.entries.map((ArchiveEntry e) => e.meta),
        );

        return PageScaffold(
          title: '归档',
          subtitle: '${data.entries.length} 个 · ${_formatBytes(summary.totalBytes)}',
          actions: <Widget>[
            SketchButton(
              label: '归档网址',
              glyph: SketchGlyph.plus,
              tone: SketchTone.primary,
              dense: true,
              onPressed: () {},
            ),
          ],
          child: snapshot.connectionState == ConnectionState.waiting
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(SketchSpace.xxl),
                    child: CircularProgressIndicator(),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    SketchSpace.lg,
                    SketchSpace.md,
                    SketchSpace.lg,
                    SketchSpace.xxl,
                  ),
                  children: <Widget>[
                    TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: '找哪个归档…',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String value) =>
                          setState(() => _query = value),
                    ),
                    const SizedBox(height: SketchSpace.md),
                    Wrap(
                      spacing: SketchSpace.sm,
                      runSpacing: SketchSpace.sm,
                      children: <Widget>[
                        for (final (label, filter) in _filters)
                          GestureDetector(
                            onTap: () => setState(() {
                              _filter = filter;
                              _site = null;
                            }),
                            child: SketchTag(
                              label,
                              tone: _filter == filter && _site == null
                                  ? SketchTone.primary
                                  : SketchTone.plain,
                            ),
                          ),
                        if (sites.isNotEmpty) ...<Widget>[
                          const SizedBox(width: SketchSpace.sm),
                          for (final group in sites.take(6))
                            GestureDetector(
                              onTap: () => setState(() => _site = group.site),
                              child: SketchTag(
                                '${group.site} ${group.count}',
                                tone: _site == group.site
                                    ? SketchTone.blue
                                    : SketchTone.plain,
                              ),
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: SketchSpace.lg),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: SketchSpace.xl,
                        ),
                        child: Text(
                          '这个筛选下还没有归档',
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      )
                    else
                      for (final entry in visible)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: SketchSpace.md),
                          child: _ArchiveTile(entry: entry),
                        ),
                    const SizedBox(height: SketchSpace.lg),
                    SketchCard(
                      variant: 3,
                      fill: p.noteAlt,
                      tilt: SketchTilt.none,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '存储：正文 ${_formatBytes(summary.textBytes)} · '
                            '快照 ${_formatBytes(summary.snapshotBytes)} · '
                            '图片 ${_formatBytes(summary.imageBytes)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.6,
                              color: p.blue,
                            ),
                          ),
                          const SizedBox(height: SketchSpace.sm),
                          Text(
                            '${data.sites.length} 个站点。超过 80% 配额时'
                            '新归档只存正文层，最老的快照会被降级。',
                            style: TextStyle(fontSize: 11, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<_ArchiveData> _load(ArchiveRepository repo) async {
    final entries = await repo.list();
    final sites = await repo.sites();
    return _ArchiveData(entries: entries, sites: sites);
  }
}

class _ArchiveData {
  const _ArchiveData({required this.entries, required this.sites});

  final List<ArchiveEntry> entries;
  final List<ArchiveSiteGroupCount> sites;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({required this.entry});

  final ArchiveEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final meta = entry.meta;
    final title = entry.title ?? meta.title ?? '(无标题)';
    final badges = <(String, SketchTone)>[
      if (meta.hasSnapshot) ('快照', SketchTone.primary),
      if (meta.isDeadLink) ('原站已失效', SketchTone.primary),
      if (meta.status == ArchiveStatus.blocked) ('反爬', SketchTone.blue),
      if (meta.status == ArchiveStatus.paywalled) ('付费墙', SketchTone.blue),
      if (meta.status == ArchiveStatus.metadata) ('仅元数据', SketchTone.plain),
      if (meta.changed) ('内容有变更', SketchTone.blue),
    ];
    final trailing = meta.isDeadLink
        ? '试 Wayback'
        : meta.changed
            ? '对比'
            : '下次检查 ${meta.policy.wire}';

    return SketchCard(
      variant: meta.url.hashCode.abs() % 4,
      tilt: meta.url.hashCode.isEven ? SketchTilt.left : SketchTilt.right,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SketchFrame(
            radius: SketchRadii.d,
            fill: p.note,
            padding: const EdgeInsets.all(6),
            shadowOffset: SketchShadowOffset.card,
            child: Text(
              meta.site.isEmpty ? '?' : meta.site.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.ink,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: SketchSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta.site.isEmpty
                      ? '待补全网址'
                      : '${meta.site} · ${_formatBytes(meta.snapshotBytes)}',
                  style: TextStyle(fontSize: 10.5, color: p.muted),
                ),
                if (meta.excerpt.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    meta.excerpt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: p.muted),
                  ),
                ],
                const SizedBox(height: SketchSpace.sm),
                Wrap(
                  spacing: SketchSpace.xs,
                  runSpacing: SketchSpace.xs,
                  children: <Widget>[
                    for (final (label, tone) in badges)
                      SketchTag(label, tone: tone, dense: true),
                    Text(trailing,
                        style: TextStyle(fontSize: 10.5, color: p.muted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
