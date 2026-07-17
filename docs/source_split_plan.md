# 源码拆分清单与分阶段任务规划

> 状态：规划稿  
> 范围：非生成 Dart / Rust 源文件  
> 原则：按**职责边界**拆，不为行数而拆；保持对外 API（尤其 FRB `pub` 签名）稳定；小步可回滚；每步可测。

---

## 0. 目标与非目标

### 目标

1. 把「编排页 / 管理器 / API 桶」里混杂的职责拆成可导航、可单测的模块。
2. 延续已有拆分模式：
   - Player：`lib/ui/pages/player/**`
   - Download：`lib/services/download/**`
3. 降低改一处牵全身的风险，缩短 review 面。
4. 行数下降是结果，不是 KPI；可测性与边界清晰才是 KPI。

### 非目标

- 不重写播放/搜索/下载业务语义。
- 不手改 `frb_generated*`、`*.g.dart`、第三方插件目录。
- 不做全仓「按 500 行硬切」的机械拆分。
- 不把 UI 重构（视觉改版）绑进本轮。

### 成功标准（整体）

| 指标 | 目标 |
|------|------|
| `player_page.dart` | ≤ ~1500 行，State 以 glue + build 为主 |
| `download_manager.dart` | ≤ ~800–1000 行，Manager 只调度 |
| `generic_scraper.rs` 门面 | ≤ ~400–600 行 `pub` re-export / 薄 API |
| `bangumi.rs` / `crawler.rs` 门面 | 同上，实现下沉子模块 |
| 测试 | 每阶段有对应单测绿；关键路径不回归 |
| API | Dart 公共入口路径尽量不变；Rust FRB 函数名/签名不变 |

---

## 1. 优先级总览

| 优先级 | 文件（约行数） | 原因 | 阶段 |
|--------|----------------|------|------|
| P0 | `lib/ui/pages/player_page.dart` (~7000) | 最大热点；已有半成品模块与测试 | Phase 1 |
| P0 | `lib/services/download_manager.dart` (~2600) | 已有 `download/` 子模块与测试，适合继续下沉 | Phase 2 |
| P1 | `rust/src/api/generic_scraper.rs` (~4500) | 职责清晰可切；纯逻辑多，易测 | Phase 3 |
| P1 | `rust/src/api/bangumi.rs` (~2300) | types / fetch / markup 边界清楚 | Phase 4a |
| P1 | `rust/src/api/crawler.rs` (~2400) | bangumi-data / schedule / sites-index | Phase 4b |
| P2 | `lib/ui/pages/bangumi_details_page.dart` (~2500) | controller 已有雏形，主要抽 section widgets | Phase 5 |
| P2 | `lib/services/webview_captcha_job_runner.dart` (~1800) | 与 player 解耦后单独拆 | Phase 6 |
| P3 | 详情页族 / 设置页 / 1k–1.5k 级文件 | 有需求再动 | Phase 7+ |

**暂缓 / 不拆**

- `lib/src/rust/**`、`frb_generated*`、`app_database.g.dart`、`app_localizations*`
- 已较薄的 pure policy（如 `player_search_session_policy.dart`）
- 第三方 / ephemeral 插件代码

---

## 2. 拆分内容清单（按文件）

### 2.1 `lib/ui/pages/player_page.dart`（P0）

**现状**

- 页面 State 仍承担：生命周期、BT/在线源加载、captcha preflight、WebView pool 泵、搜索流、自动播放、评论/推荐/站点、UI build。
- 已抽出（应继续复用，不重复造轮子）：
  - Controllers：`player_playback_controller`、`player_source_controller`、`player_sample_source_controller`、`player_episode_controller`
  - Scheduler：`player_webview_scheduler`、`webview_pool_pump_coordinator`、`webview_worker_*`
  - Policy：`player_search_session_policy`、`sample_search_finish_policy`
  - Widgets：`player_comments`、`player_recommendations`、`player_resource_list`、`bt_resource*`
  - 测试：`test/ui/pages/player/**` 已较全

**建议新文件 / 职责**

| 目标路径 | 迁出内容 | 类型 |
|----------|----------|------|
| `player/player_captcha_preflight_coordinator.dart` | `_CaptchaPreflightTask`、queue、start one captcha、result/release slot、runtime overrides 更新 | coordinator |
| `player/player_search_session_coordinator.dart` | `_launchSearchStream`、`_loadSampleSource`、progress update、finish sample search、cancel subscriptions、search keyword 构建 | coordinator |
| `player/player_webview_pool_host.dart`（或并入现有 scheduler 边界） | pump/stagger、affinity、idle trim、worker status labels、extraction start、stats labels | host glue（尽量把 pure 逻辑继续沉到现有 scheduler/bookkeeping） |
| `player/player_bt_source_loader.dart` | mikan/dmhy 加载、alias 提取、BT 既有下载检测与 stream play 触发 | loader |
| `player/player_side_panel_loader.dart` | comments / recommendations / onair sites 加载与排序 | loader |
| `player/player_autoplay_coordinator.dart` | `_attemptAutoPlay`、低优先级取消、probe+register、open online source 中的自动播决策 | coordinator |
| `player/widgets/player_page_scaffold*.dart`（按需） | 大体量 `build*` 区块（源控制区、WebView 状态行、当前源操作按钮） | UI |
| 保留在 `player_page.dart` | `PlayerPage` / State 字段声明、`initState`/`dispose`、把 coordinator 接到 UI、顶层 layout | glue |

**不要拆进本文件族的**

- `CaptchaJobRunner` 本体（属 service，Phase 6）
- media_kit 控件实现（`video_player_controls`）

**验收**

- `player_page.dart` 主要读起来像「接线板」
- 现有 `test/ui/pages/player/**` 全绿；新增 coordinator 的 pure 分支有单测
- 手动：打开播放页 → 搜索源 → captcha/web 提取 → 自动播 → 切集

---

### 2.2 `lib/services/download_manager.dart`（P0）

**现状**

- 已 re-export 模型；子模块齐全（queue / task store / http / m3u8 / bt backends / cleanup / stream restore）
- Manager 仍集中：初始化、settings、BT start/resume/pause、HTTP/m3u8 任务、stats 轮询、Android service、libtorrent resume

**建议新文件 / 职责**

| 目标路径 | 迁出内容 | 说明 |
|----------|----------|------|
| `download/download_manager_settings.dart` 或 mixin | `setDownloadDir` / `setDownloadSettings` / 限速应用 / 默认目录解析 | 配置面 |
| `download/download_stats_poller.dart` | `_updateStats`、polling start/stop、active/seeding 计数相关调度 | 定时器逻辑 |
| `download/download_android_service_bridge.dart` | MethodChannel、service running 同步 | 平台桥 |
| `download/download_bt_session.dart` | `_startTorrentWithBackend`、resume/reattach 队列、pause/stop/stats with backend、stream url | BT 会话 |
| `download/download_http_pipeline.dart` | `startHttpDownload`、`_downloadHttpFile`、m3u8 分支调度、throttle chunk | HTTP 管线 glue |
| `download/download_path_utils.dart`（若尚未集中） | sanitize / extension / m3u8 判断 / path under dir | pure |
| 保留 `DownloadManager` | 单例、`ChangeNotifier`、任务 map、对外 `startDownload` / `initialize` / 查询 API | façade |

**验收**

- 对外 `DownloadManager` API 不变（UI/调用方零改或仅 import 兼容）
- `test/services/download/**` 全绿
- BT stream / HTTP / m3u8 各跑一轮

---

### 2.3 `rust/src/api/generic_scraper.rs`（P1）

**建议模块树**（门面文件保留 `generic_scraper.rs` 或改为 `generic_scraper/mod.rs`）

```
rust/src/api/generic_scraper/
  mod.rs                 # pub use + FRB 入口薄包装（可选）
  types.rs               # MediaSource, CaptchaConfig, SearchConfig, selectors, MatchVideo, ChannelInfo, EpisodeInfo, progress types...
  region.rs              # detect_current_region*, filter_restricted_sources
  headers_cookies.rs     # merge_cookie_strings, apply_*_headers
  matching.rs            # preprocess/search candidates, score, select subject/episode, chinese number, channel name
  episode_table.rs       # parse/select/cache episode table
  source_config.rs       # load/save/cache config, get_playback_sources, update/add source, invalidate
  search_play.rs         # generic_search_play_pages*, search_single_source*
  search_channels.rs     # generic_search_with_channels*, get_episode_play_url
  search_progress.rs     # generic_search_with_progress*, stream variants, debug_search_*
```

**约束**

- 所有现有 `pub async fn` / `pub struct` / `pub enum` 名称与字段保持 FRB 兼容。
- 优先：`mod.rs` 里 `pub use` 重导出，避免改 Dart 调用。
- pure 函数（matching / region normalize）优先补 Rust 单测。

**验收**

- `cargo check` / 现有 rust 测试通过；必要时 `flutter_rust_bridge` 不强制 codegen（若仅 `mod` 拆分且路径稳定）。
- Dart 侧搜索/播源流程无签名变更。

---

### 2.4 `rust/src/api/bangumi.rs`（P1）

```
rust/src/api/bangumi/
  mod.rs
  types.rs               # Episode/Character/Comment/Person/Images...
  fetch_episodes.rs
  fetch_characters.rs
  fetch_relations.rs
  fetch_comments.rs      # subject + episode comments, legacy/next
  fetch_persons.rs
  markup.rs              # smile, render markup/plain, escape, normalize urls
  character_detail.rs
  person_detail.rs
  user.rs                # user info / collections / subject image bytes
  util.rs                # timestamp, truncate, next url
```

**验收**：`pub` API 表面不变；markup 单测覆盖 smile/标签；评论双路径（legacy/next）行为不变。

---

### 2.5 `rust/src/api/crawler.rs`（P1）

```
rust/src/api/crawler/
  mod.rs
  types.rs               # AnimeInfo, ArchiveQuarter, bangumi-data JSON structs
  parse_time.rs          # begin/broadcast → day/time, quarter title
  schedule_api.rs        # archive list + schedule API/html/local json
  bangumi_data_store.rs  # download, markers, mmap load, single-flight, invalidate cache
  sites_index.rs         # build/index/lookup sites by bgm/mikan id
  fill_details.rs        # fill_anime_details + subject rest json
```

**验收**：档期/archive、sites index、失败 marker 冷却逻辑不变；注意 `replace_atomic` 等平台条件编译原样迁移。

---

### 2.6 `lib/ui/pages/bangumi_details_page.dart`（P2）

**现状**：数据多已在 details controller；页面仍堆 mobile/wide layout 与 section widgets。

| 目标路径 | 内容 |
|----------|------|
| `bangumi_details/widgets/header_*.dart` | poster、title、rating、action buttons、collection stats |
| `bangumi_details/widgets/summary_tags.dart` | summary / tags / infobox |
| `bangumi_details/widgets/characters_section.dart` | 角色列表与 badge |
| `bangumi_details/widgets/comments_section.dart` | comment card / load more |
| `bangumi_details/widgets/sites_section.dart` | onair sites |
| `bangumi_details/person_text_spans.dart` | person-aware text / `_PersonTextMatch` |
| `bangumi_details/layouts/mobile_layout.dart` / `wide_layout.dart` | 布局拼装 |
| 保留 page | 路由参数、controller 生命周期、layout 选择 |

**验收**：controller 测试仍绿；移动/宽屏布局冒烟。

---

### 2.7 `lib/services/webview_captcha_job_runner.dart`（P2）

| 目标路径 | 内容 |
|----------|------|
| `captcha/captcha_job_types.dart` | enums、candidate、extraction config、signals |
| `captcha/captcha_page_signal.dart` | 页面信号判定 |
| `captcha/captcha_search_flow.dart` | search stage |
| `captcha/captcha_detail_flow.dart` | detail stage |
| `captcha/captcha_job_runner_sink.dart` | sink（已有类可原样迁） |
| 保留 `CaptchaJobRunner` | 对外 API 与编排入口 |

**验收**：与 player captcha preflight 联调；不改变 job 生命周期语义。

---

### 2.8 P3 候补（有触达再拆）

- `person_detail_page.dart` / `character_detail_page.dart` / `my_page.dart`
- `danmaku_settings.dart` / `data_source_config_page.dart`
- `index_page.dart` / `subscription_debug_page.dart`
- `video_player_controls.dart`（若继续膨胀，按 panel 拆）

规则：单次只拆「正在改的文件」，避免无关连重构。

---

## 3. 分阶段任务清单

### 总节奏

```
Phase 0 准备 → Phase 1 Player → Phase 2 Download
→ Phase 3 generic_scraper → Phase 4 bangumi+crawler
→ Phase 5 details UI → Phase 6 captcha runner → Phase 7 收尾
```

每阶段结束：提交独立 commit（或小 PR）、测试绿、简短 CHANGELOG/说明。  
建议分支继续 `ai_refactor` 或 `refactor/split-phase-N`。

---

### Phase 0 — 准备（0.5–1 天）

| # | 任务 | 产出 |
|---|------|------|
| 0.1 | 冻结本清单为基线；确认不改 FRB 签名 | 本文档 |
| 0.2 | 跑一轮基线测试：player + download 相关 test | 基线绿/已知失败列表 |
| 0.3 | 约定命名：`*_coordinator` / `*_loader` / `*_host`（Dart），Rust `api/<name>/mod.rs` | 团队约定 |
| 0.4 | 每个大文件先画「职责注释块」（仅注释分区，不迁代码）可选 | 降低后续迁错概率 |

**完成定义**：基线测试结果已知；拆分命名约定确认。

---

### Phase 1 — Player 页面瘦身（优先，约 3–6 天）

> 策略：先抽 **无 Widget 依赖** 的 coordinator/loader，再抽 UI section。每 PR 只迁 1 个职责簇。

| # | 步骤 | 迁出 | 测试 |
|---|------|------|------|
| 1.1 | 抽 `player_side_panel_loader` | comments / recommendations / onair sites | 现有 comments/recommendations 测 + 新 loader 测 |
| 1.2 | 抽 `player_bt_source_loader` | mikan/dmhy、alias、既有 BT 播放 | source 相关测；手动 BT |
| 1.3 | 抽 `player_captcha_preflight_coordinator` | queue/start/result/overrides | 新增单元测；手动 captcha 源 |
| 1.4 | 抽 `player_search_session_coordinator` | load sample、stream、progress、finish、cancel | `player_search_session_policy` + 新测 |
| 1.5 | 收敛 WebView pool glue | 尽量调用已有 scheduler/pump/bookkeeping；页面只留回调接线 | `player_webview_scheduler_test` |
| 1.6 | 抽 `player_autoplay_coordinator` | attempt autoplay、probe/register、cancel lower priority | playback/source 测 |
| 1.7 | （可选）拆大型 build section widgets | 源控制条、worker 状态行、action buttons | 编译 + 手动 UI |
| 1.8 | 清理：删除死代码、统一 import、State 字段归组 | — | full player test suite |

**Phase 1 完成定义**

- [x] `player_page.dart` ≤ ~1500 行（当前约 500 行，只保留字段、生命周期与顶层 build）
- [x] `test/ui/pages/player/**` 全绿
- [x] 手动冒烟：进页、搜源、提取、自动播、切集、BT、评论/推荐

**回滚点**：每个 1.x 独立 commit。

---

### Phase 2 — DownloadManager 继续下沉（约 2–4 天）

| # | 步骤 | 迁出 | 测试 |
|---|------|------|------|
| 2.1 | path/sanitize/hash 等 pure → `download_path_utils`（若仍留在 manager） | pure | 新测或归入现有 |
| 2.2 | Android service bridge | channel | 编译；Android 有设备再冒烟 |
| 2.3 | stats poller | 轮询与 active 判定调度 | manager bt/http 测 |
| 2.4 | BT session 模块 | start/resume/pause/stream | `download_manager_bt*` / libtorrent / stream |
| 2.5 | HTTP/m3u8 pipeline glue | startHttp / download file / throttle | `*_http_*` / `*_m3u8_*` |
| 2.6 | settings 面整理 | setDownloadDir/settings/limits | 设置相关测或手动 |
| 2.7 | Manager 瘦身验收 | 对外 API 清单核对 | full download test suite |

**Phase 2 完成定义**

- [ ] `download_manager.dart` 以 façade + 委托为主
- [ ] `test/services/download/**` 全绿
- [ ] 公共方法签名不变

---

### Phase 3 — `generic_scraper` 模块化（约 2–4 天）

| # | 步骤 | 说明 |
|---|------|------|
| 3.1 | 建 `generic_scraper/` 目录，`mod.rs` 先 `include!` 或整体 move 再切 | 先保证编译 |
| 3.2 | 抽出 `types.rs` | 所有 struct/enum |
| 3.3 | 抽出 `matching.rs` + 单测 | score / episode / chinese number |
| 3.4 | 抽出 `region.rs`、`headers_cookies.rs` | |
| 3.5 | 抽出 `episode_table.rs`、`source_config.rs` | 缓存路径逻辑小心 |
| 3.6 | 抽出 search 三件套：`search_play` / `search_progress` / `search_channels` | 保持 pub API |
| 3.7 | 门面 re-export；`api/mod.rs` 路径保持 `generic_scraper` | Dart 零改 |
| 3.8 | `cargo test` / 集成冒烟：generic search + config update | |

**完成定义**：单文件 ~4500 行变为多模块；FRB 表面不变；搜索链路可用。

---

### Phase 4 — `bangumi` + `crawler`（约 2–4 天，可并行）

**4a bangumi**

| # | 步骤 |
|---|------|
| 4a.1 | `types` + `util` + `markup`（markup 先加/迁测） |
| 4a.2 | fetch 按资源切分（episodes/characters/comments/...） |
| 4a.3 | character/person detail + user |
| 4a.4 | re-export 验收 |

**4b crawler**

| # | 步骤 |
|---|------|
| 4b.1 | types + parse_time |
| 4b.2 | schedule_api（archive/schedule） |
| 4b.3 | bangumi_data_store（download/marker/cache slot） |
| 4b.4 | sites_index + fill_details |
| 4b.5 | 注意 single-flight / generation 失效语义原样保留 |

**完成定义**：两套 API 门面稳定；档期页与条目详情数据路径冒烟。

---

### Phase 5 — Bangumi 详情 UI（约 1–3 天）

| # | 步骤 |
|---|------|
| 5.1 | 抽 person-aware text / infobox helpers |
| 5.2 | 抽 header / summary / tags 等 section widgets |
| 5.3 | 抽 comments / characters / sites sections |
| 5.4 | mobile / wide layout 文件 |
| 5.5 | page 只保留 controller 与 layout 选择 |

**完成定义**：详情页文件显著变短；controller 测试绿；双布局冒烟。

---

### Phase 6 — Captcha job runner（约 1–2 天）

| # | 步骤 |
|---|------|
| 6.1 | types/enums/candidates 迁出 |
| 6.2 | search flow / detail flow 迁出 |
| 6.3 | Runner 保留编排；与 Phase 1 captcha coordinator 对齐调用 |
| 6.4 | 联调 captcha 源 |

---

### Phase 7 — 收尾与规范（约 0.5–1 天）

| # | 任务 |
|---|------|
| 7.1 | 更新本清单：勾选完成项、记录偏差 |
| 7.2 | 在 `CLAUDE.md` 或贡献文档加一句：新代码优先落在子模块，禁止把逻辑堆回 page/manager 桶 |
| 7.3 | 删除过时注释/重复 re-export |
| 7.4 | （可选）对 P3 文件建「触达再拆」清单，不主动开干 |

---

## 4. 每步标准作业程序（SOP）

对**每一个**拆分 PR/commit：

1. **锁定边界**：列出将迁移的类型/函数名单（可贴在 PR 描述）。
2. **先搬后改**：纯移动 + 必要 `pub`/`import`，不改行为。
3. **编译**：Dart `analyze` / Rust `cargo check`。
4. **测**：相关单测；没有则补最小 pure 测。
5. **冒烟**：该阶段「完成定义」中的手动路径。
6. **提交**：`refactor(scope): extract X from Y` 一类信息。
7. **禁止**：同 PR 修 bug + 大拆（bugfix 另开）。

### Rust 拆分特别注意

- 优先 `generic_scraper/mod.rs` 模式，对外模块名不变。
- FRB 导出函数保持在原模块路径下可见（`pub use`）。
- 条件编译、`static` 单例、`Semaphore` single-flight 一并迁移，勿拆丢。

### Dart 拆分特别注意

- `DownloadManager` / `PlayerPage` 的**调用方 API** 优先稳定。
- private 类（`_Foo`）迁出后若需跨文件，改为 public 或 `part`（优先独立库文件 + public，少用 `part` 扩散）。
- 避免循环 import：loader/coordinator 不 import page；page import 它们。

---

## 5. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 拆分时改变时序（搜索/captcha/pool） | 先 move；回调签名原样；Phase 1 加强手动冒烟 |
| FRB/codegen 路径变化 | 模块名不变 + `pub use`；避免改函数名 |
| 测试紧耦合 private 状态 | 测 coordinator 的 public 行为；必要时 `@visibleForTesting` |
| 大 PR 无法 review | 严格按 1.x / 2.x 小步 |
| 并行改业务功能 | 业务修在 main 线小 PR；拆分分支定期 rebase |

---

## 6. 建议实施顺序（一页纸）

```text
Week 1:  Phase 0 + Phase 1.1–1.4（side panel / BT / captcha / search）
Week 2:  Phase 1.5–1.8 + Phase 2（player 收尾 + download）
Week 3:  Phase 3（generic_scraper）
Week 4:  Phase 4（bangumi + crawler）± Phase 5（details UI）
Buffer:  Phase 6 + 7
```

若人力有限：**只做 Phase 1 + 2** 已能覆盖最大痛点（~7000 + ~2600 行 Dart 热点）。

---

## 7. 任务勾选清单（执行用）

### Phase 0
- [ ] 0.1 清单确认
- [ ] 0.2 基线测试
- [ ] 0.3 命名约定
- [ ] 0.4（可选）职责注释分区

### Phase 1 Player
- [x] 1.1 side panel loader
- [x] 1.2 BT source loader
- [x] 1.3 captcha preflight coordinator — queue / active / runtime override 只能通过 coordinator 修改，对外为只读视图
- [x] 1.4 search session coordinator — stream subscription 生命周期、generation guard、error/done 路径已有单测；State 编排在独立 search host
- [x] 1.5 webview pool glue 收敛 — scheduler、pump、result/idle host 与 runner widget 分文件，page 只持有 scheduler 状态和生命周期接线
- [x] 1.6 autoplay — candidate/cancel policy 在 coordinator，probe/open/cancel 编排迁入独立 autoplay host
- [x] 1.7 build sections — mobile/PC layout、video area、source/sample panel、WebView runners、side panels 均已迁出 page；可复用叶子继续使用独立 widget
- [x] 1.8 清理与验证 — `player_page.dart` 约 500 行；`flutter analyze` 与 `test/ui/pages/player/**` 全绿

实现说明：需要直接访问 `_PlayerPageState`、`mounted`、media_kit 或 WebView widget
生命周期的代码使用同一 library 的 `part` + extension host 分区，以保持原时序和 private
边界；纯状态、策略和可复用 UI 继续使用独立 controller/coordinator/widget 文件。设备手动冒烟
仍需在可运行桌面/Android 环境执行。

**Phase 1 补充（审查后）：** UI-only part 已继续下沉为独立 StatelessWidget
（`player_video_area` / `player_source_selector` / `player_sample_source_panel` /
`player_mobile_layout` / `player_pc_layout`），page part 只保留 glue；新增
`test/ui/pages/player/widgets/player_layout_widgets_test.dart` 覆盖布局冒烟。
lifecycle host（search/autoplay/webview/playback/episode）仍保留为 part。

### Phase 2 Download
- [ ] 2.1 path utils
- [ ] 2.2 Android bridge
- [ ] 2.3 stats poller
- [ ] 2.4 BT session
- [ ] 2.5 HTTP/m3u8 pipeline
- [ ] 2.6 settings
- [ ] 2.7 API 验收 + 全量 download 测

### Phase 3 generic_scraper
- [ ] 3.1 目录/mod 骨架
- [ ] 3.2 types
- [ ] 3.3 matching + tests
- [ ] 3.4 region / headers
- [ ] 3.5 episode table / source config
- [ ] 3.6 search_* 模块
- [ ] 3.7 re-export
- [ ] 3.8 cargo + 冒烟

### Phase 4 Rust API
- [ ] 4a bangumi 模块化
- [ ] 4b crawler 模块化

### Phase 5–7
- [ ] 5 bangumi details UI
- [ ] 6 captcha job runner
- [ ] 7 收尾与规范

---

## 8. 附录：现有可复用资产

**Player 已存在**

- Controllers / scheduler / policy / widgets 见 `lib/ui/pages/player/`
- 测试见 `test/ui/pages/player/`

**Download 已存在**

- `lib/services/download/*`（task、queue、http、m3u8、bt backends、cleanup…）
- 测试见 `test/services/download/`

**Rust API 入口**

- `rust/src/api/mod.rs` 当前为扁平 `pub mod ...`；拆分后保持同名模块即可。

---

*本文档只描述拆分规划，不包含行为变更。执行中若发现某块内聚过强（例如 matching 全套），允许保持单文件，在清单中标注「有意不拆」。*
