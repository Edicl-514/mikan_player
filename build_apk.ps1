# Windows PowerShell script to build the Android APK.
# Rust native libraries are compiled automatically by Gradle during the Flutter build.
Write-Host "Building arm64 release APK..."
flutter build apk --release --target-platform android-arm64

Write-Host "APK build completed!"
