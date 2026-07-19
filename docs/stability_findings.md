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

### L10N-3-001 — Bangumi 详情页缺日期时展示虚假占位日期

- 工作包：L10N-3（2026-07-18）
- 现象：`data['date']` 为空时，移动端详情 header 仍显示硬编码 `2026年 1月`。
- 根因：`mobile_layout.dart` 把未知日期回退到固定字面量，而不是隐藏日期芯片。
- 影响：无播出日期的作品会显示错误日期，用户可能误判放送信息。
- 修复：仅在 `data['date']` 存在时渲染日期徽章，并走 locale-aware `formatDateToMonth`。
- 回归测试：helpers 的 `formatDateToMonth` 单测 + 详情 widget 本地化 smoke；该分支为缺字段 UI 隐藏，无额外 mock 数据页测试。
- 迁移/回滚：不涉及。

### L10N-3-002 — ARB 中文错误文案误写英文

- 工作包：L10N-3（2026-07-18）
- 现象：`app_zh.arb` 的 `characterDetailsLoadFailed` / `personDetailsLoadFailed` 值为英文。
- 根因：早期占位文案未按模板 locale 补中文。
- 影响：中文 locale 下角色/人物详情加载失败提示显示英文。
- 修复：改为「角色详情加载失败」「人物详情加载失败」。
- 回归测试：`arb_consistency_test.dart`。
- 迁移/回滚：不涉及。

### L10N-5-001 — 旧版 player webview 控件无 tooltip / Semantics label

- 工作包：L10N-5（2026-07-19）
- 现象：`PlayerVideoArea` 的移动端顶栏 `IconButton`（返回 / more_vert）没有 `tooltip` 属性。屏幕阅读器朗读不到语义。
- 根因：L10N-2 之前这些按钮只关心可见图标，a11y 漏写。
- 影响：英文 / 中文 locale 下，TalkBack / VoiceOver 朗读按钮含义为「按钮」或「icon」，盲用户无法识别动作。
- 修复：返回按钮使用 `l10n.back`，更多按钮使用 `l10n.playerMoreOptions`，与现有
  `EpisodeSidePanel` / `SettingsPanel` 的 barrier 标签保持一致。
- 回归测试：玩家控件 bdd 集成于 `PlayerVideoArea` widget 测试；`flutter analyze` 通过；中英文 widget 渲染 smoke test 通过。
- 迁移/回滚：不涉及。

### L10N-5-002 — `PlayerSearchSessionCoordinator` 文案函数签名未带 l10n

- 工作包：L10N-5（2026-07-19）
- 现象：L10N-4 之后 `sampleSearchProgressLabel` / `sampleSearchFinishMessage` 仍是裸字符串构造函数，无法注入本地化文案。
- 根因：它们运行在 `PlayerPage` 之外的 pure helper 上下文里，无法直接 `AppLocalizations.of(context)`。
- 影响：扫描器仍能扫到 medium 候选；L10N-4 之后的新状态文案无法本地化。
- 修复：pure helper 只接收 UI 层 formatter / 已本地化的终态文案，不依赖
  `AppLocalizations`；调用方在 `PlayerPage` host 中完成本地化。
- 回归测试：`player_search_session_coordinator_test.dart` 使用 deterministic formatter
  验证参数顺序和分支选择。
- 迁移/回滚：不涉及（helper 调用方已知上下文）。

### L10N-5-003 — `playerSearchSessionProgressLine` ARB 缺 `@key` 元数据 → placeholder 顺序错乱

- 工作包：L10N-5（2026-07-19）
- 现象：仅声明 `"搜索进度: {completed}/{enabled}，验证码 {activeCaptcha} 运行/{pendingCaptcha} 排队"`，`gen-l10n` 按出现顺序生成参数，参数顺序是 `(activeCaptcha, completed, enabled, pendingCaptcha)`；调用方按 `(completed, enabled, activeCaptcha, pendingCaptcha)` 传，输出变成 `5/1` 而非 `2/5`。
- 根因：多 placeholder 的 ARB 没声明 `@key` 元数据时，gen-l10n 不保证生成签名顺序与调用直觉一致。
- 影响：状态栏文本错位（英文 locale 下尤为明显），计划 §4 L10N-3 的 placeholder 命名一致性要求被破坏。
- 修复：在 `app_zh.arb` / `app_en.arb` 显式补 `@playerSearchSessionProgressLine` 元数据，按 `(completed, enabled, activeCaptcha, pendingCaptcha)` 顺序列出。
- 回归测试：`player_search_session_coordinator_test.dart` 的 `progress label` 断言已覆盖；`arb_consistency_test.dart` 的 `placeholder sets align per shared message key` 也覆盖。
- 迁移/回滚：不涉及（仅是 ARB 元数据补全）。

### L10N-5-004 — `PlayerComments` widget 测试未注入 `AppLocalizations`，迁移到 l10n 后批量失败

- 工作包：L10N-5（2026-07-19）
- 现象：把 `Text('加载失败: $error')` 换成 `l10n.playerCommentsLoadFailed(error)` 之后，9 个 widget 测试因为 `MaterialApp` 缺少 `localizationsDelegates` 抛 `AppLocalizations.of(context)` Null check。
- 根因：原测试 `MaterialApp` 只设了 `home: Scaffold(...)`；gen-l10n 启用了 `nullable-getter: false`，要求 `AppLocalizations.delegate` 必须在树中。
- 影响：批量回归失败；反映 L10N-* 的迁移如果不同步改测试，会埋下回归。
- 修复：测试统一改为 `pumpLocalizedWidget` 风格 helper（`_wrap` / `_list`），并 `setUpAll` 加载 `AppLocalizations.delegate.load(const Locale('zh'))`，断言使用 l10n 值。
- 回归测试：本身即回归；运行后所有 L10N-5 受影响 widget 测试全绿。
- 迁移/回滚：未来 L10N-* 涉及文本的 widget 改动须同步更新测试 helper，否则会再次触发。

### L10N-5-005 — `PlayerVideoArea` more 按钮误用 `l10n.back` tooltip

- 工作包：L10N-5 复核（2026-07-19）
- 现象：移动端顶栏 `more_vert` `IconButton` 的 `tooltip` 写成了 `l10n.back`。
- 根因：a11y 补丁时复制了返回按钮属性。
- 影响：TalkBack / VoiceOver 将「更多」读成「返回」。
- 修复：新增 ARB `playerMoreOptions`（zh「更多」/ en「More」），more 按钮改用该 key。
- 回归测试：依赖 gen-l10n + 现有 video area 构建路径；可在 bilingual smoke 中后续加 tooltip 断言。
- 迁移/回滚：不涉及。

### L10N-5-006 — `playerMobilePlayableEpisodeCount` 中文模板残留英文

- 工作包：L10N-5 复核（2026-07-19）
- 现象：`app_zh.arb` 值为 `"{count} Episodes"`。
- 根因：英文占位文案未按模板 locale 改回中文（同类 L10N-3-002）。
- 影响：中文 locale 下可播放集数显示 “24 Episodes”。
- 修复：改为 `"{count} 集"`。
- 回归测试：`arb_consistency_test` + mobile info layout smoke。
- 迁移/回滚：不涉及。

### L10N-5-007 — `PlayerPlaybackController` 用户可见错误串硬编码中文

- 工作包：L10N-5 复核（2026-07-19）
- 现象：`_videoError` 赋值为 `'播放失败: $error'` / `'当前线路启动超时，请切换其他源'`。
- 根因：controller 无 BuildContext，先前用 i18n-ignore  defer 到后续包。
- 影响：英文 locale 下仍显示中文错误。
- 修复：controller 保存 `PlayerPlaybackErrorKind` + detail 的结构化错误，UI 构建时再走
  `playerPlaybackOpenFailed` / `playerPlaybackStartupTimeout`，因此 controller 保持 pure Dart，
  运行时切换语言也能重新解析当前错误。
- 回归测试：`player_playback_controller_test.dart` 断言 timeout/open-error 的 kind/detail。
- 迁移/回滚：不涉及（调用方均在 PlayerPage host）。

### L10N-5-008 — `initState` 读取 `AppLocalizations` 导致播放页生命周期异常

- 工作包：L10N-5 复核（2026-07-19）
- 现象：`PlayerPage.initState` 初始化标题 notifier 时调用 `AppLocalizations.of(context)`。
- 根因：`Localizations.of` 依赖 inherited widget，不能在 `initState` 阶段注册依赖。
- 影响：调试/测试构建打开播放页会触发 `dependOnInheritedWidgetOfExactType` 生命周期异常。
- 修复：`initState` 只创建空 notifier；在 `didChangeDependencies` 中解析标题，语言变化时同步刷新。
- 回归测试：全量 analyze/test + 双语言 player 子树 smoke。
- 迁移/回滚：不涉及。

### L10N-5-009 — 扫描器漏掉 `${...}` 内的字符串字面量

- 工作包：L10N-5 复核（2026-07-19）
- 现象：下载任务名中的「第 N 集」和调试日志中的「可播放/不可播放」未被严格扫描发现。
- 根因：轻量 lexer 把插值表达式内部的引号误判为外层字符串终止符。
- 影响：扫描报告 0 项但英文 locale 仍可能显示中文，严格门禁产生假阴性。
- 修复：lexer 在插值表达式中递归扫描字符串，并处理嵌套大括号、注释和 raw/triple string；
  同时迁移下载任务名、probe 日志和 captcha fallback 文案。
- 回归测试：`scan_hardcoded_ui_text_test.dart` 通过真实 CLI 验证嵌套插值触发失败退出。
- 迁移/回滚：不涉及。

### L10N-5-010 — 360px smoke 只伪造 MediaQuery，未约束实际布局

- 工作包：L10N-5 复核（2026-07-19）
- 现象：测试设置 `MediaQueryData(size: 360×800)`，但 RenderView 仍使用默认测试尺寸。
- 根因：MediaQuery 只提供环境数据，不改变父级 BoxConstraints。
- 影响：真实 360px 下英文 BT 资源卡操作按钮溢出 25px，但原 smoke 全绿。
- 修复：测试直接设置 `tester.view.physicalSize/devicePixelRatio`；BT 操作区改为可换行 Wrap；
  另补 1280×800 的 `PlayerPcLayout` 中英文 smoke。
- 回归测试：24 个双语言 mobile/desktop smoke 全部通过。
- 迁移/回滚：不涉及。

### L10N-5-011 — 新增 placeholder 消息缺少类型元数据

- 工作包：L10N-5 复核（2026-07-19）
- 现象：35 个新增 player placeholder key 没有 `@key` 块，一致性测试仅在元数据存在时校验。
- 根因：门禁没有断言元数据必须存在。
- 影响：生成函数参数顺序/类型可能漂移；英文计数文案还会出现 `1 Episodes` / `source(s)`。
- 修复：所有新增 player placeholder 补 description/type，英文计数使用 ICU plural；一致性测试
  新增 `player placeholder messages declare typed metadata`。
- 回归测试：`arb_consistency_test.dart` + `flutter gen-l10n`。
- 迁移/回滚：不涉及。

### DT-1-001 — `BangumiUrlRewriter.canonicalize` 主机子串重叠 → 缓存键漂移

- 工作包：DT-1（2026-07-19）
- 现象：`canonicalize('https://api.bangumi.lol/v0/subjects/1')` 实际产出
  `https://api.bangumi.tv/v0/subjects/1`（一个不存在的镜像 host），而不是预期的
  `https://api.bgm.tv/v0/subjects/1`。
- 根因：`_mirrorToReal` 是按插入顺序迭代的 `Map`，且使用 `result.contains(mirror)`
  + `result.replaceAll(mirror, real)` 的整体字符串替换；bare-host 键 `'bangumi.lol': 'bangumi.tv'`
  会先匹配并替换 `api.bangumi.lol` 后缀里的 `bangumi.lol` → `bangumi.tv`，
  随后 `api.bangumi.lol` → `api.bgm.tv` 这条更具体的规则因字符串已被改而无法命中。
- 影响：`ImageCacheService._normalizeCacheKey` 用 `canonicalize` 生成缓存文件名；
  同一张 API 图片在「用户切换反向代理」前后会落到不同的本地缓存文件（哈希不同），
  重复下载并占用磁盘，且在重新启用代理后无法命中之前 mirror 模式下已经写好的缓存。
  `canonicalize` 当前仅用于图片缓存键，不影响分享链接。
- 修复：统一通过 `Uri.tryParse` 解析完整 authority，只对 `Uri.host` 做精确映射。
  这既消除了短键与子域的重叠，也避免把 `bangumi.tv.example.com` 等相似域名或 query
  参数中嵌套的 URL 当成当前 URL 的主机改写。
- 回归测试：`test/utils/bangumi_url_rewriter_test.dart` 的
  `api.bangumi.lol maps to api.bgm.tv (not api.bangumi.tv)` /
  `mirror and real forms of the same API host share a cache key` /
  `mirror and real forms of the lain host share a cache key`，以及相似域名、query 嵌套 URL
  保持不变的反例测试。
- 迁移/回滚：仅 `BangumiUrlRewriter.canonicalize` 的实现细节；调用方（image cache）
  行为更正确，无需数据迁移。已存在的旧缓存文件可由 LRU 自然淘汰。

### DT-2-001 — 播放历史单条损坏导致整表清空

- 工作包：DT-2（2026-07-19）
- 现象：`playback_history_v1` 中只要有一条字段不全/类型不对的 JSON 对象，
  `_loadFromDisk` 就会在 `map(...fromJson)` 时抛异常，外层 `catch` 返回空列表，
  用户全部历史在下次读取时消失。
- 根因：对整段数组做一次性 `map`/`cast`，任一元素失败即整表失败。
- 影响：升级、并发写入中断、手动编辑 prefs 等场景下一条坏记录即可抹掉最多 200 条
  播放进度，恢复播放位置丢失。
- 修复：按元素 try/parse；非 `List` / 整段 JSON 非法仍返回空；单条坏数据跳过并保留
  其余合法项。同时补 `debugResetCacheForTest` 便于测试直接 seed prefs。
- 回归测试：`test/services/playback_history_manager_dt2_test.dart` 的
  `single corrupt entry does not wipe the rest of the list` /
  `non-JSON payload yields empty history instead of throwing` /
  `JSON object (not list) yields empty history` /
  `legacy entry without lastPositionMs defaults to 0`。
- 迁移/回滚：读路径更宽容，无需写迁移；下次 `addOrUpdate`/`updatePosition` 会
  以修复后的合法子集重新持久化。

### DT-3-001 — Header injection proxy 对原 URL 二次 percent-decode

- 工作包：DT-3（2026-07-19）
- 现象：注册含字面 `%2F` 查询值的上游 URL（线上表现为 `token=%252F`）后，代理从
  `request.uri.queryParameters` 取出已经解码一次的 `url`，又调用 `Uri.decodeComponent`，
  导致上游实际收到 `/` 而不是字面 `%2F`。
- 根因：混淆了 raw query 与 `queryParameters` 的解码契约。
- 影响：带 percent-encoded token、签名或嵌套 URL 的媒体地址可能被代理改写，产生 403、
  签名校验失败或请求到错误资源。
- 修复：直接使用 `queryParameters['url']`；同时调整 header 合并顺序，让注册的注入值覆盖
  播放器发给本地代理的同名 header。
- 回归测试：`HeaderInjectionProxy preserves percent-encoded data in the original URL exactly once`、
  `injected headers override conflicting client headers`。
- 迁移/回滚：不涉及。

### DT-3-002 — Windows 图片缓存清理后同步索引仍返回已删除路径

- 工作包：DT-3（2026-07-19）
- 现象：`cleanupOldCache` 已删除过期/超限文件，但 `getCachedPathSync` 仍返回旧路径；Windows
  下尤其稳定复现，因为缓存写入路径使用 `/`，`File.path` 枚举结果使用 `\`，字符串相等失败。
- 根因：路径通过字符串拼接生成，内存索引淘汰又使用未规范化的精确字符串比较；TTL/size
  cleanup 原本也没有主动清除内存条目。
- 影响：UI 可能继续尝试读取不存在的封面，直到异步磁盘检查或进程重启修正，表现为空图/
  闪烁；同步缓存命中契约失真。
- 修复：统一使用 `path.join`，以 `path.equals` 淘汰相同文件，并在单图删除、按年龄清理、
  按容量清理时同步清除内存路径。
- 回归测试：`age cleanup evicts stale synchronous memory paths`、
  `size cleanup removes oldest files until under the limit`、`delete and clear evict both disk and synchronous memory entries`。
- 迁移/回滚：不涉及；旧文件布局不变。

### DT-3-003 — 非默认端口从图片/Captcha Referer 中丢失

- 工作包：DT-3（2026-07-19）
- 现象：请求 `http://host:PORT/...` 时，图片下载和 Captcha 导航构造的默认 Referer 都是
  `http://host/`，端口被丢弃。
- 根因：手工拼接 `${uri.scheme}://${uri.host}`，没有使用 authority/origin。
- 影响：使用非 80/443 端口的数据源、本地调试源或带端口鉴权的源站可能拒绝请求；图片加载、
  Captcha/detail 导航出现 403。
- 修复：两处统一使用 `Uri.origin`。
- 回归测试：`downloads bytes with image headers and reuses the disk cache`、
  `navigation headers preserve a non-default port and explicit referer`。
- 迁移/回滚：不涉及。

### DT-3-004 — 弹幕返回不可变列表时排序失败，且旧请求可覆盖新状态

- 工作包：DT-3（2026-07-19）
- 现象一：API 返回 `const`/不可变列表时，服务对结果原地 `sort`，成功请求转为
  `Unsupported operation: Cannot modify an unmodifiable list`。
- 现象二：连续搜索/选集时，先发出的慢请求晚返回后会覆盖后发请求的结果；`clearDanmaku`
  也无法阻止已在途请求重新填充列表。
- 根因：服务持有并修改调用方列表；异步操作没有 generation/token 判定。
- 影响：后端实现变化或测试/缓存返回只读集合时弹幕无法加载；快速切换作品/剧集可能显示上一项
  的搜索结果或弹幕。
- 修复：复制为可变 `List<Danmaku>.of` 后排序；所有请求使用递增 generation，落地状态前确认
  仍为当前请求，clear 同时使在途 generation 失效。
- 回归测试：`title lookup sorts comments and clears loading state`、
  `late search response cannot overwrite the latest query`、`clear invalidates an in-flight request`。
- 迁移/回滚：不涉及。

### DT-3-005 — ECH 临时 endpoint 探测异常时污染用户配置

- 工作包：DT-3（2026-07-19）
- 现象：`testDohEndpoint` 临时把候选 endpoint 写入 prefs/Rust 后，若 refresh 抛异常，函数直接
  进入 `catch` 返回 0，没有恢复先前列表，与代码注释“regardless of refresh outcome”矛盾。
- 根因：恢复逻辑位于 `try` 正常路径，而非 `finally`。
- 影响：一次失败的“测试 DoH”会悄悄把用户正式 DoH 列表替换为失败候选，后续 Bangumi ECH
  请求持续失败，直到用户手动修改或重启同步。
- 修复：预先保存旧列表，并在 `finally` 中同时恢复 SharedPreferences 与 Rust runtime；
  `syncToRust` 也移除一次重复的 ECH toggle 调用。
- 回归测试：`test endpoint restores persisted and runtime lists when refresh throws`（并覆盖成功路径）。
- 迁移/回滚：不涉及；修复后首次调用/启动同步会恢复 prefs 中的正式列表。

### DT-3-006 — OCR 初始化失败 Future 被永久缓存

- 工作包：DT-3（2026-07-19）
- 现象：首次模型复制/初始化失败后，`_initializing ??=` 永久保存失败 Future；后续每次识别都立即
  重放同一异常，即使磁盘/资源条件已经恢复。
- 根因：初始化去重没有区分“成功完成”与“失败完成”。
- 影响：一次瞬时 I/O、asset 或 Rust 初始化错误会让 OCR 验证码功能在整个进程生命周期内不可用。
- 修复：成功 Future 继续复用；失败完成时仅在仍为当前初始化任务的情况下清空 `_initializing`，
  允许下一次调用重试，同时保留并发初始化去重。
- 回归测试：`failed initialization is cleared so a later attempt can retry`、
  `concurrent initialization shares one backend check and future`。
- 迁移/回滚：不涉及。

### DT-3-007 — BangumiImageBridge clear 与 in-flight 完成竞态

- 工作包：DT-3（2026-07-19）
- 现象：`clear()` 清空 map 后，旧下载仍可完成并重新写入 cache；若同 key 已启动新下载，旧 Future
  完成时无条件 `_inFlight.remove(key)` 还会删除新任务的去重槽，触发重复下载。
- 根因：缓存没有 generation，in-flight 清理也没有确认 map 中仍是同一个 Future。
- 影响：用户清缓存后旧图片可能立刻回填；同 URL 短时间重复请求绕过去重，增加 Rust/网络负载。
- 修复：clear 递增 generation，旧 generation 不再写缓存；完成清理仅在 map 当前值与自身 Future
  identical 时执行。
- 回归测试：`clear prevents an old request from repopulating or removing a newer flight`。
- 迁移/回滚：不涉及。

### DT-3-008 — 视频探测先等待错误 body，HTTP 状态被 timeout 掩盖

- 工作包：DT-3（2026-07-19）
- 现象：服务端已返回 500 header 但保持/缓慢发送 body 时，probe 仍先读取最多 2KB body；最终返回
  `Probe timed out`，而不是立即返回 `HTTP 500`。
- 根因：状态码判断放在 `_readProbeBytes` 之后。
- 影响：探测延迟被放大到完整 timeout，错误诊断不准确；批量线路探测占用连接和 gate 更久。
- 修复：收到 response header 后先处理 `>=400`，无需读取错误 body，finally 强制关闭 client。
- 回归测试：`reports HTTP errors without waiting for an unbounded error body`。
- 迁移/回滚：不涉及。

### DT-3-009 — 详情缓存内嵌集数去重依赖返回顺序

- 工作包：DT-3（2026-07-19）
- 现象：同一 `sort` 的无标题幽灵集数若出现在真实命名集数之前，详情服务的单遍去重会先保留
  幽灵项，随后再保留真实项；重复 id 也没有过滤。
- 根因：`_parseEpisodesFromSubjectData` 维护“已经见过的命名 sort”，只能删除位于真实项之后的
  幽灵项，且复制了另一套不完整的去重实现。
- 影响：缓存/详情 JSON 调整 episode 顺序时，选集面板可能出现两个相同集号或重复 episode。
- 修复：解析完成后统一调用 DT-1 已覆盖的 `withoutPhantomEpisodes()` 两遍算法；同时避免
  `loadInitialData` 对同一 JSON 重复解析两次。
- 回归测试：`cached initial data parses embedded episodes and builds person map`（fixture 让幽灵项
  位于真实项之前，并加入重复 id）。
- 迁移/回滚：只影响读时规范化，不修改缓存数据。
