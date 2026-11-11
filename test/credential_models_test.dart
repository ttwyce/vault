import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/credential_models.dart';

/// docs/11 §4.4 / docs/09 §8 密码纯判定层测试。
const int _now = 1731052800000;

void main() {
  group('自定义字段（docs/11 §4.3）', () {
    test('JSON 往返保真，secret 标记不丢失', () {
      const fields = CustomFields(<CredentialField>[
        CredentialField(
          id: 'f1',
          label: '恢复码',
          value: 'xxxx-xxxx',
          type: CustomFieldType.text,
          secret: true,
          sort: 0,
        ),
        CredentialField(
          id: 'f2',
          label: '服务器',
          value: 'sftp.example.com',
          type: CustomFieldType.url,
          secret: false,
          sort: 1,
        ),
      ]);
      final decoded = CustomFields.fromJsonString(fields.toJsonString());
      expect(decoded.fields, hasLength(2));
      expect(decoded.fields.first.secret, isTrue);
      expect(decoded.fields.last.type, CustomFieldType.url);
      expect(decoded.redactedLabels(), <String>['恢复码', '服务器']);
    });

    test('超过 20 个 / id 重复 / 非法 type 一律拒绝', () {
      List<CredentialField> many(int n) => List<CredentialField>.generate(
            n,
            (int i) => CredentialField(
              id: 'f$i',
              label: '字段$i',
              value: 'v',
              type: CustomFieldType.text,
              secret: false,
              sort: i,
            ),
          );
      expect(
        () => CustomFields.fromJsonString(
          CustomFields(many(21)).toJsonString(),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CustomFields.fromJsonString(jsonEncode(<Object?>[
              many(1).first.toJson(),
              many(1).first.toJson(),
            ])),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CustomFields.fromJsonString(jsonEncode(<Object?>[
              <String, Object?>{
                'id': 'x',
                'label': 'x',
                'value': 'v',
                'type': 'wat',
              },
            ])),
        throwsA(isA<FormatException>()),
      );
    });

    test('空字符串按空列表处理，不抛错', () {
      expect(CustomFields.fromJsonString(null).fields, isEmpty);
      expect(CustomFields.fromJsonString('  ').fields, isEmpty);
    });
  });

  group('密码强度（docs/09 §8）', () {
    test('长度与字符种类递增；常见弱模式直接 0', () {
      expect(estimatePasswordStrength(''), 0);
      expect(estimatePasswordStrength('abc'), 0);
      expect(estimatePasswordStrength('12345678'), lessThanOrEqualTo(2));
      expect(estimatePasswordStrength('Abcdefgh1234!'), greaterThanOrEqualTo(3));
      expect(estimatePasswordStrength('aaaaaaaaaaaa'), 0);
      expect(estimatePasswordStrength('password123'), 0);
      expect(estimatePasswordStrength('Qwerty!2026#Long'), 4);
    });
  });

  group('健康报告（只返回统计）', () {
    test('重复 / 弱 / 泄露 / 超 180 天 / 收藏统计', () {
      final report = computeCredentialHealth(
        nowMs: _now,
        samples: <CredentialHealthSample>[
          const CredentialHealthSample(
            strength: 0,
            passwordFingerprint: 'same',
            leaked: true,
            favorite: true,
            passwordUpdatedAt: _now - 1000,
          ),
          const CredentialHealthSample(
            strength: 4,
            passwordFingerprint: 'same',
            leaked: false,
            favorite: false,
            passwordUpdatedAt: _now - 1000,
          ),
          const CredentialHealthSample(
            strength: 4,
            passwordFingerprint: 'other',
            leaked: false,
            favorite: false,
            passwordUpdatedAt: null,
          ),
        ],
      );
      expect(report.total, 3);
      expect(report.weak, 1);
      expect(report.reused, 2);
      expect(report.leaked, 1);
      expect(report.outdated, 1,
          reason: 'passwordUpdatedAt 为 null 视为超期');
      expect(report.favorite, 1);
      // 报告里没有任何指纹 / 明文。
      expect(jsonEncode(report.toJson()), isNot(contains('same')));
      expect(jsonEncode(report.toJson()), isNot(contains('other')));
    });

    test('空库报告全 0', () {
      final report = computeCredentialHealth(
        nowMs: _now,
        samples: const <CredentialHealthSample>[],
      );
      expect(report.toJson(), <String, int>{
        'total': 0,
        'weak': 0,
        'reused': 0,
        'leaked': 0,
        'outdated': 0,
        'favorite': 0,
      });
    });
  });

  group('HIBP k-anonymity', () {
    test('只取 SHA1 前 5 位，后缀在本地比对', () {
      final sha = 'a' * 5 + 'B' * 35;
      expect(hibpPrefix(sha), 'AAAAA');
      expect(hibpHit(sha, <String>{'B' * 35}), isTrue);
      expect(hibpHit(sha, <String>{'C' * 35}), isFalse);
      expect(() => hibpPrefix('short'), throwsA(isA<FormatException>()));
    });
  });

  group('CredentialGuard（docs/11 §4.4 代码级拦截）', () {
    test('敏感字段与自定义字段值整体脱敏', () {
      final redacted = CredentialGuard.redact(<String, Object?>{
        'id': 'cred-1',
        'password': 'hunter2',
        'totp_secret': 'JBSWY3DPEHPK3PXP',
        'custom_fields': 'xxxx-xxxx',
        'url': 'https://example.com',
        'meta': <String, Object?>{
          'secret_pin': '8842',
          'label': '服务器',
        },
      });
      expect(redacted['id'], 'cred-1');
      expect(redacted['password'], '[已隐藏]');
      expect(redacted['totp_secret'], '[已隐藏]');
      expect(redacted['custom_fields'], '[已隐藏]');
      expect(redacted['url'], 'https://example.com');
      expect(
        (redacted['meta'] as Map)['secret_pin'],
        '[已隐藏]',
      );
      expect(jsonEncode(redacted), isNot(contains('hunter2')));
      expect(jsonEncode(redacted), isNot(contains('8842')));
    });

    test('prompt 扫描命中任一明文即拒绝；备注默认不许进云端', () {
      expect(
        CredentialGuard.containsSecret(
          '请总结这条笔记，密码是 hunter2',
          <String>['hunter2', '8842'],
        ),
        isTrue,
      );
      expect(
        CredentialGuard.containsSecret('普通笔记正文', <String>['hunter2']),
        isFalse,
      );
      expect(CredentialGuard.allowNotesInCloud(explicitlyAuthorized: false),
          isFalse);
      expect(CredentialGuard.allowNotesInCloud(explicitlyAuthorized: true),
          isTrue);
    });
  });
}
