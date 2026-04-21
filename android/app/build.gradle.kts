import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun RepositoryHandler.rustlsPlatformVerifier() = maven {
    val dependencyText = providers.exec {
        workingDir = File(project.rootDir, "..")
        commandLine(
            "cargo",
            "metadata",
            "--format-version",
            "1",
            "--filter-platform",
            "aarch64-linux-android",
            "--manifest-path",
            File(project.rootDir, "../rust/Cargo.toml").path,
        )
    }.standardOutput.asText.get()

    @Suppress("UNCHECKED_CAST")
    val packages = (JsonSlurper().parseText(dependencyText) as Map<String, Any>)["packages"] as List<Map<String, Any>>
    val manifestPath = packages
        .first { it["name"] == "rustls-platform-verifier-android" }["manifest_path"]
        .toString()

    url = uri(File(File(manifestPath).parentFile, "maven").path)
    metadataSources.artifact()
}

repositories {
    rustlsPlatformVerifier()
}

android {
    namespace = "com.edicl.mikan_player"
    compileSdk = 36
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.edicl.mikan_player"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("rustls:rustls-platform-verifier:latest.release")
}
