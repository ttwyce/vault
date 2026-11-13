import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/archive/archive_highlight_writer.dart';
import '../../data/archive/archive_meta.dart';
import '../../data/archive/archive_cache_policy.dart';
import '../../data/archive/http_blob_downloader.dart';
import '../../data/archive/archive_reader.dart';
import '../../data/sync/version_diff.dart';
import 'widgets/archive_download_banner.dart';

/// 归档阅读器（docs/05 §9）。
///
/// 用 `resolveReaderModes` 决定哪些模式可点：纯净（L1 正文）/ 原貌（L2 PDF）/
/// 对比（新旧正文）。PDF 渲染与并排 diff 属于平台层，这里只给出明确的
/// 「需要先下载 / 没有快照 / 无上一版」提示，绝不假装能显示。
class ArchiveReaderPage extends ConsumerStatefulWidget {
  const ArchiveReaderPage({
    super.key,
    required this.title,
    required this.meta,
    required this.archivedAtMs,
    required this.pdfLocal,
    required this.hasPreviousTextVersion,
    this.body,
    this.previousBody,
    this.textDownload,
    this.pdfDownload,
    this.blobBaseUrl,
    this.entryId,
  });

  final String title;
  final ArchiveMeta meta;
  final int archivedAtMs;
  final bool pdfLocal;
  final bool hasPreviousTextVersion;
  final String? body;

  /// 新旧对比用的上一版 L1 正文；由上层从历史版本解密提供。
  /// 为 null 时对比模式明确说明缺上一版，不假装能 diff。
  final String? previousBody;
  final DownloadRequest? textDownload;
  final DownloadRequest? pdfDownload;

  /// blob 云端根地址；为空时只展示计划、不提供下载按钮。
  final String? blobBaseUrl;

  /// 有 entryId 才能把高亮写回 meta；旧调用不传时按钮禁用。
  final String? entryId;

  @override
  ConsumerState<ArchiveReaderPage> createState() => _ArchiveReaderPageState();
}

class _ArchiveReaderPageState extends ConsumerState<ArchiveReaderPage> {
  ReaderMode _mode = ReaderMode.clean;
  final TextEditingController _selection = TextEditingController();
  String? _askHint;
  final Map<String, _DownloadState> _downloads = <String, _DownloadState>{};

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  static String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final availability = resolveReaderModes(
      meta: widget.meta,
      pdfLocal: widget.pdfLocal,
      hasPreviousTextVersion: widget.hasPreviousTextVersion,
    );
    if (!availability.can(_mode)) {
      _mode = fallbackReaderMode(availability);
    }
    final status = readerStatusLine(
      meta: widget.meta,
      archivedAtMs: widget.archivedAtMs,
      formatDate: _formatDate,
    );

    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '归档阅读',
      subtitle: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: SketchSpace.sm,
            children: <Widget>[
              for (final mode in ReaderMode.values)
                GestureDetector(
                  onTap: availability.can(mode)
                      ? () => setState(() => _mode = mode)
                      : null,
                  child: SketchTag(
                    _label(mode),
                    tone: _mode == mode ? SketchTone.primary : SketchTone.plain,
                  ),
                ),
            ],
          ),
          const SizedBox(height: SketchSpace.md),
          Expanded(
            child: SketchCard(
              variant: 1,
              fill: p.surface,
              tilt: SketchTilt.none,
              child: SingleChildScrollView(
                child: _bodyFor(p, availability),
              ),
            ),
          ),
          const SizedBox(height: SketchSpace.sm),
          TextField(
            controller: _selection,
            decoration: const InputDecoration(
              hintText: '粘贴一段正文，问 AI…',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SketchSpace.xs),
          Row(
            children: <Widget>[
              SketchButton(
                label: '问 AI',
                dense: true,
                onPressed: () {
                  final ok = canAskAiAboutSelection(_selection.text);
                  setState(() => _askHint = ok
                      ? '选区长度合规，可进入 L1 逐次授权流程'
                      : '选区太短/太长，不能问 AI');
                },
              ),
              const SizedBox(width: SketchSpace.sm),
              SketchButton(
                label: '标注高亮',
                dense: true,
                onPressed: widget.entryId == null
                    ? null
                    : () async {
                        final text = _selection.text.trim();
                        if (text.isEmpty) {
                          setState(() => _askHint = '请先粘贴要标注的正文');
                          return;
                        }
                        final changed = await ArchiveHighlightWriter(
                          db: ref.read(vaultDatabaseProvider),
                          gateway: ref.read(writeGatewayProvider),
                        ).addHighlight(
                          widget.entryId!,
                          ArchiveHighlight(
                            text: text,
                            offset: widget.meta.excerpt.length,
                          ),
                        );
                        if (mounted) {
                          setState(() => _askHint = changed
                              ? '高亮已写回 meta（新版本已入 oplog）'
                              : '高亮无变化');
                        }
                      },
              ),
              const SizedBox(width: SketchSpace.sm),
              Expanded(
                child: Text(
                  _askHint ??
                      '高亮合并 ${mergeHighlights(widget.meta.highlights).length} 段',
                  style: TextStyle(fontSize: 10.5, color: p.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: SketchSpace.sm),
          Text(status, style: TextStyle(fontSize: 10.5, color: p.muted)),
          for (final reason in availability.reasons)
            Text(reason,
                style: TextStyle(fontSize: 10.5, color: p.blue)),
        ],
      ),
    ),
    );
  }

  Widget _bodyFor(SketchPalette p, ReaderAvailability availability) {
    switch (_mode) {
      case ReaderMode.clean:
        final body = widget.body;
        if (body == null || body.trim().isEmpty) {
          final request = widget.textDownload;
          if (request != null) {
            return _downloadBanner(request);
          }
          return Text(
            widget.meta.hasText
                ? 'L1 正文层尚未按需下载。'
                : '这条归档目前只有元数据，还没有正文层。',
            style: TextStyle(fontSize: 13, color: p.muted),
          );
        }
        return Text(body,
            style: TextStyle(fontSize: 14.5, height: 1.9, color: p.ink));
      case ReaderMode.original:
        final pdfRequest = widget.pdfDownload;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '原貌模式需要 L2 PDF 快照。当前标记为'
              '${widget.pdfLocal ? '已本地缓存' : '仅云端'}，'
              'PDF 渲染由平台层提供。',
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
            if (pdfRequest != null) ...<Widget>[
              const SizedBox(height: SketchSpace.sm),
              _downloadBanner(pdfRequest),
            ],
          ],
        );
      case ReaderMode.compare:
        final before = widget.previousBody;
        final after = widget.body;
        if (before == null || after == null) {
          return Text(
            '对比模式需要新旧两版 L1 正文。当前只有'
            '${after == null ? '零版' : '当前版'}，'
            '已检测到内容变更：${widget.meta.changed ? '是' : '否'}。'
            '旧版需由历史版本解密后传入。',
            style: TextStyle(fontSize: 13, color: p.muted),
          );
        }
        return _buildVersionDiff(before, after, p);
    }
  }

  /// 用真实行级 diff 渲染 +/- 行（docs/05 §9 对比模式）。
  /// 超过行数上限时 buildVersionDiff 会降级成统计视图，不跑 O(n·m) DP。
  Widget _buildVersionDiff(
    String before,
    String after,
    SketchPalette p,
  ) {
    final view = buildVersionDiff(before, after);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '新旧正文差异：${view.summary}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: p.blue,
          ),
        ),
        const SizedBox(height: SketchSpace.sm),
        if (view.degraded)
          Text(
            '版本过大，只显示统计；逐行对比请到历史版本页。',
            style: TextStyle(fontSize: 12, color: p.muted),
          )
        else ...<Widget>[
          // 外层是 SingleChildScrollView（高度无界），这里不能用 Expanded /
          // ListView；只展示前 200 行，超出明确提示，避免撑爆布局。
          for (final line in view.lines.take(200))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                '${line.marker} ${line.text}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: switch (line.kind) {
                    DiffLineKind.added => p.green,
                    DiffLineKind.removed => p.red,
                    DiffLineKind.context => p.muted,
                  },
                ),
              ),
            ),
          if (view.lines.length > 200)
            Text(
              '还有 ${view.lines.length - 200} 行未显示，完整对比请到历史版本页。',
              style: TextStyle(fontSize: 11, color: p.muted),
            ),
        ],
      ],
    );
  }

  Widget _downloadBanner(DownloadRequest request) {
    final state = _downloads[request.blobHash];
    final base = widget.blobBaseUrl;
    return ArchiveDownloadBanner(
      request: request,
      receivedBytes: state?.received ?? 0,
      totalBytes: state?.total ?? 0,
      completed: state?.done ?? false,
      downloading: state?.running ?? false,
      onDownload: base == null || base.isEmpty
          ? null
          : () => _startDownload(request, base),
    );
  }

  Future<void> _startDownload(DownloadRequest request, String base) async {
    if (_downloads[request.blobHash]?.running == true) return;
    final normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final url = Uri.parse('$normalized/blobs/${request.blobHash}');
    setState(() {
      _downloads[request.blobHash] = const _DownloadState(running: true);
    });
    final downloader = HttpBlobDownloader(
      gateway: ref.read(writeGatewayProvider),
    );
    final result = await downloader.download(
      entryId: request.entryId,
      blobHash: request.blobHash,
      url: url,
      expectedBytes: 0,
      onProgress: (double progress) {
        if (!mounted) return;
        setState(() {
          _downloads[request.blobHash] = _DownloadState(
            running: true,
            done: false,
            received: (progress * 1024).round(),
            total: 1024,
          );
        });
      },
    );
    downloader.close();
    if (!mounted) return;
    setState(() {
      _downloads[request.blobHash] = _DownloadState(
        running: false,
        done: result.ok,
        received: result.bytes,
        total: result.bytes,
      );
    });
  }

  String _label(ReaderMode mode) => switch (mode) {
        ReaderMode.clean => '纯净',
        ReaderMode.original => '原貌',
        ReaderMode.compare => '对比',
      };
}

class _DownloadState {
  const _DownloadState({
    this.running = false,
    this.done = false,
    this.received = 0,
    this.total = 0,
  });

  final bool running;
  final bool done;
  final int received;
  final int total;
}
