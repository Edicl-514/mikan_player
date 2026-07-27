# Bangumi 账号集成：进度与后续计划

本文档记录 Bangumi 账号功能的落地进度。端点级参考见 [`bangumi-integration.md`](./bangumi-integration.md)；本文只讲**已实现的架构**和**后续 plan**。

分支：`bangumi_sync`

上游契约以实时规范为准，不以本文表格为准：
p1 = `https://next.bgm.tv/p1/openapi.json`（核对时 `info.version` 为 `2026-07-27-3ea7b96`），
v0 = `bangumi/api` 仓库 `open-api/v0.yaml`。

---

## 1. 总览

目标：在不依赖中转服务器的前提下，直接对接 Bangumi 官方 API。

**写操作只保留收藏模块**；社区内容（吐槽、讨论版、透视、长评）一律只读，
发送类操作的可行实现方法只记录在第 6 章，不实现。理由见 5.1。

| 阶段 | 内容 | 写操作 | 状态 |
|---|---|---|---|
| **Phase 1** | OAuth 登录 + 收藏状态同步 | 有 | ✅ 已完成 |
| Phase 2 | 收藏的评价 / 评分 / 标签 / 隐私 | 有 | ⏳ 待开发 |
| Phase 3 | 社区内容只读（条目吐槽、长评、讨论版、透视、角色 / 人物吐槽） | 无 | ⏳ 待开发 |
| — | 发送吐槽 / 发帖 / 说句话 | — | ❌ 不实现，见第 6 章 |

---

## 2. Phase 1 已完成的变更

### 2.1 凭证管理（Rust，编译期注入）

- `BANGUMI_APP_ID` / `BANGUMI_APP_SECRET` 存放在项目根目录 `/.env`。
- `rust/build.rs` 在编译时把 `.env` 的每一项导出为编译期环境变量。
- `rust/src/api/bangumi/auth.rs` 通过 `option_env!` 读取（与 `danmaku.rs` 的
  `DANDANPLAY_*` 完全一致的模式）。
- **`client_secret` 不跨越 FRB 边界** —— `code` → `token` 的兑换、以及后续
  刷新，全部在 Rust 内完成。Dart 只拿得到最终的 `access_token` / `refresh_token`。
- 这只是代码所有权边界，**不是保密保证**：分发到用户机器上的二进制可以被反编译，
  编译期注入的 `client_secret` 仍然可能被提取。发布流程必须支持凭据轮换；若 Bangumi
  后续支持 PKCE/public client，应优先迁移。需要真正保密时只能由可信后端兑换 token。

### 2.2 OAuth 登录流程

```
┌───────────────┐  1. 打开授权页        ┌──────────┐
│ InAppWebView  │ ───────────────────► │  bgm.tv  │
│ (Dart)        │                       │ authorize│
└───────────────┘                       └──────────┘
       │  2. 拦截 302 到 redirect_uri?code=...       │
       │ ◄───────────────────────────────────────────┘
       │  3. 提取 code，关闭 WebView
       ▼
┌───────────────┐  4. exchange(code)    ┌──────────┐
│ BangumiAuth   │ ───────(Rust)───────► │  bgm.tv  │
│ Manager       │ ◄─────────────────────│  token   │
└───────────────┘   5. access/refresh   └──────────┘
       │
       ▼  6. 存入 secure storage + 推入 Rust RuntimeConfig
```

- 授权 URL 由 **Rust** 构建（`bangumi_oauth_authorize_url`），确保授权 GET 与后续
  token POST 用的是**同一个 OAuth host**。每次登录由 Dart 生成 256-bit 随机 `state`，
  回调必须精确匹配 scheme/host/port/path 和 `state` 才会接受 code。
- WebView（`lib/ui/pages/oauth/bangumi_oauth_page.dart`）拦截跳转到
  `redirectUri = http://127.0.0.1:6274/callback` 的导航，提取 `code`。
  - 不启动本地 HTTP 服务，只观察浏览器尝试访问该地址。
  - 用 `127.0.0.1` 而非 `localhost`（Bangumi 会拒绝 `localhost`）。
  - **该 redirect_uri 必须与 bgm.tv/dev/app 上注册的回调地址逐字节一致**，否则兑换会 400。
  - 授权请求申请 `write:collection` scope，否则收藏写接口可能返回 403。

### 2.3 Token 存储与传递

- `lib/services/bangumi_auth_manager.dart`：
  - 用 `flutter_secure_storage` 持久化 token（**v10.x**，v9 与 `wakelock_plus`
    在 `win32` 依赖上冲突）。
  - 通过 `setBangumiAccessToken` 把 access token 推入 Rust `RuntimeConfig`。
  - 提前刷新：到期前 7 天窗口内主动 refresh，避免在线时遇到 401。
  - 并发 refresh 合并为一个请求；登出或新登录会让旧 refresh 结果失效，避免会话复活。
  - refresh 失败后认证请求不会继续发送旧 token；过期 token 会被清除。
- **Rust 掌管所有 HTTP**：认证请求从 config 读取 token 并加
  `Authorization: Bearer`（见 `user.rs`）。
- OAuth 授权与 token 请求**始终直连 `https://bgm.tv`**，不经过可选的内容反向代理；
  ECH 和系统网络代理仍可正常生效。

### 2.4 "账号" 与 "资料" 分离

- `BangumiAuthManager` 只管 token（身份）。
- `UserManager` 只管资料（昵称 / 头像）：
  - 已登录（有 OAuth token）→ 走 `/v0/me`（`refreshFromMe()`）。
  - 未登录 → 走旧的公开用户名查询（`login(username)`）。
- `main.dart` 初始化顺序：**auth manager 必须在 UserManager 之前**，
  这样 UserManager 自动刷新走 `/v0/me` 时 token 已经在 config 里。

### 2.5 收藏同步

- **拉取**：`fetch_my_bangumi_collections` 用**真实 username** 请求
  `/v0/users/{username}/collections`，并带 bearer token（这样连私有收藏也能返回）。
  Flutter 以每页 100 条循环拉取，直到最后一页，不再只显示前 30 条。
- **写入**：`update_bangumi_collection` 用 `-` 别名请求
  `POST /v0/users/-/collections/{subject_id}`（幂等 upsert）。
- 详情页收藏选择器通过 `BangumiDetailsFavoritesPort.syncRemoteCollection`
  这个可选回调，把本地收藏状态尽力（best-effort）同步到 Bangumi；仅在
  `isAuthenticated` 时启用，失败不影响已成功的本地收藏。

---

## 3. 踩过的坑（重要，后续阶段会再遇到）

1. **OAuth 只认 `bgm.tv`，不认 `bangumi.tv` 别名。**
   `POST bangumi.tv/oauth/access_token` 会 301 跳到 `bgm.tv`，而 reqwest
   在重定向时**会丢掉表单 body**，导致 400 `invalid_grant`。
   解决：`config::get_bangumi_oauth_url()` 始终返回 `https://bgm.tv`；OAuth 不参与
   内容反代改写，避免把应用凭据、授权码或 refresh token 暴露给第三方代理。

2. **`-` 自别名只对收藏"写"端点有效，对"列表"端点无效。**
   `GET /v0/users/-/collections` 返回 404 "user doesn't exist"，即便带了
   有效 token。列表端点必须用真实 username；写端点 `POST .../users/-/...` 才接受 `-`。
   （集成文档 `bangumi-integration.md` 在这一点上是错的。）

3. **reqwest 用 `default-features = false`**，没有 `.form()` helper。
   表单 body 需用 `urlencoding` 手动拼接并手动设 `content-type`。

---

## 4. 关键文件索引

| 层 | 文件 | 职责 |
|---|---|---|
| Rust | `api/bangumi/auth.rs` | OAuth 兑换 / 刷新 / 授权 URL 构建 |
| Rust | `api/bangumi/user.rs` | `/v0/me`、收藏拉取、收藏写入 |
| Rust | `api/config.rs` | `bangumi_access_token` 字段 + OAuth host 解析 |
| Rust | `frb_api/bangumi.rs` | 参数校验后的 FRB 门面 |
| Dart | `services/bangumi_auth_manager.dart` | token 生命周期、secure storage、刷新 |
| Dart | `services/user_manager.dart` | 资料（`/v0/me` 或公开查询） |
| Dart | `ui/pages/oauth/bangumi_oauth_page.dart` | 登录 WebView，抓 `code` |
| Dart | `ui/pages/my_page.dart` | 登录 / 登出入口 |
| Dart | `ui/pages/favorites_page.dart` | 收藏列表（认证 / 公开两条路径） |
| Dart | `ui/pages/bangumi_details/bangumi_details_controller.dart` | 收藏写回 Bangumi |

---

## 5. 后续计划

### 5.1 范围与技术决策

调整后的目标只有三条：

1. **完善收藏模块的写入能力** —— 番剧的评价（`comment`）、评分（`rate`）、标签（`tags`）、
   隐私（`private`）全部通过收藏接口落地。这是唯一保留的写操作。
2. **剧集评论保持只读**，不变。
3. **新增条目吐槽、长评、讨论版、透视、角色 / 人物吐槽的只读展示**。

发送吐槽、发帖、回帖、说句话**一律不实现**，可行实现方法记录在第 6 章备查。

#### 为什么写操作只留收藏

Bangumi 的写接口分两套，成本差一个数量级：

| | 收藏写入 | 社区内容写入 |
|---|---|---|
| API | `api.bgm.tv` v0，公开稳定契约 | `next.bgm.tv` p1，私有契约 |
| 鉴权 | OAuth bearer 即可 | bearer **+ 每次现取的 Turnstile token** |
| 幂等 | 是，可安全重试 | 否，超时后重试会产生重复内容 |
| 依赖 | 无 | WebView 内取 Turnstile，受 CSP / site key / 上游策略影响 |

已核对上游实时规范（`https://next.bgm.tv/p1/openapi.json`，`info.version`
`2026-07-27-3ea7b96`，155 个 path）：p1 中要求 `turnstileToken` 的端点共 14 个，
**全部是创建内容的 POST**，清单见 6.1。收藏写入完全不涉及 Turnstile。

因此本轮把 Turnstile 整条依赖链（原 Phase 2B PoC、2C、2D）从计划中移除。
收益是社区功能可以立刻做只读展示而不被 PoC 阻塞，代价是用户需要跳到 Bangumi 网页发内容。

#### 只读端点的鉴权结论

2026-07-27 实测：条目吐槽、长评、条目 / 小组讨论、透视、角色 / 人物吐槽的 GET
**匿名（不带 bearer）即可返回 200**。所以社区只读功能不要求登录。

例外：`GET /p1/timeline?mode=friends` 语义上依赖当前用户的好友关系，未登录时
应只提供 `mode=all`，不要把 `friends` 入口暴露给未登录用户。

带上 bearer 的收益是 `reactions` 里能标出自己、以及能看到自己的私有内容，
所以已登录时仍应携带 token。但**任何携带 bearer 的请求都必须直连官方域名**：

- v0 认证请求固定使用 `https://api.bgm.tv`；
- p1 认证请求固定使用 `https://next.bgm.tv`；
- ECH 和用户配置的系统网络代理仍可使用；
- 可选的 Bangumi 内容反代只允许承载匿名 GET，不得收到 bearer。

这是 Phase 2 / 3 的前置安全改造。当前 `get_bangumi_api_url()` /
`get_bangumi_next_url()` 会按反代模式改写 host，不能直接用于带认证头的请求；应增加
credential-aware URL helper，并用 mock server / URL resolver 测试认证与匿名两条路由。

---

### 5.2 Phase 2：收藏的评价 / 评分 / 标签 / 隐私

#### 现状

Rust `api/bangumi/user.rs:334` 的 `update_bangumi_collection` 已经能在 POST body 中发送
`rate` / `comment` / `private` / `tags`，`frb_api/bangumi.rs:317` 的门面也已透出这些字段。
但现有能力还不能直接作为 Phase 2 的最终接口：

- `services/bangumi_collections_repository.dart:19` 的 `BangumiCollectionsBackend.update`
  只声明了 `subjectId` 和 `type`，把其余字段挡在了接口外。
- Rust / FRB 强制要求 `collection_type`，无法保证元数据编辑只发送实际改动字段。
- 缺少元数据专用 PATCH，以及使用真实 username 的单条完整收藏读取。
- 现有 `fetch_my_bangumi_collection_type` 使用 `GET /v0/users/-/...`，不符合单条读取契约。

所以 Phase 2 需要调整 Rust API 边界和 Dart repository，不只是给现有 Dart 方法增加参数。

#### API 契约

沿用现有的 v0 端点，不迁到 p1：

状态 upsert：

```http
POST https://api.bgm.tv/v0/users/-/collections/{subject_id}
Authorization: Bearer <access_token>
Content-Type: application/json

{"type":3}
```

已有收藏的元数据部分修改：

```http
PATCH https://api.bgm.tv/v0/users/-/collections/{subject_id}
Authorization: Bearer <access_token>
Content-Type: application/json

{"rate":8,"comment":"评价内容","private":false,"tags":["科幻"]}
```

已核对 v0 规范（`bangumi/api` 仓库 `open-api/v0.yaml`）的
`UserSubjectCollectionModifyPayload`，逐字段规则：

| 字段 | 规则 |
|---|---|
| `type` | 可选；传入时必须为 `1..5`。POST 时不存在则创建，存在则修改 |
| `rate` | `0..10`，`0` 表示**删除评分** |
| `comment` | 官方描述就是「评价」；空字符串清空 |
| `private` | 仅自己可见 |
| `tags` | 不传或 `null` 被忽略，传 `[]` **删除所有 tag**；单个 tag **不能包含空格** |
| `ep_status` / `vol_status` | 只能用于书籍条目，动画条目不要发 |

两个必须落到实现里的约束：

- **`tags` 的 `null` 与 `[]` 语义不同。** 「不修改标签」必须传 `null`（即 Rust 侧
  `None`，字段整体省略），「清空标签」才传 `[]`。Dart 侧不能用 `[]` 表示「没改」，
  否则会静默删除用户所有标签。
- **tag 不能含空格。** UI 用 Enter / 逗号确认一个 tag；每项 trim、删除空项并去重，
  对仍含空白字符的单项显示字段错误，不做可能改变用户意图的静默切分。

v0 规范明确说明 POST / PATCH 的 payload **所有字段均可选**。因此写入按用途拆成两条
通道，避免编辑评价时携带一个可能已经过期的收藏状态：

- `POST /v0/users/-/collections/{subject_id}`：只用于新增收藏或明确修改收藏状态；
  此时传 `type`，保留 upsert 语义。
- `PATCH /v0/users/-/collections/{subject_id}`：用于修改 `rate` / `comment` /
  `private` / `tags`；默认不传 `type`。条目未收藏时的 404 是有用的并发保护，提示用户
  刷新状态，而不是静默重新创建收藏。

Rust / FRB 不能再把 `collection_type` 作为所有更新的必填参数。可以拆成两个明确函数，
或把底层 payload 的 `collection_type` 改成 `Option<i32>` 并校验请求至少包含一个字段。

> ⚠️ p1 的 `PATCH /p1/collections/subjects/{subjectID}` **只有** `epStatus` 和
> `volStatus` 两个字段，改不了评价 / 评分 / 标签；p1 的 `PUT` 是全量替换。
> 都不要用来写短评。

#### 实现落点

- `api/config.rs` / Bangumi 请求 helper：认证请求绕过内容反代，匿名 GET 才允许使用反代；
  不改变 ECH 和系统网络代理行为。
- Rust / FRB：保留状态 POST，新增元数据 PATCH；PATCH 的
  `rate` / `comment` / `private` / `tags` 均为可选参数，区分「不修改」（`None`）和
  「清空」（`0` / `''` / `[]`）。
- Rust / FRB：新增 `fetch_my_bangumi_collection(username, subject_id)`，通过
  `GET /v0/users/{username}/collections/{subject_id}` 返回完整收藏。**读取单条收藏不能用
  `-` 自别名**；现有 `fetch_my_bangumi_collection_type` 使用 `-` 的实现一并替换。
- `services/bangumi_collections_repository.dart`：分别暴露 `setStatus`、`patchMetadata`、
  `fetchMineOne`，不要用一个始终要求 `type` 的 `update` 混合两类语义。
- `models/bangumi_user_collection.dart`：已有 `comment` / `tags` / `rate` / `private`
  字段，无需扩展。
- `ui/pages/bangumi_details/`：收藏面板增加评分选择、评价输入、标签编辑和隐私开关；
  打开面板时用真实 username 拉取完整远端收藏，提交时只发送用户实际改动的元数据字段。
- `services/bangumi_collection_sync_service.dart`：本阶段仍然只同步收藏状态。当前
  `LocalFavorite` / `DbLocalFavorites` 没有用户评分、评价、标签、隐私、修改时间和同步基线，
  不具备可靠的字段级双向合并条件。评价元数据以 Bangumi 远端为唯一事实来源。
- 成功后用 `fetchMineOne` 重新拉取该条目的完整收藏，以服务端结果为准，不做乐观更新。
- 增加跨 FRB 的结构化 `BangumiApiError`（至少包含 `operation`、`status`、上游
  `code`、`retry_after_seconds`），Dart 不解析错误字符串来区分状态。

#### 验收标准

- 可以新增、修改、清空评分（`0`）和评价（空串），且不影响未提交的其他字段。
- 「不修改标签」不会删除既有标签；「清空标签」能确实清空。
- 含空格的 tag 在提交前被处理，不会被服务端拒绝或截断。
- 隐私开关生效，且不会意外重置收藏状态。
- 仅修改评分 / 评价 / 标签 / 隐私时，请求 body 不包含 `type`。
- 单条收藏读取使用真实 username，能够加载并回读全部元数据。
- 401 / 404 / 429 / 网络错误通过结构化错误稳定提示；401 刷新 token 后最多重试一次，
  429 尊重 `Retry-After`。收藏写入使用同一 payload 时幂等，允许有界退避重试。
- 开启内容反代时，认证请求仍发往官方域名，反代不会收到 bearer。

---

### 5.3 Phase 3：社区内容只读

全部为 GET，无 Turnstile，无写操作。已核对端点、响应 schema 和匿名可用性。

#### 3A 条目吐槽（当前收藏短评聚合）

```http
GET https://next.bgm.tv/p1/subjects/{subjectID}/comments?type=&limit=&offset=
```

- 响应 `{data: SubjectInterestComment[], total}`，字段
  `id` / `user` / `type` / `rate` / `comment` / `updatedAt` / `reactions`。
- `type` 按收藏状态过滤（`1..5`，`CollectionType`）。
- 这是「别人的收藏评价」聚合视图，和 Phase 2 写的是同一份数据，可与详情页收藏面板互相印证。
- Rust `api/bangumi/fetch_comments.rs:418` **已经在用这个端点**，Phase 3 只需补齐
  `rate` / `reactions` 等展示字段。

#### 3B 长评（reviews）

```http
GET https://next.bgm.tv/p1/subjects/{subjectID}/reviews?limit=&offset=
```

- 响应 `{data: SubjectReview[], total}`，但 `SubjectReview` 只有
  `id` / `user` / `entry`，**`entry` 是 `SlimBlogEntry`，只含 `summary` 摘要**。
- **长评正文需要第二次请求**：`GET /p1/blogs/{entryID}`，返回 `BlogEntry`，
  其中 `content` 是完整正文（实测某条 2409 字符）。
- 也就是说 Bangumi 的长评实体就是**日志（blog entry）**，不是独立类型。
  列表页展示 `summary`，点开再拉全文，不要在列表阶段 N+1 拉取所有正文。
- 日志的吐槽可另取 `GET /p1/blogs/{entryID}/comments`。

#### 3C 讨论版

条目讨论：

```http
GET https://next.bgm.tv/p1/subjects/{subjectID}/topics?limit=&offset=   # {data: Topic[], total}
GET https://next.bgm.tv/p1/subjects/-/topics/{topicID}                  # SubjectTopic
GET https://next.bgm.tv/p1/subjects/-/posts/{postID}                    # 单楼层
```

小组讨论：

```http
GET https://next.bgm.tv/p1/groups/{groupName}                           # Group（含 topics/posts/members 计数）
GET https://next.bgm.tv/p1/groups/{groupName}/topics?limit=&offset=
GET https://next.bgm.tv/p1/groups/-/topics/{topicID}                    # GroupTopic
GET https://next.bgm.tv/p1/groups/-/posts/{postID}
```

- **主贴详情内嵌全部楼层**：`SubjectTopic` = `Topic` + `{subject: SlimSubject, replies: Reply[]}`，
  `GroupTopic` 同构。所以「打开一个帖子」只要 1 次请求，不需要单独翻楼层。
- `Reply` 自身带 `replies: ReplyBase[]`（一层子回复）、`reactions` 和 `state`；不要把
  `ReplyBase` 递归解析成要求自身继续带 `replies` 的 `Reply`。
- 楼层正文是 **BBCode**，必须走安全渲染，不能当 HTML 注入。
  Rust 侧已有 `api/bangumi/markup.rs`，优先复用。
- `state` / `display` 标记删除、折叠、管理员操作过的楼层，必须尊重，不能强行展示原文。
- 额外可用入口：`GET /p1/subjects/-/topics`（全站最近条目讨论）、
  `GET /p1/groups/-/topics?mode=all|joined|created|replied`、
  `GET /p1/trending/subjects/topics`（热门条目讨论，实测可用）。

#### 3D 透视（时间线）

```http
GET https://next.bgm.tv/p1/timeline?mode=all|friends&limit=&until=   # Timeline[]
GET https://next.bgm.tv/p1/timeline/-/events?cat=&mode=
GET https://next.bgm.tv/p1/timeline/{timelineID}/replies
GET https://next.bgm.tv/p1/users/{username}/timeline?limit=&until=
```

- 响应是**裸数组**，不是 `{data, total}`；分页用 `until` 游标而非 `offset`。
- `Timeline.cat` 是 `TimelineCat` 枚举：`1` Daily、`2` Wiki、`3` Subject、
  `4` Progress、`5` Status、`6` Blog、`7` Index、`8` Mono、`9` Doujin。
- `memo` 是**按 `cat` 分叉的联合体**（`daily` / `wiki` / `subject` / `progress` /
  `status` / `blog` / `index` …）。解析必须按 `cat` 分派，且对未知 `cat` 保留原样跳过，
  不要假设某个 `memo` 子字段一定存在。
- `mode=friends` 需登录才有意义（见 5.1）；`mode=all` 在高频请求下可能被风控，
  拉取间隔不低于 1 秒并本地按 `id` 去重。

#### 3E 角色 / 人物吐槽

```http
GET https://next.bgm.tv/p1/characters/{characterID}/comments
GET https://next.bgm.tv/p1/persons/{personID}/comments
GET https://next.bgm.tv/p1/characters/{characterID}/photos/{photoID}/comments
GET https://next.bgm.tv/p1/persons/{personID}/photos/{photoID}/comments
```

- 响应是**裸 `Reply[]` 数组**，与条目吐槽的 `{data, total}` 形状**不同**，
  不要共用解析器。
- 可挂在现有角色 / 人物详情页（`api/bangumi/character_detail.rs`、`person_detail.rs`）。
- 附带可用：`GET /p1/subjects/{subjectID}/collects`（谁收藏了本条目，
  支持 `mode=all|friends`）、`/p1/characters/{id}/collects`、`/p1/persons/{id}/collects`。

#### 通用实现约束

- 所有 p1 只读请求继续走 Rust 的 ECH-aware client 和现有 `User-Agent`，不在 Dart
  侧直接发 HTTP。匿名 GET 可以走可选内容反代；携带 bearer 时强制直连
  `https://next.bgm.tv`。
- 时间字段（`createdAt` / `updatedAt` / `joinedAt`）是 **Unix 秒**，
  与 v0 收藏接口的 ISO 字符串不同，不要混用同一个解析函数。
- p1 是私有契约。每类响应都要有 fixture 驱动的解析测试，容忍字段缺失和未知枚举，
  上游变动时表现为「该区块不展示」而不是整页崩溃。
- 只读功能不需要登录；未登录时隐藏 `mode=friends` 之类的入口，而不是报错。

#### 验收标准

- 五类内容都能在无账号状态下正常浏览；支持分页的端点能够正确分页。角色 / 人物吐槽
  是无分页参数的裸数组，完整拉取后应限制首屏渲染量，避免大列表卡顿。
- BBCode 正文安全渲染，删除 / 折叠状态被尊重。
- 时间线未知 `cat` 不会导致解析失败。
- 角色吐槽（裸数组）与条目吐槽（`{data,total}`）各自解析正确。
- 长评列表只拉 `summary`，展开时才请求 `/p1/blogs/{entryID}`。

---

### 5.4 测试计划

#### Rust

- 收藏写入：mock server 断言 method / URL / Bearer，以及 `tags: null` 时字段**被省略**、
  `tags: []` 时字段**存在且为空数组**。
- 收藏写入：`rate=0` 与 `comment=""` 出现在 body 中，而不是被当成空值丢弃。
- 收藏写入：元数据 PATCH 不包含 `type`；状态 POST 包含 `type`；空 payload 在网络请求前
  被拒绝。
- 认证路由：开启内容反代时，带 bearer 的 v0 / p1 请求仍使用官方 host；匿名 GET
  可以使用反代 host。
- 单条收藏：使用真实 username 构建 URL，解析完整收藏；404 与其他错误结构化返回。
- 只读解析 fixture：条目吐槽 `{data,total}`、角色吐槽裸数组、
  主贴内嵌 `Reply[]` 及其 `ReplyBase[]` 子回复、时间线各 `cat` 的 `memo` 分支 + 一个未知 `cat`。
- 覆盖 401 / 404 / 429 / 畸形 JSON / 缺失 `user` / 未知枚举。

#### Dart

- repository：`setStatus` / `patchMetadata` 路由和字段组合透传正确，尤其「不改标签」与
  「清空标签」，以及 metadata 请求不携带 `type`。
- 含空格 tag 的规范化。
- 详情页：加载远端完整收藏、只提交 dirty fields、提交后以回读结果刷新表单。
- 收藏同步继续只比较状态，不把条目公共 `score` 当成用户 `rate`。
- 结构化错误到本地化提示的映射，以及 401 单次刷新、429 `Retry-After` 行为。
- 社区只读页：未登录可浏览、分页、空列表、解析失败降级。
- FRB 重新生成后的 contract tests。

#### 人工集成测试

- 测试账号验证评分 / 评价 / 标签 / 隐私的增改清空，逐项确认未误改其他字段。
- 确认「不修改标签」的提交后，Bangumi 网页端标签未变。
- 未登录状态下浏览全部五类社区内容。
- Release 构建检查日志，确认 bearer token 未泄漏。

---

### 5.5 通用待办 / 加固

- 限速：只读和幂等收藏写入可有界退避重试，429 优先尊重 `Retry-After`；时间线
  `mode=all` 拉取间隔不低于 1 秒。
- 增量同步仅覆盖现有收藏状态。若将来要双向同步评价元数据，必须先为本地收藏增加
  `rate` / `comment` / `tags` / `private`、本地修改时间、远端 `updated_at` 和上次同步
  快照，通过数据库迁移后做三方合并；不能仅比较本地值和当前远端值。
- 离线队列本轮不实现。若未来实现，队列项必须绑定 Bangumi account ID、保存字段级
  payload / 同步基线并支持同条目操作合并，登出或切换账号时不得发送旧账号任务。
- 认证：收藏写操作开始前调用 `ensureFreshToken()`。
- 私有 API 隔离：p1 读取集中在单独模块。fixture contract tests 只保证本地解析回归；
  另加固定版本的 OpenAPI snapshot diff 或低频 smoke test 才能发现上游契约变化，并为
  每类社区区块保留独立关闭 / 降级能力。
- 可观测性：仅记录操作类型、目标 ID、status 和错误 code；严禁记录 bearer 和正文。

### 5.6 建议实施顺序

1. **认证路由与错误契约**：先完成 credential-aware 官方域名路由、结构化错误和
   `Retry-After` 处理；这是后续所有认证请求的共同基础。
2. **Phase 2 读取与写入边界**：实现真实 username 的单条完整读取，拆分状态 POST 和
   元数据 PATCH，重新生成 FRB，并完成 Rust / repository contract tests。
3. **Phase 2 UI**：详情页加载远端表单、dirty-field 提交、提交后回读；现有收藏同步保持
   只同步状态。
4. **Phase 3A 条目吐槽**：先扩展已有端点和模型，验证公共 p1 client、分页、匿名 / 认证
   路由及区块级错误降级。
5. **Phase 3B / 3C 长评与讨论版**：复用安全 BBCode 渲染；列表只取摘要，详情按需加载。
6. **Phase 3E 角色 / 人物吐槽**：处理无分页裸数组和首屏渲染限制。
7. **Phase 3D 透视**：最后实现游标分页和 `TimelineMemo` 联合类型；未知 `cat` 降级跳过。

---

## 6. 备查：发送类操作的可行实现方法（不实现）

本章只记录调研结论，供未来重新评估。**当前不实现，也不要因为「文档里写了」就动手。**
需要发内容时，产品上引导用户跳到 Bangumi 网页对应页面。

### 6.1 需要 Turnstile 的端点全集

以 `https://next.bgm.tv/p1/openapi.json`（`2026-07-27-3ea7b96`）为准，
`turnstileToken` 通过 `allOf` 合并 `TurnstileToken` schema 进入 requestBody
（**不是 header**），共 14 个端点，全部是创建内容的 POST：

| 端点 | 功能 |
|---|---|
| `POST /p1/subjects/{id}/topics` | 条目讨论开新主贴 |
| `POST /p1/subjects/-/topics/{topicID}/replies` | 条目讨论回帖 |
| `POST /p1/groups/{groupName}/topics` | 小组开新帖 |
| `POST /p1/groups/-/topics/{topicID}/replies` | 小组回帖 |
| `POST /p1/episodes/{episodeID}/comments` | 剧集吐槽 |
| `POST /p1/characters/{characterID}/comments` | 角色吐槽 |
| `POST /p1/characters/{characterID}/photos/{photoID}/comments` | 角色图片吐槽 |
| `POST /p1/persons/{personID}/comments` | 人物吐槽 |
| `POST /p1/persons/{personID}/photos/{photoID}/comments` | 人物图片吐槽 |
| `POST /p1/blogs/{entryID}/comments` | 日志吐槽 |
| `POST /p1/indexes/{indexID}/comments` | 目录吐槽 |
| `POST /p1/timeline` | 透视「说句话」 |
| `POST /p1/timeline/{timelineID}/replies` | 透视回复 |
| `POST /p1/login` | 站内密码登录（走 OAuth，用不到） |

**不需要** Turnstile 的写操作：所有评论 / 楼层的 `PUT`（编辑）和 `DELETE`、
全部 `/like`、`PUT /p1/subjects/-/topics/{id}`（编辑主贴）、
`PUT /p1/groups/-/topics/{id}`、`DELETE /p1/timeline/{id}`、`POST /p1/report`、
全部 `/p1/collections/*` 和全部 wiki 编辑端点。

即：**创建要 Turnstile，改和删不要**。不要把 `turnstileToken` 扩散成所有 mutation 的必填字段。

### 6.2 请求形状

```http
POST https://next.bgm.tv/p1/episodes/{episode_id}/comments
Authorization: Bearer <access_token>
Content-Type: application/json

{"content":"BBCode 正文","replyTo":0,"turnstileToken":"<一次性 token>"}
```

- `replyTo` 为 `0` 表示顶层回复，否则为被回复的**楼层 ID**（不是 topic ID）。
- 开新主贴用 `{title, content, turnstileToken}`。
- 成功响应只有 `{"id": 12345}`，缺 user / 时间 / state / reactions，
  必须重新拉列表，不能构造乐观对象。
- 正文按 BBCode 处理，不发送 HTML 或 Markdown。

### 6.3 Turnstile token 的取得方式

规范原文直接给出 site key（比 `bgm-cli` 的间接来源更权威）：

- `next.bgm.tv`：`0x4AAAAAAABkMYinukE8nzYS`
- `dev.bgm38.tv`（测试）：`1x00000000000000000000AA`

可行路径：加载真实 `https://next.bgm.tv/`，确认当前 origin 仍是 `next.bgm.tv` 后
注入本地常量脚本，加载官方 Turnstile JS 并以上述 site key 渲染 widget，
用户完成验证后经 `flutter_inappwebview` JavaScript handler 把 token 交给 Dart，
立即用于一次 POST，随后销毁。

若将来重启此路径，以下约束不可省：

- token 只在内存中，不进日志 / 崩溃报告 / analytics / 持久化存储。
- 只在真实 `next.bgm.tv` 页面注入；禁止 `loadDataWithBaseURL` 伪造 origin。
- 逐字段校验 scheme / host / port；导航到其他 origin 立即终止。
- **不借用白名单中的 `chii://`、`bangumi://` 或其他项目的回调 scheme**
  —— 系统级 scheme 派发不归本应用控制，回调可能被其他进程接走，
  等于把授权凭证交给第三方；同时构成应用身份冒用，风控后果会落在无关项目上。
- 创建类 POST **禁止自动重试**：超时可能已成功，重试会产生重复内容。
  只重新加载列表让用户确认。
- site key 是可变的上游公开配置，集中定义并记录来源。
- 官方把 `/p1/turnstile` 的 redirect 白名单描述为防滥用机制。若上游不接受页面内
  widget 方式，**关闭该能力并使用网页降级入口，不追加规避手段**。

### 6.4 长评（reviews）没有写接口

p1 只有 `GET /p1/subjects/{subjectID}/reviews`；v0 全库没有任何评论 / 长评写端点。
长评实体是日志（blog entry），也没有开放的创建接口。
唯一可行方式是 WebView 打开 `https://bgm.tv/subject/{id}/reviews/new` 由用户提交，
该路径依赖网页 Cookie session，不适合自动化，也不在计划内。

### 6.5 若将来实现，剧集评论的错误分类

| 类别 | 处理 |
|---|---|
| 未登录 / token 过期 | 发送前刷新；仍失败则重新登录并重做 Turnstile，不复用旧 token |
| `CAPTCHA_ERROR` | token 已失效，销毁后允许重新验证 |
| 403 | 展示 Bangumi 返回的原因，不重试 |
| 404 | 目标不存在或已下线，刷新目标信息 |
| 429 | 尊重 `Retry-After`，倒计时结束前禁用发送 |
| 网络错误 / 超时 / 5xx | 不自动重发，刷新列表核对是否已发布，保留草稿 |
