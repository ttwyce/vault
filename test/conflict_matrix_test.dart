import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/sync/conflict_matrix.dart';

void main() {
  group('12 条冲突矩阵（docs/04 §5.1）', () {
    test('每条规则都落到唯一动作，未定义组合不猜', () {
      final cases =
          <({SyncSide local, SyncSide remote, ConflictAction action, int rule})>[
        // 1：远端有、本地无
        (
          local: SyncSide.absent,
          remote: SyncSide.created,
          action: ConflictAction.insertRemote,
          rule: 1,
        ),
        (
          local: SyncSide.absent,
          remote: SyncSide.unchanged,
          action: ConflictAction.insertRemote,
          rule: 1,
        ),
        (
          local: SyncSide.absent,
          remote: SyncSide.modified,
          action: ConflictAction.insertRemote,
          rule: 1,
        ),
        // 2：本地有、远端无
        (
          local: SyncSide.created,
          remote: SyncSide.absent,
          action: ConflictAction.keepLocal,
          rule: 2,
        ),
        (
          local: SyncSide.unchanged,
          remote: SyncSide.absent,
          action: ConflictAction.keepLocal,
          rule: 2,
        ),
        (
          local: SyncSide.modified,
          remote: SyncSide.absent,
          action: ConflictAction.keepLocal,
          rule: 2,
        ),
        // 3~5
        (
          local: SyncSide.modified,
          remote: SyncSide.unchanged,
          action: ConflictAction.pushLocal,
          rule: 3,
        ),
        (
          local: SyncSide.unchanged,
          remote: SyncSide.modified,
          action: ConflictAction.overwriteLocal,
          rule: 4,
        ),
        (
          local: SyncSide.modified,
          remote: SyncSide.modified,
          action: ConflictAction.merge3,
          rule: 5,
        ),
        // 6~7
        (
          local: SyncSide.deleted,
          remote: SyncSide.unchanged,
          action: ConflictAction.writeTombstone,
          rule: 6,
        ),
        (
          local: SyncSide.unchanged,
          remote: SyncSide.deleted,
          action: ConflictAction.softDeleteLocal,
          rule: 7,
        ),
        // 8~9：编辑胜
        (
          local: SyncSide.modified,
          remote: SyncSide.deleted,
          action: ConflictAction.resurrectLocalEdit,
          rule: 8,
        ),
        (
          local: SyncSide.created,
          remote: SyncSide.deleted,
          action: ConflictAction.resurrectLocalEdit,
          rule: 8,
        ),
        (
          local: SyncSide.deleted,
          remote: SyncSide.modified,
          action: ConflictAction.resurrectRemoteEdit,
          rule: 9,
        ),
        (
          local: SyncSide.deleted,
          remote: SyncSide.created,
          action: ConflictAction.resurrectRemoteEdit,
          rule: 9,
        ),
        // 10：幂等
        (
          local: SyncSide.deleted,
          remote: SyncSide.deleted,
          action: ConflictAction.noop,
          rule: 10,
        ),
        (
          local: SyncSide.absent,
          remote: SyncSide.absent,
          action: ConflictAction.noop,
          rule: 10,
        ),
        (
          local: SyncSide.unchanged,
          remote: SyncSide.unchanged,
          action: ConflictAction.noop,
          rule: 10,
        ),
        (
          local: SyncSide.deleted,
          remote: SyncSide.absent,
          action: ConflictAction.noop,
          rule: 10,
        ),
        // 11：同一 id 两边各自新建 / 文档未定义组合
        (
          local: SyncSide.created,
          remote: SyncSide.created,
          action: ConflictAction.quarantine,
          rule: 11,
        ),
        (
          local: SyncSide.created,
          remote: SyncSide.unchanged,
          action: ConflictAction.quarantine,
          rule: 11,
        ),
        // 12：坏数据优先级最高，绝不覆盖本地
        (
          local: SyncSide.corrupt,
          remote: SyncSide.modified,
          action: ConflictAction.quarantine,
          rule: 12,
        ),
        (
          local: SyncSide.unchanged,
          remote: SyncSide.corrupt,
          action: ConflictAction.quarantine,
          rule: 12,
        ),
        (
          local: SyncSide.corrupt,
          remote: SyncSide.deleted,
          action: ConflictAction.quarantine,
          rule: 12,
        ),
      ];

      for (final row in cases) {
        final decision = resolveConflict(
          local: row.local,
          remote: row.remote,
        );
        expect(
          decision.action,
          row.action,
          reason: '${row.local.name} / ${row.remote.name}',
        );
        expect(
          decision.rule,
          row.rule,
          reason: '${row.local.name} / ${row.remote.name}',
        );
        expect(decision.reason, isNotEmpty);
      }
    });

    test('T11：解密失败或 hash 不匹配隔离，本地数据不变', () {
      final decision = resolveConflict(
        local: SyncSide.modified,
        remote: SyncSide.corrupt,
      );
      expect(decision.action, ConflictAction.quarantine);
      expect(decision.rule, 12);
      expect(decision.reason, contains('不覆盖本地'));
    });
  });

  group('墓碑与删除顺序（docs/04 §6 / T06~T08）', () {
    test('删除必须先写墓碑，再 DELETE 条目文件', () {
      expect(
        DeletePlan.standard.steps,
        <DeleteStep>[
          DeleteStep.writeTombstone,
          DeleteStep.deleteItemFile,
        ],
      );
    });

    test('T07：本地有未推编辑时忽略远端墓碑，编辑胜', () {
      final decision = resolveConflict(
        local: SyncSide.modified,
        remote: SyncSide.deleted,
      );
      expect(decision.action, ConflictAction.resurrectLocalEdit);
      expect(decision.rule, 8);

      expect(
        decideTombstone(
          localDeleted: false,
          localRev: 6,
          baseRev: 5,
        ),
        TombstoneAction.ignoreKeepLocal,
      );
      expect(
        decideTombstone(
          localDeleted: false,
          localRev: 5,
          baseRev: 5,
        ),
        TombstoneAction.apply,
      );
      expect(
        decideTombstone(
          localDeleted: true,
          localRev: 9,
          baseRev: 5,
        ),
        TombstoneAction.alreadyDeleted,
      );
    });

    test('T06：删除期间远端确有内容变化且 rev 更大才复活', () {
      final decision = resolveConflict(
        local: SyncSide.deleted,
        remote: SyncSide.modified,
      );
      expect(decision.action, ConflictAction.resurrectRemoteEdit);
      expect(decision.rule, 9);

      expect(
        shouldResurrectAfterDelete(
          localDeleted: true,
          localRev: 5,
          remoteRev: 6,
          remoteDiffersFromBase: true,
        ),
        isTrue,
      );
      expect(
        shouldResurrectAfterDelete(
          localDeleted: false,
          localRev: 5,
          remoteRev: 6,
          remoteDiffersFromBase: true,
        ),
        isFalse,
        reason: '本地没删就谈不上复活',
      );
      expect(
        shouldResurrectAfterDelete(
          localDeleted: true,
          localRev: 6,
          remoteRev: 6,
          remoteDiffersFromBase: true,
        ),
        isFalse,
        reason: 'rev 没更大不能复活',
      );
      expect(
        shouldResurrectAfterDelete(
          localDeleted: true,
          localRev: 5,
          remoteRev: 6,
          remoteDiffersFromBase: false,
        ),
        isFalse,
        reason: '只是同步了一次、内容没变也不能复活',
      );
    });

    test('T08：双方删除幂等清理，不重复写墓碑', () {
      final decision = resolveConflict(
        local: SyncSide.deleted,
        remote: SyncSide.deleted,
      );
      expect(decision.action, ConflictAction.noop);
      expect(decision.rule, 10);
      expect(
        decideTombstone(
          localDeleted: true,
          localRev: 8,
          baseRev: 5,
        ),
        TombstoneAction.alreadyDeleted,
      );
    });

    test('墓碑 90 天 / 回收站 30 天，边界当天不过期', () {
      expect(kTombstoneTtl, const Duration(days: 90));
      expect(kTrashRetention, const Duration(days: 30));

      const deletedAt = 1700000000000;
      final tombstoneBoundary =
          deletedAt + kTombstoneTtl.inMilliseconds;
      final trashBoundary = deletedAt + kTrashRetention.inMilliseconds;

      expect(isTombstoneExpired(deletedAt, tombstoneBoundary), isFalse);
      expect(isTombstoneExpired(deletedAt, tombstoneBoundary + 1), isTrue);
      expect(isTrashExpired(deletedAt, trashBoundary), isFalse);
      expect(isTrashExpired(deletedAt, trashBoundary + 1), isTrue);
    });

    test('冲突副本标题包含来源设备与时间', () {
      expect(
        conflictCopyTitle('周报', '设备B', '2026-11-08 13:25'),
        '周报 (冲突副本 设备B 2026-11-08 13:25)',
      );
    });
  });
}
