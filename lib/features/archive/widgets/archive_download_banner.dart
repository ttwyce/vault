/// 按需下载 UI（docs/05 §7）。
///
/// 不发网络请求、不写库：把 [DownloadRequest] + 已完成字节渲染成
/// L1 正文骨架屏 / L2 PDF 进度条 / 完成态。真实下载由平台层驱动。
library;

import 'package:flutter/material.dart';

import '../../../app/theme/sketch_metrics.dart';
import '../../../app/theme/sketch_palette.dart';
import '../../../app/theme/sketch_theme.dart';
import '../../../core/widgets/sketch_frame.dart';
import '../../../data/archive/archive_cache_policy.dart';
import '../../../data/archive/archive_job_queue.dart' show downloadProgress;

class ArchiveDownloadBanner extends StatelessWidget {
  const ArchiveDownloadBanner({
    super.key,
    required this.request,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.completed = false,
  });

  final DownloadRequest request;
  final int receivedBytes;
  final int totalBytes;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    if (completed) {
      return Text(
        '已下载到本地缓存（local=1），云端副本保留',
        style: TextStyle(fontSize: 11, color: p.blue),
      );
    }
    if (request.showSkeleton) return _skeleton(p);
    final progress = downloadProgress(receivedBytes, totalBytes);
    return SketchFrame(
      radius: SketchRadii.b,
      fill: p.noteAlt,
      padding: const EdgeInsets.all(SketchSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            request.requiresUserTap ? '点「查看原貌」才下载 PDF' : request.hint,
            style: TextStyle(fontSize: 11, color: p.ink),
          ),
          const SizedBox(height: SketchSpace.xs),
          LinearProgressIndicator(value: totalBytes > 0 ? progress : null),
          const SizedBox(height: SketchSpace.xs),
          Text(
            totalBytes > 0
                ? '${(progress * 100).toStringAsFixed(0)}% · '
                    '${receivedBytes ~/ 1024}/${totalBytes ~/ 1024} KB'
                : '等待下载开始…',
            style: TextStyle(fontSize: 10, color: p.muted),
          ),
        ],
      ),
    );
  }

  Widget _skeleton(SketchPalette p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(request.hint, style: TextStyle(fontSize: 11, color: p.muted)),
          const SizedBox(height: SketchSpace.sm),
          for (final width in <double>[1, 0.85, 0.92, 0.6])
            Padding(
              padding: const EdgeInsets.only(bottom: SketchSpace.xs),
              child: FractionallySizedBox(
                widthFactor: width,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: p.lineSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      );
}
