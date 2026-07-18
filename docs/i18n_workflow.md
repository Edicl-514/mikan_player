# i18n 工作流

> 伴随 `docs/full_project_i18n_test_plan.md` §4 L10N-0 制定的可执行规约。后续
> L10N-1..5 工作包按本文文件操作；如遇本文未覆盖的情况，先补本文件再落地代码。

## 1. 工具链

| 任务 | 命令 |
|---|---|
| 扫描候选 | `dart run tool/scan_hardcoded_ui_text.dart [--max-results=N]` |
| 分类候选 | `dart run tool/classify_i18n_candidates.dart` |
| ARB 一致性测试 | `flutter test --no-pub test/i18n/arb_consistency_test.dart` |
| 生成代码 | `flutter gen-l10n` |
| 单 locale widget pump | `test/support/localized_widget_tester.dart` 的 `pumpLocalizedWidget` |

派生文件位置：
- 扫描结果（基线）：`docs/i18n_classification_baseline.json` / `.md`
- 测试辅助：`test/support/**`（由 F-0 引入；详见该目录 README 注释）
- ARB：`lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb`，**模板是 zh**
- 生成的 `AppLocalizations`：`lib/gen/app_localizations*.dart`（**禁止手改**）

## 2. ARB key 命名

1. key 形如 `功能域 + 语义`，lowerCamelCase。
   - 好：`dataSourceConfigSaveFailed`、`playerDanmakuBlockedHint`
   - 坏：`text1`、`label2`、`按中文命名`、`anNiu`、`btn_save`
2. 一条消息一个 key；不要为同义复用造成中英文使用不同分支。
3. key 必须在 `app_zh.arb` 与 `app_en.arb` **同时**出现；`test/i18n/arb_consistency_test.dart`
   会断言对齐，缺失即 CI 失败。
4. 删除一条消息同时从两个 ARB 移除；rename 视为删除+新增。

## 3. placeholder / ICU 规则

1. 变量必须走 ICU：`"statusPlaying": "正在播放：{streamUrl}"` ——禁止在 Dart 里拼半句翻译。
2. 带 placeholder 的消息必须补 `@key` 元数据：
   ```json
   "clearConfirmMessage": "将清除 {count} 个已完成的任务",
   "@clearConfirmMessage": {
     "description": "Confirmation body for the clear-completed downloads action.",
     "placeholders": {
       "count": { "type": "int" }
     }
   }
   ```
   `arb_consistency_test.dart` 的 `@key metadata blocks agree with placeholder
   names` 测试会在声明与实际文本不一致时失败。
3. placeholder 名称使用 lowerCamelCase，且 zh/en 必须一致。新增时务必补齐
   description/type；旧消息在对应工作包修改时逐步补齐。
4. 复数、性别、选择走 ICU 子消息（`{count, plural, ...}`）， 不要写多个 key。

## 4. 三类标签（L10N-0 §1）

每个 high/medium 扫描候选必须落入其一，最终在 PR 描述里给链接：

| 标签 | 含义 | 落地方式 |
|---|---|---|
| `localize` | 用户可见文案 | 进入 ARB，Dart 用 `AppLocalizations.of(context).xxx` |
| `keep` | 品牌、行业术语、固定显示（如 `Mikan`、`EP {n}`、`1080p`） | 保留硬编码；如需可选本地化则单独建 case |
| `protocol` | 源数据 token、selector、正则、JSON key、URL、比对值 | 保留硬编码；如需显示，UI 层映射成 `localize` 文案 |

`tool/classify_i18n_candidates.dart` 输出的 `docs/i18n_classification_baseline.{json,md}`
是 L10N-1..5 的起点，不是终审；改动具体文件时要逐行复核。

## 5. `i18n-ignore` 注释

明确不迁移的硬编码串必须紧靠其行加注释：

```dart
// i18n-ignore: upstream Bangumi role token used for matching
const mainRoleToken = '主角';
```

整文件无 UI 文案可加：

```dart
// i18n-scan-ignore-file: generated or protocol-only file
```

只有加注释的行才被 `scan_hardcoded_ui_text.dart` 跳过；其它行不论 human
判断如何，仍然进入候选计数。门禁启用 `--fail-on-findings` 之前需先
把 medium 候选清零或全部加注释（L10N-5 任务）。

## 6. 单个 L10N-* 工作包的标准动作

每个工作包（如 L10N-1A）：

1. 在 `docs/i18n_classification_baseline.md` 找到本工作包覆盖的文件列表。
2. 对每个 `localize` 候选：
   - 在 `app_zh.arb` 与 `app_en.arb` 添加 key + 翻译；
   - 在 Dart 里替换为 `AppLocalizations.of(context).xxx`；
   - 若所改 widget 没走过 `pumpLocalizedWidget`，补 widget 测试断言中/英
     都能找到文本。
3. 对每个 `protocol` / `keep` 候选：保留硬编码，加 `// i18n-ignore: <原因>` 注释。
4. 若新 key 含 placeholder，补 `@key` 元数据。
5. 运行验收命令（见下）。任何一条不过则修复后再提交。

## 7. 工作包验收命令

```powershell
flutter gen-l10n
dart run tool/scan_hardcoded_ui_text.dart
flutter analyze
flutter test --no-pub test/i18n/arb_consistency_test.dart
flutter test --no-pub <本包相关测试路径>
flutter test --no-pub
```

## 8. CI 门禁路线图（L10N-5 启用前先做以下三步）

1. `i18n_classification_baseline.{json,md}` 与本计划文件纳入仓库；
2. 把 `test/i18n/arb_consistency_test.dart` 加进默认 `flutter test`；
3. L10N-5 阶段所有 medium 候选处理后，CI 增设
   `dart run tool/scan_hardcoded_ui_text.dart --fail-on-findings`。

在此之前的 L10N-1..4 工作包**不**启用 `--fail-on-findings`，只需保证自己
处理的文件不再新增 high 候选即可。

#### 启用状态（2026-07-19）

L10N-5 已完成扫描清零与严格模式开关，但 **本批不提交 GitHub Actions 工作流**
（避免 Flutter 版本钉死与离线 cargo 等问题阻塞合并）。门禁以本地命令为准：

```powershell
dart run tool/scan_hardcoded_ui_text.dart --fail-on-findings
flutter gen-l10n
flutter analyze
flutter test --no-pub
```

- 全部 high / medium 候选清零（见 `docs/full_project_i18n_test_plan.md` §4 L10N-5）。
- 后续 `Q-0` 再把上述命令挂入 CI；在此之前请在本地 PR 检查中手动跑扫描门禁。
