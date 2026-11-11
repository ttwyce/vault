import 'dart:math';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/argon2_params.dart';
import '../../core/crypto/recovery_code.dart';
import '../../core/crypto/vault_lock.dart';
import '../../core/crypto/vault_meta.dart';
import '../../core/identity/uuid_v7.dart';
import '../../core/sync/hlc.dart';
import '../../data/activity/activity_logger.dart';
import '../../data/db/database_key.dart';
import '../../data/db/database_opener.dart';
import '../../data/db/vault_database.dart';
import '../../data/vault/credential_repository.dart';
import '../../data/write/write_gateway.dart';
import 'vault_storage.dart';

/// vault 的生命周期状态。
///
/// 五个状态互斥且顺序明确，UI 只需要 `switch` 一次就能决定渲染什么 ——
/// 不需要在页面里堆一堆 `if (loading) ... else if (error) ...`。
enum VaultStatus {
  /// 本机还没有 vault，走首次创建流程。
  needsSetup,

  /// 有 vault 但未解锁。
  locked,

  /// 正在派生密钥 / 打开数据库。**这个状态会持续 2 秒以上**（见 R19）。
  unlocking,

  /// 已解锁，数据库与写入口可用。
  unlocked,

  /// 致命错误（`meta.enc` 损坏、数据库打不开）。
  ///
  /// 与普通错误分开：普通错误（密码错）可以重试，
  /// 这个状态意味着"重试也没用"，UI 必须给出别的出路。
  failed,
}

/// 会话状态。这是 App 的根状态。
class VaultSessionState {
  const VaultSessionState({
    required this.status,
    this.meta,
    this.unlocked,
    this.database,
    this.opener,
    this.gateway,
    this.activity,
    this.recoveryCode,
    this.deviceId,
    this.error,
    this.derivingSince,
  });

  final VaultStatus status;

  /// 有 vault 时非空（含 `locked` 状态）。
  final VaultMeta? meta;

  /// 解锁后才有：密钥与子密钥。
  final UnlockedVault? unlocked;

  final VaultDatabase? database;
  final VaultDatabaseOpener? opener;
  final WriteGateway? gateway;
  final ActivityLogger? activity;

  /// **仅在刚创建 vault 时非空**。
  ///
  /// 这是 24 个词唯一一次出现在内存里的时机。UI 必须在这时候引导抄写，
  /// 之后无法再取回（系统只存被包裹的 DEK，不存词）。
  final RecoveryCode? recoveryCode;

  final String? deviceId;

  /// 用户可见的错误文案。**不区分"密码错"与"文件坏"**（AEAD 的性质）。
  final String? error;

  /// 开始派生的时刻。UI 用它显示已用秒数 ——
  /// Argon2id 没有进度回调，**不要伪造百分比**，见 [VaultSessionState.elapsed]。
  final DateTime? derivingSince;

  bool get isBusy => status == VaultStatus.unlocking;
  bool get isUnlocked => status == VaultStatus.unlocked;
  bool get hasVault => meta != null;
  bool get hasRecoveryCode => meta?.hasRecoveryCode ?? false;

  /// 已用时间。null 表示不在派生中。
  Duration? get elapsed {
    final since = derivingSince;
    if (since == null) return null;
    return DateTime.now().difference(since);
  }

  VaultSessionState copyWith({
    VaultStatus? status,
    VaultMeta? meta,
    UnlockedVault? unlocked,
    VaultDatabase? database,
    VaultDatabaseOpener? opener,
    WriteGateway? gateway,
    ActivityLogger? activity,
    RecoveryCode? recoveryCode,
    String? deviceId,
    String? error,
    DateTime? derivingSince,
    bool clearError = false,
    bool clearRecoveryCode = false,
    bool clearDeriving = false,
    bool clearHandles = false,
  }) {
    return VaultSessionState(
      status: status ?? this.status,
      meta: meta ?? this.meta,
      // 解锁态的四件套要么全有要么全无。用 `?? this.x` 的话永远清不掉 ——
      // 一旦将来出现"换 vault""会话失效"这类需要回到锁定态且**保留 meta**
      // 的路径，就会留下一个指向已关闭数据库的 gateway。
      unlocked: clearHandles ? null : (unlocked ?? this.unlocked),
      database: clearHandles ? null : (database ?? this.database),
      opener: clearHandles ? null : (opener ?? this.opener),
      gateway: clearHandles ? null : (gateway ?? this.gateway),
      activity: clearHandles ? null : (activity ?? this.activity),
      recoveryCode: clearRecoveryCode ? null : (recoveryCode ?? this.recoveryCode),
      deviceId: deviceId ?? this.deviceId,
      error: clearError ? null : (error ?? this.error),
      derivingSince: clearDeriving ? null : (derivingSince ?? this.derivingSince),
    );
  }
}

/// `main()` 阶段就准备好的东西。
///
/// 为什么把"读 meta"提到 `runApp` 之前：这样首帧就能确定该显示解锁页
/// 还是创建页，不会先闪一下 loading 再跳。
class VaultBootstrap {
  const VaultBootstrap({
    required this.storage,
    required this.deviceId,
    required this.meta,
    this.params = Argon2Params.recommended,
    this.bootError,
  });

  final VaultStorage storage;
  final String deviceId;
  final VaultMeta? meta;

  /// 生产用 [Argon2Params.recommended]；测试注入低代价参数。
  final Argon2Params params;

  /// `meta.enc` 读取失败时的原因。非空意味着 [meta] 不可信。
  final String? bootError;

  bool get hasVault => meta != null;
}

final Provider<VaultBootstrap> vaultBootstrapProvider = Provider<VaultBootstrap>(
  (Ref ref) => throw UnimplementedError(
    'vaultBootstrapProvider 需要在 main() 中 override，见 docs/18',
  ),
);

final NotifierProvider<VaultSession, VaultSessionState> vaultSessionProvider =
    NotifierProvider<VaultSession, VaultSessionState>(VaultSession.new);

/// vault 会话控制器。
///
/// 只做三件事：**创建、解锁、锁定**。所有密码学细节都在 `VaultLock` 里，
/// 所有文件布局在 `VaultStorage` 里 —— 这一层只负责"把两者接起来 + 管状态"。
class VaultSession extends Notifier<VaultSessionState> {
  VaultBootstrap? _boot;

  @override
  VaultSessionState build() {
    final boot = ref.watch(vaultBootstrapProvider);
    _boot = boot;

    if (boot.bootError != null) {
      return VaultSessionState(
        status: VaultStatus.failed,
        deviceId: boot.deviceId,
        error: boot.bootError,
      );
    }

    return VaultSessionState(
      status: boot.hasVault ? VaultStatus.locked : VaultStatus.needsSetup,
      meta: boot.meta,
      deviceId: boot.deviceId,
    );
  }

  VaultStorage get _storage => _boot!.storage;

  Argon2Params get _params => _boot!.params;

  String get _deviceId => _boot!.deviceId;

  // ---------------------------------------------------------------------------
  // 创建
  // ---------------------------------------------------------------------------

  /// 首次创建 vault。
  ///
  /// 成功后 [VaultSessionState.recoveryCode] 有值，**UI 必须立刻展示并让用户确认抄写**。
  Future<void> createVault(String passphrase) async {
    if (state.isBusy) return;

    // 已有 vault 时**绝不能**走创建流程。
    //
    // 这条不是洁癖：`createVault` 会生成一把全新的 DEK 并写进 meta.enc，
    // 而 meta.enc 是解锁的唯一入口 —— 覆盖之后，旧 DEK 的包裹结果消失，
    // 老数据永久打不开，而且整个过程没有任何报错。
    //
    // 正常情况下闸门不会把用户送到这里（有 vault 时显示解锁页），
    // 但"闸门判断错"和"将来重构"都可能让这个调用发生。宁可多一行判断。
    if (state.hasVault) {
      state = state.copyWith(
        status: VaultStatus.locked,
        error: '本机已经有 vault，不能重复创建。请用主密码解锁。',
      );
      return;
    }

    state = state.copyWith(
      status: VaultStatus.unlocking,
      clearError: true,
      derivingSince: DateTime.now(),
    );

    UnlockedVault? unlocked;
    var metaWritten = false;
    try {
      unlocked = await VaultLock.create(passphrase: passphrase, params: _params);
      // 纵深防御：文件存在与否是事实，状态判断可能被绕过
      if (!await _storage.writeMetaIfAbsent(unlocked.meta)) {
        throw const VaultMetaException('本机已有 vault，拒绝覆盖 meta.enc。');
      }
      metaWritten = true;
      await _activate(unlocked);
    } on Object catch (error) {
      // 创建失败：把已经算出来的密钥清掉，不要留在内存里
      unlocked?.dispose();

      if (metaWritten) {
        // meta.enc 已经落盘 —— 本机现在**确实有**一个 vault 了。
        // 这时候再报 `needsSetup` 会引导用户重新创建，等于把刚写好的
        // meta 覆盖掉。正确状态是 `locked`：让用户用刚设的密码再试一次
        // （失败可能是磁盘满、临时 IO 错误这类可重试的原因）。
        state = state.copyWith(
          status: VaultStatus.locked,
          meta: unlocked?.meta,
          error: '库已创建但打不开：${describeFailure(error)}',
          clearDeriving: true,
        );
      } else {
        state = state.copyWith(
          status: VaultStatus.needsSetup,
          error: describeFailure(error),
          clearDeriving: true,
        );
      }
    }
  }

  /// 用户确认已抄写恢复码之后调用，清掉内存里的明文词。
  void acknowledgeRecoveryCode() {
    state = state.copyWith(clearRecoveryCode: true);
  }

  // ---------------------------------------------------------------------------
  // 解锁
  // ---------------------------------------------------------------------------

  Future<void> unlock(String passphrase) async {
    final meta = state.meta;
    if (meta == null) {
      // 没有 meta 就不可能解锁。推进 `needsSetup` 而不是 `failed`：
      // 这种情况（例如刚被 `lock()` 清过、或将来支持切换 vault）应该
      // 让用户走创建流程，而不是把他钉在一个没有出路的错误页上。
      state = state.copyWith(
        status: VaultStatus.needsSetup,
        error: '本机没有 vault 元数据，请先创建。',
        clearDeriving: true,
      );
      return;
    }
    if (state.isBusy) return;

    state = state.copyWith(
      status: VaultStatus.unlocking,
      clearError: true,
      derivingSince: DateTime.now(),
    );

    UnlockedVault? unlocked;
    try {
      unlocked = await VaultLock.unlock(meta: meta, passphrase: passphrase);
      await _activate(unlocked);
    } on VaultUnlockException catch (error) {
      unlocked?.dispose();
      state = state.copyWith(
        status: VaultStatus.locked,
        error: error.message,
        clearDeriving: true,
      );
    } on Object catch (error) {
      unlocked?.dispose();
      state = state.copyWith(
        status: VaultStatus.locked,
        error: describeFailure(error),
        clearDeriving: true,
      );
    }
  }

  /// 用 24 词恢复码解锁。
  ///
  /// 走 HKDF 而不是 Argon2id，所以**几乎是瞬时的** ——
  /// 这正是灾难恢复时最需要的（见 docs/16 §5.3）。
  Future<void> unlockWithRecoveryCode(String input) async {
    final meta = state.meta;
    if (meta == null) {
      // 静默 return 会让用户点了按钮什么都不发生 —— 必须给一句话。
      state = state.copyWith(
        status: VaultStatus.needsSetup,
        error: '本机没有 vault 元数据，请先创建。',
        clearDeriving: true,
      );
      return;
    }
    if (state.isBusy) return;

    state = state.copyWith(
      status: VaultStatus.unlocking,
      clearError: true,
      derivingSince: DateTime.now(),
    );

    UnlockedVault? unlocked;
    try {
      unlocked = await VaultLock.unlockWithRecoveryCode(meta: meta, input: input);
      await _activate(unlocked);
    } on VaultUnlockException catch (error) {
      unlocked?.dispose();
      state = state.copyWith(
        status: VaultStatus.locked,
        error: error.message,
        clearDeriving: true,
      );
    } on Object catch (error) {
      unlocked?.dispose();
      state = state.copyWith(
        status: VaultStatus.locked,
        error: describeFailure(error),
        clearDeriving: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 锁定
  // ---------------------------------------------------------------------------

  /// 锁屏 / 主动锁定。关闭数据库并清掉内存里的密钥。
  Future<void> lock() async {
    final opener = state.opener;
    final unlocked = state.unlocked;

    // 先关库再清密钥：反过来的话，drift 在关闭时可能还有挂起的写事务，
    // 而密钥已经被清零，会抛一个很难查的错。
    if (opener != null) {
      await opener.close();
    }
    unlocked?.dispose();

    // 用 copyWith 而不是重新构造整个 state：将来加了新字段（比如生物识别
    // 的会话票据），重新构造的写法会静默把它丢掉。
    state = state.copyWith(
      status: VaultStatus.locked,
      clearHandles: true,
      clearRecoveryCode: true,
      clearError: true,
      clearDeriving: true,
    );
  }

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  /// 解锁成功后：打开数据库 → 恢复 HLC → 装配写入口与埋点。
  Future<void> _activate(UnlockedVault unlocked) async {
    final directory = await _storage.ensureDirectory();

    // 本地库密钥从 DEK 派生，与内容密钥分离（见 docs/16 §2.1）
    final localKey = await unlocked.keys.localDatabase();
    final opener = VaultDatabaseOpener(
      key: DatabaseKey(localKey.bytes),
      storageDir: directory,
    );

    VaultDatabase? database;
    try {
      database = await opener.open();
    } on Object {
      await opener.close();
      rethrow;
    }

    final clock = HlcClock(node: _deviceId, now: _nowMillis);
    await _restoreClock(database, clock, _deviceId);

    final gateway = WriteGateway(
      db: database,
      keys: unlocked.keys,
      clock: clock,
      deviceId: _deviceId,
      uuid: UuidV7(),
    );
    // 搜索埋点的敏感值集合在解锁时一次性取好；后续新增密码由下次
    // 解锁重新装配覆盖。这样写入热路径不需要每条都解密全表。
    final knownSecrets = await CredentialRepository(database, gateway)
        .knownSecretValues();
    final activity = ActivityLogger(
      db: database,
      deviceId: _deviceId,
      knownSecrets: knownSecrets,
    );

    state = VaultSessionState(
      status: VaultStatus.unlocked,
      meta: unlocked.meta,
      unlocked: unlocked,
      database: database,
      opener: opener,
      gateway: gateway,
      activity: activity,
      recoveryCode: unlocked.recoveryCode,
      deviceId: _deviceId,
    );
  }

  /// 从 `device_watermark` 读回 HLC。
  ///
  /// **不做这一步的后果很具体**：App 重启后时钟从零开始，可能生成比历史
  /// 更小的值，同步合并时被判定为旧版本，旧数据覆盖新数据。
  Future<void> _restoreClock(
    VaultDatabase db,
    HlcClock clock,
    String deviceId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT max_hlc FROM device_watermark WHERE device_id = ? LIMIT 1;',
          variables: <Variable<Object>>[Variable<String>(deviceId)],
        )
        .get();
    if (rows.isEmpty) return;

    final encoded = rows.first.readNullable<String>('max_hlc');
    if (encoded == null) return;
    clock.restore(Hlc.tryParse(encoded));
  }

  static int _nowMillis() => DateTime.now().millisecondsSinceEpoch;
}

/// 当前是否有可用写入口。没有就说明还没解锁。
///
/// **调用方注意**：riverpod 会把这里抛出的错误包一层 `ProviderException`
/// 再抛出，所以 `catch (e)` 拿到的不是原始 `StateError`，要看 `e.toString()`
/// 或判断 `e is ProviderException`。正常路径下（闸门保证只有解锁后才渲染
/// 主界面）不该触发，它存在是为了在**写错调用时机时立刻炸**，
/// 而不是给出一个指向已关闭数据库的失效 gateway。
final Provider<WriteGateway> writeGatewayProvider = Provider<WriteGateway>((Ref ref) {
  final gateway = ref.watch(vaultSessionProvider).gateway;
  if (gateway == null) {
    throw StateError('vault 未解锁，WriteGateway 不可用（这是调用时机错误，不是用户操作错误）');
  }
  return gateway;
});

/// 当前是否有可用埋点器。错误包装行为同 [writeGatewayProvider]。
final Provider<ActivityLogger> activityLoggerProvider = Provider<ActivityLogger>((Ref ref) {
  final logger = ref.watch(vaultSessionProvider).activity;
  if (logger == null) {
    throw StateError('vault 未解锁，ActivityLogger 不可用');
  }
  return logger;
});

/// 当前数据库。错误包装行为同 [writeGatewayProvider]。
final Provider<VaultDatabase> vaultDatabaseProvider = Provider<VaultDatabase>((Ref ref) {
  final db = ref.watch(vaultSessionProvider).database;
  if (db == null) {
    throw StateError('vault 未解锁，数据库不可用');
  }
  return db;
});

/// 便于测试注入确定性随机（生产用 `Random.secure()`）。
final Provider<Random?> sessionRandomProvider =
    Provider<Random?>((Ref ref) => null);
