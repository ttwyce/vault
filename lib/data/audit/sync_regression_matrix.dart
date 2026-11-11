/// M9 同步回归 26 用例清单（docs/04 §9 / docs/09 §12）。
///
/// 不跑真实服务器：只把「用例 → 期望 → 当前验证状态」写成可复现报告。
/// 本地单测覆盖 ≠ 三套服务器环境全绿；凡是 requireRealServer 的用例，
/// 报告一律标未通过，避免把纯逻辑测试冒充同步验收。
library;

/// 验证状态。
enum RegressionStatus { localVerified, requiresRealServer }

class SyncRegressionCase {
  const SyncRegressionCase({
    required this.id,
    required this.scenario,
    required this.expectation,
    required this.status,
  });

  final String id;
  final String scenario;
  final String expectation;
  final RegressionStatus status;

  bool get isRealServer => status == RegressionStatus.requiresRealServer;
}

/// 26 条 = 原 20 条 + T21~T26。只有不依赖真实 WebDAV/真机的少数
/// 纯合并语义被本地单测覆盖；其余明确留给三套服务器环境与真机。
const List<SyncRegressionCase> kSyncRegressionCases = <SyncRegressionCase>[
  SyncRegressionCase(
    id: 'T01',
    scenario: '单设备首次上传 5000 条',
    expectation: '全部成功、无重复、可中断续传',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T02',
    scenario: '空设备首次下载 5000 条',
    expectation: '全部成功、FTS 索引完整',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T03',
    scenario: 'A、B 各自新建不同条目',
    expectation: '双向可见、无冲突',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T04',
    scenario: 'A、B 同时编辑同一笔记的不同段落',
    expectation: '自动合并、两处修改都在',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T05',
    scenario: 'A、B 同时编辑同一笔记的同一段落',
    expectation: '生成冲突副本、两份内容都在',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T06',
    scenario: 'A 删除、B 编辑（编辑晚于删除）',
    expectation: '条目复活，内容为 B 版本',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T07',
    scenario: 'A 编辑、B 删除（删除晚于编辑）',
    expectation: '条目复活，内容为 A 版本',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T08',
    scenario: 'A、B 同时删除同一条',
    expectation: '只生效一次、墓碑唯一、无残留',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T09',
    scenario: '同步中途断网',
    expectation: '恢复后继续、无重复无丢失',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T10',
    scenario: '连续 3 次 412',
    expectation: '第 4 次生成冲突副本、不丢失任一方',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T11',
    scenario: '云端文件被外部工具篡改',
    expectation: '解密失败→隔离→本地数据不变',
    status: RegressionStatus.localVerified,
  ),
  SyncRegressionCase(
    id: 'T12',
    scenario: '误连另一个 vault 目录',
    expectation: '拒绝同步、本地数据不变',
    status: RegressionStatus.localVerified,
  ),
  SyncRegressionCase(
    id: 'T13',
    scenario: '设备 B 系统时间快 1 小时',
    expectation: 'HLC 排序正确、LWW 符合预期',
    status: RegressionStatus.localVerified,
  ),
  SyncRegressionCase(
    id: 'T14',
    scenario: '坚果云限流（模拟 429）',
    expectation: '退避后成功、无数据损坏',
    status: RegressionStatus.localVerified,
  ),
  SyncRegressionCase(
    id: 'T15',
    scenario: '同步中强杀 App',
    expectation: '重启后状态一致、无半写状态',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T16',
    scenario: '大 blob（20MB）按需下载',
    expectation: '不阻塞列表、带进度',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T17',
    scenario: '冲突副本后续再同步',
    expectation: '副本作为普通条目正常同步、不再冲突',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T18',
    scenario: '云端 schema 高于本地',
    expectation: '拒绝同步并提示升级',
    status: RegressionStatus.localVerified,
  ),
  SyncRegressionCase(
    id: 'T19',
    scenario: '5000 条下常规同步（无变化）',
    expectation: '≤ 3 请求、≤ 800ms',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T20',
    scenario: '同一条目在 3 台设备上并发编辑',
    expectation: '最终一致、无丢失',
    status: RegressionStatus.requiresRealServer,
  ),
  SyncRegressionCase(
    id: 'T21',
    scenario: '两设备各建同名标签',
    expectation: '自动合并为一个、关联不丢',
    status: RegressionStatus.localVerified,
  ),
  SyncRegressionCase(
    id: 'T22',
    scenario: '两设备给同一笔记设不同分类',
    expectation: '保留 HLC 较大者、不产生两条',
    status: RegressionStatus.localVerified,
  ),
  SyncRegressionCase(
    id: 'T23',
    scenario: '删除分类后同步',
    expectation: '条目全部进未分类、条目数不变',
    status: RegressionStatus.localVerified,
  ),
  SyncRegressionCase(
    id: 'T24',
    scenario: '账号 secret 字段跨设备同步',
    expectation: '解密正确、AI 侧仍不可见',
    status: RegressionStatus.localVerified,
  ),
  SyncRegressionCase(
    id: 'T25',
    scenario: '会话消息并发追加',
    expectation: 'append-only 不冲突、顺序正确',
    status: RegressionStatus.localVerified,
  ),
  SyncRegressionCase(
    id: 'T26',
    scenario: '草稿态会话未发消息就切走',
    expectation: '不产生空记录',
    status: RegressionStatus.localVerified,
  ),
];

class SyncRegressionReport {
  const SyncRegressionReport(this.cases);

  final List<SyncRegressionCase> cases;

  int get total => cases.length;

  int get localVerified => cases
      .where((SyncRegressionCase c) =>
          c.status == RegressionStatus.localVerified)
      .length;

  int get pendingRealServer => cases
      .where((SyncRegressionCase c) => c.isRealServer)
      .length;

  /// 26 个用例全绿才算通过；这里永远 false，直到真实环境注入结果。
  bool get allPassed => pendingRealServer == 0;

  List<String> pendingIds() => <String>[
        for (final c in cases)
          if (c.isRealServer) c.id,
      ];
}

SyncRegressionReport auditSyncRegression({
  Iterable<SyncRegressionCase> cases = kSyncRegressionCases,
}) =>
    SyncRegressionReport(List<SyncRegressionCase>.unmodifiable(cases));
