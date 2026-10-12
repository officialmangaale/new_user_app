import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps API key for the live-tracking map.
//
// Never committed. Read, in order, from:
//   1. android/local.properties  ->  MAPS_API_KEY=...   (developer machines;
//      already git-ignored by android/.gitignore)
//   2. the MAPS_API_KEY environment variable              (CI builds)
//
// With neither set the placeholder resolves to an empty string. The map is
// also gated in Dart by --dart-define=GOOGLE_MAPS_ENABLED=true, so a build
// without a key never instantiates the map widget and cannot crash on it.
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val mapsApiKey: String =
    localProperties.getProperty("MAPS_API_KEY")
        ?: System.getenv("MAPS_API_KEY")
        ?: ""

// Release signing (FD-05).
//
// Never committed. The release keystore and its passwords are read, in order,
// from:
//   1. android/key.properties (git-ignored; copy key.properties.example)
//        storeFile=...  storePassword=...  keyAlias=...  keyPassword=...
//   2. environment variables for CI:
//        ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD,
//        ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
//
// Debug builds are always debug-signed. A RELEASE build without a real
// keystore FAILS instead of quietly shipping a debug-signed app. A local
// release smoke test can opt out with ALLOW_DEBUG_SIGNED_RELEASE=true in
// key.properties or the environment; such a build must never be distributed.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(propertyKey: String, envKey: String): String =
    (keystoreProperties.getProperty(propertyKey) ?: System.getenv(envKey) ?: "").trim()

fun String.isRealSigningValue(): Boolean =
    isNotEmpty() &&
        !startsWith("YOUR_", ignoreCase = true) &&
        !contains("path/to/your", ignoreCase = true) &&
        !contains("path\\to\\your", ignoreCase = true)

val releaseStorePath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStoreFile = releaseStorePath
    .takeIf { it.isRealSigningValue() }
    ?.let { rootProject.file(it).takeIf { f -> f.isFile } ?: file(it).takeIf { f -> f.isFile } }
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val hasReleaseSigningConfig =
    releaseStoreFile != null &&
        releaseStorePassword.isRealSigningValue() &&
        releaseKeyAlias.isRealSigningValue() &&
        releaseKeyPassword.isRealSigningValue()
val allowDebugSignedRelease =
    (keystoreProperties.getProperty("ALLOW_DEBUG_SIGNED_RELEASE")
        ?: System.getenv("ALLOW_DEBUG_SIGNED_RELEASE")
        ?: "").trim().equals("true", ignoreCase = true)

gradle.taskGraph.whenReady {
    val releaseBuildRequested = allTasks.any {
        it.project == project &&
            (it.name.startsWith("assembleRelease") ||
                it.name.startsWith("bundleRelease") ||
                it.name.startsWith("packageRelease"))
    }
    if (releaseBuildRequested && !hasReleaseSigningConfig && !allowDebugSignedRelease) {
        throw GradleException(
            "Release signing is not configured: refusing to produce a debug-signed release. " +
                "Provide android/key.properties (see key.properties.example) or the " +
                "ANDROID_KEYSTORE_* environment variables. For a local smoke test only, set " +
                "ALLOW_DEBUG_SIGNED_RELEASE=true."
        )
    }
}

android {
    namespace = "com.mangaale.order"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mangaale.order"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    buildTypes {
        release {
            // Production key when configured. Without it the task graph check
            // above already refused the build, unless ALLOW_DEBUG_SIGNED_RELEASE
            // explicitly opted in for a local, non-distributable smoke test.
            signingConfig = if (hasReleaseSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
}
