import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/biometric_session_policy.dart';
import 'package:vault/features/unlock/unlock_page.dart';
import 'package:vault/app/session/biometric_unlock.dart';
import 'package:vault/app/session/unlock_policy.dart';
import 'package:vault/core/crypto/argon2_params.dart';
import 'package:vault/core/crypto/vault_meta.dart';
import 'package:vault/data/agent/context_compressor.dart';
import 'package:vault/data/agent/http_model_catalog.dart';
import 'package:vault/data/agent/llm_config_store.dart';
import 'package:vault/data/agent/openai_compat.dart';

/// 本轮补齐能力的回归：多端点、模型列表、上下文压缩、生物识别。
void main() {
  test('LlmConfigService 保存多个端点并可移除活动档案', () async {
    final store = InMemoryLlmConfigStore();
    final service = LlmConfigService(store);
    await service.saveProfile(
      profile: LlmProfile(
        id: 'deepseek',
        label: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-chat',
      ),
      apiKey: 'k1',
    );
    await service.saveProfile(
      profile: LlmProfile(
        id: kCustomLlmEndpointId,
        label: '自建',
        baseUrl: 'https://llm.example.com/v1',
        model: 'local-chat',
      ),
      apiKey: 'k2',
    );
    final loaded = await service.load();
    expect(loaded!.profiles, hasLength(2));
    expect(loaded.endpointId, kCustomLlmEndpointId);
    expect(loaded.active!.baseUrl, 'https://llm.example.com/v1');
    await service.removeProfile(kCustomLlmEndpointId);
    final after = await service.load();
    expect(after!.profiles, hasLength(1));
    expect(after.endpointId, 'deepseek');
  });

  test('HttpModelCatalog 从 /models 返回去重排序的模型列表', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((HttpRequest request) async {
      expect(request.uri.path, '/v1/models');
      expect(request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer sk-test');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{'id': 'b-model'},
          <String, Object?>{'id': 'a-model'},
          <String, Object?>{'id': 'b-model'},
          <String, Object?>{'id': 123},
        ],
      }));
      await request.response.close();
    });
    final catalog = HttpModelCatalog();
    addTearDown(catalog.close);
    final result = await catalog.listModels(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      apiKey: 'sk-test',
    );
    expect(result.ok, isTrue);
    expect(result.models, <String>['a-model', 'b-model']);
  });

  test('packLlmContext 超预算时压缩较早历史，保留 system 与当前问题', () {
    final history = <LlmMessage>[
      for (var i = 0; i < 30; i++)
        LlmMessage(role: 'user', content: '历史消息 $i ${'很长的正文' * 40}'),
    ];
    final plan = packLlmContext(
      systemPrompt: '系统提示词',
      history: history,
      currentQuestion: '现在的问题',
      maxTokens: 1200,
    );
    expect(plan.compressed, isTrue);
    expect(plan.packedTokens, lessThanOrEqualTo(plan.budgetTokens));
    expect(plan.messages.first.role, 'system');
    expect(plan.messages.first.content, '系统提示词');
    expect(plan.messages.last.role, 'user');
    expect(plan.messages.last.content, '现在的问题');
    expect(plan.messages.any((LlmMessage m) => m.content.contains('历史摘要')),
        isTrue);
  });

  test('BiometricVaultUnlock 认证成功才解出 DEK，失败不产密钥', () async {
    final dek = Uint8List.fromList(
        List<int>.generate(32, (int i) => i));
    final fake = _FakeBiometric(dekBase64: base64.encode(dek));
    final unlock = BiometricVaultUnlock(authenticator: fake);
    final meta = _meta();

    fake.authenticated = false;
    final denied = await unlock.unlock(meta);
    expect(denied.ok, isFalse);
    expect(denied.unlocked, isNull);

    fake.authenticated = true;
    final ok = await unlock.unlock(meta);
    expect(ok.ok, isTrue);
    expect(ok.unlocked!.keys.fingerprint.isNotEmpty, isTrue);
    ok.unlocked!.dispose();
  });

  test('未注册指纹时解锁页按钮仍可点击，走主密码启用路径', () {
    expect(biometricActionLabel(BiometricGate.notEnrolled),
        '输主密码解锁并启用指纹');
    expect(
      biometricActionEnabled(gate: BiometricGate.notEnrolled, busy: false),
      isTrue,
    );
    expect(biometricActionEnabled(gate: BiometricGate.available, busy: false),
        isTrue);
    expect(
        biometricActionEnabled(
            gate: BiometricGate.unavailable, busy: false),
        isFalse);
    expect(biometricActionEnabled(gate: BiometricGate.available, busy: true),
        isFalse);
  });

  test('生物识别失败 5 次后强制主密码', () {
    var policy = const UnlockPolicyState();
    for (var i = 0; i < kMaxBiometricFailures; i++) {
      policy = recordUnlockFailure(
        policy,
        method: UnlockMethod.biometric,
        nowMs: 1000 + i,
      );
    }
    final decision = decideBiometricGate(
      platformAvailable: true,
      enrolled: true,
      policy: policy,
      nowMs: 9000,
    );
    expect(decision.gate, BiometricGate.forcePassphrase);
  });
}

VaultMeta _meta() => VaultMeta(
      vaultId: 'v1',
      createdAt: 0,
      kdfParams: Argon2Params.insecureForTests,
      kdfSalt: KdfSalt(Uint8List(16)),
      wrappedDek: Uint8List(73),
    );

class _FakeBiometric implements BiometricAuthenticator {
  _FakeBiometric({required this.dekBase64});

  String dekBase64;
  bool authenticated = false;
  bool enrolled = true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> hasEnrollment() async => enrolled;

  @override
  Future<bool> enroll(String value) async {
    dekBase64 = value;
    enrolled = true;
    return true;
  }

  @override
  Future<String?> authenticate() async => authenticated ? dekBase64 : null;

  @override
  Future<void> disable() async => enrolled = false;
}
