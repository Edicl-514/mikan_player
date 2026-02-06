# Mikan Player

English | [简体中文](./README_zh.md)

A modern Flutter + Rust application for streaming anime, with Bangumi integration.

## Features

- **Torrent Streaming**: Instant playback of torrent magnets without waiting for full downloads (powered by `rqbit`).
- **Bangumi Integration**:
  - View weekly broadcast timetable.
  - Browse rankings and seasonal anime.
  - Manage your watch progress and collection.
  - Auto-match and search for episodes on generic BT sources.
- **Media Player**:
  - High-performance playback using `media_kit` (MPV based).
  - Danmaku (commentary overlay) support.
- **Cross-Platform**:
  - Windows
  - Android
- **Offline Capabilities**: Intelligent caching with Isar database.

## Data Sources

- **Bangumi**: Anime metadata
- **bgmlist**: Broadcast timetable
- **Mikan Project**: Resources and magnet links
- **Anime Garden**: Resources and magnet links
- **DanDanPlay**: Danmaku data

## Stack

- **Flutter**: UI, Media Player (`media_kit`), Danmaku (`canvas_danmaku`).
- **Rust**: Application Logic and Torrent Engine (`rqbit` via `flutter_rust_bridge`).
- **Isar**: Local database.

## Prerequisites

- Flutter SDK 3.10+ (Running 3.38.7)
- Rust 1.80+ (Running 1.92.0)
- Visual Studio (Windows) with C++ Desktop development workload
- Android Studio / NDK (for Android build)

## Setup

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Generate Rust Bindings** (Needed if you modify Rust code):
   ```bash
   flutter_rust_bridge_codegen generate
   ```

3. **Run**:
   - **Windows**:
     ```bash
     flutter run -d windows
     ```
   - **Android**:
     ```bash
     flutter run -d android
     ```

## Architecture

- `lib/main.dart`: Entry point.
- `lib/ui/`: Flutter UI pages (Timetable, Player, Settings, etc.).
- `lib/src/rust/`: Generated Rust bindings.
- `rust/src/`: Rust backend logic (`rqbit` integration).
- `windows/CMakeLists.txt`: Configured to build Rust code automatically.

