# Mikan Player

[English](./README_en.md) | [简体中文](./README.md)

一个现代的 Flutter + Rust 动漫流媒体应用，集成了 Bangumi。

## 功能

- **Torrent 流媒体**：无需等待完整下载即可即时播放磁力链接（基于 `rqbit`）。
- **Bangumi 集成**：
  - 查看每周番剧放送表。
  - 浏览排行榜和季度番剧。
  - 管理您的观看进度和收藏。
  - 在通用 BT 源上自动匹配和搜索剧集。
- **媒体播放器**：
  - 使用 `media_kit`（支持 MPV）的高性能播放。
  - 支持弹幕。
- **跨平台**：
  - Windows
  - Android
- **离线功能**：使用 Isar 数据库进行智能缓存。

## 数据来源

- **Bangumi**：番剧元数据
- **bgmlist**：放送表
- **蜜柑计划**：资源与磁力链接
- **动漫花园**：资源与磁力链接
- **弹弹play**：弹幕数据

## 技术栈

- **Flutter**：UI、媒体播放器 (`media_kit`)、弹幕 (`canvas_danmaku`)。
- **Rust**：应用逻辑和 Torrent 引擎（通过 `flutter_rust_bridge` 调用 `rqbit`）。
- **Isar**：本地数据库。

## 开发前提

- Flutter SDK 3.10+ (当前运行 3.38.7)
- Rust 1.80+ (当前运行 1.92.0)
- Visual Studio (Windows) 需包含 C++ 桌面开发工作负载
- Android Studio / NDK (用于 Android 构建)

## 设置

1. **安装依赖**：
   ```bash
   flutter pub get
   ```

2. **生成 Rust 绑定**（如果您修改了 Rust 代码）：
   ```bash
   flutter_rust_bridge_codegen generate
   ```

3. **运行**：
   - **Windows**：
     ```bash
     flutter run -d windows
     ```
   - **Android**：
     ```bash
     flutter run -d android
     ```

## 项目架构

- `lib/main.dart`: 应用程序入口。
- `lib/ui/`: Flutter UI 页面（时间表、播放器、设置等）。
- `lib/src/rust/`: 生成的 Rust 绑定。
- `rust/src/`: Rust 后端逻辑（`rqbit` 集成）。
- `windows/CMakeLists.txt`: 已配置为自动构建 Rust 代码。
