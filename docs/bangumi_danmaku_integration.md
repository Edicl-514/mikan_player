# Bangumi TV 弹幕自动匹配功能

## 功能说明

实现了通过 Bangumi TV 的 `subject_id` 和集号自动匹配 `episodeId` 并加载弹幕的功能。

## API 接口

### Rust API

#### 1. `danmaku_get_bangumi_episodes(subject_id: i64)`

获取指定 Bangumi TV subject 的所有剧集信息。

**参数:**
- `subject_id`: Bangumi TV 的 subject_id (例如: 517057)

**返回:**
- `Vec<BangumiTvEpisode>`: 剧集列表

**示例:**
```rust
let episodes = danmaku_get_bangumi_episodes(517057).await?;
for ep in episodes {
    println!("Episode {}: {} (ID: {})", 
        ep.episode_number, 
        ep.episode_title, 
        ep.episode_id
    );
}
```

#### 2. `danmaku_get_by_bangumi_id(subject_id: i64, episode_number: String)`

通过 Bangumi TV subject_id 和集数直接获取弹幕。

**参数:**
- `subject_id`: Bangumi TV 的 subject_id
- `episode_number`: 集数编号 (例如: "1", "2", "SP1" 等)

**返回:**
- `Vec<Danmaku>`: 弹幕列表

**示例:**
```rust
let danmakus = danmaku_get_by_bangumi_id(517057, "1".to_string()).await?;
println!("Loaded {} danmaku comments", danmakus.len());
```

### Dart API

#### `DanmakuService.loadDanmakuByBangumiId(int subjectId, String episodeNumber)`

通过 Bangumi TV subject_id 和集数加载弹幕。

**参数:**
- `subjectId`: Bangumi TV 的 subject_id
- `episodeNumber`: 集数编号

**示例:**
```dart
await _danmakuService.loadDanmakuByBangumiId(517057, "1");
```

## 使用场景

### 播放器页面自动加载

播放器页面 (`player_page.dart`) 会自动检测动画信息中是否包含 `bangumiId`：

1. **优先使用 Bangumi TV ID**: 如果 `anime.bangumiId` 存在，使用 `loadDanmakuByBangumiId` 进行精确匹配
2. **降级到标题搜索**: 如果没有 Bangumi ID，使用 `loadDanmakuByTitle` 进行标题搜索

这样可以确保更高的匹配准确率。

## API 调用示例

### 示例请求

```bash
curl -X 'GET' \
  'https://api.dandanplay.net/api/v2/bangumi/bgmtv/517057' \
  -H 'accept: application/json' \
  -H 'X-AppId: gz2wnihj9d' \
  -H 'X-Signature: <generated_signature>' \
  -H 'X-Timestamp: <current_timestamp>'
```

### 示例响应

```json
{
  "bangumi": {
    "type": "tvseries",
    "typeDescription": "TV动画",
    "titles": [
      {
        "language": "主标题",
        "title": "【我推的孩子】 第三季"
      }
    ],
    "episodes": [
      {
        "episodeId": 189010001,
        "episodeTitle": "第1话 入れ込み",
        "episodeNumber": "1",
        "airDate": "2026-01-14T00:00:00"
      },
      {
        "episodeId": 189010002,
        "episodeTitle": "第2话 打算",
        "episodeNumber": "2",
        "airDate": "2026-01-21T00:00:00"
      }
    ]
  }
}
```

## 测试

运行以下命令测试功能：

```bash
# 测试获取剧集列表
cargo test --package rust --lib api::danmaku::tests::test_get_bangumi_episodes -- --exact --nocapture

# 测试通过 Bangumi ID 获取弹幕
cargo test --package rust --lib api::danmaku::tests::test_get_danmaku_by_bangumi_id -- --exact --nocapture
```

## 实现细节

1. **签名生成**: 使用 SHA256 + Base64 生成 API 签名
2. **自动匹配**: 通过 `episode_number` 字段精确匹配剧集
3. **错误处理**: 如果找不到匹配的剧集，返回空列表而不是错误
4. **日志记录**: 详细的日志输出便于调试

## 优势

- **更高的准确率**: 使用 Bangumi TV 的 subject_id 可以避免标题搜索的歧义
- **支持特殊集**: 可以匹配 SP、OVA 等特殊集号
- **自动降级**: 当 Bangumi ID 不可用时自动降级到标题搜索
