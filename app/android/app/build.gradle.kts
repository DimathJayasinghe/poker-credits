import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (docs/RELEASE_CHECKLIST.md). The upload key lives in android/key.properties, which
// is git-ignored and made by the owner: storeFile, storePassword, keyAlias, keyPassword. This
// repository never contains or generates a key.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keyProperties.getProperty("storeFile") != null

// A build for a store sets REQUIRE_RELEASE_SIGNING=1 (or -PrequireReleaseSigning) so that a missing
// key stops the build instead of quietly producing something signed with the public debug key.
val requireReleaseSigning =
    System.getenv("REQUIRE_RELEASE_SIGNING") == "1" || project.hasProperty("requireReleaseSigning")

android {
    namespace = "dev.pokercredits.poker_credits"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.pokercredits.poker_credits"
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
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKey) {
                    signingConfigs.getByName("release")
                } else if (requireReleaseSigning) {
                    throw GradleException(
                        "Release signing is required but android/key.properties is missing. " +
                            "See docs/RELEASE_CHECKLIST.md.",
                    )
                } else {
                    // Sideloaded builds for friends and the GitHub release only. Android and the
                    // Play Store accept this key; so does anyone else, because it is public.
                    logger.warn("WARNING: no android/key.properties, signing the release with the debug key.")
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
