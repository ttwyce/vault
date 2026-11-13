import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/search/model_source_store.dart';

final Provider<ModelSourceStore> modelSourceStoreProvider =
    Provider<ModelSourceStore>((Ref ref) => const SecureModelSourceStore());

final Provider<ModelSourceService> modelSourceServiceProvider =
    Provider<ModelSourceService>(
  (Ref ref) => ModelSourceService(ref.watch(modelSourceStoreProvider)),
);
