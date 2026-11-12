import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_card_variant.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import 'archive_reader_page.dart';
import '../../data/archive/archive_duplicate.dart';
import '../../data/archive/archive_body_meta_writer.dart';
import '../../data/archive/archive_cache_policy.dart';
import '../../data/archive/archive_meta.dart';
import '../../data/archive/archive_policy.dart';
import '../../data/archive/archive_recheck_actions.dart';
import '../../data/archive/archive_body_meta.dart';
import '../../data/archive/content_change_policy.dart';
import '../../data/archive/content_change_service.dart';
import '../../data/archive/archive_settings.dart';
import '../../data/archive/http_archive_fetcher.dart';
import '../../data/archive/http_link_checker.dart';
import '../../data/archive/http_wayback_client.dart';
import '../../data/archive/link_check_service.dart';
import '../../data/archive/archive_repository.dart';
import '../../app/session/vault_session.dart';
import '../../data/archive/archive_repository_provider.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/db/vault_database.dart' show BlobRefRow, EntryHistoryRow;
import '../../data/write/write_gateway.dart';

/// 归档网站总览（docs/11 §3.2）。
///
/// 数据来自 `ArchiveRepository`（真实 `entry(kind=5)` 的 meta），
/// 筛选 / 站点聚合 / 存储汇总全走 [archive_policy.dart] 的纯函数。
/// 这里只展示事实：状态、站点、摘要、快照大小、下次检查时间。
class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({
    super.key,
    this.checkerFactory,
    this.waybackClientFactory,
    this.blobBaseUrl,
    this.fetcherFactory,
  });

  /// 真实执行批量检查时可注入（widget 测试里 HttpClient 被绑定拦截，
  /// 用假 checker 覆盖），生产环境为 null → 真实 dart:io HEAD。
  final HttpLinkChecker Function()? checkerFactory;
  final HttpWaybackClient Function()? waybackClientFactory;

  /// blob 云端根地址（由装配层注入）；为空时阅读器只展示下载计划。
  final String? blobBaseUrl;
  final HttpArchiveFetcher Function()? fetcherFactory;

  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  ArchiveFilter _filter = ArchiveFilter.all;
  String? _site;
  String _query = '';
  final TextEditingController _search = TextEditingController();
  Future<_ArchiveData>? _future;
  final TextEditingController _newUrl = TextEditingController();

  @override
  void dispose() {
    _newUrl.dispose();
    _search.dispose();
    super.dispose();
  }

  /// 新建归档：只持久化 L1 元数据层（URL / site / 状态），真实抓取、
  /// readability 注入与 PDF 生成由 M4 平台层按策略补上。
  Future<void> _addArchiveUrl() async {
    final url = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('归档网址'),
        content: TextField(
          controller: _newUrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://example.com/post'),
          onSubmitted: (String value) =>
              Navigator.of(dialogContext).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_newUrl.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    // docs/05 §4 第 1 步：同 URL 已有条目时先问「是否更新快照」，
    // 不静默插入重复条目。
    final repo = ref.read(archiveRepositoryProvider);
    final data = await (_future ??= _load(repo));
    final plan = planArchiveDuplicate(
      rawUrl: trimmed,
      existing: <({String entryId, String url, String? finalUrl})>[
        for (final entry in data.entries)
          (
            entryId: entry.id,
            url: entry.meta.url,
            finalUrl: entry.meta.finalUrl,
          ),
      ],
    );
    if (plan.action == ArchiveDuplicateAction.invalid) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(plan.reason)));
      }
      return;
    }
    if (plan.action == ArchiveDuplicateAction.askUpdate) {
      if (!mounted) return;
      final existing = data.entries
          .where((ArchiveEntry e) => e.id == plan.existingEntryId)
          .firstOrNull;
      final open = await showDialog<bool>(
            // 上面已用 mounted 守住异步间隙。
            // ignore: use_build_context_synchronously
            context: context,
            builder: (BuildContext dialogContext) => AlertDialog(
              title: const Text('已归档过'),
              content: const Text('这条 URL 已经有归档条目；'
                  '真实重抓/更新快照尚未接入，是否打开已有条目？'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('打开'),
                ),
              ],
            ),
          ) ??
          false;
      if (open && existing != null && mounted) {
        await _openReader(existing);
      }
      _newUrl.clear();
      return;
    }
    // docs/05 §5：真实 GET 抽 L1 正文；失败只落 metadata，不写空正文。
    final fetcher = widget.fetcherFactory?.call() ?? HttpArchiveFetcher();
    final fetched = await fetcher.fetch(Uri.parse(plan.normalizedUrl));
    fetcher.close();
    final ArchiveMeta meta;
    try {
      final derived = fetched.ok && fetched.body != null
          ? planArchiveBodyMeta(fetched.body!)
          : null;
      meta = ArchiveMeta(
        url: plan.normalizedUrl,
        site: ArchiveMeta.siteOf(plan.normalizedUrl),
        status: fetched.ok ? ArchiveStatus.text : ArchiveStatus.metadata,
        title: fetched.title,
        policy: RecheckPolicy.monthly,
        excerpt: derived?.excerpt ?? '',
        readingTimeMin: derived?.readingTimeMin ?? 0,
        httpStatus: fetched.statusCode,
      );
    } on FormatException catch (e) {
      // 上面已用 mounted 守住异步间隙。
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    await ref.read(writeGatewayProvider).writeEntry(EntryWrite.create(
          kind: EntryKind.bookmark,
          title: fetched.title ?? plan.normalizedUrl,
          body: fetched.ok ? fetched.body : null,
          meta: meta.toJsonString(),
        ));
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(fetched.hint)),
      );
    }
    _newUrl.clear();
    setState(() {
      _future = _load(ref.read(archiveRepositoryProvider));
    });
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
              onPressed: _addArchiveUrl,
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
                      for (var i = 0; i < visible.length; i++)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: SketchSpace.md),
                          child: GestureDetector(
                            onTap: () => _openReader(visible[i]),
                            child: _ArchiveTile(
                              entry: visible[i],
                              variant: sketchCardVariants(visible.length)[i],
                              onWayback: () => _tryWayback(visible[i]),
                            ),
                          ),
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
                          const SizedBox(height: SketchSpace.sm),
                          Wrap(
                            spacing: SketchSpace.sm,
                            children: <Widget>[
                              SketchButton(
                                label: '批量检查计划',
                                dense: true,
                                onPressed: () => _showBatchRecheckPlan(
                                  context,
                                  data,
                                ),
                              ),
                              SketchButton(
                                label: '清理旧快照计划',
                                tone: SketchTone.ghost,
                                dense: true,
                                onPressed: () => _showQuotaCleanupPlan(
                                  context,
                                  data,
                                  summary,
                                ),
                              ),
                              SketchButton(
                                label: '检查内容变更',
                                tone: SketchTone.ghost,
                                dense: true,
                                onPressed: () => _checkContentChanges(data),
                              ),
                            ],
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

  /// docs/05 §6.2：只对「关注变更」或 30 天内访问过的条目重抓 L1，
  /// 真实计算 simhash 比对，变更时经 WriteGateway 保留旧版 history。
  Future<void> _checkContentChanges(_ArchiveData data) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final candidates = <ChangeCheckCandidate>[
      for (final entry in data.entries)
        ChangeCheckCandidate(
          entryId: entry.id,
          watchChanges: entry.meta.watchChanges,
          lastVisitedAtMs: entry.updatedAt,
        ),
    ];
    final ids = planChangeCheckBatch(candidates, nowMs: nowMs);
    final fetcher = widget.fetcherFactory?.call() ?? HttpArchiveFetcher();
    final service = ContentChangeService(
      db: ref.read(vaultDatabaseProvider),
      gateway: ref.read(writeGatewayProvider),
      fetcher: fetcher,
    );
    var changed = 0;
    for (final id in ids.take(20)) {
      final result = await service.checkAndApply(entryId: id, nowMs: nowMs);
      if (result.plan?.action == ContentChangeAction.promptChange) {
        changed++;
      }
    }
    fetcher.close();
    if (!mounted) return;
    setState(() {
      _future = _load(ref.read(archiveRepositoryProvider));
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('已检查 ${ids.length} 条，$changed 条内容有变化')),
    );
  }

  /// docs/11 §3.4：按 recheck_policy 分批列出待检查条目。
  /// 只展示计划，真实 HEAD 请求由平台层执行。
  void _showBatchRecheckPlan(BuildContext context, _ArchiveData data) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final batches = planBatchRecheck(
      metasById: <String, ArchiveMeta>{
        for (final entry in data.entries) entry.id: entry.meta,
      },
      nowMs: nowMs,
    );
    final ids = <String>[for (final batch in batches) ...batch];
    _showBatchDialog(
      context,
      '批量重检查计划',
      ids,
      '共 ${batches.length} 批 / ${ids.length} 条到期条目。'
      '点「执行 HEAD 检查」会真的发请求并落 link_check 证据。',
      onExecute: ids.isEmpty ? null : () => _executeBatchRecheck(data, ids),
    );
  }

  /// 死链 → 真实查询 Wayback availability，命中则把存档 URL 写回 meta
  /// （docs/05 §6.1）。走唯一写入口，保留 title/body/其它 meta 字段。
  Future<void> _tryWayback(ArchiveEntry entry) async {
    final client = widget.waybackClientFactory?.call() ?? HttpWaybackClient();
    final result = await client.findSnapshot(entry.meta.url);
    client.close();
    if (!mounted) return;
    if (result.available && result.archiveUrl != null) {
      final db = ref.read(vaultDatabaseProvider);
      final gateway = ref.read(writeGatewayProvider);
      final row = await (db.select(db.entries)
            ..where((t) => t.id.equals(entry.id)))
          .getSingleOrNull();
      if (row == null) return;
      final next = entry.meta.copyWith(waybackUrl: result.archiveUrl);
      await gateway.writeEntry(EntryWrite.update(
        id: entry.id,
        title: row.title,
        body: row.body,
        meta: next.toJsonString(),
      ));
      if (mounted) {
        setState(() {
          _future = _load(ref.read(archiveRepositoryProvider));
        });
      }
    }
    if (!mounted) return;
    if (!result.available) {
      // docs/05 §6.3：把 URL 发给第三方必须用户逐次勾选。
      final optedIn = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('提交到 Internet Archive？'),
          content: Text('${result.hint}\n\n勾选后会把该 URL 发送给 archive.org。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认提交'),
            ),
          ],
        ),
      );
      if (optedIn == true && mounted) {
        final submitClient =
            widget.waybackClientFactory?.call() ?? HttpWaybackClient();
        final saved = await submitClient.submitSave(
          targetUrl: entry.meta.url,
          userOptedIn: true,
        );
        submitClient.close();
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(saved)),
          );
        }
      }
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(result.hint)),
    );
  }

  /// 真实执行：dart:io HEAD + 唯一写入口落证据。
  /// 网络不可达按 unreachable 记录，不抛给 UI；失败不阻断其余条目。
  Future<int> _executeBatchRecheck(
    _ArchiveData data,
    List<String> ids,
  ) async {
    final checker = widget.checkerFactory?.call() ?? HttpLinkChecker();
    final service = LinkCheckService(
      db: ref.read(vaultDatabaseProvider),
      gateway: ref.read(writeGatewayProvider),
    );
    var done = 0;
    for (final id in ids.take(20)) {
      final entry = data.entries
          .where((ArchiveEntry e) => e.id == id)
          .firstOrNull;
      if (entry == null) continue;
      try {
        await service.runHttpCheck(
          entryId: id,
          url: entry.meta.url,
          checker: checker,
          nowMs: DateTime.now().millisecondsSinceEpoch,
          policy: entry.meta.policy,
        );
        done++;
      } on Object {
        // 单条失败继续下一条。
      }
    }
    checker.close();
    if (mounted) {
      setState(() {
        _future = _load(ref.read(archiveRepositoryProvider));
      });
    }
    return done;
  }

  /// docs/11 §3.4「清理」：按 LRU 列出将被降级为 text 的条目。
  void _showQuotaCleanupPlan(
    BuildContext context,
    _ArchiveData data,
    ArchiveStorageSummary summary,
  ) {
    const settings = ArchiveSettings();
    final quotaLimit = (summary.totalBytes / settings.quotaRatio).floor();
    final ids = planQuotaCleanup(
      metasById: <String, ArchiveMeta>{
        for (final entry in data.entries) entry.id: entry.meta,
      },
      quotaLimitBytes: quotaLimit == 0 ? 1 : quotaLimit,
      currentBytes: summary.totalBytes,
    );
    _showBatchDialog(
      context,
      '清理旧快照 · 计划',
      ids,
      '最老带快照的条目优先降级为 text（只留正文，不删条目 / 不删云端）。'
      '真实落库与删 blob 待平台层接入。',
    );
  }

  void _showBatchDialog(
    BuildContext context,
    String title,
    List<String> ids,
    String hint, {
    Future<int> Function()? onExecute,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(hint, style: const TextStyle(fontSize: 11.5, height: 1.6)),
              const SizedBox(height: SketchSpace.sm),
              if (ids.isEmpty)
                const Text('当前没有需要处理的条目。')
              else
                for (final id in ids.take(20))
                  Text('· $id', style: const TextStyle(fontSize: 11)),
              if (ids.length > 20)
                Text('还有 ${ids.length - 20} 条…',
                    style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        actions: <Widget>[
          if (onExecute != null)
            TextButton(
              onPressed: () async {
                final done = await onExecute();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(content: Text('已检查 $done 条归档')),
                  );
                }
              },
              child: const Text('执行 HEAD 检查'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _openReader(ArchiveEntry entry) async {
    // 真实接线：L1 正文来自 entry.body；L2 PDF 是否本地可读来自 blob_ref；
    // 上一版正文来自 entry_history 里最近的加密信封（解密失败只跳过，不崩页）。
    final db = ref.read(vaultDatabaseProvider);
    final gateway = ref.read(writeGatewayProvider);
    // docs/05 §10：列表页摘要不能读 blob，打开时按 L1 正文懒补
    // excerpt / reading_time_min（幂等，已存在不制造新版本）。
    await ArchiveBodyMetaWriter(db: db, gateway: gateway)
        .ensureDerivedMeta(entry.id);
    final row = await (db.select(db.entries)
          ..where((t) => t.id.equals(entry.id)))
        .getSingleOrNull();
    final pdfRows = await (db.select(db.blobRefs)
          ..where((t) => t.entryId.equals(entry.id)))
        .get();
    final pdfLocal = pdfRows.any((BlobRefRow r) => r.kind == 2 && r.local == 1);
    final body = row?.body;

    // docs/05 §7 按需下载：从 blob_ref 取各层 hash/local，交给阅读器
    // 渲染骨架屏与进度条；本地已有则 request 为 null。
    final textBlob = (await (db.select(db.blobRefs)
          ..where((t) => t.entryId.equals(entry.id)))
        .get())
        .where((BlobRefRow r) => r.kind == 1)
        .firstOrNull;
    final pdfBlob = pdfRows
        .where((BlobRefRow r) => r.kind == 2)
        .firstOrNull;
    final textRequest = textBlob == null
        ? null
        : planOnDemandRequest(
            entryId: entry.id,
            blobHash: textBlob.blobHash,
            layer: OnDemandLayer.text,
            local: textBlob.local == 1,
          );
    final pdfRequest = pdfBlob == null
        ? null
        : planOnDemandRequest(
            entryId: entry.id,
            blobHash: pdfBlob.blobHash,
            layer: OnDemandLayer.pdf,
            local: pdfBlob.local == 1,
          );

    String? previousBody;
    final historyRows = await (db.select(db.entryHistory)
          ..where((t) => t.entryId.equals(entry.id)))
        .get();
    // 只对早于当前 rev 的版本按 rev 倒序尝试，纯 Dart 过滤避开
    // drift 组合表达式差异。
    final candidates = historyRows
        .where((EntryHistoryRow h) => h.rev < (row?.rev ?? 0))
        .toList()
      ..sort((EntryHistoryRow a, EntryHistoryRow b) =>
          b.rev.compareTo(a.rev));
    if (candidates.isNotEmpty) {
      for (final history in candidates.take(5)) {
        try {
          final snapshot = await gateway.readEntryPayload(
            history.payload,
            expectedId: entry.id,
          );
          if (snapshot.body != null && snapshot.body != body) {
            previousBody = snapshot.body;
            break;
          }
        } on Object {
          // 坏信封 / 密钥不匹配：不让一条历史把阅读器打挂。
        }
      }
    }
    final hasPrevious = previousBody != null && body != null;
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => ArchiveReaderPage(
          entryId: entry.id,
          title: entry.title ?? entry.meta.title ?? '(无标题)',
          meta: entry.meta,
          archivedAtMs: entry.updatedAt,
          pdfLocal: pdfLocal,
          hasPreviousTextVersion: hasPrevious,
          body: body,
          previousBody: previousBody,
          textDownload: textRequest,
          pdfDownload: pdfRequest,
          blobBaseUrl: widget.blobBaseUrl,
        ),
      ),
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
  const _ArchiveTile({
    required this.entry,
    this.variant = 0,
    this.onWayback,
  });

  final ArchiveEntry entry;
  final int variant;
  final VoidCallback? onWayback;

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
    final wayback = planWaybackBadge(meta);
    final nextCheck = meta.nextCheckAt();
    final trailing = wayback.visible
        ? wayback.label
        : meta.isDeadLink
            ? '试 Wayback'
            : meta.changed
                ? '对比'
                : _nextCheckLabel(meta, nextCheck);

    return SketchCard(
      variant: variant,
      tilt: variant.isEven ? SketchTilt.left : SketchTilt.right,
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
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: trailing == '试 Wayback' ? onWayback : null,
                      child: Text(
                        trailing,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: trailing == '试 Wayback' ? p.blue : p.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// docs/11 §3.2「下次检查 12-01」：按 recheck_policy 与上次检查时刻算。
  static String _nextCheckLabel(ArchiveMeta meta, int? nextCheckAtMs) {
    if (meta.policy == RecheckPolicy.never) return '不自动重检查';
    if (meta.lastCheckedAt == null || nextCheckAtMs == null) {
      return '待首次检查';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(nextCheckAtMs);
    String two(int v) => v.toString().padLeft(2, '0');
    return '下次检查 ${two(date.month)}-${two(date.day)}';
  }
}
