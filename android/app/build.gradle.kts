plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.shiyi.vault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.shiyi.vault"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 固定 debug 签名：AGP 默认会在每台机器 ~/.android/debug.keystore
    // 现生成一把新 key，CI 每次全新 runner 的 APK 签名都不一样。
    // 这里显式指向仓库内的测试 keystore（仅 debug/test，不是发布密钥），
    // 让本机与 CI 产物可互相覆盖安装、证书指纹可核对。
    signingConfigs {
        create("vaultDebug") {
            storeFile = file("vault-debug.keystore")
            storePassword = "android"
            keyAlias = "vault-debug"
            keyPassword = "android"
        }
        // flutter run / flutter build apk --debug 的默认 debug 配置也一起固定，
        // 避免 AGP 自带的 debug signingConfig 再落回机器本地 keystore。
        getByName("debug") {
            storeFile = file("vault-debug.keystore")
            storePassword = "android"
            keyAlias = "vault-debug"
            keyPassword = "android"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("vaultDebug")
        }
        release {
            signingConfig = signingConfigs.getByName("vaultDebug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
