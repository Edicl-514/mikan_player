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

### DT-4-001 — Captcha 完成与取消竞态会重复发送 idle

- 工作包：DT-4（2026-07-19）
- 现象：Captcha job 已通过结果、失败或 timeout 完成后，如果 host 尚未来得及 rebuild 为
  idle/null job 就收到 `cancelCurrentJob`，runner 会再次调用 `sink.onIdle`；最小复现是缺少
  initial URL 的任务在 `acceptJob` 内同步失败，随后立即 cancel，观察到两次 idle。
- 根因：`_complete` 以 `_isCompleted` 保证 result 只发一次，但 `_cancelCurrentJob` 只检查
  `_currentJob != null`，没有识别“currentJob 尚未清空但已经完成”的短暂状态。
- 影响：同一 WebView dispatch 会被调度器结算两次，重复执行 slot release、post-frame idle
  和 pool pump；大多数释放操作虽为幂等，竞态下仍会产生额外调度和状态日志，并扩大旧 idle
  回调碰到新任务的窗口。
- 修复：`_cancelCurrentJob` 遇到 `_isCompleted` 时只清空任务并推进 token，禁止再次发送
  result/idle；未完成任务的正常 cancel 语义保持不变。
- 回归测试：`test/services/captcha_job_runner_test.dart` 的
  `complete followed by cancel settles the job only once`，并由
  `cancel wins a timeout race without a late result or second idle` 覆盖相邻 timeout 竞态。
- 迁移/回滚：仅运行时调度幂等性修复，不涉及持久化数据或配置迁移。

### DT-5-001 — 非 Player 页面旧请求可覆盖新状态或显示过期错误

- 工作包：DT-5（2026-07-19）
- 现象：Search 连续提交两个关键词时，先发出的慢请求可在后发请求之后完成并覆盖结果；
  Character/Person details 的 retry 或 widget id 替换存在相同风险；Index 虽有 fetch id，但旧请求
  失败后仍会弹出与当前筛选无关的 SnackBar。主页与收藏页的并行刷新也缺少统一 latest-wins 门禁。
- 根因：多数页面只检查 `mounted`；`mounted` 只能说明 State 尚存活，不能说明异步结果仍属于当前
  query、entity 或 refresh generation。
- 影响：快速搜索、切换筛选、重试或刷新时可能看到上一关键词/人物/分区的数据，或收到已经过期的
  错误提示，页面可见状态与当前输入不一致。
- 修复：新增 `PagedRequestController`、`EntityDetailsController` 与 `RequestGenerationGuard`；
  Search/Ranking/Character/Person/History 接入 controller，Home/Favorites 使用独立 generation；
  Index 的错误提示也要求 fetch id 仍为当前值。
- 回归测试：`late old query cannot overwrite the latest query`、
  `refresh invalidates in-flight load more`、`late previous entity cannot overwrite replacement`、
  `search: late old query cannot replace latest results`、dispose late completion 测试。
- 迁移/回滚：仅运行时状态所有权调整，无持久化迁移。

### DT-5-002 — Home 下拉刷新 Future 在数据完成前返回

- 工作包：DT-5（2026-07-19）
- 现象：Home PC/mobile 的 `RefreshIndicator.onRefresh` 调用 `_loadAllData`，但该方法只启动四个
  async loader 而不 await；刷新指示器会立即消失，实际 timetable/ranking/history/favorites 仍在后台加载。
- 根因：`async` 方法内部调用 Future 时既未 `await`，也未通过 `Future.wait` 聚合。
- 影响：用户收到错误的“刷新完成”反馈，并可在前一轮尚未结束时再次触发刷新，扩大旧结果覆盖窗口。
- 修复：两种布局统一 `await Future.wait([...])`，四个分区各自使用 generation guard，UI 只接受
  当前轮次的完成结果。
- 回归测试：`RequestGenerationGuard` latest/invalidate/dispose 测试；全量 Home 编译与页面回归。
- 迁移/回滚：不涉及。

### DT-5-003 — History 读取异常被渲染成“无历史”

- 工作包：DT-5（2026-07-19）
- 现象：`FutureBuilder` 只读取 `snapshot.data ?? []`，未处理 `snapshot.error`；存储读取失败时页面
  显示正常空态，用户无法区分“确实为空”和“加载失败”，也没有 retry 入口。
- 根因：页面状态仅由 FutureBuilder 的 data/connectionState 推导，遗漏 error 分支。
- 影响：瞬时 I/O 或未来 backend 异常会被静默吞掉，删除/刷新失败后的诊断与恢复能力不足。
- 修复：History 接入分页状态 controller（只使用 refresh 能力），显式渲染 loading/error/retry/
  empty/success；删除操作等待持久化完成后再刷新列表。
- 回归测试：`history: load failure is retryable instead of looking empty`、
  `history: delete waits for persistence then refreshes`。
- 迁移/回滚：不涉及。

### DT-5-004 — 播放源刷新完成时可能在已销毁 State 上 setState

- 工作包：DT-5（2026-07-19）
- 现象：离开 DataSourceSettingsPage 时若播放源刷新仍在进行，成功路径更新 `_sources` 以及
  `finally` 清除 `_isRefreshing` 都会无条件调用 `setState`。
- 根因：异步方法的部分分支有 `mounted` 检查，但成功提交和 `finally` 遗漏生命周期门禁。
- 影响：刷新过程中快速返回上一页会触发 `setState() called after dispose()`，在测试/调试环境报错，
  并可能中断后续帧处理。
- 修复：两处状态提交均要求 `mounted`；持久化与 Rust runtime 同步仍允许在页面离开后正常完成。
- 回归测试：controller dispose late-completion 回归 + DataSourceSettings 静态分析/全量 Widget 回归。
- 迁移/回滚：不涉及。

### DT-6-001 — Bangumi mobile 评分行在 360px 下溢出

- 工作包：DT-6（2026-07-19）
- 现象：Bangumi 详情 mobile header 在真实 360×800 约束下，评分/投票/排名行中文溢出 33px，
  英文溢出 67px；此前仅对单个详情 widget 做过局部宽度 smoke，未覆盖完整 header 组合。
- 根因：`BangumiRatingRow` 的评分数字与右侧 `Column` 都按自然宽度参与横向 `Row` 布局；
  海报和间距占用后右栏最多约 194px，但投票/排名文本没有 `Flexible`、换行或省略约束。
- 影响：窄屏设备详情页出现黄黑 overflow 条，英文信息被截出屏幕；较大的投票数/排名会进一步
  放大问题。
- 修复：右侧星级与投票信息使用 `Flexible` 接受剩余宽度，投票/排名文案最多两行并在极端长度下
  省略；评分数字和星级仍保持原视觉层级。
- 回归测试：`Bangumi mobile layout fits 360px (zh/en)` 直接设置 RenderView 为 360×800，
  组合完整 `BangumiDetailsMobileLayout` 并断言无异常。
- 迁移/回滚：仅布局约束调整，不涉及数据或配置迁移。

### DT-6-002 — Bangumi wide 空简介在中文界面仍显示英文

- 工作包：DT-6（2026-07-19）
- 现象：wide 详情布局的 subject 没有 summary 时，中文 locale 显示固定英文
  `No summary available.`；mobile 布局使用的却是已存在的 `bangumiDetailsNoSummary`。
- 根因：wide/mobile 拆分时 wide fallback 保留了英文字符串，没有复用同一 l10n key；现有硬编码
  扫描器主要针对 CJK 和直接 UI 参数，未把这个间接传入子 widget 的英文 fallback 标为候选。
- 影响：桌面中文界面出现语言漂移，且同一数据在 mobile/wide 两种布局的文案不一致。
- 修复：wide 布局统一使用 `AppLocalizations.of(context).bangumiDetailsNoSummary`。
- 回归测试：`Bangumi wide layout fits 1280px (zh/en)` 组合真实 1280×800 布局，并断言各 locale
  的空简介文案存在且无 overflow。
- 迁移/回滚：不涉及。

### DT-6-003 — 纯图标操作缺少本地化 tooltip/无障碍名称

- 工作包：DT-6（2026-07-19）
- 现象：全仓 UI 复核发现 12 个 `IconButton` 没有 tooltip，包括下载/搜索设置保存、Search 搜索、
  History 删除、Favorites 取消收藏、Home 完整时间表、Timetable 季度选择、两套弹幕源搜索、
  SettingsPanel 返回/关闭及 EpisodeSidePanel 关闭。
- 根因：此前 i18n 工作集中在可见 `Text` 和已有 tooltip 的翻译，缺少对“只有图标且 tooltip
  参数完全不存在”的构造器级门禁。
- 影响：桌面悬停无法得知按钮用途；读屏 Semantics tooltip 为空，保存、删除、关闭等关键操作
  难以识别，且不同页面的无障碍质量不一致。
- 修复：所有 UI `IconButton` 补本地化 tooltip；复用 `save`、`searchHint`、`selectQuarter`、
  `viewFullTimetable`、`back`、`closeSettingsBarrier`、`closeEpisodesBarrier` 等既有 key，并新增
  语义准确的 `historyDeleteTooltip` / `favoritesRemoveTooltip`。复核脚本确认 `lib/ui/**` 不再有
  缺少 tooltip 的 `IconButton`。
- 回归测试：Search/History 断言 Semantics tooltip；Danmaku、Download/Search settings、
  SettingsPanel、EpisodeSidePanel 断言 locale 对应 tooltip；全量 ARB 一致性测试通过。
- 迁移/回滚：不涉及。

### DT-7-001 — BT `resumeTask` 后端异常时任务卡在假活跃状态且无法重试

- 工作包：DT-7（2026-07-19）
- 现象：暂停中的 BT 任务点「继续」时，`_resumeTaskImpl` 先把 `task.status` 从
  `paused` 翻成 `metadata`/`pending`/`queued`（并保存/通知 UI），随后调用
  `_resumeTorrentWithBackend`。若后端 `resumeTorrent` 抛异常，`catch` 只做
  `_releaseSlotForTask(id)` 并返回 `false`，任务停留在 `metadata` 等活跃状态，
  但 id 仍留在 `_pausedTaskIds` 里。
- 根因：进入 resume 流程后立即乐观地写入过渡态，异常路径没有回滚 `task.status`
  与 `_pausedTaskIds`，导致「可见状态」与「暂停集合」不一致。
- 影响：UI 显示一个永远转圈的假下载（实际未启动）；因为状态不是 `paused`/`error`，
  用户界面通常不再提供「继续」入口，任务无法自然恢复，直到重启 App 走
  `_loadTasks` 重新归位。属于用户可见的下载卡死。
- 修复：`_resumeTaskImpl` 进入 try 前快照 `resumeEntryStatus` /
  `resumeEntryWasPaused`；`catch` 分支在任务仍被本对象持有且未被移除时，把
  速度清零，按进入前是否为暂停回滚到 `paused`（并重新加入 `_pausedTaskIds`）或
  记为可重试的 `error`，再 `_saveTasks` + `_notifyChanged`。这样一次瞬时后端失败
  后，第二次 resume 仍能成功。
- 回归测试：`test/services/download/download_manager_resume_rollback_test.dart`
  的 `resumeTask returns false and does not throw when the backend resume throws`
  / `after a failed backend resume the task is left retryable (paused status
  agrees with the paused set)` / `a second resume attempt after a transient
  backend failure can succeed`。
- 迁移/回滚：不涉及（仅内存态回滚逻辑；持久化 JSON 形状不变）。

### DT-7 覆盖补洞（无 bug，仅回归加固）

- 工作包：DT-7（2026-07-19）
- 背景：DT-7 要求「先跑覆盖率再补真正空洞，不重复 happy-path」。核查后发现
  `DownloadManager._loadTasks` 的应用重启恢复分支与 `_updateStats` 的
  暂停/移除竞态分支此前只被间接触及，缺少直接回归。
- 新增回归（均使用注入的 `FakeBtBackend` / 预置 SharedPreferences，不触碰真实 FFI）：
  - `download_manager_restart_recovery_test.dart`：HTTP 活跃任务重启后降级为
    `paused`（不自动续传）并进入暂停集；已完成但本地文件丢失 → `error`（文案
    `本地文件已删除`）；本地文件仍在 → 保持 `completed`；持久化的暂停 HTTP 任务
    进入暂停集；空磁链 BT 任务在加载时被丢弃；rqbit `pending` 在加载时提升为
    `metadata` 并触发一次自动续传；持久化的暂停 BT 任务不自动续传；空存储不产生任务。
  - `download_manager_stats_poller_test.dart`：暂停任务的轮询只更新字节/peer 而
    不翻回 `downloading`（用第二个活跃任务保活轮询，复现真实竞态）；移除后的陈旧
    stat 不会复活任务；`progress>=100`→`seeding`、`error`→`error`、`checking`→
    `checking` 的终态映射；epsilon 内的无变化轮询不改状态。
- 为支持上述测试新增的测试专用接缝：`loadTasksForTesting()`、
  `isPausedForTesting(id)`（均 `@visibleForTesting`），并让 `FakeBtBackend` 的
  异常注入字段按其文档承诺改为可变，新增 `clear*Exception()` 便于在同一场景内
  切换瞬时故障。
- 迁移/回滚：不涉及。

### RT-0-001 — Dandanplay 非 2xx 响应正文被网络层提前丢弃

- 工作包：RT-0（2026-07-19）
- 现象：`danmaku_search_anime` 等函数在收到非 2xx 后本应返回
  `API error <status>: <body>`，但实际会先从 `retry_request` 的 `error_for_status()`
  返回 `Request failed`，后面的状态码/正文分支永远无法执行。
- 根因：弹幕 API 同时在共享网络层和业务层处理 HTTP status；共享网络层默认把错误响应转换成
  `reqwest::Error`，导致业务层无法再读取 Dandanplay 返回的限流、鉴权或参数错误正文。
- 影响：用户与日志只能看到通用 HTTP 错误，丢失上游提供的具体原因，验证码/凭据/限流类问题
  难以诊断；原代码中用于保留正文的错误分支属于死代码。
- 修复：内部 `DanmakuApiClient` 使用 `retry_request_with_status(..., true)` 保留最终响应，
  仍对 5xx 执行既有重试，再由弹幕业务层统一读取 status/body 并构造错误。
- 回归测试：`api_errors_preserve_status_and_response_body`，本地 server 返回 429 + JSON error，
  断言错误同时包含 `429 Too Many Requests` 和 `rate limited`。
- 迁移/回滚：不涉及；公开 FRB 返回类型不变，仅错误信息更完整。

### RT-0-002 — 极小相对集号会触发整数下溢

- 工作包：RT-0（2026-07-19）
- 现象：`danmaku_get_by_title` / `danmaku_get_by_bangumi_id` 在编号匹配失败后直接计算
  `(rel_ep - 1) as usize`；传入 `i32::MIN` 时 debug 构建会因减法溢出 panic，其他非正数也会
  被转换成无意义的巨大索引。
- 根因：相对集号来自跨语言 API，却在转成零基索引前未验证必须为正数，也未使用 checked
  arithmetic。
- 影响：异常 Dart/FFI 输入可让调试版请求崩溃；release 下虽通常只会找不到剧集，但行为依赖
  overflow 设置且日志无法区分非法输入与正常未命中。
- 修复：集中为 `relative_episode_index`，先 `checked_sub(1)`，再通过 `usize::try_from`
  验证非负；非法相对集号按“无可用 fallback”处理，不再请求弹幕。
- 回归测试：`invalid_relative_episode_never_underflows_or_fetches_comments`，输入 `i32::MIN`
  时返回空列表且本地 server 只收到剧集请求。
- 迁移/回滚：不涉及；合法的 1-based 相对集号语义保持不变。

### RT-1-001 — Mikan 引号封面分支不可达且绝对 URL 会被重复拼接

- 工作包：RT-1（2026-07-19）
- 现象：搜索结果封面样式若为 `url(&quot;/cover.jpg&quot;)` / `url("/cover.jpg")`，原解析器
  只有先命中 `url('` 但找不到结束单引号时才会检查 `&quot;`，正常双引号分支实际不可达；若
  上游直接给出 `https://cdn...`，又会无条件拼上 Mikan base URL。
- 根因：CSS URL 提取由嵌套的字符串 `find` 分支实现，并把所有提取结果都当作站内相对路径。
- 影响：对应搜索结果显示空封面，或得到 `https://mikan...https://cdn...` 形式的非法图片地址。
- 修复：独立解析 `url(...)`，统一剥离单引号、双引号和 `&quot;`；使用 `url::Url` 区分并解析
  绝对、协议相对和站内相对 URL。
- 回归测试：`minimal_search_fixture_resolves_relative_cover_url`、
  `search_parser_handles_quoted_and_absolute_covers_and_skips_bad_or_duplicate_nodes`。
- 迁移/回滚：仅影响读时 URL 规范化，不修改缓存或配置。

### RT-1-002 — DMHY 单条缺少 title 会让整份 RSS 解析失败

- 工作包：RT-1（2026-07-19）
- 现象：RSS 中任意 `<item>` 缺少 `<title>` 时，`quick_xml` 因 `Item.title: String` 缺字段而
  返回错误，即使其余资源完全合法也不会返回任何结果。
- 根因：站点 feed 的逐项可选字段被建模为整份文档的强制字段，解析和条目校验没有分层。
- 影响：一次上游脏数据即可让某集的全部 DMHY 资源加载失败，用户只能看到空结果/请求错误。
- 修复：将 channel、title、enclosure URL/length 建模为可选值；XML 结构损坏仍返回错误，单条
  缺字段或非法磁链则跳过，并继续保留其他合法资源。
- 回归测试：`edge_fixture_skips_bad_nodes_and_duplicates_but_preserves_unicode_and_raw_date`、
  `missing_channel_is_an_empty_feed_and_malformed_xml_is_an_error`。
- 迁移/回滚：不涉及；公开资源结构不变。

### RT-1-003 — DMHY 极大 enclosure.length 会触发整数乘法溢出

- 工作包：RT-1（2026-07-19）
- 现象：原代码先执行 `length.parse::<u64>().unwrap_or(0) * 1024`；当 length 接近 `u64::MAX`
  时 debug 构建直接 panic，release 构建则依赖溢出设置产生回绕值。
- 根因：Anime Garden feed 的 length 按 KiB 使用，但格式化前先在整数域转换为 bytes，且没有
  checked/saturating arithmetic。
- 影响：异常上游数字可以让 Rust/FFI 调用崩溃，或向 UI 返回完全错误的大小。
- 修复：从 KiB 单位直接在 `f64` 格式化，补 B～ZB 单位；缺失/非法值稳定返回 `0.0 B`，不再
  进行可能溢出的 `u64 * 1024`。
- 回归测试：`size_formatter_uses_feed_kib_units_without_integer_overflow`，覆盖 `u64::MAX`。
- 迁移/回滚：正常 feed 的既有 KiB 语义与显示值保持不变。

### RT-1-004 — 长 Unicode 磁链日志预览可能按非法 UTF-8 边界切片

- 工作包：RT-1（2026-07-19）
- 现象：`start_torrent` 对长度超过 200 bytes 的输入执行 `&magnet[..200]`；若第 200 byte 位于
  中文/emoji 等多字节字符中间，Rust 会因非字符边界切片而 panic。
- 根因：日志预览把 UTF-8 字符串长度和 byte offset 当作可互换值。
- 影响：跨语言入口收到带长 Unicode `dn` 参数或异常输入时，可能在真正交给 BT 引擎前崩溃。
- 修复：提取 `text_preview`，按 `chars()` 截取最多 200 个 Unicode scalar，再追加省略号。
- 回归测试：`text_preview_truncates_by_character_boundary` 使用 201 个中文字符复现边界。
- 迁移/回滚：仅日志预览变化，传给 librqbit 的完整磁链不变。

### RT-1-005 — ranking rank 窄化会回绕，非法日期会被格式化成“合法样式”

- 工作包：RT-1（2026-07-19）
- 现象：Bangumi API 的 `i64` rank 直接 `as i32`，超出范围时会回绕成负数；`2026-02-30`
  等非法日期只要形似三段数字，就会显示为 `2026年2月30日`。
- 根因：数字窄化未使用 checked conversion，日期 formatter 只拆字符串而未验证日历合法性。
- 影响：异常/变更后的上游数据可能在排行 UI 显示负排名或看似已正规化的不存在日期。
- 修复：rank 使用 `i32::try_from`，越界时按缺失处理；日期用 `chrono::NaiveDate` 严格解析，
  非法值保留原文以便诊断；HTML score 同时拒绝 NaN/Infinity。
- 回归测试：`json_edge_fixture_skips_bad_items_deduplicates_and_rejects_rank_overflow`、
  `invalid_year_month_and_calendar_dates_are_not_normalized_as_valid`。
- 迁移/回滚：不涉及；合法 rank/日期输出不变。

### RT-1-006 — 弹幕解析接受 NaN/负时间和越界 type/color

- 工作包：RT-1（2026-07-19）
- 现象：`f64::parse` 会接受 `NaN`/`Infinity`，原解析器也接受负时间、任意 i32 type 和任意
  u32 color；这些记录随后进入按 `partial_cmp` 排序的列表。
- 根因：解析成功被等同于业务合法，缺少有限值、时间范围、类型枚举和 RGB 上限校验。
- 影响：非有限时间会破坏稳定排序并把不可调度值传给播放器；负时间、未知类型和超 24-bit 颜色
  可能造成弹幕提前触发、渲染异常或平台间行为漂移。
- 修复：丢弃非有限/负时间和空文本；type 仅接受 1～5，color 仅接受 `0x000000..0xFFFFFF`，
  非法元数据回退到滚动白色；缺 comments 数组按空列表处理。
- 回归测试：`comment_edge_fixture_discards_non_finite_negative_and_empty_rows`、
  `missing_comments_array_parses_as_an_empty_response`。
- 迁移/回滚：仅过滤无效上游行，合法弹幕结构和排序不变。

### RT-1-007 — torrent progress 在瞬时统计不一致时可超过 100%

- 工作包：RT-1（2026-07-19）
- 现象：`downloaded / total_size * 100` 未限制范围；当 librqbit 元数据/进度快照处于瞬时不一致，
  或 downloaded 略大于 total 时，会通过 FRB 返回大于 100 的百分比。
- 根因：对外 stats 转换直接暴露内部计数比值，没有落实百分比字段的 0～100 契约。
- 影响：UI 可能显示超过 100% 的进度，并让依赖阈值的下载状态判断提前或反复切换。
- 修复：提取 `calculate_progress`，total 为 0 时返回 0，其余结果 clamp 到 0～100。
- 回归测试：`progress_handles_zero_and_transient_overrun`。
- 迁移/回滚：不涉及；正常范围内数值不变。

### RT-2-001 — 相对 URL 手工拼接丢端口且不支持标准引用形式

- 工作包：RT-2（2026-07-19）
- 现象：`generic_scraper` 把源站返回的相对链接拼成绝对 URL 时，只保留 `scheme://host`，丢弃非默认
  端口；同时仅能处理 `/detail/1` 这类 root-relative 链接，`detail/1`、`../play/1`、`//cdn/x` 会被
  拼成无效 URL 或错误 origin。
- 根因：`episode_table::absolutize_url` 以及 `search_play.rs` / `search_progress.rs` 中至少 8 处内联的
  URL 拼接副本都写成 `format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))`，未读取 `u.port()`。
- 影响范围 / 用户可见后果：非 80/443 端口的自定义源，以及返回 path-relative、parent-relative 或
  protocol-relative 链接的站点，都可能无法解析出可播放链接；用户只会看到“未找到剧集列表/无可播放线路”。
- 修复：`absolutize_url` 统一使用 `url::Url::join`，并把 `search_play.rs`、`search_progress.rs` 中所有
  内联副本收敛到该 helper；端口、当前目录、父目录和 protocol-relative 语义均由标准 URL 解析器处理。
- 回归测试：`episode_table` 的 `absolutize_url_preserves_scheme_host_and_nondefault_port`；
  `absolutize_url_handles_path_relative_parent_and_protocol_relative_urls`；
  `search_channels` 的 `search_with_channels_resolves_detail_and_episodes_over_loopback` 与
  `search_play` 的 `search_single_source_resolves_episode_url_and_preserves_port` 通过随机端口的
  loopback server 串起完整链路，断言解析出的 URL 携带该端口。
- 迁移/回滚：不涉及；此前能工作的默认端口源行为不变。

### RT-2-002 — 搜索结果日志按非法 UTF-8 边界切片 URL

- 工作包：RT-2（2026-07-19）
- 现象：`matching::log_subject_selection` 对长度超过 100 bytes 的候选 URL 执行 `&href[..100]`；当第
  100 个 byte 落在多字节字符（中文/emoji，或百分号编码里的中文）中间时，Rust 因非字符边界切片 panic。
- 根因：与 RT-1-004 同类——把 byte offset 当作字符数使用（`href.len() > 100` 判断 + `&href[..100]` 切片）。
- 影响范围 / 用户可见后果：源站返回带长 Unicode 路径/查询串的详情链接时，仅仅是记录一条搜索日志就会
  panic，进而中断该源的搜索任务；对含中文 slug 的站点尤为容易触发。
- 修复：改用 `href.chars().count() > 100` 判断，并以 `href.chars().take(100).collect::<String>()` 截取，
  始终落在字符边界。
- 回归测试：`matching` 的 `log_subject_selection_does_not_panic_on_long_unicode_url`（用 120 个中文字符
  构造 URL，断言不 panic）。
- 迁移/回滚：仅日志预览变化，实际使用的 URL 不变。

### RT-2-003 — 播放页 m3u8 调试预览按任意 byte 边界切片 HTML

- 工作包：RT-2（2026-07-19）
- 现象：播放页包含 `m3u8` 时，调试日志用匹配 byte offset 前减 100、后加 200 后直接切片；中文 HTML
  很容易让边界落在多字节字符中间并 panic，完整 search → play API 因日志代码中断。
- 根因：`match_indices` 返回合法 byte 边界，但对该位置做任意 byte 加减后不再保证是 UTF-8 字符边界。
- 修复：提取 `text_window_around_match`，以匹配位置为锚点按 `chars()` 构造前后预览。
- 回归测试：`text_window_around_match_respects_unicode_boundaries`；完整 loopback 播放测试使用长中文播放页。
- 迁移/回滚：仅日志预览截取单位从 byte 改为字符，视频匹配输入保持完整不变。

### RT-2-004 — 非法 selector/regex 配置可成功持久化

- 工作包：RT-2（2026-07-19）
- 现象：新增/更新源配置只做 Serde 字段反序列化，`li[`、`(` 等语法非法的 CSS selector/regex 仍会
  保存；实际搜索时解析失败并表现为无结果，用户无法从保存操作得到明确反馈。
- 根因：配置写入路径没有调用 `scraper::Selector`、`regex::Regex`、`fancy_regex::Regex` 做语法校验。
- 修复：集中新增 `validate_search_config` / `validate_captcha_config`，覆盖 subject/channel/captcha selector、
  剧集/线路普通 regex 和播放/嵌套 fancy regex；校验在修改内存配置和写文件之前完成。
- 回归测试：`add_source_config_rejects_invalid_regex_and_selector_without_persisting`、
  `update_single_source_config_rejects_invalid_selector_without_persisting`。
- 迁移/回滚：合法配置不变；此前可保存但运行时必然失效的配置现在会在保存时返回具体字段错误。

### RT-2-005 — FRB 进度流关闭后 Rust 搜索仍继续请求

- 工作包：RT-2（2026-07-19）
- 现象：Dart 取消进度 Stream 后，`StreamSink::add` 返回发送失败，但所有调用都用 `.ok()` 忽略；Rust
  仍会继续抓取详情页、解析剧集和写缓存，取消只能停止 UI 接收，不能停止后台工作。
- 根因：搜索函数直接依赖 FRB sink，未把发送结果作为取消信号，也无法在纯 Rust 测试中替换 sink。
- 修复：抽出 `ProgressEmitter` 和逐源 `run_source_with_progress`；任一中间事件发送失败即返回，不再发起
  下一阶段请求，同时保持对外 FRB 函数签名不变。
- 回归测试：`closed_progress_sink_stops_before_detail_fetch` 模拟首个事件后关闭 sink，断言 search 请求为 1、
  detail 请求为 0；另覆盖步骤单调和每源单一终态。
- 迁移/回滚：仅改变已关闭流后的后台行为；正常打开的进度流事件顺序与字段兼容。

### RT-3-001 — Bangumi fetch 的状态码处理分支被网络助手提前截断

- 工作包：RT-3（2026-07-19）
- 现象：character/person/relation/episode/comment/user/image/GraphQL 多个函数调用
  `retry_request_bangumi` 后再检查 `resp.status()`，但该助手默认先执行 `error_for_status()`；因此源码中
  “404 返回空列表”“第二页失败保留前页”“返回自定义错误”“读取 API 错误正文”等分支实际不可达。
- 根因：fetch 层同时混用了网络层自动状态错误和端点自己的状态策略，没有显式请求
  `allow_error_status=true`。
- 影响：本应视为无数据的 404 会冒泡成请求错误；REST episode 后续页限流会丢弃已经取得的完整页；
  用户 API 丢失服务端错误正文；GraphQL 无法保留非 2xx 返回的结构化 `errors` 数据。
- 修复：所有需要自行解释状态码的 Bangumi 请求改用 `retry_request_bangumi_with_status(..., true)`，
  仍由网络层对 5xx 做既有重试，最终状态交给端点按原设计映射。
- 回归测试：`rest_episode_fetch_returns_completed_pages_when_later_page_is_rate_limited`、
  `character_fetch_applies_rest_empty_and_next_error_status_policies`、
  `person_fetch_uses_custom_detail_error_and_empty_list_fallbacks`、
  `user_fetch_encodes_username_and_reports_api_error_body`、
  `execute_graphql_preserves_json_error_body_on_http_error`。
- 迁移/回滚：不涉及持久化；成功响应不变，仅恢复原源码已经表达但此前不可达的错误/降级语义。

### RT-3-002 — Bangumi JSON 的 i64 直接窄化为 i32 会回绕

- 工作包：RT-3（2026-07-19）
- 现象：人物类型、角色统计、生日字段、收藏 type/rate、剧集数和收藏人数等值使用 `as i32`；超过
  `i32` 范围的上游数字会回绕成负数或其他无关值。
- 根因：把 JSON 数字解析成功等同于目标 DTO 可表示，未做 checked conversion。
- 影响：异常或 schema 变化后的 API 数据可能让 UI 显示负收藏数、负剧集数、错误类型/评分；未知收藏
  状态也可能因溢出与合法枚举碰撞。
- 修复：集中增加 `json_i32`，使用 `i32::try_from`；合法未知收藏状态（例如 `99`）原样保留给 UI 的
  unknown fallback，真正越界或字段类型变化则稳定回退 `0`/`None`。
- 回归测试：`json_i32_rejects_type_changes_and_overflow`、
  `character_details_normalize_missing_types_and_infobox_values`、
  `person_details_normalize_type_changes_and_mixed_infobox`、
  `collections_preserve_unknown_enum_and_reject_overflow_and_missing_identity`。
- 迁移/回滚：不涉及；i32 范围内的正常值和 1～5 收藏状态保持原样。

### RT-3-003 — 协议相对图片与双引号 avatar style 未被可靠规范化

- 工作包：RT-3（2026-07-19）
- 现象：`normalize_image_url`/`normalize_avatar_url` 仅调用 host rewrite，`//lain.bgm.tv/x.jpg` 在直连
  模式保持无 scheme，在代理模式也可能只改 host 仍保持 `//`；legacy subject comment 的 avatar 只识别
  `url('...')`，无法读取 `url("...")`、`url(&quot;...&quot;)` 或无引号形式。
- 根因：URL 绝对化发生在 rewrite 未命中之后，而 rewrite 命中协议相对 host 时会跳过补 scheme；CSS URL
  提取又绑定单一引号形式。
- 影响：图片组件收到不可直接请求的 URL，开启代理后仍可能加载失败；部分 legacy 评论头像稳定为空。
- 修复：先把协议相对/站内相对 URL 绝对化，再统一应用代理 rewrite；CSS `url(...)` 提取支持单引号、
  双引号、`&quot;` 和无引号，并复用同一 normalize 路径。
- 回归测试：`image_normalization_absolutizes_protocol_relative_urls_before_proxy_rewrite`、
  `avatar_style_parser_accepts_quote_variants_and_relative_urls`、
  `hybrid_subject_comments_fall_back_to_legacy_html`。
- 迁移/回滚：仅规范化读时 URL，不修改缓存或用户配置；已有绝对 URL 保持不变。

### RT-3-004 — 多个 Bangumi 列表会向 UI 暴露 id=0 的无效实体

- 工作包：RT-3（2026-07-19）
- 现象：subject characters/persons、episodes、relations 和用户收藏等解析器对缺失/类型变化的 ID 使用
  `unwrap_or(0)` 后仍加入结果；actor/person 关联也可能产生 ID 0。
- 根因：可选字段默认值与列表条目的最小身份校验混在一起，缺少“有效 ID 才能成为可导航实体”的约束。
- 影响：用户可看到无效卡片/剧集/收藏项，点击后请求 `/subjects/0`、`/characters/0` 等不存在资源；
  同一批脏数据还可能产生重复的 ID 0 项。
- 修复：所有可导航列表统一要求 ID `> 0`；关联人物也过滤无效 ID，非身份字段仍按既有默认值容错。
- 回归测试：`rest_character_normalization_filters_invalid_ids_and_actor_shapes`、
  `episode_page_normalization_handles_schema_drift_and_invalid_rows`、
  `persons_normalize_optional_fields_and_reject_invalid_identity`、
  `relations_keep_supported_anime_rows_and_filter_invalid_identity`、
  `collections_preserve_unknown_enum_and_reject_overflow_and_missing_identity`。
- 迁移/回滚：不涉及；只丢弃无法正确导航的异常上游条目。

### RT-3-005 — 现代 Bangumi 评论接受超出 10 分制的评分

- 工作包：RT-3（2026-07-19）
- 现象：Next comments 解析只判断 `rate > 0`，因此 11、极大整数等值可能作为有效评分进入 DTO。
- 根因：只验证正数，没有落实 Bangumi 评分的 1～10 枚举范围，也没有统一使用 checked i32 转换。
- 影响：评分星级/文本可能显示异常，极大值在窄化路径中还可能回绕。
- 修复：评分先经 `json_i32`，仅保留 `1..=10`，零、负数、越界和字段类型变化统一为 `None`。
- 回归测试：`next_subject_comments_escape_markup_and_validate_rating_range` 同时覆盖 10、11、i32 溢出、
  空评论和 XSS-like markup 转义。
- 迁移/回滚：合法 1～10 评分不变；仅将不可能的上游评分视为未评分。

### RT-4-001 — Legacy schedule 拆分时间节点时丢失播出时间

- 工作包：RT-4（2026-07-19）
- 现象：新版 legacy archive HTML 把“每周日”和“01:30”放在两个 datetime `<span>` 中时，解析器只取
  第一个包含周/时间标记的节点，结果只有 `broadcast_day`，`broadcast_time` 为空。
- 根因：现代时间 selector 使用 `.find(...)`，没有合并同一条目中的多个时间片段。
- 影响：时间表可显示正确星期但缺少具体开播时间，排序/分组依赖时间时也会退化。
- 修复：收集同一条目内所有包含星期或时间的片段后统一交给 `parse_broadcast_parts`。
- 回归测试：`legacy_schedule_resolves_relative_official_urls_and_keeps_stable_order`。
- 迁移/回滚：不涉及；单节点时间文本行为不变。

### RT-4-002 — Archive/schedule 的缺字段、非法季度和重复项可破坏整批结果

- 工作包：RT-4（2026-07-19）
- 现象：season 响应缺 `version` 会反序列化失败，`2025q9` 会进入 archive；schedule 中单条缺 title/begin
  可使整批 JSON 失败，重复 Bangumi ID/无 ID 同名条目会重复展示，相对 `officialSite` 原样传给 UI。
- 根因：未使用字段仍是 required；季度正则接受任意单数字；强类型列表没有坏行默认值、实体去重和 URL join。
- 影响：上游轻微 schema 漂移可能让整个季度不可用，或导致重复卡片、打不开的官网链接。
- 修复：可选/未使用字段补 `serde(default)`；季度严格限制 q1～q4；按 Bangumi/Mikan ID 或标题稳定去重；
  API/HTML 相对官网链接通过 `url::Url::join` 绝对化，非法 scheme 丢弃。
- 回归测试：`archive_html_deduplicates_valid_quarters_without_requiring_year_heading`、
  `api_archive_and_schedule_skip_duplicates_missing_fields_and_bad_quarters`。
- 迁移/回滚：不涉及；合法且唯一的既有响应顺序保持不变。

### RT-4-003 — Sites index 的重复 subject 覆盖站点且相对 URL 未解析

- 工作包：RT-4（2026-07-19）
- 现象：同一 Bangumi subject 在 `bangumi-data` 出现多行时，后写入的 `HashMap::insert` 覆盖前一行全部
  sites；显式 `/rss/1`、`extra.xml` URL 直接暴露，缺少 site meta 字段会让整份 JSON 解析失败，ID 0 也可建索引。
- 根因：索引按行 replace 而不是 merge，没有 site+URL 去重、相对引用解析和最小身份校验。
- 影响：详情页会随机缺少部分资源站点，点击相对链接失败；一条不完整 metadata 可让整个离线 sites 能力失效。
- 修复：按 subject 合并并稳定去重；site meta 可选字段默认化；相对 URL 以填充后的 `urlTemplate` 为基准
  使用标准 URL join；只索引正 Bangumi/Mikan ID 和 HTTP(S) URL。
- 回归测试：`site_map_merges_duplicate_subjects_and_resolves_relative_urls`。
- 迁移/回滚：索引仅驻留内存，无持久化迁移；下一次构建自动获得新语义。

### RT-4-004 — 并发原子写共享同一临时文件名

- 工作包：RT-4（2026-07-19）
- 现象：同进程两个 `atomic_write_bytes` 都使用 `<name>.tmp.<pid>`，会同时 truncate/写入同一 staging
  文件；rename 竞争可能报错，甚至把由另一调用改写的内容提交到目标文件。
- 根因：临时文件名只有 PID，没有线程/调用级唯一值；Windows rename 失败后还会退化为可被读到半文件的 copy。
- 影响：并发刷新或未来新增的并行写路径可能产生失败、错配 payload 或部分文件，破坏离线 schedule/sites。
- 修复：临时文件名增加进程内原子 sequence；所有平台只接受原子 rename，失败时保留旧目标并清理 staging，
  不再 copy fallback。
- 回归测试：`atomic_writes_replace_existing_files_and_leave_no_partial_temp_files`（12 路并发）。
- 迁移/回滚：无格式变化；遗留 `.tmp.*` 不会被读取，新写入成功后测试确认无残留。

### RT-4-005 — 刷新竞态可重新安装或继续复用旧 parsed data/sites index

- 工作包：RT-4（2026-07-19）
- 现象：线程 A 解析旧 JSON 时线程 B invalidate/替换文件，A 随后仍可把旧 `Arc` 写回全局 slot；sites index
  只判断 `Option::is_some`，即使 data generation 已变化也会直接复用旧映射。
- 根因：parsed cache 安装前未比较 generation，sites index 本身也不记录构建 generation；检查与写入之间缺少
  对刷新版本的契约。
- 影响：手动刷新或跨路径并发 warmup 后，当前进程可能继续显示旧季度/旧资源站点，直到再次显式 invalidate。
- 修复：data invalidate 先递增 generation；冷读安装前在写锁内复核，不一致则重读；sites index 保存 generation，
  build/lookup/background warmup 都拒绝复用过期 index。
- 回归测试：`concurrent_readers_share_cached_arc_and_invalidation_loads_replacement`、
  `concurrent_builds_share_one_index_and_invalidation_reloads_new_file`。
- 迁移/回滚：仅内存缓存协议变化；磁盘 JSON 格式不变。

### RT-4-006 — 详情补全会覆盖已有有效字段并对重复 ID 重复请求

- 工作包：RT-4（2026-07-19）
- 现象：`apply_subject_details` 无条件替换 score/rank/tags/full JSON；同一 subject 在 schedule 中重复出现且
  GraphQL 未命中时，每个条目各发一次 REST/P1 请求；modern 非法 ID 还会退化为请求 `/0`。
- 根因：fill 操作没有区分“已有有效值”和“待补字段”，fallback task 以条目 index 而非 subject ID 建立。
- 影响：较完整的上游/缓存数据可能被较弱 fallback 清空或降级，重复条目放大网络请求，非法 ID 产生无意义请求。
- 修复：仅填空白/无效字段；按正 subject ID 聚合 index，同一 ID 请求一次并将结果应用到原位置；非法 ID 跳过。
- 回归测试：`apply_details_fills_only_missing_or_invalid_fields`、
  `partial_fallback_failure_preserves_order_and_deduplicates_requests`。
- 迁移/回滚：不涉及；成功补全仍保留输入顺序，已有有效字段现在优先。

### RT-4-007 — Unicode 非法季度参数可在字节切片时 panic

- 工作包：RT-4（2026-07-19）
- 现象：`fetch_extra_bangumi_subjects` 先检查 byte length，再执行 `&year_quarter[..4]`；中文等多字节输入
  的第 4 byte 可能不是 UTF-8 字符边界，直接 panic。
- 根因：把季度格式校验实现为固定 byte offset 切片，并在校验合法性前切片。
- 影响：FRB 或内部调用收到异常 Unicode 参数时可让 Rust 调用崩溃，而不是稳定返回空结果/参数错误。
- 修复：先用完整字符串正则匹配 `^(\d{4})q([1-4])$`，再从 capture 读取 year/quarter，不做任意 byte 切片。
- 回归测试：`invalid_unicode_quarter_returns_empty_without_panicking_or_network`。
- 迁移/回滚：合法季度行为不变。

### RT-4-008 — Crawler 详情的 score/rank 缺少范围与 checked conversion

- 工作包：RT-4（2026-07-19）
- 现象：crawler 的 `apply_subject_details`、light subject 和 extra subjects 仍把 `i64 rank` 用 `as i32`
  窄化，并接受 11 分 score；字符串 `NaN` 也会进入数值转换分支后退化为非预期 JSON 值。这是 RT-3
  在其他 Bangumi normalize 模块修复后遗漏的副本。
- 根因：详情补全路径各自解析数字，没有复用范围/checked 规则。
- 影响：异常上游值会回绕成负排名，或让时间表/补充条目显示不可能的评分。
- 修复：集中 `valid_score`（有限且 0～10）与 `valid_rank`（正数且 `i32::try_from` 成功），所有 crawler
  详情入口统一使用。
- 回归测试：`detail_normalization_rejects_non_finite_scores_and_rank_overflow`。
- 迁移/回滚：合法数值不变；只把不可表示/越界值视为缺失。

### RT-4-009 — 未来时间的 failure marker 会长期抑制缓存重试

- 工作包：RT-4（2026-07-19）
- 现象：系统时钟回拨或 marker 来自未来时间时，`saturating_sub` 返回 0，warmup 会把它视为刚失败并持续
  跳过重试，最长直到本机时钟追上 marker。
- 根因：未来 epoch 与真实的“刚刚失败”共用同一数值 0，没有把 clock-skew/损坏状态视为未知。
- 影响：已有 stale cache 的用户可能在较长时间内无法自动刷新。
- 修复：marker epoch 大于当前时间时返回 `None`，允许正常 freshness/retry 策略继续执行。
- 回归测试：`version_and_failure_markers_tolerate_empty_corrupt_and_future_values`。
- 迁移/回滚：marker 格式不变；未来值现在按无有效失败记录处理。
