package com.shiyi.vault

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/// 生物识别解锁：平台 BiometricPrompt + Android Keystore（不引入 androidx 依赖）。
/// DEK 用需要用户认证的 AES/GCM 密钥加密后存 SharedPreferences；
/// 认证成功才在进程内解出 DEK 返回 Dart，绝不把明文写磁盘。
class MainActivity : FlutterActivity() {
    private val channelName = "vault/biometric"
    private val keyAlias = "vault_biometric_dek_key"
    private val prefsName = "vault_biometric"
    private val ivKey = "iv"
    private val ciphertextKey = "ciphertext"
    private var pendingShareText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureShareIntent(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kShareChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "consumeInitial") {
                    val text = pendingShareText
                    pendingShareText = null
                    result.success(text)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(available())
                    "hasEnrollment" -> result.success(prefs().contains(ciphertextKey))
                    "enroll" -> {
                        val dek = call.argument<String>("dek")
                        if (dek == null || !available()) {
                            result.success(false)
                        } else {
                            result.success(runCatching { encryptAndStore(dek) }.isSuccess)
                        }
                    }
                    "disable" -> {
                        prefs().edit().clear().apply()
                        result.success(true)
                    }
                    "authenticate" -> authenticate(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun captureShareIntent(source: Intent?) {
        if (source == null || source.action != Intent.ACTION_SEND) return
        if (source.type != "text/plain") return
        pendingShareText = source.getStringExtra(Intent.EXTRA_TEXT)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        captureShareIntent(intent)
    }

    private fun available(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val manager = getSystemService(BiometricManager::class.java)
        return manager != null &&
            manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
                BiometricManager.BIOMETRIC_SUCCESS
    }

    private fun prefs(): SharedPreferences =
        getSharedPreferences(prefsName, Context.MODE_PRIVATE)

    private fun secretKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (store.containsAlias(keyAlias)) {
            return store.getKey(keyAlias, null) as SecretKey
        }
        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore",
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(true)
                .setInvalidatedByBiometricEnrollment(true)
                .build(),
        )
        return generator.generateKey()
    }

    private fun encryptAndStore(dekBase64: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val bytes = cipher.doFinal(Base64.decode(dekBase64, Base64.DEFAULT))
        prefs().edit()
            .putString(ivKey, Base64.encodeToString(cipher.iv, Base64.DEFAULT))
            .putString(ciphertextKey, Base64.encodeToString(bytes, Base64.DEFAULT))
            .apply()
    }

    private fun authenticate(result: MethodChannel.Result) {
        if (!available() || !prefs().contains(ciphertextKey)) {
            result.success(null)
            return
        }
        runCatching {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            val iv = Base64.decode(prefs().getString(ivKey, "")!!, Base64.DEFAULT)
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, iv))
            val prompt = BiometricPrompt.Builder(this)
                .setTitle("解锁拾遗")
                .setSubtitle("验证指纹后读取本地密钥")
                .setNegativeButton("改用主密码", mainExecutor) { _, _ -> result.success(null) }
                .build()
            val ciphertext = Base64.decode(
                prefs().getString(ciphertextKey, "")!!,
                Base64.DEFAULT,
            )
            prompt.authenticate(
                BiometricPrompt.CryptoObject(cipher),
                CancellationSignal(),
                Executors.newSingleThreadExecutor(),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        authResult: BiometricPrompt.AuthenticationResult,
                    ) {
                        val crypto = authResult.cryptoObject?.cipher ?: run {
                            result.success(null)
                            return
                        }
                        val dek = crypto.doFinal(ciphertext)
                        result.success(Base64.encodeToString(dek, Base64.DEFAULT))
                    }

                    override fun onAuthenticationFailed() {
                        // 手指没放好：prompt 保持打开，不结束本次认证。
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence?) {
                        result.success(null)
                    }
                },
            )
        }.onFailure { result.success(null) }
    }
}


    companion object {
        private const val kShareChannelName = "vault/share"
    }
