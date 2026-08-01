# Mikan Player

[English](./README_en.md) | [简体中文](./README.md)

A Flutter + Rust anime streaming application.

## Features

- **Bangumi integration**:
  - Schedule
  - Rankings
  - Comments
  - Anime, character, and person details
  - Search and filters
  - Sync favorite anime from your Bangumi account
  - Automatic matching and search across BT and online sources
- **Torrent streaming**:
  - Download, stream, and seed (dual backends: `rqbit` and `libtorrent`, switchable)
- **Media player**:
  - Danmaku and subtitle settings
  - Playback speed control, seek forward/backward with gesture support
  - Download
  - History
- **Cross-platform**:
  - Windows
  - Android
- **Convenience**:
  - Automatic captcha and WAF bypass
  - Proxy-free access to Bangumi via ECH or reverse proxy


## Data sources

- **[Bangumi](https://bangumi.tv/)**: anime metadata
- **[bangumi-data](https://github.com/bangumi-data/bangumi-data)**: anime metadata
- **[bgmlist](https://bgmlist.com/)**: broadcast schedule
- **[Mikan Project (蜜柑计划)](https://mikanani.me/)**: resources and magnet links
- **[DMHY (动漫花园)](https://animes.garden/)**: resources and magnet links
- **[DanDanPlay (弹弹play)](https://www.dandanplay.com/)**: danmaku data
- **Custom data sources**: add web search/scraping sources via `Data Source Configuration`, with optional captcha handling and subtitle-language tagging

## Tech stack

- **Flutter**: UI, media player (`media_kit`), danmaku (`canvas_danmaku`).
- **Rust**: app logic and torrent engine (called via `flutter_rust_bridge`, using `rqbit`).
- **Drift**: local database.

## Prerequisites

- Flutter SDK 3.10+ (currently running 3.44.8)
- Rust 1.80+ (currently running 1.97.1)
- Visual Studio (Windows) with the C++ desktop development workload
- Android Studio / NDK r29 (for Android builds)

## Run and build

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Generate Rust bindings** (if you modified Rust code):
   ```bash
   flutter_rust_bridge_codegen generate
   ```

3. **Build libtorrent**
    ```bash
   build_libtorrent_windows.ps1
   build_libtorrent_android.ps1
    ```

4. **Run**:
   - **Windows**:
     ```bash
     flutter run -d windows
     ```
   - **Android**:
      ```bash
      flutter run -d android
      ```


5. **Build**
   - **Windows**:
     ```bash
     build_windows.ps1
     ```
   - **Android**:
      ```bash
     build_apk.ps1
     ```