import Flutter
import LocalAuthentication
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "vault/biometric"
  private let service = "com.shiyi.vault.biometric"
  private let account = "dek"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let controller = engineBridge.applicationWindow?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "isAvailable":
        var error: NSError?
        let context = LAContext()
        result(context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error))
      case "hasEnrollment":
        result(self.hasEnrollment())
      case "enroll":
        guard let args = call.arguments as? [String: Any],
              let base64 = args["dek"] as? String,
              let data = Data(base64Encoded: base64) else {
          result(false)
          return
        }
        result(self.storeDek(data))
      case "disable":
        self.deleteDek()
        result(true)
      case "authenticate":
        self.authenticate(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func baseQuery() -> [String: Any] {
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }

  /// Keychain 查询本身也可能触发系统认证，这里只查有没有条目，不取数据。
  private func hasEnrollment() -> Bool {
    var query = baseQuery()
    query[kSecReturnData as String] = kCFBooleanFalse as Any
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
  }

  private func storeDek(_ data: Data) -> Bool {
    deleteDek()
    guard let access = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      .biometryCurrentSet,
      nil
    ) else { return false }
    var query = baseQuery()
    query[kSecValueData as String] = data
    query[kSecAttrAccessControl as String] = access
    return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
  }

  private func deleteDek() {
    SecItemDelete(baseQuery() as CFDictionary)
  }

  /// 先用 LAContext 认证，认证成功后再读受访问控制保护的 Keychain 条目。
  private func authenticate(result: @escaping FlutterResult) {
    let context = LAContext()
    context.localizedFallbackTitle = "改用主密码"
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      result(nil)
      return
    }
    context.evaluatePolicy(
      .deviceOwnerAuthenticationWithBiometrics,
      localizedReason: "验证面容或指纹后解锁拾遗"
    ) { ok, _ in
      DispatchQueue.main.async {
        guard ok else {
          result(nil)
          return
        }
        var query = self.baseQuery()
        query[kSecReturnData as String] = kCFBooleanTrue as Any
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
          result(nil)
          return
        }
        result(data.base64EncodedString())
      }
    }
  }
}
