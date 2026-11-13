import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/diary/diary_handbook.dart';
import 'package:vault/data/diary/diary_review.dart';
import 'package:vault/data/vault/credential_models.dart';
import 'package:vault/data/vault/passkey_record.dart';

/// PDF 手账与 Passkey 本地登记（docs/11 §1.5 / §4.7）。
void main() {
  DiaryYearReview review() => buildDiaryYearReview(
        year: 2026,
        entries: <DiaryReviewEntry>[
          const DiaryReviewEntry(
            date: '2026-01-01',
            words: 120,
            mood: '好',
            backfilled: false,
          ),
        ],
      );

  test('buildDiaryHandbookText 只含聚合统计，不含正文/密码', () {
    final text = buildDiaryHandbookText(review());
    expect(text, contains('2026 年度回顾'));
    expect(text, contains('01 月 · 1 篇'));
    expect(text, contains('好 · 1 次'));
    expect(text, isNot(contains('password')));
  });

  test('导出 PDF 手账需二次确认，确认后真实写盘', () async {
    final root = await Directory.systemTemp.createTemp('vault-handbook-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final denied = await exportDiaryHandbook(
      review: review(),
      root: root,
      confirmed: false,
    );
    expect(denied.ok, isFalse);
    expect(root.listSync(), isEmpty);

    final ok = await exportDiaryHandbook(
      review: review(),
      root: root,
      confirmed: true,
    );
    expect(ok.ok, isTrue);
    expect(ok.pageCount, greaterThan(0));
    expect(ok.bytes, greaterThan(0));
    final bytes = await File(ok.path!).readAsBytes();
    expect(bytes.length, ok.bytes);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
  });

  test('Passkey 以 secret 字段登记并可往返/移除', () {
    const record = PasskeyRecord(
      id: 'pk-1',
      relyingParty: 'example.com',
      credentialId: 'cred-1',
      publicKeyFingerprint: 'sha256:abcd',
      userHandle: 'user-1',
      createdAtMs: 1000,
    );
    final fields = upsertPasskey(
      const CustomFields(<CredentialField>[]),
      record,
    );
    expect(fields.fields.single.secret, isTrue);
    expect(fields.fields.single.id, startsWith(kPasskeyFieldPrefix));
    final loaded = passkeysIn(fields);
    expect(loaded, hasLength(1));
    expect(loaded.single.relyingParty, 'example.com');
    expect(loaded.single.credentialId, 'cred-1');
    expect(passkeysIn(removePasskey(fields, 'pk-1')), isEmpty);
  });

  test('坏 Passkey JSON 不进入列表', () {
    const fields = CustomFields(<CredentialField>[
      CredentialField(
        id: 'passkey:broken',
        label: 'Passkey',
        value: '{bad',
        type: CustomFieldType.text,
        secret: true,
        sort: 0,
      ),
    ]);
    expect(passkeysIn(fields), isEmpty);
  });
}
