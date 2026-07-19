# 全项目 i18n 与稳定性测试执行计划

> 状态：可执行规划稿  
> 基线日期：2026-07-18  
> 范围：Flutter/Dart UI 国际化、Dart 关键模块测试、Rust 关键模块测试、缺陷发现与回归保护  
> 执行原则：小批次、可独立验收、默认离线、先写特征/回归测试再修复缺陷

---

## 1. 目标与非目标

### 1.1 目标

1. 找出所有用户可见的硬编码 UI 文本，迁移到现有 Flutter `gen-l10n` 体系。
2. 对关键业务、状态管理、持久化、解析和网络边界补充 Dart/Rust 测试。
3. 通过异常输入、并发、取消、重试、缓存和生命周期测试主动发现潜在缺陷。
4. 建立可重复执行的扫描与回归门禁，避免后续重新引入同类问题。
5. 把工作拆成适合 AI 单独执行和 review 的小任务，避免一次全仓修改。

### 1.2 非目标

- 不做视觉改版，不以 i18n 为由改变交互和业务语义。
- 不机械翻译第三方品牌、协议值、CSS selector、JSON key、正则、源站返回标记。
- 不手改 `lib/gen/**`、`lib/src/rust/frb_generated*`、`*.g.dart`、`third_party/**`。
- 不让默认测试依赖真实网络、真实 WebView、真实 BT 引擎或用户机器状态。
- 不追求一次性达到某个漂亮的全仓覆盖率数字；优先覆盖高风险行为和失败分支。
- 不把本计划与大规模源码拆分混成一个改动；如需重构，按
  [`source_split_plan.md`](source_split_plan.md) 的边界另开任务。

---

## 2. 当前基线

### 2.1 仓库现状

| 项目 | 当前值 |
|---|---:|
| l10n 方案 | Flutter `gen-l10n`，`app_zh.arb` 为模板 |
| ARB 消息 | 中文 401、英文 401，key 当前一致 |
| UI Dart | 114 个文件，约 37,200 行；加 `main.dart` 后扫描 115 个文件 |
| service Dart | 67 个文件，约 24,945 行 |
| Dart 测试 | 59 个测试文件；基线 `894` 个测试通过 |
| Rust 业务源码 | 排除 `frb_generated.rs` 后 46 个文件，约 13,856 行 |
| Rust 测试 | 69 个；基线 68 通过、1 个 ECH 真实网络测试 ignored；另有 4 个 danmaku 测试当前会访问真实服务 |

基线命令与结果：

```powershell
flutter test --no-pub
# 894 tests passed，约 60 秒

cargo test --manifest-path rust/Cargo.toml
# 68 passed, 0 failed, 1 ignored；首次编译约 68 秒
```

注意：当前 `rust/src/api/danmaku.rs` 中的 4 个 `#[tokio::test]` 会访问真实的
弹幕/Bangumi 服务。这次基线运行通过，但它们仍是网络波动、限流或上游数据变化导致 flaky 的风险，
应在 `RT-0` 首先改为本地 fixture/本地 server 测试，或转成显式 `#[ignore]` 的 smoke test。

现有 Dart 测试主要集中在：

- `test/services/download/**`：19 个文件；
- `test/ui/pages/player/**`、其 widgets 及播放器控件：约 24 个文件；
- 其余缓存、设置、收藏、用户、主页、索引、搜索、排行等模块覆盖明显较少。

Rust 已覆盖一部分 `crawler`、`ranking`、`config`、`ech`、`captcha`、`danmaku`、
`generic_scraper/matching`，但以下大文件或关键路径仍基本无测试：

- `generic_scraper/search_progress.rs`、`search_play.rs`、`search_channels.rs`、`source_config.rs`；
- `simple.rs`、`mikan.rs`、`dmhy.rs`；
- `crawler/fill_details.rs`、`bangumi_data_store.rs`、`schedule_api.rs`、`sites_index.rs`；
- Bangumi 人物、角色、剧集、评论等 fetch/normalize 模块；
- 网络重试和错误语义目前只有一个默认 ignored 的真实网络回归测试。

### 2.2 硬编码文本首轮扫描

仓库已增加候选扫描器：

```powershell
dart run tool/scan_hardcoded_ui_text.dart
```

首轮结果：

| 级别 | 数量 | 含义 |
|---|---:|---|
| high | 216 | 直接出现在 `Text`/`SelectableText`/`TextSpan.text` 或 tooltip、label、title 等 UI 参数中 |
| medium | 468 | UI 源文件中的 CJK 字符串，需区分用户文案和业务/源数据标记 |
| 合计 | 684 | 候选数，不等于最终需要迁移的消息数 |

已确认的高密度区域包括：

- `lib/ui/pages/data_source_config_page.dart`；
- `lib/ui/widgets/video_player_controls.dart`；
- `lib/ui/pages/bangumi_details/**`；
- `lib/ui/pages/character_detail_page.dart`、`person_detail_page.dart`；
- 主页、历史、收藏等页面中的日期、星期、状态和空态文案。

以下类型必须人工判断，不能批量替换：

- 源数据/匹配标记：`主角`、`配角`、`导演`、`原作`、`[简介原文]`；
- selector、JSON key、正则、URL、HTTP header、资源路径；
- `Mikan`、`Bangumi`、`BT`、`CV`、`EP` 等可能无需翻译的产品或行业术语；
- 服务端返回值的比较 token。若需要本地化，应保留 token，比对后再映射为 l10n 文案。

---

## 3. 总体分块与依赖顺序

每个编号都是一个可单独交给 AI 的工作包。建议单个工作包只覆盖一个功能域，
不要让一次改动同时横跨多个大页面和多个 Rust API。

| ID | 工作包 | 优先级 | 依赖 | 建议体量 |
|---|---|---|---|---|
| F-0 | 固化基线、测试约定和公共测试工具 | P0 | 无 | M |
| L10N-0 | 扫描结果分类、key 规范、l10n 测试骨架 | P0 | F-0 | M |
| L10N-1 | 数据源配置与设置页国际化 | P0 | L10N-0 | L，可再拆 |
| L10N-2 | 播放器控件、弹幕、字幕国际化 | P0 | L10N-0 | L，可再拆 |
| L10N-3 | Bangumi/角色/人物详情国际化 | P0 | L10N-0 | L，可再拆 |
| L10N-4 | 首页、索引、搜索、排行、历史、收藏、我的 | P1 | L10N-0 | L，可再拆 |
| L10N-5 | 全仓残留、无障碍文本、格式化与门禁 | P1 | L10N-1~4 | M |
| DT-1 | Dart 纯函数、models、utils 测试 | P0 | F-0 | M |
| DT-2 | Dart 持久化、缓存、设置、用户状态测试 | P0 | F-0 | L |
| DT-3 | Dart 数据/API/代理/探测服务测试 | P0 | F-0 | L，可再拆 |
| DT-4 | Captcha/WebView/异步调度剩余测试 | P1 | F-0 | M |
| DT-5 | 非 Player 页面 controller/state 测试 | P1 | 对应 L10N 批次 | L，可再拆 |
| DT-6 | Widget、双语言、桌面/移动布局回归 | P1 | L10N-1~4 | L，可再拆 |
| DT-7 | Download/Player 已有测试的风险补洞 | P1 | F-0 | M |
| RT-0 | Rust fixture、本地 HTTP server、测试工具 | P0 | F-0 | M |
| RT-1 | Rust 纯解析：Mikan/DMHY/simple/格式化 | P0 | RT-0 | L |
| RT-2 | generic scraper 搜索与播放链路 | P0 | RT-0 | L，必须细拆 |
| RT-3 | Bangumi API normalize/fetch 边界 | P1 | RT-0 | L，可再拆 |
| RT-4 | crawler 缓存、文件、schedule、sites | P1 | RT-0 | L，可再拆 |
| RT-5 | 网络重试、超时、状态码和 header/cookie | P0 | RT-0 | M |
| RT-6 | FRB 对外契约与错误映射 | P1 | RT-1~5 | M |
| Q-0 | 全量回归、覆盖率审计、缺陷清单、CI 门禁 | P0 | 以上批次 | M |

推荐执行顺序：

1. `F-0` → `L10N-0`、`RT-0`；
2. 先做 `DT-1`、`DT-2`、`RT-1`、`RT-5`，尽早发现底层缺陷；
3. 按功能域执行 `L10N-*`，紧接对应的 `DT-5/DT-6`，减少 UI 文件反复修改；
4. 执行数据服务与复杂 scraper/crawler 测试；
5. 最后做 Player/Download 补洞、FRB 契约和 `Q-0` 全量门禁。

---

## 4. i18n 工作流详细拆分

### L10N-0：分类与规范

任务：

1. 保存首轮扫描结果，并按下列三类逐项分类：
   - `localize`：用户可见，必须进入 ARB；
   - `keep`：品牌、通用缩写或不需翻译的固定显示；
   - `protocol`：源数据 token、selector、正则、key，只能在显示层映射。
2. 新增/修改 ARB 消息时遵守：
   - key 使用 `功能域 + 语义`，例如 `dataSourceConfigSaveFailed`；
   - 不按中文原文命名，不使用 `text1`、`label2`；
   - 带变量的消息使用 ICU placeholder，不在 Dart 中拼接半句翻译；
   - 新增带 placeholder 的消息补 `@key` description/type 元数据；
   - 中英文 key、placeholder 名称和数量必须一致。
3. 建立 l10n 测试辅助：能以 `zh`、`en` 包装任意 Widget。
4. 新增 ARB 一致性测试：key 对齐、placeholder 对齐、JSON 可解析。
5. 对确认无需迁移的扫描项使用带原因的注释：

```dart
// i18n-ignore: upstream Bangumi role token used for matching
const mainRoleToken = '主角';
```

验收：

- 每个 high 候选都有分类；
- medium 候选至少按文件/功能域归类，不能直接全部忽略；
- `flutter gen-l10n` 后无差异漂移或生成错误；
- ARB 一致性测试通过。

### L10N-1：数据源配置与设置

建议拆成两个提交：

1. `data_source_config_page.dart`：表单 label/helper、校验错误、步骤标题、保存结果、JSON 预览、tooltip；
2. 各 settings page：网络、搜索、下载、主题、数据源、URL 管理对话框。

重点：

- `{keyword}`、正则示例、JSONPath、selector 作为 placeholder 或技术示例保留；
- 表单 validator 返回本地化文本，但配置内部枚举值不变；
- 测试保存成功、异常、必填、整数范围和两种 locale。

### L10N-2：播放器、弹幕、字幕

范围：

- `video_player_controls.dart` 与 `video_player_controls/**`；
- `danmaku_settings.dart`、字幕选择/样式、源列表、选集面板；
- 加载、锁定/解锁、返回、空降、关闭面板、失败提示和无障碍 label。

重点：

- 不翻译实际字幕轨名称、源站名称和资源标题；
- `EP`、`CV`、分辨率等术语先明确产品策略；
- 不把 `AppLocalizations` 强塞入 pure policy；由 UI/formatter 层传入本地化结果；
- 检查全屏/非全屏、移动/桌面两套控件是否文案漂移。

### L10N-3：详情页族

建议拆分：

1. Bangumi details layouts；
2. details widgets：角色、评论、评分、收藏统计、简介、站点；
3. character/person detail；
4. 日期、性别、角色类型、收藏状态等 formatter。

重点：

- `主角` 等服务端 token 与显示文案分离；
- `YYYY年 M月`、`全 N 话`、`N 人评` 必须改为 locale-aware formatter/ARB；
- mobile/wide layout 复用同一组文案，不允许一边中文、一边英文占位；
- placeholder/loading/coming soon 等临时文案也必须处理。

### L10N-4：主流程页面

按冲突较小的四批执行：

1. home PC/mobile：星期、原作/导演、空态；
2. index/search/ranking：筛选、范围、排序、时间显示和错误；
3. history/favorites/my：状态枚举、空态、操作确认；
4. about/login/navigation 及遗漏页面。

### L10N-5：残留与门禁

1. 再次全仓扫描并逐项清零/说明 high 候选；
2. 人工搜索 `Text('`、`tooltip:`、`label:`、`hintText:`、`SnackBar`、validator；
3. 检查无障碍 `Semantics.label`、modal `barrierLabel`、图片 `semanticLabel`；
4. 在中英文 locale 下跑关键 Widget smoke test；
5. 检查英文变长后的 overflow，至少覆盖 360px 移动宽度和常用桌面宽度；
6. 分类完成后将扫描器接入 CI：

```powershell
dart run tool/scan_hardcoded_ui_text.dart --fail-on-findings
```

注意：只有 medium 候选已迁移或用原因明确的注释处理后，才启用严格失败模式。

#### L10N-5 执行结果（2026-07-19）

- `dart run tool/scan_hardcoded_ui_text.dart` 从首轮 187（high 52 / medium 135）清零到
  **0 / 0**（已支持 `--fail-on-findings` 严格模式作为 CI gate）。
- 玩家侧全量迁移：player_page、player_page_*_host、player_search_session_coordinator、
  player_side_panel_loader、player_source_helpers、player_bt_source_loader、subscription_debug_page、
  以及 `lib/ui/pages/player/widgets/` 下所有 widget。
- 不可本地化的 `protocol` / `keep` 串统一用 `// i18n-ignore: <原因>` 注释；bt_resource_tags.dart
  整文件以 `// i18n-scan-ignore-file:` 标识（协议匹配 token 集合）。
- 新增 ARB 键约 85 个，全部为 `player*` 前缀；所有新增 placeholder 消息均补齐
  `@key` description/type 元数据，并对英文计数文案使用 ICU plural。
- `PlayerVideoArea` 两个移动端 `IconButton` 分别补上本地化的返回/更多 tooltip，
  解决无障碍朗读（L10N-5-001 / L10N-5-005）。
- 新增 `test/ui/pages/player/widgets/player_l10n5_bilingual_smoke_test.dart`：
  24 个中英文 smoke 用例，覆盖 `PlayerComments` / `PlayerRecommendations` /
  `PlayerResourceList` / `PlayerCurrentSourceActions` / `PlayerSourceSelector` /
  `PlayerSampleSourcePanel` / `PlayerMobileLayout` / `PlayerMobileInfoLayout` / `PlayerPcLayout`；
  测试直接设置 RenderView 为 360×800 / 360×1200 / 1280×800，并断言
  `tester.takeException()` 为 null。
- 扫描器补充 `${...}` 内嵌字符串解析与 CLI 回归测试，避免插值中的用户文案绕过严格门禁。
- CI 工作流 **暂不纳入本批**：扫描门禁命令已就绪
  （`dart run tool/scan_hardcoded_ui_text.dart --fail-on-findings`），
  本地/后续 `Q-0` 再挂到 `.github/workflows`。

### DT-1 执行结果（2026-07-19）

- 新增 7 个测试文件、共 73 个测试，全部通过：
  - `test/models/bangumi_episode_filter_test.dart`（20）：覆盖 `isReleased`
    空 airdate / 昨天 / 明天 / 同日 / 远期 / 非法日期 / Unicode 描述；
    `withoutPhantomEpisodes` 名实两套判定、id 去重、CN-only 标题、顺序保持、空列表；
    `releasedEpisodes` 组合 + `latestReleasedEpisode` 高 sort 选优 / 跳过未发布 /
    全空 / 全未发布 / 空 airdate 视为已发布。
  - `test/models/bangumi_user_collection_test.dart`（7）：全字段、缺失字段默认、
    null score 强转 double、tag 任意类型原样透传、unicode/emoji 文本。
  - `test/models/local_favorite_test.dart`（5）：默认 type 1、type 2~5 覆盖、
    Unicode/emoji、createdAt 不为负/不为未来、两条连续创建非严格降序。
  - `test/models/user_test.dart`（10）：`User.fromJson` / `toJson` 往返、缺失键
    vs null 字段差异、avatar URL rewrite pass-through、unicode/emoji；`UserAvatar`
    独立往返。
  - `test/utils/bangumi_url_rewriter_test.dart`（23）：`rewrite` 在禁用 / 启用
    缓存下的多种映射、协议相对 URL 升级、幂等、未知 host 保留、查询串内 host
    不被改写及相似 host 前缀隔离；`canonicalize` 与缓存标志无关、aliases 折叠、
    协议相对 URL 升级、empty pass-through、非 bangumi/嵌套 URL 保留、幂等；
    `setEnabled` 往返。
  - `test/utils/url_latency_test.dart`（7）：`selectFastestUrl` 空列表 / 单元素
    / 多元素本地服务 / 全失败 fallback；`tcpPing` 无路由 / 非法 URL 返回哨兵
    `999999`、本地 URL 返回非负整数。
  - `test/utils/feature_flags_test.dart`（1）：默认关闭订阅调试入口，并使用单独的
    `--dart-define=ENABLE_SUBSCRIPTION_DEBUG=true` 命令验证启用分支。
- 复用了 `test/support/local_http_server.dart` 提供的 loopback HTTP server，
  未引入任何真实网络或真实 BT 引擎调用。
- `flutter analyze` 0 issue；`flutter test --no-pub` 全量 1075 个测试通过。
- **发现并修复 1 个 bug**（DT-1-001）：`BangumiUrlRewriter.canonicalize` 在
  处理 `api.bangumi.lol` / `next.bangumi.lol` / `lain.bangumi.lol` 时，因
  `_mirrorToReal` map 的 bare-host 键（`bangumi.lol` → `bangumi.tv`）会先于
  更具体的子域键命中，导致子域被错误改写成不存在的 `api.bangumi.tv`。
  该函数被 `ImageCacheService._normalizeCacheKey` 用作磁盘缓存键，因此
  用户在「启用/禁用反向代理」之间切换时，同一张 API 图片会落到两个不同的
  本地缓存文件，造成重复下载和磁盘浪费。修复方法是解析 `Uri.host` 后做完整主机
  精确映射，同时避免改写相似域名和 query 中嵌套的 URL；详见
  `docs/stability_findings.md` DT-1-001。

---

## 5. Dart 测试工作流

### F-0：测试基础设施

建立可复用的 `test/support/**`，避免每个测试自行造轮子：

- `pumpLocalizedWidget(locale, child)`；
- fake clock/timer 或可注入的 delay；
- fake HTTP client/response；
- SharedPreferences 初始化与清理；
- Drift 内存数据库创建/关闭；
- 临时目录和文件 fixture；
- controllable fake service、事件记录器、Completer 辅助；
- 测试结束统一检查未关闭 stream/timer/database。

若生产代码无法测试，优先提取小型 pure function、接口或注入点；不要为了测试暴露大量全局
`debug*ForTest` API。

### DT-1：models、utils、纯逻辑

目标文件：

- `models/bangumi_episode_filter.dart`、`bangumi_user_collection.dart`、`local_favorite.dart`、`user.dart`；
- `utils/bangumi_url_rewriter.dart`、`source_channel_key.dart`、`url_latency.dart`、`feature_flags.dart`；
- 从详情/搜索/主页抽出的日期、状态、排序、去重 formatter。

必测：null/空值、Unicode、非法 URL、边界日期、重复项、稳定排序、序列化往返、兼容旧字段。

### DT-2：持久化与状态

拆成四包：

1. `settings_service.dart`、`base_url_list_service.dart`；
2. `favorites_manager.dart`、`user_manager.dart`；
3. playback history 现有覆盖补充并发/损坏记录/迁移；
4. `cache/**` 与 Drift database。

重点缺陷假设：

- 初始化重复执行、并发写覆盖、通知次数错误；
- 旧版本字段缺失或值越界导致启动失败；
- TTL/时区边界、缓存失效后仍返回陈旧值；
- 数据库迁移、唯一键冲突、删除级联、关闭后异步回写。

### DT-3：数据服务与网络边界

拆成：

1. Bangumi data/details/ECH/request mode/reverse proxy；
2. danmaku/subtitle/image bridge/image cache；
3. header injection proxy、video URL probe；
4. OCR 与 captcha flow 的非 WebView 部分。

默认使用 fake client 或本地 server，覆盖：

- 2xx/3xx/4xx/5xx、空 body、非预期 JSON/HTML、编码异常；
- timeout、取消、重试次数、指数退避、请求头与 cookie 合并；
- 并发请求去重、gate slot 释放、异常后资源清理；
- 代理 URL 重写幂等性，避免二次代理；
- 返回部分数据时的降级行为。

### DT-4：Captcha/WebView/异步调度

现有测试较多，本批只补高风险空洞：

- dispose 后的 late callback 不得 setState/发结果；
- cancel 与 complete 同时发生时只结算一次；
- timeout 必须释放 worker/gate；
- 相同 key 不同 generation 不串结果；
- cookie 清理失败不阻塞下一任务；
- job queue 公平性和饥饿场景。

### DT-5：非 Player controller/state

按页面拆包：

1. home PC/mobile 的共享加载逻辑；
2. index/search/ranking 的筛选、分页、取消旧查询；
3. Bangumi/character/person details controller；
4. settings/data source config 的保存和失败恢复；
5. favorites/history/my 的刷新与删除。

每个页面至少覆盖：initial/loading/success/empty/error/retry/dispose，并验证旧请求晚返回时不会覆盖新状态。

### DT-6：Widget 与本地化回归

Widget 测试只验证用户可观察行为，不大量断言内部 Widget 树实现：

- 中英文关键文本可找到；
- 点击、选择、保存、重试能触发正确回调；
- 错误和空态可恢复；
- mobile/wide 两种布局不抛 overflow；
- modal、tooltip、Semantics label 存在且已本地化。

### DT-7：Player/Download 补洞

不要重复已有大量 happy-path 测试。先跑覆盖率并定位真正空洞，优先：

- 应用重启后的下载恢复、损坏 resume、重复任务；
- pause/resume/remove 与 stats polling 的竞态；
- HTTP/m3u8 重试后不重复写入或重复完成；
- Player 快速切集/切源、页面销毁、自动播放和手动播放竞争；
- native backend 异常时 Dart 状态能回滚并允许重试。

---

## 6. Rust 测试工作流

### RT-0：Rust 测试基础设施

- 在 `rust/tests/fixtures/**` 保存最小化、脱敏、稳定的 HTML/JSON/XML fixture；
- 提供本地 Axum HTTP server helper，支持自定义状态码、延迟、重定向、header 和分段 body；
- 处理 `danmaku.rs` 中 4 个默认访问公网的测试：核心断言迁移到 fixture，本地无法覆盖的端到端部分改为 `#[ignore]` smoke test；
- 测试不得修改真实用户配置/缓存目录；使用 `tempfile`；
- 全局配置、lazy cache、环境变量相关测试串行化或显式恢复现场；
- 默认测试不访问公网。真实网络 smoke test 保持 `#[ignore]` 并单独运行。

### RT-1：纯解析与站点适配

建议拆包：

1. `mikan.rs`：列表/详情、磁链、标题、缺字段、HTML 变化；
2. `dmhy.rs`：搜索结果、编码、空列表、非法链接；
3. `simple.rs`：公共解析/转换/错误路径；
4. 已有 ranking/danmaku parser 的异常 fixture 补充。

每个 parser 至少包含：正常 fixture、最小 fixture、缺节点、重复节点、非法数字/日期、Unicode 标题。

### RT-2：generic scraper

该模块复杂度最高，必须继续细拆：

1. `source_config.rs`：反序列化默认值、校验、非法 regex/selector、兼容旧配置；
2. `search_progress.rs`：进度单调、取消、错误聚合、任务完成计数；
3. `search_channels.rs`：线路提取、去重、排序、空名称、相对 URL；
4. `search_play.rs`：嵌套 URL、header/cookie、候选回退、验证码标记；
5. 组合测试：用本地 server 串起 search → channel → episode → play。

重点查找：死锁/slot 泄漏、取消后继续回调、重复结果、错误被吞、相对 URL 拼错、regex catastrophic input。

### RT-3：Bangumi API

按 types/normalize 与 fetch 分开：

- person/character/episode/comment/relation 的 JSON normalize；
- null、缺字段、字段类型变化、空数组、分页边界；
- markup/XSS-like 输入只验证输出语义，不执行外部内容；
- API error、限流、部分成功与缓存回退；
- 用户收藏状态枚举的未知值兼容。

### RT-4：crawler 与本地数据

拆包：

1. `parse_time.rs`：时区、季度边界、夏令时、非法输入；
2. `sites_index.rs`、`schedule_api.rs`：重复、缺字段、相对 URL；
3. `bangumi_data_store.rs`：原子写、损坏文件、并发读取/刷新、invalidate；
4. `fill_details.rs`：部分失败、重试、顺序稳定、不会覆盖已有有效字段。

### RT-5：网络层

用本地 server 替代公网，覆盖：

- transient 状态码是否按约定重试，永久错误是否立即返回；
- retry 次数和退避，不在测试中真实等待长时间；
- `allow_error_status` 行为；
- redirect、gzip/brotli、空 body、超大/截断 body；
- timeout、连接断开、无效证书相关错误映射；
- header/cookie/referer/user-agent 合并和敏感信息不进入日志。

现有 `ech_pinned_client_reaches_bangumi_api` 继续作为手工 smoke test：

```powershell
cargo test --manifest-path rust/Cargo.toml ech_pinned -- --ignored --nocapture
```

### RT-6：FRB 契约

- 不测试生成文件内部实现；
- 测试手写 `frb_api/**` 的参数校验、错误映射、取消语义；
- 对关键 DTO 做 serde/FRB 往返和默认值测试；
- 执行现有 `tool/check_frb_codegen.ps1`，保证手写 API 与生成结果同步；
- 公共函数签名变化必须单独 review，不能夹在补测试任务中。

### 可选 RT-7：属性/模糊测试

在常规单测稳定后，再对 URL、episode number、日期、HTML/JSON parser 增加：

- 固定 seed 的随机表格测试；
- `proptest` 属性测试；
- 独立、非默认 CI 的 `cargo-fuzz` target。

核心性质：任意输入不 panic、输出排序稳定、normalize 幂等、相同输入结果确定。

---

## 7. 主动发现缺陷的测试矩阵

每个工作包不能只补 happy path，至少从下表选择与模块相关的失败场景。

| 风险 | 应测试的性质 | 常见潜在缺陷 |
|---|---|---|
| 异步生命周期 | dispose/cancel 后不再更新状态 | `setState after dispose`、late result 覆盖新结果 |
| 并发 | 同 key 去重、不同 key 独立、slot 最终释放 | 死锁、重复请求、计数泄漏 |
| 重试 | 次数、条件、退避、幂等 | 永久错误被重试、重复写文件/重复通知 |
| 持久化 | 损坏/旧版本/部分字段/并发写 | 启动崩溃、设置丢失、迁移失败 |
| 缓存 | TTL、invalidate、原子替换、陈旧回退 | 永久脏缓存、半文件、跨用户污染 |
| 解析 | 缺节点、类型变化、非法字符、超长输入 | panic、错误默认值、抓错链接 |
| URL/代理 | 相对 URL、重复 rewrite、header/cookie | 双重代理、referer 丢失、隐私泄漏 |
| UI 状态 | loading/empty/error/retry/locale | 永久 loading、错误不可恢复、文本遗漏 |
| 格式化 | locale、时区、复数、边界值 | 中文格式写死、英文语序错误、日期偏一天 |
| 平台差异 | Windows/Android 路径与能力分支 | 路径越界、平台 API 在测试环境误调用 |

当测试发现缺陷时，必须：

1. 保留一个修复前会失败的最小回归测试；
2. 在 `docs/stability_findings.md` 记录现象、根因、影响、测试名和修复；
3. 缺陷修复与无关重构分开；
4. 对可能改变用户数据的修复补迁移/回滚验证。

---

## 8. 单个 AI 工作包模板

后续给 AI 下发任务时建议使用以下固定格式：

```markdown
任务 ID：DT-2A
范围：settings_service.dart、base_url_list_service.dart 及对应测试
目标：补齐初始化、旧值兼容、并发写和失败恢复测试；发现 bug 时修复并保留回归测试
禁止：真实网络、修改无关 UI、手改生成文件、扩大公共 API
步骤：
1. 阅读生产代码和现有测试，列行为矩阵；
2. 先加测试，确认测试确实覆盖目标分支；
3. 若测试暴露 bug，最小化修复；
4. 运行局部测试、全量 Dart 测试和 analyze；
5. 汇报新增测试、发现的 bug、剩余风险。
验收命令：...
```

单个包的提交要求：

- 生产文件通常不超过一个功能域；
- 不顺手清理大范围格式或重命名；
- 测试命名描述行为和条件，不写 `test1`；
- 不用无意义的“构造不抛异常”测试凑数；
- 对 bug 修复说明测试为何能防止回归。

---

## 9. 验收命令与门禁

### 9.1 每个 Dart/i18n 工作包

```powershell
flutter gen-l10n
dart run tool/scan_hardcoded_ui_text.dart
flutter analyze
flutter test --no-pub <相关测试路径>
flutter test --no-pub
```

### 9.2 每个 Rust 工作包

```powershell
cargo fmt --manifest-path rust/Cargo.toml -- --check
cargo test --manifest-path rust/Cargo.toml <相关测试过滤器>
cargo test --manifest-path rust/Cargo.toml
```

`cargo clippy --all-targets -- -D warnings` 建议先记录当前 baseline，再作为后续独立门禁启用，
避免补测试任务被历史 lint 阻塞。

### 9.3 最终验收标准

- 两份 ARB key 和 placeholder 完全一致，`flutter gen-l10n` 成功；
- 无未分类的 high 扫描候选；medium 候选均已迁移或有明确原因；
- 关键页面在 zh/en、mobile/wide 下无文本缺失和明显 overflow；
- 默认 Dart/Rust 测试完全离线、可重复、无随机 flaky；
- `flutter analyze`、全量 Flutter test、全量 Cargo test 通过；
- 新增/修改的核心 pure logic 以分支覆盖为主，目标约 80% 以上；
- coordinator/service 至少覆盖成功、失败、取消/超时、dispose/清理；
- 每个发现的缺陷都有最小回归测试和 findings 记录；
- 真实网络 smoke test 与默认 CI 分离。

---

## 10. 建议的首批任务

按收益和冲突控制，建议先下发以下六个工作包：

1. `L10N-0`：扫描分类、ARB/l10n 测试骨架；
2. `DT-1`：models/utils/formatters 纯逻辑测试；
3. `DT-2A`：settings/base URL 持久化测试；
4. `RT-0 + RT-5`：本地 HTTP server 与网络重试测试；
5. `RT-1A`：Mikan/DMHY parser fixture 测试；
6. `L10N-1A`：`data_source_config_page.dart` 国际化及表单 Widget 测试。

这六包能尽早建立规则和工具，并优先触达当前覆盖最薄、最容易发现真实缺陷的区域。
