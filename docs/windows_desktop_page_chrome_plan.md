# Windows 多 Tab 页面顶部栏改造计划

> 状态：页面盘点与实施计划
> 日期：2026-07-26
> 范围：Windows 桌面端，基于现有 `WindowsDesktopFrame`、`WorkspaceTabHost` 和全局上下文工具栏
> 非目标：本计划不直接修改页面代码，不改变 Android/iOS 的布局与交互

## 1. 背景与结论

Windows 现在有两层统一外壳：第一层是 Tab/窗口控制，第二层是返回、前进和当前 Tab 标题。页面仍保留各自的 `Scaffold.appBar` 或页面内部顶部栏，因此会出现重复的返回按钮和标题。改造目标是：

1. Windows 页面不再重复绘制“返回按钮 + 页面标题”。返回统一由 `WorkspaceContextToolbar` 处理，标题统一由当前 route/tab metadata 处理。
2. 页面顶部仍承载的业务操作不能简单删除：搜索输入、筛选、TabBar、保存/刷新、播放器下载等要迁移到页面内容区，或接入可选的桌面页面操作槽。
3. 详情页的沉浸式图片头部、移动端可折叠标题栏、播放器视频控制不能被通用规则破坏，需单独处理。
4. 移动端继续使用现有 `AppBar`/`SliverAppBar`/底部导航；所有新组件都必须由 Windows capability 或平台分支启用，不能用“宽度小于某值”替代平台判断。

### 1.1 建议的统一接口

新增一个轻量的桌面页面 Chrome 约定（名称可按实现调整）：

- `DesktopPageChromeScope`：页面声明桌面标题、是否显示页面内 action row、当前 route 是否允许全局返回。
- `DesktopPageActionRow`：页面内容内的业务操作行，支持 `pinned`/随内容滚动两种模式。
- `WorkspaceContextToolbar` 继续只负责 Back、Forward、Tab title；必要时预留右侧 action slot，但不把所有页面业务操作强行塞进全局栏。
- `DesktopOnly`/平台 capability：Windows 使用新 Chrome，移动端和 Linux/macOS 走现有页面树。

推荐优先把操作放在页面内容第一行：这样不会挤压全局标题栏，也能让搜索、筛选、保存等操作与其作用对象保持上下文；只有播放器下载等必须常驻的操作才考虑放到上下文工具栏右侧。

### 1.2 统一结构调整

Windows 页面移除自身 `AppBar` 后，页面根布局需要检查以下问题：

- 删除 `extendBodyBehindAppBar` 后的顶部 padding，避免留下 `kToolbarHeight` 空白。
- `CustomScrollView`/`NestedScrollView` 的首个 sliver 改为承载 action row 或 tab row。
- 页面有错误、加载、空状态分支时也不能重新创建旧 AppBar。
- `Navigator.pop`、`PopScope`、`WorkspaceRouteCloseScope` 继续交给当前 Tab 的统一返回协议。

## 2. 页面盘点总表

| 页面/入口 | 当前顶部内容 | Windows 目标方案 | 移动端处理 | 工作量/轮次 |
|---|---|---|---|---|
| `PcHomeLayout` / 首页壳 | 标题、搜索、头像；左侧 `NavigationRail` | 移除标题；搜索和头像迁移到首页内容顶部或桌面 action row；`NavigationRail` 保留为首页专属导航 | `HomeMobilePage` 的 AppBar 原样保留 | 中 / Round 2 |
| `HomePcPage` | 无自身 AppBar | 配合首页壳提供可滚动/可固定的首页操作区；卡片入口继续走 Workspace | 不改 | 低-中 / Round 2 |
| `IndexPage` | 移动宽度下标题+搜索；桌面宽度无 AppBar | 独立 Tab 打开时，在筛选区顶部提供搜索入口；作为首页 IndexedStack 时复用首页 action row，避免重复 | 现有移动 AppBar 保留 | 低 / Round 1 |
| `MyPage` | 移动宽度下标题+搜索；桌面宽度无 AppBar | 独立 Tab 打开时不再补标题栏；搜索入口放到内容 action row；头像/下载入口留在内容 | 现有移动 AppBar 保留 | 低 / Round 1 |
| `SearchPage` | 搜索输入、模式菜单、排序菜单、提交按钮 | 移除 AppBar，新增紧凑搜索 command row；Windows 建议 `SliverPersistentHeader(pinned: true)`，输入框保持可见，结果区正常滚动 | 原 AppBar 及键盘行为不变 | 中 / Round 2 |
| `RankingPage` | 标题、趋势/排行 `TabBar` | 移除 AppBar；标题交给全局工具栏；TabBar 作为 body 顶部 pinned row，保持两个列表状态 | 现有 AppBar+TabBar 保留 | 中 / Round 2 |
| `TimeTablePage` | 标题、季度选择、日期 `TabBar` | 移除 AppBar；季度按钮与日期 TabBar 合并为页面顶部控制区，日期栏 pinned；季度 picker 不放进全局返回栏 | 现有 AppBar+TabBar 保留 | 中 / Round 2 |
| `FavoritesPage` | 标题、刷新、Local/Bangumi `TabBar` | 移除 AppBar；刷新和 TabBar 放在 body 顶部，TabBar pinned；刷新作用于当前两个数据源 | 现有 AppBar+TabBar 保留 | 中 / Round 2 |
| `HistoryPage` | 仅标题 | Windows 直接删除 AppBar，列表成为页面根内容 | 保留 AppBar | 低 / Round 1 |
| `DownloadManagerPage`（`my_page.dart`） | 标题、清理已完成 | 标题由全局栏提供；清理按钮迁移到内容顶部 action row，列表滚动时可固定 | 保留现有 AppBar 和清理逻辑 | 低-中 / Round 2 |
| `AboutPage` | 仅标题 | 直接删除 AppBar，内容根布局接管顶部间距 | 保留 AppBar | 低 / Round 1 |
| `SettingsPage` | 仅标题 | 直接删除 AppBar；设置列表成为根内容 | 保留 AppBar | 低 / Round 1 |
| `DataSourceSettingsPage` | 标题、恢复默认、保存 | 标题交给全局栏；恢复/保存迁移到订阅 URL 区域上方的 action row，保存状态必须可见 | 保留 AppBar+actions | 中 / Round 2 |
| `DataSourceConfigPage` | 标题、保存；新建/编辑/只读状态 | Windows 使用页面顶部 sticky action row；保存按钮随表单状态禁用/加载；只读模式仍显示状态 | 保留 AppBar+save | 中-高 / Round 3 |
| `NetworkSettingsPage` | 标题、恢复默认、保存 | 将两个操作迁移到设置列表顶部；保存/恢复不可被滚动内容遮挡 | 保留 AppBar+actions | 中 / Round 2 |
| `SearchSettingsPage` | 标题、保存 | 保存按钮迁移到表单顶部或 sticky action row | 保留 AppBar+save | 低-中 / Round 2 |
| `DownloadSettingsPage` | 标题、保存 | 保存按钮迁移到表单顶部；保存反馈仍使用现有 SnackBar | 保留 AppBar+save | 低-中 / Round 2 |
| `ThemeSettingsPage` | 仅标题 | 直接删除 AppBar | 保留 AppBar | 低 / Round 1 |
| `SubscriptionDebugPage` | 标题（两个 debug 状态分支） | 两个分支都移除 AppBar；全局 Tab title 根据 destination metadata 显示；不能只改成功分支 | 移动端两个 AppBar 保留 | 低 / Round 1 |
| `BangumiDetailsPage` 宽屏 | 透明 AppBar，仅返回；内容已有图片背景、标题和操作 | Windows 宽屏移除透明 AppBar；保留详情内容自己的标题/收藏/分享操作；修正左右滚动区顶部 padding | 移动端保持现有宽屏/移动分支行为 | 中 / Round 3 |
| `BangumiDetailsPage` 移动/紧凑 | `SliverAppBar`，可折叠头部、返回、详情/评论 Tab | 不套用普通页面删除规则；Windows 紧凑模式单独验证。若复用该结构，允许标题栏随详情内容滚动，但返回仍隐藏以避免重复 | 现有 `SliverAppBar` 原样保留 | 高 / Round 3 |
| `CharacterDetailPage` | 透明 AppBar，仅返回，背景图/渐变 | Windows 桌面分支移除 AppBar，把顶部间距纳入内容布局；背景渐变保留 | 移动端透明 AppBar 保留 | 中 / Round 3 |
| `PersonDetailPage` | 透明 AppBar，仅返回，背景图/渐变 | 与角色页一致；错误态也必须去掉重复返回栏 | 移动端透明 AppBar 保留 | 中 / Round 3 |
| `TagBrowsePage` | 实际复用 `SearchPage` | 跟随 SearchPage 的 Windows command row；tag 初始条件必须继续显示 | 跟随 SearchPage 原行为 | 低 / Round 2 |
| `PlayerPage` / `PlayerPcLayout` | 页面内部返回、剧集标题/集数、当前源下载/复制按钮 | Windows 桌面移除内部返回和重复标题；剧集标题/集数成为视频上方的内容 heading；下载/复制保留在视频上方 sticky action row，必要时接入 context toolbar action slot | 移动播放器布局和返回/锁屏/手势不改 | 高 / Round 3 |
| `PlayerPage` 紧凑桌面模式 | 可能复用单列信息结构 | 沿用 `PlayerUiMode.desktopCompact`，不得启用移动顶部栏或触屏手势；统一返回由 Workspace 提供 | 移动模式不改 | 高 / Round 3 |
| 播放器全屏 | frame 被全屏覆盖 | 继续由 `WindowsDesktopFrameController` 隐藏全部外壳；退出后恢复全局工具栏和 action row | 不改 | 回归 / Round 4 |

## 3. 分轮实施计划

### Round 0：Chrome 能力与回归基线（低风险，约 1–2 人日）

目标是先让页面能在 Windows 判断“是否由 Workspace 承载”，不改移动端树。

1. 定义 `DesktopPageChromeScope`/页面 action row 的最小 API，或在现有 `WorkspaceContextToolbar` 上增加等价的可选 action slot。
2. 统一 desktop page body 的顶部间距规则，提供不带 AppBar 的 `DesktopPageScaffold`（名称可调整）。
3. 确认 `WorkspaceDestination` 的 title 是唯一的 Windows route 标题来源；处理异步打开和前进重建后的标题更新。
4. 增加 widget 测试：Windows 分支无重复 back/title；非 Windows 分支仍渲染原 AppBar；全屏时页面 Chrome 不覆盖播放器。
5. 建立页面清单截图基线：720、900、1280 px，亮/暗主题各一组。

验收：只打开基础能力开关时，移动端像素和交互无变化，Windows 仍可通过全局 Back 返回/关闭 route。

### Round 1：纯标题栏页面（低工作量，约 1–2 人日）

优先处理没有业务 action 的页面，快速消除大部分重复标题。

- `AboutPage`
- `HistoryPage`
- `SettingsPage`
- `ThemeSettingsPage`
- `SubscriptionDebugPage`（包括 feature disabled/error 分支）
- `IndexPage`、`MyPage` 的 Windows 独立 Tab 标题处理

实现要点：

- Windows 删除 `Scaffold.appBar`，保留 body、滚动控制器和状态。
- 所有内容顶部 padding 重新按 frame/context toolbar 后的可用高度计算，不继续使用为 AppBar 预留的 `kToolbarHeight`。
- `IndexPage`/`MyPage` 的搜索按钮不因删除移动 AppBar 而消失；放到 Round 2 的共享 action row，或在本轮暂时保留桌面内容入口。

验收：页面标题只在全局上下文工具栏出现一次，Back 只出现一次，列表首项无额外空白。

### Round 2：业务操作迁移（中等工作量，约 4–6 人日）

处理顶部仍有搜索、筛选、Tab、刷新、保存等业务操作的页面。

- 首页壳、`SearchPage`、`RankingPage`、`TimeTablePage`、`FavoritesPage`
- `DownloadManagerPage`
- `DataSourceSettingsPage`、`NetworkSettingsPage`、`SearchSettingsPage`、`DownloadSettingsPage`
- `TagBrowsePage`

实现顺序建议：先做可复用的 `DesktopPageActionRow`，再按页面迁移：

1. 搜索页：输入框/模式/排序/提交按钮改为 pinned command row，保留 autofocus、提交和滚动行为。
2. Tab 页面：把 `TabBar` 从 AppBar 的 `bottom` 移到 body 顶部；需要持续可见的日期/分类 Tab 使用 pinned header。
3. 设置页：保存/恢复作为表单顶部操作；保存中、保存成功、失败状态与当前按钮绑定。
4. 首页：标题删除，搜索和头像迁移到内容顶部；`NavigationRail` 仍只属于首页。
5. 下载页：清理操作保留在列表上方，避免放入全局栏后与 Tab/返回按钮竞争空间。

验收：所有原 AppBar action 都能在 Windows 找到；键盘输入、Tab 切换、刷新、保存和滚动位置不回归；页面标题不重复。

### Round 3：沉浸式详情与播放器（高工作量，约 5–8 人日）

这是风险最高的一轮，单独处理不能套用普通 Scaffold 规则的页面。

1. `BangumiDetailsPage`：
   - 宽屏移除透明 AppBar，只保留内容内标题、收藏、分享、播放和关系入口。
   - 调整左右滚动区的顶部 inset，避免背景图/海报被多留或少留一条 toolbar 高度。
   - 紧凑 Windows 模式明确采用桌面详情策略；不能因为 720–900 px 而误启用移动端触控语义。
   - 移动端 `SliverAppBar`、折叠头和底部 Tab 保持不变。
2. `CharacterDetailPage`、`PersonDetailPage`：
   - Windows 桌面/错误态移除透明 AppBar，保留背景渐变、内容头部和错误重试。
   - 移动端继续使用透明返回栏。
3. `PlayerPage`：
   - `PlayerPcLayout` 去掉内部 Back 和重复 anime title；使用全局 Workspace Back/title。
   - episode label、当前源操作（下载/复制链接）迁移到视频上方稳定 action row；操作不能随主滚动区消失。
   - `desktopCompact` 与 `desktopWide` 共用桌面输入能力；不复用移动端锁屏、亮度/音量手势和移动顶部栏。
   - 保持 `WorkspaceRouteCloseScope`、播放焦点、session close、全屏 frame handoff 不变。

验收：详情/播放器在 720、900、1280 px 下无重叠、无黑色/空白顶部；播放器下载、复制、切集、返回、全屏和后台 Tab 播放行为不变；Android/iOS 截图与现状一致。

### Round 4：收尾、清理与跨页面回归（约 2–3 人日）

1. 删除 Windows 分支中已无调用的 AppBar/标题专用代码和重复 padding。
2. 检查所有 loading/error/empty/dialog 返回路径，确认没有页面重新创建旧顶部栏。
3. 完成页面矩阵测试：
   - 720/900/1280 px；亮/暗主题；鼠标/键盘；窗口最大化/还原；应用全屏。
   - 当前 Tab、Ctrl+左键后台 Tab、中键后台 Tab、Back/Forward、关闭 Tab。
   - 移动端至少覆盖 360/412 px，确认 AppBar、底部导航、播放器手势和 `SliverAppBar` 未改变。
4. 更新截图基线和用户可见文案（若设置页 action row 需要新 tooltip）。

## 4. 依赖与风险

| 风险 | 影响 | 规避方式 |
|---|---|---|
| 用宽度判断 Windows/移动布局 | Windows 窄窗误进入移动交互，移动端也可能被误改 | 使用平台 capability + `PlayerUiMode`，不要新增全局宽度断点替代平台判断 |
| 删除 AppBar 后仍保留 `kToolbarHeight` padding | 页面顶部出现空白 | 每页删除 AppBar 后检查 scroll/Sliver inset；为普通页提供统一 scaffold |
| 把所有 action 塞进全局 context toolbar | 小窗口按钮拥挤、标题被截断 | 默认使用页面内 action row；仅播放器等常驻操作使用 toolbar action slot |
| 详情透明 AppBar 与全局 toolbar 叠加 | 背景图、海报和标题错位 | 桌面详情单独布局；移动 `SliverAppBar` 不参与普通页迁移 |
| 播放器页面销毁/重建 | 丢失播放、WebView、焦点或 session 资源 | 只改 `PlayerPcLayout` 视觉层，保留 PlayerPage State、session、close scope 和 fullscreen 协议 |
| 设置页使用 `await Navigator.push<T>` | 返回值语义或保存结果丢失 | 继续使用 `WorkspaceNavigation.pushForResult`/当前 Tab 命令式 route，不把编辑器强行拆成新 Tab |
| Windows frame 初始化失败 | 旧 AppBar 与原生标题栏组合异常 | 保留现有 native title-bar fail-safe，并在失败环境跳过 desktop page Chrome |

## 5. 完成定义

- Windows 每个 route 只显示一套返回/标题；全局 Back、Forward 与 Tab title 可用。
- 页面原有的搜索、筛选、Tab、保存、刷新、下载和复制能力均有明确的新位置。
- 详情页和播放器的沉浸式/高频操作不被普通页规则破坏。
- 切换、关闭、前进重建 Tab 不改变 Player session 的生命周期协议。
- Android/iOS 不引入桌面 action row、不删除现有 AppBar、不改变底部导航和移动播放器交互。

