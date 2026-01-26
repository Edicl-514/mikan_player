# Mikan Player

A Flutter + Rust video player capable of streaming torrents directly.

## Stack
- **Flutter**: UI and Media Player (`media_kit`)
- **Rust**: Application Logic and Torrent Engine (`rqbit` via `flutter_rust_bridge`)

## Prerequisites
- Flutter SDK 3.10+ (Running 3.38.7)
- Rust 1.80+ (Running 1.92.0)
- Visual Studio (Windows) with C++ Desktop development workload

## Setup

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Generate Rust Bindings (already done, but if you modify Rust code)**:
   ```bash
   flutter_rust_bridge_codegen generate
   ```

3. **Run**:
   ```bash
   flutter run -d windows
   ```
   
## Android Setup
To run on Android, ensure you have NDK installed and configure `android/app/build.gradle` to include the Rust library (e.g. using `cargo-ndk` or scanning `jniLibs`). 
Note: The project currently has basic Android permissions (`INTERNET`) in `AndroidManifest.xml`.

## Architecture
- `lib/main.dart`: Entry point, UI initialization.
- `lib/src/rust`: Generated bindings.
- `rust/src/api/simple.rs`: Rust backend logic. Currently mocks `rqbit` streaming.
- `windows/CMakeLists.txt`: Configured to build Rust code automatically.

## Usage
Enter a magnet link in the text field and click "Play".
If you leave it empty or use "demo", it plays "Big Buck Bunny".

