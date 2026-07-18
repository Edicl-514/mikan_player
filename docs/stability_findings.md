# 稳定性发现日志（Stability Findings）

> 伴随 `docs/full_project_i18n_test_plan.md` 的工作包进展，按计划 §7 在本文件累积 bug 与回归信息：
> 现象、根因、影响、对应的回归测试名称与修复 commit/PR。

格式约定：每条目建议包含：

- ID（如 `F0-001`、`DT-2A-001`、`RT-1A-002`），用对应工作包前缀；
- 发现时间 / 工作包；
- 现象（最小复现或失败测试名）；
- 根因；
- 影响范围 / 用户可见后果；
- 修复（commit/PR/编辑文件）+ 保留的回归测试名；
- 是否涉及迁移/回滚路径，以及其验证方式。

---

## 现有记录

### F0-001 — `LocalHttpServer.ignoreBody` 未真正丢弃上传内容

- 工作包：F-0（复核修复，2026-07-18）
- 现象：传入 `ignoreBody: true` 后，服务仍把请求体完整缓存并交给 handler/ledger。
- 根因：参数只设置了字段，serve loop 未将其传递到 body snapshot 的读取逻辑。
- 影响：大上传 fixture 会意外占用测试进程内存，且 helper 行为与其文档不一致。
- 修复：`LocalHttpServerRequest.from` 支持无缓存 drain；`ignoreBody` 下 handler 与
  `recordedRequests` 均收到空 body。
- 回归测试：`ignoreBody drains uploads without retaining them`。
- 迁移/回滚：不涉及。

### F0-002 — `EventRecorder.expectInOrder` 不支持空期望序列

- 工作包：F-0（复核修复，2026-07-18）
- 现象：`expectInOrder([])` 访问第一个期望项时抛出越界异常。
- 根因：循环前未处理空列表。
- 影响：无法将空序列作为自然的「不要求特定调用顺序」断言。
- 修复：空期望序列直接成功返回。
- 回归测试：`expectInOrder accepts an empty expected sequence`。
- 迁移/回滚：不涉及。

### F0-003 — `equalsClockTime` 的精度契约未兑现

- 工作包：F-0（复核修复，2026-07-18）
- 现象：文档称忽略亚毫秒精度，实际按微秒精确比较。
- 根因：使用了 `DateTime.isAtSameMomentAs`。
- 影响：跨平台时间舍入差异可能导致不必要的测试失败。
- 修复：改为比较 `millisecondsSinceEpoch`。
- 回归测试：`equalsClockTime ignores microseconds within a millisecond`。
- 迁移/回滚：不涉及。

### L10N-2-001 — `EpisodeSidePanel` 标题行在英文 locale 下横向 overflow

- 工作包：L10N-2（2026-07-18）
- 现象：英文文案 `Episodes` + `{count} episodes` 与关闭按钮在 280px 侧栏内挤爆 `Row`，widget 测试报 `A RenderFlex overflowed by … pixels on the right`。
- 根因：标题与计数 `Text` 未包 `Flexible`/`Expanded`，固定宽度侧栏无法收缩长英文串。
- 影响：英文 locale 下选集侧栏标题可能被裁切并触发 layout exception（测试与调试构建可见黄黑条）。
- 修复：标题与计数各包 `Flexible`，并加 `TextOverflow.ellipsis`。
- 回归测试：`EpisodeSidePanel renders localized header in en`。
- 迁移/回滚：不涉及。
