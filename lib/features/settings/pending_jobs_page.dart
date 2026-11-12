/// 待处理任务页（docs/10 第 20 屏）。
///
/// 读真实 `job_queue` 表；只展示状态、类型、尝试次数与到期时间，
/// 不启动后台任务。前台补偿执行器由平台层接。
library;

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
import '../../data/jobs/job_queue_repository.dart';

class PendingJobsPage extends ConsumerStatefulWidget {
  const PendingJobsPage({super.key});

  @override
  ConsumerState<PendingJobsPage> createState() => _PendingJobsPageState();
}

class _PendingJobsPageState extends ConsumerState<PendingJobsPage> {
  late Future<List<QueueJobView>> _jobs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _jobs = JobQueueRepository(
      ref.read(vaultDatabaseProvider),
    ).list();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '待处理',
        subtitle: '前台补偿任务队列（未接后台执行器）',
        showSettings: false,
        leading: SketchIconButton(
          glyph: SketchGlyph.close,
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        child: FutureBuilder<List<QueueJobView>>(
          future: _jobs,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<QueueJobView>> snap,
          ) {
            if (snap.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator(color: p.red));
            }
            final jobs = snap.data ?? const <QueueJobView>[];
            if (jobs.isEmpty) {
              return Center(
                child: Text(
                  '没有待处理任务',
                  style: TextStyle(fontSize: 12.5, color: p.muted),
                ),
              );
            }
            final grouped = <String, int>{};
            for (final job in jobs) {
              if (job.state != QueueJobState.done) {
                grouped[job.type] = (grouped[job.type] ?? 0) + 1;
              }
            }
            return ListView(
              padding: const EdgeInsets.all(SketchSpace.lg),
              children: <Widget>[
                Text(
                  grouped.entries
                      .map((MapEntry<String, int> e) => '${e.key} ${e.value}')
                      .join(' · '),
                  style: TextStyle(fontSize: 11, color: p.blue),
                ),
                const SizedBox(height: SketchSpace.md),
                for (final job in jobs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SketchSpace.sm),
                    child: SketchFrame(
                      radius: SketchRadii.c,
                      fill: p.surface,
                      borderColor: p.lineSoft,
                      padding: const EdgeInsets.all(SketchSpace.md),
                      child: Row(
                        children: <Widget>[
                          SketchTag(
                            job.state.label,
                            tone: job.state == QueueJobState.failed
                                ? SketchTone.primary
                                : SketchTone.plain,
                            dense: true,
                          ),
                          const SizedBox(width: SketchSpace.sm),
                          Expanded(
                            child: Text(
                              '${job.type} · 第 ${job.attempts} 次重试'
                              '${job.retryable ? '（可重试）' : ''}',
                              style: TextStyle(fontSize: 12, color: p.ink),
                            ),
                          ),
                          Text(
                            DateFormat('MM-dd HH:mm').format(
                              DateTime.fromMillisecondsSinceEpoch(
                                job.nextRunAt == 0
                                    ? job.createdAt
                                    : job.nextRunAt,
                              ),
                            ),
                            style: TextStyle(fontSize: 10, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
