import groovy.json.JsonSlurper
import java.util.Locale

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
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

val rustDir = File(project.rootDir, "../rust")
val rustManifest = File(rustDir, "Cargo.toml")
val rustJniLibsDir = File(project.projectDir, "src/main/jniLibs")
val rustAndroidAbis = listOf("arm64-v8a")
val rustEnvFile = File(project.rootDir, "../.env")
val mikanLibtorrentDir = File(project.rootDir, "../native/mikan_libtorrent")
val mikanLibtorrentScript = File(project.rootDir, "../build_libtorrent_android.ps1")
val mikanLibtorrentJniLib = File(rustJniLibsDir, "arm64-v8a/libmikan_libtorrent.so")

fun String.capitalized(): String =
    replaceFirstChar { char ->
        if (char.isLowerCase()) {
            char.titlecase(Locale.ROOT)
        } else {
            char.toString()
        }
    }

fun Project.registerRustAndroidBuildTask(
    variantName: String,
    cargoProfile: String,
) = tasks.register("buildRustAndroid${variantName.capitalized()}") {
    group = "rust"
    description = "Build Rust Android libraries for the $variantName variant."

    inputs.dir(rustDir)
    inputs.file(rustManifest)
    if (rustEnvFile.exists()) {
        inputs.file(rustEnvFile)
    }
    outputs.dir(rustJniLibsDir)
    outputs.upToDateWhen { false }

    doLast {
        if (!rustManifest.exists()) {
            throw GradleException("Rust manifest not found: ${rustManifest.path}")
        }

        rustJniLibsDir.mkdirs()

        val rustEnvironment = mutableMapOf<String, String>()
        val opensslDir = File(rustDir, "openssl/usr/local")
        if (opensslDir.exists()) {
            rustEnvironment["OPENSSL_DIR"] = opensslDir.absolutePath
            rustEnvironment["OPENSSL_STATIC"] = "1"
        }

        rustAndroidAbis.forEach { abi ->
            val abiOutputDir = File(rustJniLibsDir, abi)
            delete(File(abiOutputDir, "librust.so"))
            abiOutputDir.mkdirs()

            val cargoArgs = mutableListOf(
                "cargo",
                "ndk",
                "-t",
                abi,
                "-o",
                rustJniLibsDir.absolutePath,
                "build",
            )
            if (cargoProfile == "release") {
                cargoArgs += "--release"
            }

            println("Building Rust Android library for $variantName ($abi, $cargoProfile)")
            providers.exec {
                workingDir = rustDir
                commandLine(cargoArgs)
                if (rustEnvironment.isNotEmpty()) {
                    environment(rustEnvironment)
                }
            }.result.get().assertNormalExitValue()
        }
    }
}

val rustBuildTasks =
    mapOf(
        "debug" to registerRustAndroidBuildTask("debug", "debug"),
        "profile" to registerRustAndroidBuildTask("profile", "release"),
        "release" to registerRustAndroidBuildTask("release", "release"),
    )

val mikanLibtorrentBuildTask = tasks.register("buildMikanLibtorrentAndroid") {
    group = "native"
    description = "Build the Android libtorrent native library for arm64-v8a."

    inputs.dir(mikanLibtorrentDir)
    inputs.dir(File(project.rootDir, "../third_party/libtorrent"))
    inputs.file(File(project.rootDir, "../vcpkg.json"))
    inputs.file(mikanLibtorrentScript)
    outputs.file(mikanLibtorrentJniLib)
    outputs.upToDateWhen { false }

    doLast {
        if (!mikanLibtorrentScript.exists()) {
            throw GradleException("Android libtorrent build script not found: ${mikanLibtorrentScript.path}")
        }

        providers.exec {
            workingDir = File(project.rootDir, "..")
            commandLine(
                "PowerShell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                mikanLibtorrentScript.absolutePath,
                "-Configuration",
                "MinSizeRel",
                "-Abi",
                "arm64-v8a",
                "-OutputJniLibsDir",
                rustJniLibsDir.absolutePath,
            )
        }.result.get().assertNormalExitValue()
    }
}

repositories {
    rustlsPlatformVerifier()
}

android {
    namespace = "com.edicl.mikan_player"
    compileSdk = 37
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
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

        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    packaging {
        jniLibs {
            excludes += listOf(
                "lib/armeabi-v7a/**",
                "lib/x86/**",
                "lib/x86_64/**",
            )
        }
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

afterEvaluate {
    rustBuildTasks.forEach { (variantName, rustTask) ->
        val capitalizedVariant = variantName.capitalized()
        listOf(
            "pre${capitalizedVariant}Build",
            "merge${capitalizedVariant}JniLibFolders",
        ).forEach { taskName ->
            tasks.matching { it.name == taskName }.configureEach {
                dependsOn(rustTask)
                dependsOn(mikanLibtorrentBuildTask)
            }
        }
    }
}
