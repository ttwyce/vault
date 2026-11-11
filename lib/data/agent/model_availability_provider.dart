import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model_status.dart';

/// 可覆盖：M7 平台层读取端侧模型/Key 后 overrideWithValue。
/// 默认两端都未就绪 —— 这是诚实状态，不假装「端侧模型 · 就绪」。
final Provider<ModelAvailability> modelAvailabilityProvider =
    Provider<ModelAvailability>((Ref ref) => const ModelAvailability(
          onDeviceModelReady: false,
          hasCloudKey: false,
        ));
