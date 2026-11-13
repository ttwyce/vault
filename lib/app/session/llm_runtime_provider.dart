import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/agent/http_llm_client.dart';
import '../../data/agent/llm_chat_service.dart';
import '../../data/agent/llm_config_store.dart';
import '../../data/agent/openai_compat.dart';
import '../session/app_runtime.dart';

/// 测试可 override 成 InMemoryLlmConfigStore，避免平台通道。
final Provider<LlmConfigStore> llmConfigStoreProvider =
    Provider<LlmConfigStore>((Ref ref) => const SecureLlmConfigStore());

final Provider<LlmConfigService> llmConfigServiceProvider =
    Provider<LlmConfigService>((Ref ref) =>
        LlmConfigService(ref.watch(llmConfigStoreProvider)));

/// 从安全存储恢复运行期配置：Key 没保存 / 厂商 id 不认识都返回 null。
/// 这个函数不联网、不写日志；调用失败按「未配置」处理，不把异常内容带出去。
Future<LlmRuntime?> loadLlmRuntime({
  required LlmConfigService service,
  required bool enabled,
}) async {
  if (!enabled) return null;
  final LlmConfig? config;
  try {
    config = await service.load();
  } on Object {
    return null;
  }
  if (config == null || !config.isComplete) return null;
  final endpoint = resolveLlmEndpoint(
    config.endpointId,
    config.customEndpointRaw,
  );
  if (endpoint == null) return null;
  return LlmRuntime(
    endpoint: endpoint,
    apiKey: config.apiKey,
    client: HttpLlmClient(),
  );
}

/// 加载完成后一次性推进 AppRuntime；保存 / 清除 Key 时页面直接调用这里。
final FutureProvider<void> llmRuntimeBootstrapProvider =
    FutureProvider<void>((Ref ref) async {
  final runtime = await loadLlmRuntime(
    service: ref.watch(llmConfigServiceProvider),
    enabled: true,
  );
  if (runtime != null) {
    ref.read(appRuntimeProvider.notifier).setLlmRuntime(runtime);
  }
});
