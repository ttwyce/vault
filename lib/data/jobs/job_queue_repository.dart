/// 待处理任务队列（docs/10 第 20 屏 / `job_queue` 表）。
///
/// 只做本地可读视图与重试判定：不改任务执行器、不跑后台任务。
/// 前台补偿策略下，App 启动/回到前台时由平台层消费 [dueJobs]。
library;

import 'package:drift/drift.dart';

import '../db/vault_database.dart';

enum QueueJobState { pending, running, done, failed }

extension QueueJobStateWire on QueueJobState {
  int get code => switch (this) {
        QueueJobState.pending => 0,
        QueueJobState.running => 1,
        QueueJobState.done => 2,
        QueueJobState.failed => 3,
      };

  static QueueJobState fromCode(int code) => switch (code) {
        0 => QueueJobState.pending,
        1 => QueueJobState.running,
        2 => QueueJobState.done,
        3 => QueueJobState.failed,
        _ => QueueJobState.failed,
      };

  String get label => switch (this) {
        QueueJobState.pending => '待处理',
        QueueJobState.running => '进行中',
        QueueJobState.done => '已完成',
        QueueJobState.failed => '失败',
      };
}

class QueueJobView {
  const QueueJobView({
    required this.id,
    required this.type,
    required this.state,
    required this.attempts,
    required this.nextRunAt,
    required this.createdAt,
    required this.retryable,
  });

  final int id;
  final String type;
  final QueueJobState state;
  final int attempts;
  final int nextRunAt;
  final int createdAt;
  final bool retryable;
}

/// 失败重试上限与退避基数（前台补偿，不承诺后台）。
const int kMaxJobAttempts = 3;
const int kJobRetryBaseMs = 60000;

/// 失败任务是否还能重试。
bool isJobRetryable(QueueJobState state, int attempts) =>
    state == QueueJobState.failed && attempts < kMaxJobAttempts;

/// 到点到期的 pending/failed 任务；running 超时（默认 10 分钟）也回收。
bool isJobDue(
  QueueJobState state,
  int nextRunAt,
  int nowMs,
) =>
    switch (state) {
      QueueJobState.pending || QueueJobState.failed => nextRunAt <= nowMs,
      QueueJobState.running => false, // 重启回收由平台层按 createdAt 判定
      QueueJobState.done => false,
    };

/// 指数退避：1min → 2min → 4min。
int nextJobRunAt(int attempts, int nowMs) =>
    nowMs + kJobRetryBaseMs * (1 << (attempts.clamp(0, 4)));

class JobQueueRepository {
  const JobQueueRepository(this.db);

  final VaultDatabase db;

  Future<List<QueueJobView>> list() async {
    final rows = await (db.select(db.jobQueues)
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.asc(t.nextRunAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return <QueueJobView>[
      for (final row in rows)
        QueueJobView(
          id: row.id,
          type: row.type,
          state: QueueJobStateWire.fromCode(row.state),
          attempts: row.attempts,
          nextRunAt: row.nextRunAt,
          createdAt: row.createdAt,
          retryable: isJobRetryable(
            QueueJobStateWire.fromCode(row.state),
            row.attempts,
          ),
        ),
    ];
  }

  /// 前台补偿要跑的任务。
  Future<List<QueueJobView>> dueJobs(int nowMs) async => <QueueJobView>[
        for (final job in await list())
          if (isJobDue(job.state, job.nextRunAt, nowMs) &&
              (job.state != QueueJobState.failed || job.retryable))
            job,
      ];

  /// 按类型聚合，给「待处理」页做分组标题。
  Future<Map<String, int>> countByType() async {
    final out = <String, int>{};
    for (final job in await list()) {
      if (job.state == QueueJobState.done) continue;
      out[job.type] = (out[job.type] ?? 0) + 1;
    }
    return out;
  }
}
