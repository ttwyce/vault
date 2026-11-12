import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/jobs/job_queue_repository.dart';
import 'package:vault/data/db/vault_database.dart';

import 'support/test_harness.dart';

/// docs/10 第 20 屏 待处理任务队列测试。
void main() {
  late TestApp app;
  late JobQueueRepository repo;

  setUp(() async {
    app = await TestApp.create();
    repo = JobQueueRepository(app.db);
  });
  tearDown(() async => app.dispose());

  test('状态编码/标签与重试上限判定', () {
    expect(QueueJobState.pending.code, 0);
    expect(QueueJobState.failed.code, 3);
    expect(QueueJobStateWire.fromCode(2), QueueJobState.done);
    expect(QueueJobStateWire.fromCode(99), QueueJobState.failed);
    expect(QueueJobState.running.label, '进行中');
    expect(isJobRetryable(QueueJobState.failed, 2), isTrue);
    expect(isJobRetryable(QueueJobState.failed, kMaxJobAttempts), isFalse);
    expect(isJobRetryable(QueueJobState.pending, 0), isFalse);
  });

  test('到期判定与指数退避', () {
    expect(isJobDue(QueueJobState.pending, 100, 100), isTrue);
    expect(isJobDue(QueueJobState.pending, 101, 100), isFalse);
    expect(isJobDue(QueueJobState.running, 0, 100), isFalse);
    expect(isJobDue(QueueJobState.done, 0, 100), isFalse);
    expect(nextJobRunAt(0, 1000), 1000 + kJobRetryBaseMs);
    expect(nextJobRunAt(2, 1000), 1000 + 4 * kJobRetryBaseMs);
  });

  test('真实 job_queue 行读取、到期筛选、按类型聚合', () async {
    await app.gateway.enqueueArchiveJob(
      type: 'archive',
      nextRunAt: 100,
    );
    final later = await app.gateway.enqueueArchiveJob(
      type: 'deadlink',
      nextRunAt: 500,
    );
    // 手动标记失败且已达上限，验证 retryable=false。
    await (app.db.update(app.db.jobQueues)
          ..where((t) => t.id.equals(later)))
        .write(const JobQueuesCompanion(
      state: Value<int>(3),
      attempts: Value<int>(3),
    ));

    final jobs = await repo.list();
    expect(jobs, hasLength(2));
    expect(jobs.first.type, 'archive');
    expect(jobs.first.state, QueueJobState.pending);
    final failed = jobs.last;
    expect(failed.state, QueueJobState.failed);
    expect(failed.retryable, isFalse);

    final due = await repo.dueJobs(200);
    expect(due.map((QueueJobView j) => j.type), <String>['archive']);
    final counts = await repo.countByType();
    expect(counts['archive'], 1);
    expect(counts['deadlink'], 1);
  });
}
