# Bangumi 账号集成最佳实践

在不依赖任何中转服务器的前提下,直接对接 Bangumi (bgm.tv) 官方 API,实现:

- OAuth 2.0 登录
- 同步用户收藏
- 评分 / 短评
- 剧集评论
- 评价(长评)

本文档最初基于对 Animeko 项目源码的逆向分析。2026-07-27 已按**上游实时规范**重新核对:

- p1: `https://next.bgm.tv/p1/openapi.json`(`info.version` = `2026-07-27-3ea7b96`,155 个 path)
- v0: `bangumi/api` 仓库 `open-api/v0.yaml`

> ⚠️ 文中出现的 `datasource/bangumi/p1.yaml`、`v0.yaml` 是 **Animeko 仓库**的路径,
> **本仓库不存在这些文件**。核对端点契约时请拉取上面两个上游地址,不要相信本文的表格。
> `turnstileToken` 在规范中通过 `allOf` 合并进 requestBody,用 grep 找 `turnstile`
> 字面量会漏端点,必须解引用 `$ref` / `allOf`。

---

## 1. 基础信息

### 1.1 Base URL

| API | Base URL | 用途 |
|---|---|---|
| OAuth | `https://bgm.tv` | 授权、换 token |
| Open API v0 | `https://api.bgm.tv` | 用户、收藏、条目、搜索 |
| Next API (p1) | `https://next.bgm.tv` | 剧集评论、点赞 |

### 1.2 必备 Header

所有到 `api.bgm.tv` / `next.bgm.tv` 的请求**必须**携带:

```
Authorization: Bearer <access_token>   # 已登录时
User-Agent:    <AppName>/<version> (contact@example.com)
Accept:        application/json
```

**User-Agent 不可省略或使用库默认值**(`okhttp/4.x` 等会被 Bangumi 拒)。

### 1.3 应用注册

前往 [https://bgm.tv/dev/app](https://bgm.tv/dev/app) 创建应用,获得:

- `client_id`
- `client_secret`
- `redirect_uri` (必须与代码中拼接的一致,支持 `http://127.0.0.1:<port>` 用于桌面端)

回调地址中**不可使用 `localhost`**,必须使用 `127.0.0.1`,否则授权时会校验失败。

---

## 2. OAuth 登录

Bangumi 使用标准 OAuth 2.0 Authorization Code 流程,`access_token` 默认 30 天有效。

### 2.1 流程图

```
┌─────────┐                ┌──────────┐                ┌──────────┐
│  Client │  1. open URL   │  bgm.tv  │  2. login     │  bgm.tv  │
│  App    │ ─────────────► │ authorize│ ────────────► │  callback│
│         │                │  page    │                │  (code)  │
└─────────┘                └──────────┘                └──────────┘
     │                                                    │
     │  3. POST /oauth/access_token (code + client_secret)│
     │ ◄──────────────────────────────────────────────────┘
     │
     │  4. access_token + refresh_token
     ▼
 [本地安全存储]
```

### 2.2 步骤 1: 拼装授权 URL 并用 WebView 打开

```
https://bgm.tv/oauth/authorize
  ?client_id=<client_id>
  &response_type=code
  &scope=write%3Acollection
  &redirect_uri=<redirect_uri>
```

### 2.3 步骤 2: 拦截回调 URL

用户在 WebView 中完成授权后,Bangumi 会 302 到:

```
<redirect_uri>?code=<authorization_code>&state=<本次登录的随机值>
```

**实现要点**:
- 每次登录生成至少 256-bit 随机 `state`,并加入授权 URL。
- WebView 拦截 `shouldOverrideUrlLoading`,逐字段精确匹配 redirect URI 的
  scheme / host / port / path,再校验 `state`;不要用字符串前缀匹配。
- 立即关闭 WebView,提取 `code` 参数。
- 不要让 WebView 跟随到任何后续跳转,否则可能离开 Bangumi 站点。

### 2.4 步骤 3: 换 access_token

```http
POST https://bgm.tv/oauth/access_token
Content-Type: application/x-www-form-urlencoded
User-Agent: <AppName>/<version> (contact@example.com)

grant_type=authorization_code
&client_id=<client_id>
&client_secret=<client_secret>
&code=<authorization_code>
&redirect_uri=<redirect_uri>
```

授权请求必须包含 `scope=write:collection`，否则读取可能成功但收藏写操作会因 scope 不足返回 403。

响应:

```json
{
  "access_token": "xxxxxxxx",
  "token_type": "Bearer",
  "expires_in": 2592000,
  "refresh_token": "yyyyyyyy",
  "scope": null,
  "user_id": 12345
}
```

### 2.5 刷新 token

```http
POST https://bgm.tv/oauth/access_token
Content-Type: application/x-www-form-urlencoded
User-Agent: <AppName>/<version> (contact@example.com)

grant_type=refresh_token
&client_id=<client_id>
&client_secret=<client_secret>
&refresh_token=<refresh_token>
&redirect_uri=<redirect_uri>
```

### 2.6 推荐: 提前刷新策略

`access_token` 有效期 30 天。建议在**到期前 7 天**主动刷新,避免用户在线时遇到 401。本仓库 `SessionManager.kt:86-97` 用的就是这套策略。

### 2.7 Token 存储

`access_token` 等同于用户凭证,**禁止**明文存日志或上传。推荐:

- 桌面端: 系统 Keychain / Credential Manager (Windows DPAPI / macOS Keychain / Linux Secret Service)
- 移动端: Android Keystore / iOS Keychain
- 服务端(若需要代理): 加密 + 权限控制

---

## 3. 用户与自查询

### 3.1 获取当前用户信息

```http
GET https://api.bgm.tv/v0/me
Authorization: Bearer <access_token>
```

响应片段:

```json
{
  "id": 12345,
  "username": "example",
  "nickname": "示例用户",
  "avatar": { "large": "...", "medium": "...", "small": "..." }
}
```

> **重要**: `-` 别名并非所有用户端点都支持。收藏写入端点可使用 `-`,但收藏列表
> `GET /v0/users/{username}/collections` 实测必须使用 `/v0/me` 返回的真实 username。

---

## 4. 收藏同步

### 4.1 收藏类型枚举

| 值 | 含义 |
|---|---|
| 1 | 想看 (wish) |
| 2 | 看过 (collect / done) |
| 3 | 在看 (doing) |
| 4 | 搁置 (on_hold) |
| 5 | 抛弃 (dropped) |

### 4.2 拉取我的全部收藏

```http
GET https://api.bgm.tv/v0/users/{username}/collections
     ?subject_type=2          # 2=动画, 1=书籍, 3=音乐, 4=游戏, 6=三次元
     &type=3                  # 收藏类型,可选
     &limit=30
     &offset=0
Authorization: Bearer <access_token>
```

列表端点不接受 `-` 自别名。先用 `/v0/me` 取得真实 username，并循环 offset 分页直到
返回条数少于 limit；不能只取第一页。

响应包含 `data: [...]` 和 `total`。`subject_id` 在 `data[i].subject_id` 中,**不是** `subject.id`。

### 4.3 获取单条收藏

```http
GET https://api.bgm.tv/v0/users/-/collections/{subject_id}
Authorization: Bearer <access_token>
```

### 4.4 创建或修改收藏(含评分 / 短评 / 标签)

```http
POST https://api.bgm.tv/v0/users/-/collections/{subject_id}
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "type": 3,
  "rate": 8,
  "comment": "完成度极高,推荐",
  "private": false,
  "tags": ["科幻", "神作"],
  "epStatus": 0
}
```

- `type` 必填,其余字段可选。
- `rate`: `0` 表示清空评分,`1-10` 为有效评分。
- `comment`: 官方 schema 的描述就是「评价」。**没有**已确认的最大长度约束,
  不要按 250 字符硬限制。
- `tags`: 不传或 `null` 会被忽略,传 `[]` 则**删除所有 tag**;单个 tag **不能包含空格**。
- 第一次提交用 `POST`,后续修改也用 `POST`(同端点幂等更新);`PATCH` 也支持,行为等价。

### 4.5 标记单集看过

```http
PUT https://api.bgm.tv/v0/users/-/collections/-/episodes/{episode_id}
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "type": 2
}
```

`type`: `2` = 看过,也可批量传 `{ "type": 2, "batch": true }`。

### 4.6 批量同步剧集进度

```http
PATCH https://api.bgm.tv/v0/users/-/collections/{subject_id}/episodes
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "episodes": [
    { "id": 1001, "type": 2 },
    { "id": 1002, "type": 2 }
  ]
}
```

### 4.7 增量同步策略

建议本地缓存 `(subject_id, updated_at)`,定时全量拉一次后做 diff,再 `POST` 改动。Bangumi 的 `BangumiUserSubjectCollection` 响应里有 `updated_at` 字段,可直接用。

---

## 5. 评论与吐槽

Bangumi 的"吐槽"覆盖四类对象 + 两种归属:

| 对象 | 对应 Bangumi 表 | 端点前缀 |
|---|---|---|
| 剧集(episode) | `chii_ep_comments` | `/p1/episodes/{id}/comments` |
| 角色(character) | `chii_character_comments` | `/p1/characters/{id}/comments` |
| 人物(person) | `chii_person_comments` | `/p1/persons/{id}/comments` |
| 日志(blog entry) | `chii_blog_comments` | `/p1/blogs/{id}/comments` |
| 条目(subject) | `chii_subject_comments` | `/p1/subjects/{id}/comments` ⚠️ **只读** |

**条目吐槽**(`/p1/subjects/{id}/comments`)**只有 GET,没有 POST** —— 官方 API 不开放条目级吐槽写入。如果产品上"必须能对条目发吐槽",常见做法:

- **走"讨论版"**(`/p1/subjects/{id}/topics` 开新主贴 + `/replies` 回复),见第 7 章
- **写"短评"**(PATCH 收藏的 `comment` 字段),见 4.4

剧集、角色、人物、日志四类的吐槽 **POST/PUT/DELETE 全开**。所有写操作都要求 Bearer,
但 **只有创建(POST)要 Turnstile**:

```
# 创建(POST):
Authorization: Bearer <access_token>
+ body 里带 turnstileToken  (Cloudflare Turnstile)

# 编辑(PUT) / 删除(DELETE) / 点赞:
Authorization: Bearer <access_token>       # 不需要 turnstileToken
```

> ⚠️ 本节旧版写作"所有写操作都要求 turnstileToken",与上游规范不符。
> 按 `https://next.bgm.tv/p1/openapi.json`(`2026-07-27-3ea7b96`)核对,要求
> `turnstileToken` 的端点共 14 个,**全部是创建内容的 POST**;`PUT`/`DELETE`/`/like`
> 和全部收藏、wiki 端点都不要求。完整清单见
> [`bangumi-account-integration-progress.md`](./bangumi-account-integration-progress.md) 6.1。

### 5.1 Turnstile 集成

1. 在 HTML 嵌入(通常用 Bangumi 自己的授权页加载):

   ```html
   <div class="cf-turnstile" data-sitekey="0x4AAAAAAABkMYinukE8nzYS"></div>
   <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
   ```

2. `site-key`:
   - 生产: `0x4AAAAAAABkMYinukE8nzYS` (next.bgm.tv 官方)
   - 测试: `1x00000000000000000000AA` (Cloudflare 通用测试 key)

3. `cf-turnstile-response` 回调中拿到 token,有效期 **300 秒**,**每次发帖前都要重新拿**。

> 由于你已经支持 WebView,推荐做法:在 WebView 中加载 `https://next.bgm.tv/p1/episodes/<id>`,让 Turnstile 在页面上下文里完成校验,然后 JS 回调或 `evaluateJavascript` 抓取 token,再回到原生层发 POST。
>
> 抓取脚本示例(在 `next.bgm.tv` 页面上下文执行):
>
> ```js
> // Turnstile 完成校验后会写到 input[name=cf-turnstile-response]
> document.querySelector('input[name="cf-turnstile-response"]')?.value
> ```

### 5.2 剧集吐槽(最常用,Animeko 已对接)

**列出评论**

```http
GET https://next.bgm.tv/p1/episodes/{episode_id}/comments?limit=20&offset=0
```

无需 `Authorization`,但带 Bearer 不会出错。响应里评论含 `replies` 字段(嵌套的子回复)。

**发表评论**

```http
POST https://next.bgm.tv/p1/episodes/{episode_id}/comments
Authorization: Bearer <access_token>
Content-Type: application/json
User-Agent: <AppName>/<version>

{
  "content": "评论内容",
  "turnstileToken": "<turnstile token>",
  "replyTo": 0
}
```

- `replyTo`: 被回复的**楼层 ID**,顶级评论传 `0`(不是 topic ID)
- `content`: BBCode,不要带 HTML;规范未给出已确认的长度上限,不要硬编码 380
- 成功响应只有 `{"id": 12345}`,缺 user / 时间 / state / reactions,必须重新拉列表
- 失败常见原因: Turnstile token 过期 / 失效、UA 缺失

**编辑 / 删除自己评论**

```http
PUT    https://next.bgm.tv/p1/episodes/-/comments/{comment_id}
DELETE https://next.bgm.tv/p1/episodes/-/comments/{comment_id}
Authorization: Bearer <access_token>
Content-Type: application/json

// PUT body:
{ "content": "修改后的内容" }
```

**点赞 / 取消点赞**

```http
PUT    https://next.bgm.tv/p1/episodes/-/comments/{comment_id}/like?value=1
DELETE https://next.bgm.tv/p1/episodes/-/comments/{comment_id}/like
Authorization: Bearer <access_token>
```

- `value=1` 赞,`value=2` 反对(部分版本支持)
- 这两个端点**不在 OpenAPI 规范里** —— Animeko 是在 `BangumiClient.kt:151-168` 手写 URL 调的;你直连也可以硬编码

### 5.3 角色吐槽

```http
GET    https://next.bgm.tv/p1/characters/{character_id}/comments
POST   https://next.bgm.tv/p1/characters/{character_id}/comments
PUT    https://next.bgm.tv/p1/characters/-/comments/{comment_id}
DELETE https://next.bgm.tv/p1/characters/-/comments/{comment_id}
```

请求体结构和 5.2 一样(`content` + `turnstileToken` + `replyTo`)。

### 5.4 人物吐槽

```http
GET    https://next.bgm.tv/p1/persons/{person_id}/comments
POST   https://next.bgm.tv/p1/persons/{person_id}/comments
PUT    https://next.bgm.tv/p1/persons/-/comments/{comment_id}
DELETE https://next.bgm.tv/p1/persons/-/comments/{comment_id}
```

### 5.5 日志吐槽

```http
GET    https://next.bgm.tv/p1/blogs/{entry_id}/comments
POST   https://next.bgm.tv/p1/blogs/{entry_id}/comments
PUT    https://next.bgm.tv/p1/blogs/-/comments/{comment_id}
DELETE https://next.bgm.tv/p1/blogs/-/comments/{comment_id}
```

### 5.6 条目吐槽(只读)

```http
GET https://next.bgm.tv/p1/subjects/{subject_id}/comments?type=3&limit=20&offset=0
```

- `type`: 1=想看 2=在看 3=看过 4=搁置 5=抛弃(可省略)
- 无 POST —— 想"对条目发吐槽"请走短评(4.4)或讨论版(第 7 章)
- Animeko 当前**不**直接调这个端点,而是经 Ani server 走 `/v2/subjects/{id}/reviews` 拿评价

### 5.7 通用请求模板

```python
# 任何带 Turnstile 的吐槽都长这样
def post_comment(kind, target_id, content, turnstile_token, reply_to=0):
    """kind in {"episodes","characters","persons","blogs"}"""
    return requests.post(
        f"https://next.bgm.tv/p1/{kind}/{target_id}/comments",
        json={
            "content": content,
            "turnstileToken": turnstile_token,
            "replyTo": reply_to,
        },
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "User-Agent": UA,
            "Content-Type": "application/json",
        },
    )
```

---

## 6. 评价(长评)

`api.bgm.tv` **没有**公开的"写长评"端点。p1 仅暴露 `GET /p1/subjects/{subject_id}/reviews`(只读)。

```http
GET https://next.bgm.tv/p1/subjects/{subject_id}/reviews?limit=5&offset=0
```

响应 `{data: SubjectReview[], total}`,但 `SubjectReview` 只有 `id` / `user` / `entry`,
`entry` 是 `SlimBlogEntry`,**只含 `summary` 摘要,没有正文**。

**长评正文要第二次请求**:

```http
GET https://next.bgm.tv/p1/blogs/{entryID}
```

返回 `BlogEntry`,其中 `content` 是完整正文。也就是说 Bangumi 的长评实体就是
**日志(blog entry)**,不是独立类型。列表页展示 `summary`,点开再拉全文,
不要在列表阶段 N+1 拉取所有正文。日志的吐槽另取 `GET /p1/blogs/{entryID}/comments`。

可行方案:

| 方案 | 优劣 |
|---|---|
| **只写"短评"(随收藏 PATCH `comment`)** | 官方 API 稳定,完全直连,**推荐** |
| WebView 加载 `https://bgm.tv/subject/{id}/reviews/new` 自动提交 | 需要 Cookie session,不推荐用于非浏览器场景 |
| 不支持 | — |

**推荐**: 短评用 4.4 节,长评用 WebView 打开 Bangumi 官方编辑页,引导用户提交。

---

## 7. 讨论版

Bangumi 的"讨论"分两种:

- **条目讨论** —— `/p1/subjects/{id}/topics`,即"该条目页面底下"的主贴
- **小组讨论** —— `/p1/groups/{groupName}/topics`,即各小组(如"动画交流"、"galgame"等)里的主贴

两种都支持 **主贴(topics)** + **回帖(posts)** 的完整 CRUD,回帖支持嵌套。

### 7.1 条目讨论

**列出某条目的所有讨论主贴**

```http
GET https://next.bgm.tv/p1/subjects/{subject_id}/topics?limit=20&offset=0
```

**获取单个主贴详情**

```http
GET https://next.bgm.tv/p1/subjects/-/topics/{topic_id}
```

**开新主贴(写 Turnstile)**

```http
POST https://next.bgm.tv/p1/subjects/{subject_id}/topics
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "title": "讨论标题",
  "content": "BBCode 格式正文,支持 [b][/b] [img][/img] 等",
  "turnstileToken": "<turnstile token>"
}
```

**编辑自己主贴**

```http
PUT https://next.bgm.tv/p1/subjects/-/topics/{topic_id}
Authorization: Bearer <access_token>
Content-Type: application/json

{ "title": "...", "content": "..." }
```

**回帖(写 Turnstile)**

```http
POST https://next.bgm.tv/p1/subjects/-/topics/{topic_id}/replies
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "content": "回帖内容,BBCode",
  "turnstileToken": "<turnstile token>",
  "replyTo": 0       // 嵌套回复某条 post,顶级传 0
}
```

**编辑 / 删除回帖**

```http
GET    https://next.bgm.tv/p1/subjects/-/posts/{post_id}
PUT    https://next.bgm.tv/p1/subjects/-/posts/{post_id}
DELETE https://next.bgm.tv/p1/subjects/-/posts/{post_id}
Authorization: Bearer <access_token>
```

### 7.2 小组讨论

小组用 **字符串名字**(`groupName`)而不是数字 ID,例如 `bangumi` `/ `anime` `/ `galgame` 等。

**小组详情**

```http
GET https://next.bgm.tv/p1/groups/{groupName}
```

**成员列表**

```http
GET https://next.bgm.tv/p1/groups/{groupName}/members?moderator=true&limit=20&offset=0
```

**帖子列表**

```http
GET https://next.bgm.tv/p1/groups/{groupName}/topics?limit=20&offset=0
```

**开新帖(写 Turnstile)**

```http
POST https://next.bgm.tv/p1/groups/{groupName}/topics
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "title": "...",
  "content": "BBCode",
  "turnstileToken": "<turnstile token>"
}
```

**帖子详情 / 编辑**

```http
GET https://next.bgm.tv/p1/groups/-/topics/{topic_id}
PUT https://next.bgm.tv/p1/groups/-/topics/{topic_id}
```

**回帖 / 编辑 / 删除**

```http
POST   https://next.bgm.tv/p1/groups/-/topics/{topic_id}/replies
GET    https://next.bgm.tv/p1/groups/-/posts/{post_id}
PUT    https://next.bgm.tv/p1/groups/-/posts/{post_id}
DELETE https://next.bgm.tv/p1/groups/-/posts/{post_id}
```

结构和 7.1 完全对称,只是前缀变成 `groups`。

### 7.3 注意事项

- **content 用 BBCode**,不是 Markdown。常用标签:`[b][/b]` `[i][/i]` `[u][/u]` `[img=URL][/img]` `[quote][/quote]` `[url=URL][/url]` `[code][/code]` `[collapse=标题][/collapse]`。
- 嵌套回复通过 `replyTo` 字段指向 `post_id`,**不是** `topic_id`。
- 编辑主贴 / 回帖**不**需要 Turnstile,只有创建需要。

---

## 8. 透视 / 时间线

"透视"是 Bangumi 站内的动态流(`/timeline`)。完整支持**全站/好友流读取 + 发送"说句话" + 回复 + 删除**。

### 8.1 读取时间线

```http
GET https://next.bgm.tv/p1/timeline?mode=friends&limit=20&until=<last_id>
```

- `mode=friends` 好友动态(默认,只看关注的人)
- `mode=all` 全站动态(可能被风控,慎用)
- `until` 分页游标,传上一次响应里**最大**的 `id`,用于向上翻页

**读某用户的时间胶囊**

```http
GET https://next.bgm.tv/p1/users/{username}/timeline?limit=20&until=<last_id>
```

### 8.2 发送"说句话"

```http
POST https://next.bgm.tv/p1/timeline
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "content": "今天看完 XX,神作",
  "turnstileToken": "<turnstile token>"
}
```

### 8.3 删除自己时间线

```http
DELETE https://next.bgm.tv/p1/timeline/{timeline_id}
Authorization: Bearer <access_token>
```

### 8.4 回复时间线 / 列回复

```http
GET  https://next.bgm.tv/p1/timeline/{timeline_id}/replies
POST https://next.bgm.tv/p1/timeline/{timeline_id}/replies
Authorization: Bearer <access_token>
Content-Type: application/json

// POST body
{
  "content": "回复内容",
  "turnstileToken": "<turnstile token>",
  "replyTo": 0
}
```

### 8.5 实战建议

- **节奏控制**:时间线是流式内容,GET 拉取建议带本地缓存(用 `id` 去重),别每次都从头拉。
- **风控**:`mode=all` 在新 IP / 短时间高频请求下可能触发 403,务必加 1-2 秒间隔。
- **删除自己时间线 = 不发**:`POST` 后立刻 `DELETE` 也能达到"草稿不发出"的效果(谨慎用于自动化)。

---

## 9. 端点速查

### 9.1 OAuth & 基础

| 类别 | Method | URL |
|---|---|---|
| OAuth 授权页 | GET | `https://bgm.tv/oauth/authorize?client_id=...` |
| OAuth 换 token | POST | `https://bgm.tv/oauth/access_token` |
| OAuth 刷新 | POST | `https://bgm.tv/oauth/access_token` (`grant_type=refresh_token`) |
| 当前用户 | GET | `https://api.bgm.tv/v0/me` |

### 9.2 收藏

| 类别 | Method | URL |
|---|---|---|
| 我的收藏 | GET | `https://api.bgm.tv/v0/users/{username}/collections`（**不接受 `-`**，见 10.5） |
| 单条收藏 | GET | `https://api.bgm.tv/v0/users/-/collections/{subject_id}` |
| 创建/改收藏 | POST | `https://api.bgm.tv/v0/users/-/collections/{subject_id}` |
| 标记单集 | PUT | `https://api.bgm.tv/v0/users/-/collections/-/episodes/{episode_id}` |
| 批量剧集 | PATCH | `https://api.bgm.tv/v0/users/-/collections/{subject_id}/episodes` |

### 9.3 吐槽(全部要 Bearer,POST 还要 Turnstile)

| 类别 | Method | URL |
|---|---|---|
| 条目吐槽列表 | GET | `https://next.bgm.tv/p1/subjects/{id}/comments` |
| 剧集吐槽 CRUD | GET/POST/PUT/DELETE | `https://next.bgm.tv/p1/episodes/{id}/comments` |
| 角色吐槽 CRUD | GET/POST/PUT/DELETE | `https://next.bgm.tv/p1/characters/{id}/comments` |
| 人物吐槽 CRUD | GET/POST/PUT/DELETE | `https://next.bgm.tv/p1/persons/{id}/comments` |
| 日志吐槽 CRUD | GET/POST/PUT/DELETE | `https://next.bgm.tv/p1/blogs/{id}/comments` |
| 剧集吐槽点赞 | PUT/DELETE | `https://next.bgm.tv/p1/episodes/-/comments/{id}/like` |

### 9.4 评价

| 类别 | Method | URL |
|---|---|---|
| 列评价 | GET | `https://next.bgm.tv/p1/subjects/{id}/reviews` |
| 写长评 | — | **无 API**,走短评或 WebView |

### 9.5 讨论版

| 类别 | Method | URL |
|---|---|---|
| 条目讨论列表 | GET | `https://next.bgm.tv/p1/subjects/{id}/topics` |
| 条目讨论详情 | GET | `https://next.bgm.tv/p1/subjects/-/topics/{topic_id}` |
| 条目开新主贴 | POST | `https://next.bgm.tv/p1/subjects/{id}/topics` |
| 条目编辑主贴 | PUT | `https://next.bgm.tv/p1/subjects/-/topics/{topic_id}` |
| 条目回帖 | POST | `https://next.bgm.tv/p1/subjects/-/topics/{topic_id}/replies` |
| 条目回帖详情 | GET | `https://next.bgm.tv/p1/subjects/-/posts/{post_id}` |
| 条目回帖编辑/删除 | PUT/DELETE | `https://next.bgm.tv/p1/subjects/-/posts/{post_id}` |
| 小组详情 | GET | `https://next.bgm.tv/p1/groups/{groupName}` |
| 小组成员 | GET | `https://next.bgm.tv/p1/groups/{groupName}/members` |
| 小组帖子列表 | GET | `https://next.bgm.tv/p1/groups/{groupName}/topics` |
| 小组开新帖 | POST | `https://next.bgm.tv/p1/groups/{groupName}/topics` |
| 小组帖子详情 | GET | `https://next.bgm.tv/p1/groups/-/topics/{topic_id}` |
| 小组编辑主贴 | PUT | `https://next.bgm.tv/p1/groups/-/topics/{topic_id}` |
| 小组回帖 | POST | `https://next.bgm.tv/p1/groups/-/topics/{topic_id}/replies` |
| 小组回帖详情 | GET | `https://next.bgm.tv/p1/groups/-/posts/{post_id}` |
| 小组回帖编辑/删除 | PUT/DELETE | `https://next.bgm.tv/p1/groups/-/posts/{post_id}` |

### 9.6 透视 / 时间线

| 类别 | Method | URL |
|---|---|---|
| 时间线 | GET | `https://next.bgm.tv/p1/timeline?mode=friends\|all` |
| 说说 | POST | `https://next.bgm.tv/p1/timeline` |
| 删除时间线 | DELETE | `https://next.bgm.tv/p1/timeline/{id}` |
| 时间线回复 | GET/POST | `https://next.bgm.tv/p1/timeline/{id}/replies` |
| 用户时间胶囊 | GET | `https://next.bgm.tv/p1/users/{username}/timeline` |

---

## 10. 常见问题与最佳实践

### 10.1 限速

OAuth `access_token` 端点实测 1 req/s 级别限流,批量同步收藏请:

- 加 1-2 秒间隔或指数退避 (`1s, 2s, 4s, 8s, max 30s`)
- 收到 `429 Too Many Requests` 时尊重 `Retry-After` header

### 10.2 错误码

| 状态码 | 含义 | 处理 |
|---|---|---|
| 401 | token 失效 / 无 Bearer | 重新登录或刷新 |
| 403 | UA 被拒 / IP 被风控 | 检查 UA,稍后重试 |
| 404 | subject_id 不存在 | 跳过 |
| 429 | 限速 | 退避 |
| 400 (Turnstile 相关) | token 过期或无效 | 重新拉 Turnstile |

### 10.3 数据安全

- 客户端二进制中的 `client_secret` 无法真正保密，即使它通过编译期变量进入 Rust、做了
  混淆或完整性校验，仍应视为可提取。优先使用 PKCE/public client；服务端不支持时，
  真正需要保密只能由可信后端代理 token 换发，并准备凭据轮换。
- 对 `client_secret` + `code` 的换 token 请求,必须用 HTTPS,服务端校验 `redirect_uri` 一致性。
- OAuth 授权和 token 交换不得走社区内容反向代理，始终直连 `https://bgm.tv`。

### 10.4 OAuth 回调处理

桌面端推荐流程:

1. 启动本地 HTTP 服务监听 `127.0.0.1:<随机端口>`。
2. 拼 `redirect_uri=http://127.0.0.1:<port>/callback`。
3. WebView 拦截该 URL → 提取 `code` → 关闭服务 → 关闭 WebView → 换 token。
4. 失败兜底: 提供"复制授权 URL 到浏览器,完成后手动粘贴 code"的方案。

移动端:

- iOS: `ASWebAuthenticationSession` (系统接管)
- Android: Chrome Custom Tabs + `Intent.ACTION_VIEW` 拦截,或自建 WebView

### 10.5 按端点选择 username 或 `-`

收藏写入端点使用 `/v0/users/-/...`。收藏列表端点实测不接受 `-`，必须使用
`/v0/me` 返回的真实 username。不要把某个端点对 `-` 的支持推广到所有用户端点。

### 10.6 Turnstile 在原生客户端的两种拿法

**方案 A(纯 WebView,推荐)**: 在 WebView 中加载 Bangumi 评论页 → 注入 JS 抓 Turnstile token → 关 WebView → POST。

**方案 B(原生 Turnstile SDK)**: 客户端直接嵌入 Cloudflare 提供的 `cf-turnstile` 渲染方式(支持 Android/iOS SDK),无需 WebView。详见 [Cloudflare Turnstile Mobile SDK](https://developers.cloudflare.com/turnstile/)。注意: Bangumi 后端只认 `next.bgm.tv` 注册的 site-key,移动端 SDK 拿到的 token 必须与该 site-key 对应。

### 10.7 离线 / 失败重试

- 收藏同步写操作应**幂等**:`POST` 同一 `(subject_id, type)` 多次不会重复计数。
- 本地维护"待同步队列",登录态恢复后逐步回放。
- 评论不建议自动重试(用户可能改了主意),失败直接提示。

### 10.8 BBCode 渲染

条目讨论、透视、讨论版的 `content` 都是 **BBCode 格式**,前端展示时需要做 BBCode→HTML 转换。常见开源解析器:

- Python: `misaka`(纯 C 实现,快)、`bbcode` 库
- JavaScript: `bbcode-to-react`、`bbob`
- Kotlin/Java: 自己写一个简单的正则解析器即可,Bangumi 用到的标签种类不多

Bangumi 支持的标签:`[b]` `[i]` `[u]` `[s]` `[img=URL]` `[url=URL]` `[quote]` `[code]` `[collapse=标题]` `[color=...]` `[mask]`(剧透) 等。

### 10.9 OAuth 回调 5 分钟超时

桌面端 `127.0.0.1` 临时 HTTP 服务**必须**设 5 分钟超时,否则用户放弃登录时端口会一直占用。

---

## 11. 端到端实现示例

### 11.1 OAuth 登录(伪代码)

```python
def login():
    # 1. 拼授权 URL
    auth_url = (
        "https://bgm.tv/oauth/authorize"
        f"?client_id={CLIENT_ID}"
        f"&response_type=code"
        f"&redirect_uri={urllib.parse.quote(REDIRECT_URI)}"
    )
    # 2. WebView 打开,拦截 redirect_uri?code=...
    code = webview_open_and_capture_code(auth_url, REDIRECT_URI)
    # 3. 换 token
    resp = requests.post(
        "https://bgm.tv/oauth/access_token",
        data={
            "grant_type": "authorization_code",
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "code": code,
            "redirect_uri": REDIRECT_URI,
        },
        headers={"User-Agent": UA},
    ).json()
    save_tokens(resp["access_token"], resp["refresh_token"], resp["user_id"])
```

### 11.2 同步一条收藏

```python
def update_collection(subject_id, type_=3, rate=8, comment=None):
    body = {"type": type_, "rate": rate}
    if comment:
        body["comment"] = comment
    return requests.post(
        f"https://api.bgm.tv/v0/users/-/collections/{subject_id}",
        json=body,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "User-Agent": UA,
        },
    )
```

### 11.3 标记一集看过

```python
def mark_episode(episode_id):
    return requests.put(
        f"https://api.bgm.tv/v0/users/-/collections/-/episodes/{episode_id}",
        json={"type": 2},
        headers={"Authorization": f"Bearer {TOKEN}", "User-Agent": UA},
    )
```

### 11.4 发剧集评论(需 Turnstile)

```python
def post_episode_comment(episode_id, content, turnstile_token, reply_to=0):
    return requests.post(
        f"https://next.bgm.tv/p1/episodes/{episode_id}/comments",
        json={
            "content": content,
            "turnstileToken": turnstile_token,
            "replyTo": reply_to,
        },
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "User-Agent": UA,
            "Content-Type": "application/json",
        },
    )
```

### 11.5 WebView 抓 Turnstile token(伪代码)

```kotlin
// 桌面端用 JCEF,移动端用 WebView;这里写伪代码
fun fetchTurnstileToken(afterLoaded: (String) -> Unit) {
    webView.loadUrl("https://next.bgm.tv/p1/episodes/0/comments")  // 任意带 Turnstile 的页
    // 注入 JS,轮询直到 input 有值
    webView.addOnLoadFinished {
        webView.executeJavascript("""
            (function poll() {
                const t = document.querySelector('input[name="cf-turnstile-response"]');
                if (t && t.value) {
                    window.turnstileToken = t.value;
                } else {
                    setTimeout(poll, 200);
                }
            })();
        """.trimIndent())
    }
    // 业务层定一个超时,超时后回调 null
    setTimeout({ afterLoaded(turnstileToken) }, 30_000)
}
```

### 11.6 在条目下开新讨论(BBCode)

```python
def create_subject_topic(subject_id, title, bbcode_content, turnstile_token):
    return requests.post(
        f"https://next.bgm.tv/p1/subjects/{subject_id}/topics",
        json={
            "title": title,
            "content": bbcode_content,
            "turnstileToken": turnstile_token,
        },
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "User-Agent": UA,
            "Content-Type": "application/json",
        },
    )
```

### 11.7 拉取并发送"说句话"到透视

```python
def get_timeline(limit=20, until=None, mode="friends"):
    params = {"limit": limit, "mode": mode}
    if until:
        params["until"] = until
    return requests.get(
        "https://next.bgm.tv/p1/timeline",
        params=params,
        headers={"User-Agent": UA},
    ).json()

def post_timeline(content, turnstile_token):
    return requests.post(
        "https://next.bgm.tv/p1/timeline",
        json={"content": content, "turnstileToken": turnstile_token},
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "User-Agent": UA,
            "Content-Type": "application/json",
        },
    )
```

---

## 12. 参考

**权威规范(核对端点契约时用这两个)**:

- p1 Next API 实时规范: <https://next.bgm.tv/p1/openapi.json>
- v0 Open API 规范: <https://raw.githubusercontent.com/bangumi/api/master/open-api/v0.yaml>

其他:

- Bangumi 开放平台: <https://bgm.tv/dev>
- Bangumi Open API 文档: <https://github.com/bangumi/api>
- Cloudflare Turnstile: <https://developers.cloudflare.com/turnstile/>

**Animeko 仓库**内的参考路径(**不在本仓库**,仅作实现思路对照):

- `datasource/bangumi/src/commonMain/kotlin/BangumiClient.kt`
- `app/shared/app-data/src/commonMain/kotlin/data/repository/user/TokenRepository.kt` (LegacyTokenRepository)
- `datasource/bangumi/build.gradle.kts:104-186`(生成客户端裁剪规则)

**本仓库实现落点**见 [`bangumi-account-integration-progress.md`](./bangumi-account-integration-progress.md) 第 4 章。
