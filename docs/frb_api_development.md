# FRB 稳定桥接层开发约定

本文件记录 `rust/src/frb_api/` 稳定桥接层的可见性合约。任何修改 FRB
桥接层或新增 Dart 可调用函数的开发者必须遵守本约定。

## 模块布局

```text
Dart 业务代码
   │  import 'package:mikan_player/src/rust/api/bangumi.dart'  (手写 barrel)
   ▼
lib/src/rust/api/bangumi.dart           ← 手写 barrel，re-export 新 wrapper
   │  export '../frb_api/bangumi.dart';
   │  export 'bangumi/types.dart';
   ▼
lib/src/rust/frb_api/bangumi.dart       ← frb 自动生成（wrapper）
   │  RustLib.instance.api.crateFrbApiBangumi...
   ▼  (flutter_rust_bridge codegen)
rust/src/frb_api/bangumi.rs             ← 手写 wrapper，仅参数与返回值转发
   │  pub async fn fetch_bangumi_episodes(...)
   │      -> anyhow::Result<Vec<crate::api::bangumi::BangumiEpisode>>
   │  { crate::api::bangumi::fetch_bangumi_episodes(...).await }
   ▼
rust/src/api/bangumi.rs                 ← facade，pub(crate) use 重导出
   ▼
rust/src/api/bangumi/fetch_episodes.rs  ← 实现，pub(crate) async fn
```

允许的调用方向：

```text
Dart  →  frb_api::wrapper  →  api facade  →  implementation submodule
```

禁止方向：

```text
Dart / FRB  ─✗→  实现 submodule 直接调用
api 实现 submodule  ─✗→  Dart / FRB 直接暴露
```

## 可见性规则

| 层级 | 默认可见性 | 备注 |
| --- | --- | --- |
| `rust/src/frb_api/*.rs` 中的 wrapper 函数 | `pub` | 唯一允许 FRB 扫描并暴露给 Dart 的 `pub` 函数。 |
| `rust/src/api/*/*.rs` 中的实现函数 | `pub(crate)` | 即使被 `frb_api` 引用，也保持 `pub(crate)`，FRB 不应再次扫描。 |
| `rust/src/api/{bangumi,crawler,generic_scraper}/types` 模块 | `pub(crate) mod types` | DTO 类型本身保持 `pub`，让生成代码可访问，但模块本身不可见。 |
| `rust/src/api/network.rs` 的网络 Client 与重试 helper | `pub(crate)` | 一律不导出到 Dart。`get_system_proxy` 是当前唯一例外，通过 `frb_api::network::get_system_proxy` wrapper 暴露。 |
| `rust/src/api/mod.rs` 中模块声明 | `pub mod` | facade 模块本身对 crate 公开，但其内容仍然只对 crate 公开。 |

## FRB codegen 输入

`flutter_rust_bridge.yaml`：

```yaml
rust_input: "crate::frb_api, crate::api::bangumi_graphql, crate::api::captcha, crate::api::config, crate::api::danmaku, crate::api::dmhy, crate::api::ech, crate::api::mikan, crate::api::ranking, crate::api::simple"
```

迁移完成后 `rust_input` 将进一步收紧为：

```yaml
rust_input: "crate::frb_api"
```

当前已经完成 bangumi、crawler、generic_scraper 和 network 四个问题域的迁移，
共包含 51 个 wrapper（15 + 17 + 18 + 1）。其余 allowlist 模块仍由 FRB
直接扫描，因此整个 crate 的桥接层迁移尚未完成。

`stop_on_error: true` 必须在所有 API 模块都迁入 `frb_api` 之后再启用。在此之前，
未迁移模块中可能仍存在 FRB 不支持的签名，启用会导致 codegen 失败。

## 新增 Dart 可调用函数的步骤

1. 在对应的 `rust/src/api/<域>/<实现>.rs` 中实现，使用 `pub(crate) async fn`。
2. 在 `rust/src/api/<域>.rs` facade 增加 `pub(crate) use`。
3. 在 `rust/src/frb_api/<域>.rs` 增加 wrapper：函数名、参数名、参数类型、返回类型
   与实现一致；wrapper 不写业务逻辑，只转发。
4. 执行 `tool/check_frb_codegen.ps1`。脚本允许当前开发工作区包含未提交修改，
   会连续执行两次 codegen + cargo fmt 并比较快照，然后验证 cargo check、
   cargo fmt --check 和 flutter analyze。
5. 如果函数返回新增 DTO，DTO 必须：
   - 在 `<域>/types.rs` 中以 `pub struct` 声明；
   - `types` 模块本身是 `pub(crate) mod types;`；
   - 不在 `frb_api` wrapper 中重新声明 DTO；
   - 在 `lib/src/rust/api/<域>.dart` barrel 中通过
     `export '<域>/types.dart';` 暴露给 Dart。
6. 业务代码继续从历史 import 路径 `package:mikan_player/src/rust/api/<域>.dart`
   导入；不要让业务代码直接 import `lib/src/rust/frb_api/<域>.dart` 或
   `lib/src/rust/api/<域>/types.dart`，否则会绕过 barrel 破坏稳定层。

## 手写 Barrel 的维护

`lib/src/rust/api/{bangumi,crawler,generic_scraper,network}.dart` 是手写
barrel，不是 frb 生成产物：

- 不带 `@generated` 标记。
- 不被 `flutter_rust_bridge_codegen` 覆盖（因为 `crate::api::{bangumi,
  crawler, generic_scraper}` 已从 `rust_input` 中移除）。
- 内容仅为 `export '../frb_api/<域>.dart';` 和必要的 `export '<域>/types.dart';`。
- 新增 wrapper 不需要修改 barrel，自动通过 `export '../frb_api/<域>.dart'`
  得到。
- 删除 wrapper 时若其返回的 DTO 也无人使用，需要同时删除对应的
  `export '<域>/types.dart';`，并从 `rust/src/api/<域>/types.rs` 中移除
  DTO。

## 永不导出到 Dart 的内部基础设施

以下 Rust 内部 helper 一律不作为 Dart API：

- `crate::api::network::get_shared_client`
- `crate::api::network::invalidate_ech_client`
- `crate::api::network::get_ech_client`
- `crate::api::network::client_for_bangumi`
- `crate::api::network::create_client`
- `crate::api::network::retry_request*`
- `crate::api::generic_scraper::*` 内部 parser、matcher、region helper
- `crate::api::crawler::*` 内部 download / single-flight helper

返回 `&'static Client` 的函数尤其不应被 FRB 扫描，FRB 会把这类引用返回
错误翻译成 `Future<void>`，从而误导 Dart 调用方。

## 验收脚本

本地开发执行：

```powershell
tool/check_frb_codegen.ps1
```

CI 或提交后的干净工作区执行：

```powershell
tool/check_frb_codegen.ps1 -RequireClean
```

脚本执行以下检查：

1. `-RequireClean` 模式下，codegen 前工作区必须干净；
2. 连续执行两次 `flutter_rust_bridge_codegen generate` + `cargo fmt`；
3. 比较两次执行后的 Rust/Dart bridge 文件 SHA-256 快照；
4. `cargo check`；
5. `cargo fmt --check`；
6. `flutter analyze`；
7. `-RequireClean` 模式下，最终 `git status --short` 必须为空。

本地模式用于提交前验证，允许第一次 codegen 产生预期的生成文件修改；
`-RequireClean` 模式用于确认已提交的生成产物没有漂移。

## 提交建议

修复本次 codegen 失败并落地稳定桥接层，建议拆成四个提交（见
`docs/frb_api_migration_plan.md` 中"建议提交拆分"）：

1. `fix(frb): restore generated baseline before facade migration`
2. `refactor(frb): add stable bridge facade for split api modules`
3. `refactor(frb): regenerate bindings behind stable dart barrels`
4. `ci(frb): verify codegen is clean and reproducible`
