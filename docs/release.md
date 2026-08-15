# Release 流程

仓库采用 `main` 分支滚动发布：每次 push 到 `main`（或手动执行 workflow）都会构建 Windows 和 Android arm64 产物，并更新 GitHub 上唯一的 `rolling` Release。

## 版本规则

- `build-name`：UTC 日期，格式为 `YYYY.MM.DD`，例如 `2026.08.15`。
- `build-number`：GitHub Actions 的 `run_number`，保证同一天多次发布仍可区分。
- 应用完整版本：`YYYY.MM.DD+run_number`。
- `rolling` 标签会移动到本次发布的 commit；Release 资产文件名保留完整版本号。
- 同时上传 `mikan-player-windows-latest.zip` 和 `mikan-player-android-arm64-latest.apk` 两个固定资产名，供自动更新器使用。

版本计算也可以在本地运行：

```powershell
.\tool\release_version.ps1 -BuildNumber 42
```

## GitHub 配置

在仓库 Settings -> Secrets and variables -> Actions 中添加以下 secrets：

`DANDANPLAY_APP_ID`、`DANDANPLAY_APP_SECRET`、`BANGUMI_APP_ID`、`BANGUMI_APP_SECRET`。

这些值只在 runner 上生成临时 `.env`，不会写入 Git。当前 Android 配置仍使用 debug signing key；要发布到 Google Play，需要另外接入 release keystore（建议使用 base64 编码的 keystore 和独立的 `key.properties` secrets），不要把 keystore 提交到仓库。

## 日常操作

1. 合并代码到 `main`，等待 `Rolling Release` workflow 完成。
2. 在 GitHub Releases 打开 `rolling`，下载对应平台的最新资产。
3. 发布失败时修复后重新 push；需要回滚时，在目标旧 commit 上手动执行 workflow，`rolling` 会重新指向该 commit。

workflow 使用 `contents: write` 和并发锁，避免两个构建同时改写滚动 Release。若需要不可变审计记录，可以在发布 job 中额外创建 `vYYYY.MM.DD+run_number` 标签，但不要让客户端依赖这个标签进行滚动更新。

客户端可以使用以下固定地址获取滚动版本（GitHub 会返回当前 `rolling` Release 的资产）：

`https://github.com/Edicl-514/mikan_player/releases/download/rolling/mikan-player-windows-latest.zip`

`https://github.com/Edicl-514/mikan_player/releases/download/rolling/mikan-player-android-arm64-latest.apk`
