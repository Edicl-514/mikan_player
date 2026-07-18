# FRB 稳定桥接层迁移计划

## 当前实施状态（2026-07-18）

bangumi、crawler、generic_scraper 和 network 四个问题域的稳定桥接层已经完成，
共包含 51 个 wrapper（15 + 17 + 18 + 1）。对应实现已收紧为
`pub(crate)`，Dart 历史 import 由手写 barrel 保持兼容，并已通过 Rust、
Dart 和 codegen 幂等性验证。

以下长期收口项仍待完成，因此不应将整个 crate 的八阶段迁移标记为全部完成：

- 将 `bangumi_graphql`、`captcha`、`config`、`danmaku`、`dmhy`、`ech`、
  `mikan`、`ranking` 和 `simple` 迁入 `crate::frb_api`；
- 将 `rust_input` 最终缩减为单一的 `crate::frb_api`；
- 在全部 API 进入 facade 后启用 `stop_on_error: true`；
- 将 `tool/check_frb_codegen.ps1 -RequireClean` 接入实际 CI；
- 完成目标平台构建与人工冒烟测试。

下方清单保留为完整迁移与验收记录；四个问题域之外的项目仍是后续任务。

## 背景

当前 `flutter_rust_bridge_codegen 2.12.0` 使用以下配置扫描整个 Rust API：

```yaml
rust_input: "crate::api"
```

在 `bangumi`、`crawler` 和 `generic_scraper` 被拆分为 facade 与子模块后，FRB 会按照函数和类型的真实定义位置生成调用路径，而不会对当前 crate 中的 `pub use` 进行路径转换。

例如源码通过 facade 重新导出：

```rust
pub use fetch_episodes::fetch_bangumi_episodes;
```

FRB 仍可能生成：

```rust
crate::api::bangumi::fetch_episodes::fetch_bangumi_episodes(...)
```

由于 `fetch_episodes` 是私有子模块，新生成的 `frb_generated.rs` 无法访问它。与此同时，旧的聚合 Dart 文件没有被 codegen 删除，新生成的子目录文件又定义了另一套 DTO，最终造成：

- Rust 生成代码访问私有模块；
- Dart 旧方法名失效；
- 相同名称的 DTO 来自不同 Dart library，类型互不兼容；
- `pub fn` 形式的内部网络 Client helper 被误识别为 Dart API；
- 返回 `&'static Client` 的函数被错误映射为 `Future<void>`。

本计划采用专用 FRB 桥接层，将对 Dart 的稳定 API 与 Rust 内部实现彻底分离。

## 目标

- Rust 实现文件可以继续拆分、重命名和调整目录，不影响 Dart API。
- FRB 只扫描明确允许导出的 wrapper。
- 网络 Client、重试函数和其他内部 helper 永远不会导出到 Dart。
- 现有 Dart 业务代码继续使用稳定的聚合导入路径。
- 每个迁移阶段都能独立通过 `cargo check` 和 `flutter analyze`。
- codegen 可以重复执行，第二次执行不会产生额外 diff。

## 目标目录结构

```text
rust/src/
├── lib.rs
├── frb_api.rs
├── frb_api/
│   ├── bangumi.rs
│   ├── crawler.rs
│   ├── generic_scraper.rs
│   └── network.rs
└── api/
    ├── bangumi.rs
    ├── bangumi/
    ├── crawler.rs
    ├── crawler/
    ├── generic_scraper.rs
    ├── generic_scraper/
    └── network.rs
```

职责划分：

| 层级 | 可见性 | 职责 |
| --- | --- | --- |
| `frb_api/*` | `pub` | 唯一允许 FRB 扫描的函数 |
| `api/*` 实现函数 | `pub(crate)` | Rust crate 内部调用 |
| 网络 Client/helper | `pub(crate)` | Rust 内部基础设施，不导出到 Dart |
| DTO 类型模块 | `pub(crate) mod` | 允许生成代码访问，但不公开模块 |
| Dart `api/bangumi.dart` 等 | 手写 barrel | 保持现有业务导入路径稳定 |

## 阶段一：恢复可编译基线

- [ ] 恢复本次失败生成的 `rust/src/frb_generated.rs`。
- [ ] 恢复 `lib/src/rust` 下被本次 codegen 修改的生成文件。
- [ ] 删除本次 codegen 新增的以下生成目录：
  - `lib/src/rust/api/bangumi/`
  - `lib/src/rust/api/crawler/`
  - `lib/src/rust/api/generic_scraper/`
- [ ] 保留 `network.rs` 中有意义的源码修改，不直接修改生成文件解决问题。
- [ ] 执行 `cargo check --manifest-path rust/Cargo.toml`。
- [ ] 执行 `flutter analyze`。
- [ ] 确认恢复到迁移前的可编译状态。
- [ ] 保存当前 Dart 对外函数和 DTO 签名，作为迁移前 API 快照。

## 阶段二：建立专用 FRB 入口

- [ ] 在 `rust/src/lib.rs` 中增加：

```rust
pub mod frb_api;
```

- [ ] 新建 `rust/src/frb_api.rs`。
- [ ] 新建以下分域 wrapper：
  - `rust/src/frb_api/bangumi.rs`
  - `rust/src/frb_api/crawler.rs`
  - `rust/src/frb_api/generic_scraper.rs`
  - `rust/src/frb_api/network.rs`
- [ ] wrapper 只负责参数和返回值转发，不包含业务逻辑。
- [ ] wrapper 保持当前函数名、参数名、参数类型、返回类型和 Stream 行为不变。
- [ ] 在 wrapper 中使用 `crate::api::*` 调用内部实现，不直接依赖更深的实现文件布局。

建议的 `frb_api.rs` 结构：

```rust
pub mod bangumi;
pub mod crawler;
pub mod generic_scraper;
pub mod network;
```

## 阶段三：迁移当前问题域 API

当前三个聚合 Dart API 文件共有 50 个函数需要保持兼容，加上 network 的
`get_system_proxy`，稳定桥接层合计 51 个 wrapper：

- [ ] Bangumi：15 个函数。
- [ ] Crawler：17 个函数。
- [ ] Generic scraper：18 个函数。
- [ ] Network：只导出业务实际使用的 `get_system_proxy`（总计第 51 个 wrapper）。

### Bangumi wrapper

- [ ] `fetch_bangumi_episodes`
- [ ] `fetch_bangumi_characters`
- [ ] `fetch_bangumi_relations`
- [ ] `fetch_bangumi_comments`
- [ ] `fetch_bangumi_persons`
- [ ] `fetch_bangumi_episode_comments`
- [ ] `fetch_character_details`
- [ ] `fetch_person_details`
- [ ] `fetch_person_subjects`
- [ ] `fetch_person_characters`
- [ ] `fetch_character_subjects`
- [ ] `fetch_bangumi_user_info`
- [ ] `fetch_bangumi_user_collections`
- [ ] `fetch_bangumi_subject_image`
- [ ] `fetch_bangumi_image_url`

### Crawler wrapper

- [ ] `fetch_archive_list`
- [ ] `fetch_schedule_basic`
- [ ] `fetch_schedule_basic_api_only`
- [ ] `fetch_schedule_basic_from_local_json`
- [ ] `fetch_schedule_basic_from_local_json_nodl`
- [ ] `spawn_sites_index_background`
- [ ] `build_sites_index`
- [ ] `invalidate_sites_index`
- [ ] `fetch_bangumi_data_sites`
- [ ] `fetch_bangumi_data_sites_by_mikan`
- [ ] `lookup_mikan_id`
- [ ] `fill_anime_details`
- [ ] `fetch_light_subject_details`
- [ ] `fetch_extra_subjects`
- [ ] `get_bangumi_data_cache_status`
- [ ] `refresh_bangumi_data_cache`
- [ ] `ensure_bangumi_data_cache`

### Generic scraper wrapper

- [ ] `invalidate_source_config_cache`
- [ ] `refresh_playback_source_config`
- [ ] `preload_playback_sources`
- [ ] `get_playback_sources`
- [ ] `update_single_source_config`
- [ ] `add_source_config`
- [ ] `generic_search_play_pages`
- [ ] `generic_search_play_pages_stream`
- [ ] `get_enabled_source_names`
- [ ] `generic_search_with_progress`
- [ ] `generic_search_with_progress_runtime`
- [ ] `debug_search_with_local_json`
- [ ] `debug_search_with_local_json_runtime`
- [ ] `generic_search_and_play_with_episode`
- [ ] `generic_search_and_play`
- [ ] `generic_search_with_channels`
- [ ] `generic_search_with_channels_stream`
- [ ] `get_episode_play_url`

### Network wrapper

- [ ] 只导出 `get_system_proxy`。
- [ ] 不导出 `get_shared_client`。
- [ ] 不导出 `get_ech_client`。
- [ ] 不导出 `client_for_bangumi`。
- [ ] 不导出 `retry_request*`。
- [ ] 不导出 `create_client`。
- [ ] 不导出 `select_client`。

当前 Dart 业务代码只使用 `getSystemProxy`。其余返回 Client 引用并被生成为 `Future<void>` 的函数属于误导出，不作为兼容 API 保留。

## 阶段四：收紧 Rust 可见性

- [ ] 被 `frb_api` wrapper 调用的实现函数由 `pub` 改为 `pub(crate)`。
- [ ] facade 中相应的 `pub use` 改为 `pub(crate) use`。
- [ ] `network.rs` 中的 Client 和重试 helper 改为 `pub(crate)`。
- [ ] 再次确认 `select_client` 没有 Rust 调用方。
- [ ] 无调用方时删除 `select_client`；仍有调用方时保留为 `pub(crate)`。
- [ ] 将以下 DTO 模块改为 crate 内可见：

```rust
pub(crate) mod types;
```

- [ ] `bangumi::types`
- [ ] `crawler::types`
- [ ] `generic_scraper::types`
- [ ] DTO struct/enum 本身暂时保持 `pub`，确保生成代码可以访问并实现编解码 trait。
- [ ] 其他实现子模块继续使用私有 `mod`。
- [ ] 检查 `api::simple` 等 Rust 内部调用方仍能通过 facade 调用实现函数。

可见性约束：

```text
Dart -> frb_api::wrapper -> api facade -> implementation
```

禁止：

```text
Dart/FRB -> api implementation submodule
```

## 阶段五：收窄 codegen 输入

迁移期间先使用显式 allowlist，排除发生问题的实现模块：

```yaml
rust_input: "crate::frb_api, crate::api::bangumi_graphql, crate::api::captcha, crate::api::config, crate::api::danmaku, crate::api::dmhy, crate::api::ech, crate::api::mikan, crate::api::ranking, crate::api::simple"
```

- [ ] 确认不再扫描 `crate::api::bangumi`。
- [ ] 确认不再扫描 `crate::api::crawler`。
- [ ] 确认不再扫描 `crate::api::generic_scraper`。
- [ ] 确认不再扫描 `crate::api::network`。
- [ ] 后续逐步把剩余 API 模块也迁入 `crate::frb_api`。
- [ ] 全部迁移完成后，将配置缩减为：

```yaml
rust_input: "crate::frb_api"
```

- [ ] 全部 API 都进入专用 facade 后启用：

```yaml
stop_on_error: true
```

在迁移完成前不宜立即启用 `stop_on_error`，因为现有其他模块中可能仍有 FRB 不支持的公开函数签名。

## 阶段六：保持 Dart 导入兼容

现有业务代码广泛使用以下导入路径：

```dart
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
```

这些业务导入路径保持不变。

- [ ] 将 `lib/src/rust/api/bangumi.dart` 改成手写 barrel。
- [ ] 将 `lib/src/rust/api/crawler.dart` 改成手写 barrel。
- [ ] 将 `lib/src/rust/api/generic_scraper.dart` 改成手写 barrel。
- [ ] 删除这三个文件顶部的 `@generated` 标记。
- [ ] barrel 只导出新 wrapper 和对应 DTO。

示例：

```dart
export '../frb_api/bangumi.dart';
export 'bangumi/types.dart';
```

- [ ] 检查业务代码没有直接调用 `RustLib.instance.api.crate...`。
- [ ] 检查测试代码没有依赖低层生成方法名。
- [ ] 确认相同 DTO 只存在一个 Dart library 定义。
- [ ] 确认 `SourceState`、`AnimeInfo`、`BangumiEpisode` 等类型不再出现同名但不兼容的问题。

生成后的低层 `RustLibApi` 方法路径可能从 `crateApiBangumi...` 变成 `crateFrbApiBangumi...`。这是生成代码内部细节，只要顶层函数和 barrel 不变，业务代码无需修改。

## 阶段七：重新生成并检查输出

- [ ] 执行：

```powershell
flutter_rust_bridge_codegen generate
```

- [ ] 检查生成日志中不再出现以下引用返回值提示：
  - `client_for_bangumi`
  - `get_ech_client`
  - `get_shared_client`
- [ ] 检查 Dart 不再生成：
  - `getSharedClient`
  - `getEchClient`
  - `clientForBangumi`
  - `selectClient`
- [ ] 检查 `frb_generated.rs` 中桥接函数调用全部指向 `crate::frb_api::*`。
- [ ] DTO 路径可以指向 `crate::api::*::types::*`，但对应类型模块必须是 `pub(crate)`。
- [ ] 检查生成代码没有调用私有实现子模块中的函数。
- [ ] 检查没有重新覆盖三个手写 Dart barrel。
- [ ] 清理不再使用的旧生成文件。
- [ ] 连续执行两次 codegen，确认第二次执行不会产生额外 diff。

## 阶段八：验收门禁

每完成一个迁移阶段都执行以下检查。

### Rust

- [ ] `cargo fmt --check --manifest-path rust/Cargo.toml`
- [ ] `cargo check --manifest-path rust/Cargo.toml`
- [ ] Rust 单元测试通过。
- [ ] 没有 `deprecated` warning。
- [ ] 没有 FRB reference-output/lifetime 提示。
- [ ] 没有私有模块访问错误。

### Dart/Flutter

- [ ] `flutter analyze`
- [ ] Bangumi 相关测试通过。
- [ ] Crawler 相关测试通过。
- [ ] 播放器与 Generic scraper 相关测试通过。
- [ ] 完整 `flutter test` 通过。
- [ ] analyzer 不再报告同名 DTO 类型不兼容。

### 构建和运行

- [ ] Windows 或 Android 至少完成一次实际构建。
- [ ] 应用启动时 `getSystemProxy` 正常工作。
- [ ] Bangumi 详情、时间表和播放源搜索进行基本冒烟测试。
- [ ] Stream API 能正常推送进度和搜索结果。

## 完成标准

- [ ] `cargo check` 通过且无相关 warning。
- [ ] `flutter analyze` 为 0 error。
- [ ] 完整测试通过。
- [ ] 当前业务 Dart import 无需批量修改。
- [ ] FRB 不再扫描内部网络 Client/helper。
- [ ] 生成代码不访问私有实现函数。
- [ ] 再次拆分 Rust 实现文件时，Dart 顶层 API 不发生变化。
- [ ] codegen 可重复执行且结果稳定。

## 防回归措施

- [ ] 新增 `tool/check_frb_codegen.ps1`。
- [ ] 脚本在本地模式连续执行两次 codegen + fmt 并比较文件快照。
- [ ] 脚本在 `-RequireClean` 模式检查生成文件是否出现未提交 diff。
- [ ] CI 加入 `cargo check`。
- [ ] CI 加入 `flutter analyze`。
- [ ] CI 加入 codegen 后工作区 clean 检查。
- [ ] 保存一份 FRB 顶层函数签名快照或 golden 文件。
- [ ] 在开发文档中写明：实现函数默认使用 `pub(crate)`。
- [ ] 在开发文档中写明：只有 `frb_api` 中的函数允许作为 Dart API 使用 `pub`。
- [ ] 新增 Dart 可调用函数时，必须先更新桥接契约和对应测试。

## 建议提交拆分

为方便审查和回退，建议拆成四个提交：

1. `fix(frb): restore generated baseline before facade migration`
   - 恢复可编译生成文件。
   - 清理失败 codegen 产生的文件。

2. `refactor(frb): add stable bridge facade for split api modules`
   - 新增 `frb_api`。
   - 增加 50 个兼容 wrapper。
   - 收紧实现函数和网络 helper 可见性。

3. `refactor(frb): regenerate bindings behind stable dart barrels`
   - 修改 codegen 输入。
   - 重新生成绑定。
   - 建立三个稳定 Dart barrel。
   - 修复生成路径和 DTO 可见性。

4. `ci(frb): verify codegen is clean and reproducible`
   - 增加 codegen 检查脚本。
   - 增加 CI 门禁。
   - 补充维护文档和 API 快照。

## 实施原则

1. 不手工修改 `frb_generated.rs` 解决长期问题。
2. 不让业务代码依赖 `RustLibApi` 的低层生成方法名。
3. 不把 Rust 内部模块布局视为 Dart API 的一部分。
4. wrapper 不包含业务逻辑，只定义稳定的跨语言契约。
5. 每个阶段先恢复绿灯，再继续下一阶段。
