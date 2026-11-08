import 'dart:convert';
import 'dart:typed_data';

import 'argon2_params.dart';

/// `meta.enc` —— vault 级元数据。
///
/// ## 这个文件是明文的，这是刻意的
///
/// 它必须能在**解锁之前**被读到：没有它就不知道 KDF 盐和参数，
/// 也就无法从主密码算出 KEK。所以它不能整体加密。
///
/// 里面真正敏感的只有两段被包裹的 DEK（`wrappedDek` / `recoveryWrappedDek`），
/// 它们是 AEAD 密文，没有 KEK 解不开。其余字段（vaultId、创建时间、
/// 设备列表、条目数）泄露的信息量很低，但足够用来做变更检测与防误连。
///
/// ## 三个"看起来能省但不能省"的字段
///
/// | 字段 | 省掉的后果 |
/// |---|---|
/// | `vaultId` | 用户把两个 vault 指向同一个 WebDAV 目录时，会静默合并成灾难 |
/// | `kdf` 参数 + 盐 | 未来调参后，老 vault 永远解不开 |
/// | `schema` | 新版本写入的库被老版本 App 打开，静默丢字段 |
class VaultMeta {
  const VaultMeta({
    required this.vaultId,
    required this.createdAt,
    required this.kdfParams,
    required this.kdfSalt,
    required this.wrappedDek,
    this.recoveryWrappedDek,
    this.activeEmbeddingModel,
    this.embeddingDim,
    this.itemCount = 0,
    this.deviceIds = const <String>[],
  });

  /// 当前 App 能写出的格式版本。
  ///
  /// 规则：**读到比自己高的版本就拒绝**，读到更低则允许（并写回新版本）。
  /// 反过来会让老 App 把新字段悄悄丢掉。
  static const int currentSchema = 1;

  int get schema => currentSchema;

  final String vaultId;
  final int createdAt;

  final Argon2Params kdfParams;
  final KdfSalt kdfSalt;

  /// KEK 包裹的 DEK。
  final Uint8List wrappedDek;

  /// KEK'（由恢复码派生）包裹的同一把 DEK。
  ///
  /// 首次创建 vault 时必定存在。为空意味着"这个 vault 没有恢复码" ——
  /// 只可能出现在从旧版本迁移过来的库上，UI 必须显著警告。
  final Uint8List? recoveryWrappedDek;

  final String? activeEmbeddingModel;
  final int? embeddingDim;
  final int itemCount;
  final List<String> deviceIds;

  bool get hasRecoveryCode => recoveryWrappedDek != null;

  VaultMeta copyWith({
    Argon2Params? kdfParams,
    KdfSalt? kdfSalt,
    Uint8List? wrappedDek,
    Uint8List? recoveryWrappedDek,
    bool clearRecovery = false,
    String? activeEmbeddingModel,
    int? embeddingDim,
    int? itemCount,
    List<String>? deviceIds,
  }) {
    return VaultMeta(
      vaultId: vaultId,
      createdAt: createdAt,
      kdfParams: kdfParams ?? this.kdfParams,
      kdfSalt: kdfSalt ?? this.kdfSalt,
      wrappedDek: wrappedDek ?? this.wrappedDek,
      recoveryWrappedDek:
          clearRecovery ? null : (recoveryWrappedDek ?? this.recoveryWrappedDek),
      activeEmbeddingModel: activeEmbeddingModel ?? this.activeEmbeddingModel,
      embeddingDim: embeddingDim ?? this.embeddingDim,
      itemCount: itemCount ?? this.itemCount,
      deviceIds: deviceIds ?? this.deviceIds,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': schema,
        'vault_id': vaultId,
        'created_at': createdAt,
        'kdf': <String, Object?>{
          ...kdfParams.toJson(),
          'salt': kdfSalt.toBase64(),
        },
        'wrapped_dek': base64Encode(wrappedDek),
        if (recoveryWrappedDek != null)
          'recovery_wrapped_dek': base64Encode(recoveryWrappedDek!),
        if (activeEmbeddingModel != null) 'active_embedding_model': activeEmbeddingModel,
        if (embeddingDim != null) 'embedding_dim': embeddingDim,
        'item_count': itemCount,
        'device_ids': deviceIds,
      };

  /// 序列化。键顺序固定（不依赖 Map 迭代顺序），保证同一份 meta 每次写出的
  /// 字节完全一致 —— WebDAV 上 `meta.enc` 若每次都变，会导致无意义的
  /// If-Match 冲突。
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(
        Map<String, Object?>.fromEntries(
          toJson().entries.toList()
            ..sort((MapEntry<String, Object?> a, MapEntry<String, Object?> b) =>
                a.key.compareTo(b.key)),
        ),
      );

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(toJsonString()));

  factory VaultMeta.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('meta.enc 顶层不是对象');
    }
    return VaultMeta.fromJson(decoded);
  }

  factory VaultMeta.fromJson(Map<String, Object?> json) {
    final schema = _int(json, 'schema') ?? 1;
    if (schema > currentSchema) {
      throw FormatException(
        '这个 vault 由更新版本的 App 创建（格式 $schema，本机只支持到 $currentSchema）。'
        '请升级 App 后再打开 —— 用旧版本打开会丢掉新版本写入的字段。',
      );
    }

    final vaultId = json['vault_id'];
    if (vaultId is! String || vaultId.isEmpty) {
      throw const FormatException('meta.enc 缺少 vault_id');
    }

    final kdf = json['kdf'];
    if (kdf is! Map<String, Object?>) {
      throw const FormatException('meta.enc 缺少 kdf 配置');
    }
    final salt = kdf['salt'];
    if (salt is! String) {
      throw const FormatException('meta.enc 缺少 kdf.salt');
    }

    final wrapped = json['wrapped_dek'];
    if (wrapped is! String) {
      throw const FormatException('meta.enc 缺少 wrapped_dek');
    }
    final recoveryWrapped = json['recovery_wrapped_dek'];

    return VaultMeta(
      vaultId: vaultId,
      createdAt: _int(json, 'created_at') ?? 0,
      kdfParams: Argon2Params.fromJson(kdf),
      kdfSalt: KdfSalt.fromBase64(salt),
      wrappedDek: base64Decode(wrapped),
      recoveryWrappedDek: recoveryWrapped is String ? base64Decode(recoveryWrapped) : null,
      activeEmbeddingModel: json['active_embedding_model'] as String?,
      embeddingDim: _int(json, 'embedding_dim'),
      itemCount: _int(json, 'item_count') ?? 0,
      deviceIds: <String>[
        for (final id in (json['device_ids'] as List<Object?>? ?? const <Object?>[]))
          if (id is String) id,
      ],
    );
  }

  static int? _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  @override
  String toString() => 'VaultMeta($vaultId, schema $schema, '
      '${deviceIds.length} devices, $itemCount items)';
}
