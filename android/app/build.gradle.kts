import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. The key.properties file holds storeFile, storePassword,
// keyAlias, and keyPassword. It's read from the path in BLOOM_KEY_PROPERTIES,
// or from android/key.properties. Neither is checked in.
val keyPropertiesEnv: String? = System.getenv("BLOOM_KEY_PROPERTIES")?.takeIf { it.isNotBlank() }
val keyPropertiesFile: File =
    keyPropertiesEnv?.let { file(it.replaceFirst(Regex("^~"), System.getProperty("user.home"))) }
        ?: rootProject.file("key.properties")
if (keyPropertiesEnv != null && !keyPropertiesFile.isFile) {
    throw GradleException("BLOOM_KEY_PROPERTIES points to $keyPropertiesFile, which doesn't exist.")
}
val keyProperties: Properties? =
    keyPropertiesFile.takeIf { it.isFile }?.let { f ->
        Properties().apply { f.inputStream().use { load(it) } }
    }

android {
    namespace = "dev.ifkash.bloom"
    // flutter_local_notifications 23 compiles against API 37.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "dev.ifkash.bloom"
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

    signingConfigs {
        if (keyProperties != null) {
            create("release") {
                // A relative storeFile resolves against the key.properties folder.
                val store = keyProperties.getProperty("storeFile")
                    ?: error("storeFile is missing from $keyPropertiesFile")
                storeFile = keyPropertiesFile.parentFile.resolve(store)
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                // minSdk is 24 or higher, so the APK signature schemes are enough.
                enableV1Signing = false
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyProperties != null) {
                signingConfigs.getByName("release")
            } else {
                val releaseTask = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
                if (releaseTask) {
                    logger.warn(
                        "WARNING: No release keystore found (set BLOOM_KEY_PROPERTIES or add " +
                            "android/key.properties). Signing the release build with the DEBUG key; " +
                            "don't distribute it.",
                    )
                }
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
