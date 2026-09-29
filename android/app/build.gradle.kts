import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing, read from android/key.properties — a file that is
// gitignored and never committed. The keystore it points at is the app's
// identity on Play forever: lose it and you cannot ship an update to your own
// listing under any circumstances, so it belongs in a password manager and a
// backup, not in this repository.
//
// When the file is absent the build falls back to debug signing, so a fresh
// clone still builds and runs. That fallback is deliberately loud in the
// release output rather than silent, because a debug-signed bundle is
// rejected by Play at upload with an error that does not explain itself.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.astraapp.astra"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // flutter_local_notifications schedules against java.time, which does
        // not exist on older Android. Desugaring back-ports it into the app
        // rather than raising minSdk and dropping devices.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.astraapp.astra"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "\n*** astra: android/key.properties not found — signing this " +
                        "release with the DEBUG key. Play will reject the upload. " +
                        "See android/key.properties.example. ***\n",
                )
                signingConfigs.getByName("debug")
            }

            // Shrinking and obfuscation, on, with hand-written keep rules in
            // proguard-rules.pro.
            //
            // This was off, and the note here said it was worth turning on
            // later — R8 needs keep rules for the reflective parts of Firebase,
            // billing and the audio service, and a release that crashes only
            // after minification is a miserable thing to debug. That reasoning
            // was right and the bill came due anyway: Play measures how much of
            // an app is obfuscated and warns below 25%, and Astra measured 2%,
            // which is exactly what an unminified build looks like from the
            // outside. Left alone it costs search visibility and, eventually,
            // the ability to publish.
            //
            // So the keep rules are written rather than the setting flipped and
            // hoped over. Read them before adding a plugin: anything reached by
            // reflection, by native code, or by class name from the Android
            // manifest is invisible to R8 and will be renamed away.
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
    // Required by the compileOptions flag above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
