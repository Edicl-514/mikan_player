# Windows PowerShell script to build the Android APK.
# Rust and libtorrent native libraries are compiled automatically by Gradle during the Flutter build.
param(
    [switch]$AnalyzeSize,
    [switch]$SplitPerAbi
)

$ErrorActionPreference = "Stop"

$flutterArgs = @(
    "build",
    "apk",
    "--release",
    "--target-platform",
    "android-arm64",
    "--split-debug-info=build/symbols/android",
    "--tree-shake-icons"
)

if ($SplitPerAbi) {
    $flutterArgs += "--split-per-abi"
}

if ($AnalyzeSize) {
    $flutterArgs += "--analyze-size"
}

Write-Host "Building arm64 release APK..."
& flutter @flutterArgs
if ($LASTEXITCODE -ne 0) {
    throw "Flutter APK build failed with exit code $LASTEXITCODE"
}

Write-Host "APK build completed!"
