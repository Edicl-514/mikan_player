# Mikan Player

[English](./README_en.md) | [简体中文](./README.md)

一个基于 Flutter + Rust 的动漫流媒体应用

## 功能


- **Bangumi 集成**：
  - 放送表
  - 排行榜
  - 评论
  - 番剧、角色、人物详情
  - 搜索与筛选
  - 从 Bangumi 账号同步收藏番剧
  - 在 BT 源和在线源上自动匹配和搜索播放源
- **Torrent 流媒体**：
  - 下载、串流、做种（双后端，可选 `rqbit` 和 `libtorrent`）
- **媒体播放器**：
  - 弹幕与字幕设置
  - 倍速播放、快进快退，支持手势操作
  - 下载
  - 历史记录
- **跨平台**：
  - Windows
  - Android
- **便利功能**：
  - 自动过验证码和 WAF
  - 使用 ECH 或反代来实现免代理访问 Bangumi

## 数据来源

- **Bangumi**：番剧元数据
- **bgmlist**：放送表
- **蜜柑计划**：资源与磁力链接
- **动漫花园**：资源与磁力链接
- **弹弹play**：弹幕数据
- **自定义数据源**：可配置 Web 搜索/解析源

## 技术栈

- **Flutter**：UI、媒体播放器 (`media_kit`)、弹幕 (`canvas_danmaku`)。
- **Rust**：应用逻辑和 Torrent 引擎（通过 `flutter_rust_bridge` 调用 `rqbit`）。
- **Drift**：本地数据库。

## 开发前提

- Flutter SDK 3.10+ (当前运行 3.44.4)
- Rust 1.80+ (当前运行 1.92.0)
- Visual Studio (Windows) 需包含 C++ 桌面开发工作负载
- Android Studio / NDK r29(用于 Android 构建)

## 运行与编译

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


4. **编译**
   - **Windows**：
     ```bash
     build_windows.ps1
     ```
   - **Android**：
      ```bash
     build_apk.ps1
      ```

