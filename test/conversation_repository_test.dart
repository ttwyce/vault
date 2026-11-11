import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/chat/conversation_models.dart';
import 'package:vault/data/chat/conversation_repository.dart';
import 'package:vault/data/db/vault_database.dart';

import 'support/test_harness.dart';

/// 会话仓库把真实 conversation 表接进抽屉分组逻辑。
void main() {
  late TestApp app;
  late ConversationRepository repo;

  setUp(() async {
    app = await TestApp.create(now: () => 1731052800000);
    repo = ConversationRepository(app.db);
  });
  tearDown(() async => app.dispose());

  Future<void> insert(
    String id, {
    String? title,
    String? groupId,
    int updatedAt = 1731052800000,
    int deleted = 0,
  }) async {
    await app.db.into(app.db.conversations).insert(
          ConversationsCompanion.insert(
            id: id,
            hlc: '0000000000000001:0000:devA',
            title: Value<String?>(title),
            groupId: Value<String?>(groupId),
            createdAt: const Value<int?>(1731052800000),
            updatedAt: Value<int?>(updatedAt),
            deleted: Value<int>(deleted),
          ),
        );
  }

  test('空库返回空分组', () async {
    expect(await repo.list(), isEmpty);
    expect(await repo.groups(nowMs: 1731052800000), isEmpty);
  });

  test('真实行按今天/本周分组，已删除会话不出现', () async {
    await insert('c1', title: '今天会话');
    await insert('c2', title: '三天前', updatedAt: 1731052800000 - 3 * 86400000);
    await insert('c3', title: '删掉的', deleted: 1);
    await insert('g1', title: '项目会话', groupId: 'proj');

    final items = await repo.list();
    expect(items.map((ConversationSummary c) => c.id).toSet(),
        <String>{'c1', 'c2', 'g1'});

    final groups = await repo.groups(nowMs: 1731052800000);
    expect(groups.first.key, 'group:proj');
    expect(
      groups.skip(1).map((ConversationGroup g) => g.key).toList(),
      <String>['date:today', 'date:thisWeek'],
    );
  });
}
