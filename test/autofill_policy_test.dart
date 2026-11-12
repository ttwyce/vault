import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/autofill_policy.dart';

/// docs/08 §3.1 / §3.2 Autofill 判定测试。
void main() {
  test('hint / id 关键词优先识别 username / password / otp', () {
    expect(
      detectAutofillField(
        hint: 'Email', idEntry: 'login_email', inputType: 0),
      AutofillFieldType.username,
    );
    expect(
      detectAutofillField(
        hint: '密码', idEntry: 'pwd', inputType: 0),
      AutofillFieldType.password,
    );
    expect(
      detectAutofillField(
        hint: '请输入验证码', idEntry: 'code', inputType: 0),
      AutofillFieldType.otp,
    );
    expect(
      detectAutofillField(hint: '', idEntry: '', inputType: 0),
      AutofillFieldType.unknown,
    );
  });

  test('inputType 密码位兜底；otp 关键词优先于密码位', () {
    expect(
      detectAutofillField(hint: '', idEntry: '', inputType: 0x80),
      AutofillFieldType.password,
    );
    expect(
      detectAutofillField(hint: 'TOTP', idEntry: '', inputType: 0x80),
      AutofillFieldType.otp,
    );
  });

  test('域名规整：去协议/路径/www', () {
    expect(normalizeAutofillDomain('https://WWW.Example.com/login?x=1'),
        'example.com');
    expect(normalizeAutofillDomain('github.com'), 'github.com');
  });

  test('按域名 / 包名匹配候选；候选 JSON 绝不含密码', () {
    final candidates = <AutofillCandidate>[
      const AutofillCandidate(
        entryId: 'a',
        title: 'GitHub',
        username: 'user@example.com',
        domains: <String>['https://www.github.com/login'],
        androidPackage: 'com.github.android',
      ),
      const AutofillCandidate(
        entryId: 'b',
        title: '别的站',
        username: 'other',
        domains: <String>['other.com'],
      ),
    ];
    final byDomain = matchAutofillCandidates(
      candidates: candidates,
      webDomain: 'github.com/session',
    );
    expect(byDomain.map((AutofillCandidate c) => c.entryId), <String>['a']);

    final byPackage = matchAutofillCandidates(
      candidates: candidates,
      androidPackage: 'com.github.android',
    );
    expect(byPackage, hasLength(1));

    expect(
      matchAutofillCandidates(candidates: candidates, webDomain: 'nope.com'),
      isEmpty,
    );
    final json = byDomain.single.toJson();
    expect(json.containsKey('password'), isFalse);
    expect(json.containsKey('totp_secret'), isFalse);
  });
}
