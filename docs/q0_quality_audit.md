# Q-0 本地质量审计

> 执行日期：2026-07-20
> 范围：全量回归、覆盖率审计、稳定性缺陷清单、本地门禁
> 决策：本批不接入 CI，不修改 `.github/workflows/**`

## 1. 结论

Q-0 的本地验收项已经通过：l10n 可生成、硬编码严格扫描为零、Flutter analyze 无问题、
Flutter/Rust 默认测试全绿，真实网络 smoke test 与默认测试保持分离。新增
[`tool/run_q0_quality_gate.ps1`](../tool/run_q0_quality_gate.ps1) 作为可重复执行的本地门禁。

本轮没有发现新的产品缺陷。缺陷日志审计发现 RT-2 的 3 条记录缺少“影响”字段，已补齐。

## 2. 最终回归

| 门禁 | 结果 |
|---|---|
| `flutter gen-l10n` | 通过，无生成错误 |
| `dart run tool/scan_hardcoded_ui_text.dart --fail-on-findings` | 118 个 Dart UI 文件，high 0 / medium 0 |
| `flutter analyze` | 0 issue |
| `flutter test --no-pub` | 1307 passed |
| `cargo fmt --manifest-path rust/Cargo.toml -- --check` | 通过 |
| `cargo test --manifest-path rust/Cargo.toml` | 223 passed / 2 ignored |
| `tool/check_frb_codegen.ps1` | RT-6 已验证两遍 codegen 幂等，本轮脚本保留可选复核入口 |

Rust 的 2 个 ignored 测试仍是 danmaku 与 ECH 真实网络 smoke test，不进入默认门禁。

## 3. Dart 覆盖率

命令：

```powershell
flutter test --coverage --no-pub
```

统计排除 `lib/gen/**`、`lib/src/rust/**` 和 `*.g.dart`。Flutter LCOV 只统计被测试载入并插桩的
可执行行，因此本节用于定位空洞，不设全仓统一失败阈值。

| 指标 | 结果 |
|---|---:|
| 生产 Dart 文件触达 | 192 / 196（97.96%） |
| 已插桩行覆盖 | 10,504 / 25,431（41.30%） |

| 模块 | 行覆盖 |
|---|---:|
| models | 88 / 88（100.00%） |
| services/download | 1,681 / 2,379（70.66%） |
| services/cache | 919 / 1,447（63.51%） |
| services/other | 1,911 / 3,693（51.75%） |
| ui/pages/player | 2,245 / 4,994（44.95%） |
| ui/pages/other | 2,751 / 9,302（29.57%） |
| ui/widgets | 840 / 2,875（29.22%） |
| utils | 59 / 82（71.95%） |

未进入 LCOV 的 4 个文件是独立 OCR 入口、BT capability 接口、cache export 文件和编译期
feature flag。当前主要剩余风险不是文件完全不可达，而是大型 UI/页面 host 的失败分支和平台交互
仍只被 controller、pure helper 或局部 Widget 测试间接覆盖。

## 4. Rust 覆盖率

本地审计使用 `cargo-llvm-cov 0.8.7`，排除 `frb_generated.rs` 和 `build.rs`：

```powershell
rustup component add llvm-tools-preview
cargo install cargo-llvm-cov --locked --root build/q0-tools
build\q0-tools\bin\cargo-llvm-cov.exe llvm-cov `
  --manifest-path rust/Cargo.toml `
  --json --summary-only `
  --output-path build/q0-rust-coverage.json `
  --ignore-filename-regex "(frb_generated\.rs|build\.rs)" `
  --quiet
```

| 指标 | 结果 |
|---|---:|
| 行覆盖 | 10,897 / 15,409（70.72%） |
| 函数覆盖 | 1,200 / 1,741（68.93%） |
| LLVM region 覆盖 | 16,860 / 23,906（70.53%） |

| 模块 | 行覆盖 | 函数覆盖 |
|---|---:|---:|
| api/bangumi | 82.39% | 90.91% |
| api/crawler | 69.76% | 69.90% |
| api/generic_scraper | 68.55% | 65.71% |
| api/other | 70.14% | 66.30% |
| frb_api | 42.26% | 38.40% |
| root/other | 95.78% | 84.21% |

剩余高价值空洞：

- `generic_scraper/region.rs` 行覆盖 4.2%。真实 endpoint race、超时和进程级缓存缺少可注入的
  loopback seam；默认测试保持离线，因此没有直接调用公网探测。
- `simple.rs` 行覆盖 22.6%。低值主要来自真实 librqbit session、固定本地 HTTP 端口和 native
  torrent 生命周期；这些路径不适合默认单元测试，应单独做 native 集成测试。
- `frb_api/**` 行覆盖 42.26%。多数未覆盖代码是无错误返回的薄 wrapper；参数校验、错误映射、
  DTO 往返和取消语义已在 RT-6 覆盖。
- `search_progress.rs`、`fill_details.rs` 等大型状态机仍有未覆盖组合分支，后续优先按失败语义补洞，
  不以全仓百分比为目标。

## 5. 缺陷清单审计

`docs/stability_findings.md` 当前共 73 条缺陷记录：

| 类别 | 数量 |
|---|---:|
| F-0 测试基础设施 | 3 |
| L10N | 14 |
| Dart 稳定性 | 20 |
| Rust 稳定性 | 36 |

每条记录均包含现象、根因、影响、修复、回归测试和迁移/回滚说明。Q-0 修复了
RT-2-003～RT-2-005 缺少影响字段的文档完整性问题，没有删除或合并历史缺陷。

## 6. Clippy 基线

`cargo clippy --all-targets -- -D warnings` 当前失败，基线为 89 个 lint。主要是
`collapsible_if`、文档格式、`needless_*` 和少量 API 形状 lint，没有编译错误或测试失败。

按原计划，Clippy 暂不加入硬门禁。清理时应作为独立任务处理，避免为满足 lint 大范围改写已验证的
parser/state-machine 代码。

## 7. 本地门禁

常规全量门禁：

```powershell
powershell -ExecutionPolicy Bypass -File tool/run_q0_quality_gate.ps1
```

附带两端覆盖率：

```powershell
powershell -ExecutionPolicy Bypass -File tool/run_q0_quality_gate.ps1 -Coverage
```

需要复核 FRB codegen 幂等时追加：

```powershell
powershell -ExecutionPolicy Bypass -File tool/run_q0_quality_gate.ps1 -CheckFrbCodegen
```

## 8. 延后项

- CI 接入按本轮决策延后；仓库没有新增或修改 workflow。
- Clippy 89 个历史 lint 作为独立清理任务，不阻塞 Q-0。
- region detector loopback seam、native librqbit 集成测试和大型 UI host 失败分支进入后续风险清单。
- 可选 RT-7 属性/模糊测试仍不属于默认门禁。
