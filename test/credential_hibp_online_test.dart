import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/vault/credential_repository.dart';
import 'package:vault/data/vault/hibp_client.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/data/vault/http_hibp_client.dart';

import 'support/test_harness.dart';

/// docs/11 §4.4：真实 HIBP 链路端到端（本地 HttpServer，跳过真机/外网）。
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  test('在线检查命中 → credential.breached=2；未命中 =1', () async {
    const password = 'Hunter2!long';
    final checker = HibpChecker();
    final request = checker.requestFor(password);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest req) async {
      req.response.write('${request.suffix}:42\r\n');
      await req.response.close();
    });
    final client = HttpHibpClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final repo = CredentialRepository(app.db, app.gateway);

    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-online',
      kind: EntryKind.credential,
      title: '在线检查账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-online'),
        );
    await repo.setPassword('cred-online', password);

    final breached = await repo.checkBreachedOnline(
      'cred-online',
      client: client,
      nowMs: 1731052800000,
    );
    expect(breached, isTrue);
    final row = await (app.db.select(app.db.credentials)
          ..where((t) => t.id.equals('cred-online')))
        .getSingle();
    expect(row.breached, 2);

    client.close();
    await server.close(force: true);
  });
}
