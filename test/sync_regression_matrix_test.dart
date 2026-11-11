import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/audit/sync_regression_matrix.dart';

/// docs/04 §9 / docs/09 §12 同步回归 26 用例清单测试。
void main() {
  test('清单恰好 26 条，编号 T01~T26 且连续唯一', () {
    final report = auditSyncRegression();
    expect(report.total, 26);
    final ids = report.cases.map((SyncRegressionCase c) => c.id).toList();
    expect(ids.toSet(), hasLength(26));
    expect(
      ids,
      List<String>.generate(
        26,
        (int i) => 'T${(i + 1).toString().padLeft(2, '0')}',
      ),
    );
  });

  test('本地已验证与需真实服务器明确分开，门禁不通过', () {
    final report = auditSyncRegression();
    expect(report.localVerified, greaterThan(0));
    expect(report.pendingRealServer, greaterThan(0));
    expect(report.localVerified + report.pendingRealServer, 26);
    expect(report.allPassed, isFalse,
        reason: '三套服务器环境未跑，不能宣称 26 用例全绿');
    expect(report.pendingIds(), contains('T01'));
    expect(report.pendingIds(), contains('T20'));
    expect(report.pendingIds(), isNot(contains('T25')));
  });

  test('T11/T12/T13/T14/T18/T21~T26 的纯语义已本地覆盖', () {
    final local = auditSyncRegression()
        .cases
        .where((SyncRegressionCase c) =>
            c.status == RegressionStatus.localVerified)
        .map((SyncRegressionCase c) => c.id)
        .toSet();
    expect(local, containsAll(<String>[
      'T11', 'T12', 'T13', 'T14', 'T18',
      'T21', 'T22', 'T23', 'T24', 'T25', 'T26',
    ]));
  });

  test('注入全本地验证的自定义清单时门禁才通过', () {
    const onlyLocal = <SyncRegressionCase>[
      SyncRegressionCase(
        id: 'X1',
        scenario: '纯逻辑',
        expectation: '通过',
        status: RegressionStatus.localVerified,
      ),
    ];
    final report = auditSyncRegression(cases: onlyLocal);
    expect(report.allPassed, isTrue);
    expect(report.pendingIds(), isEmpty);
  });
}
