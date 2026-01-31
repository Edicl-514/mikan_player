# WebView 并发提取优化

## 改进内容

### 1. 自动启动 WebView
**之前**: 只有在用户切换到"全网搜"tab时，才会启动 WebView 来抓取视频地址  
**现在**: 当播放页面初始化时，`_loadSampleSource()` 会自动在后台启动 WebView 提取，无需用户手动切换 tab

**关键实现**: 将 WebView Widget 放置在 `Stack` 中，使用 `Offstage` 包裹，使其始终存在于 Widget 树中，即使用户没有切换到"全网搜"tab

### 2. 并发提取支持
**之前**: WebView 是串行提取的，一次只能处理一个源  
**现在**: 支持多个 WebView 并发运行，默认最多同时运行 3 个 WebView

## 技术实现

### 后台WebView容器
在 `build()` 方法中添加了一个隐藏的 WebView 容器：

```dart
Stack(
  children: [
    // 主界面
    isWide ? _buildPCLayout(context) : _buildMobileLayout(context),
    
    // 后台WebView容器（始终存在，用于后台视频提取）
    Offstage(
      offstage: !_showWebView, // 调试时可以显示，否则完全隐藏
      child: Positioned(
        left: 0,
        top: 0,
        width: _showWebView ? 400 : 1,
        height: _showWebView ? 300 : 1,
        child: Container(
          color: Colors.black,
          child: _buildWebViewExtractors(),
        ),
      ),
    ),
  ],
)
```

这确保了 WebView 始终存在于 Widget 树中，可以在后台运行，而不受 tab 切换影响。

### 新增状态变量
- `_activeWebViews: Map<String, bool>` - 跟踪当前正在运行的 WebView（sourceName -> isActive）
- `_webViewStatus: Map<String, String>` - 记录每个 WebView 的状态消息
- `_maxConcurrentWebViews: int` - 最大并发 WebView 数量（默认 3）

### 核心方法

#### `_startConcurrentWebViewExtraction()`
- 在所有源搜索完成后自动调用
- 找到需要 WebView 提取的源（没有直接视频链接的）
- 启动前 N 个源的并发提取（N = `_maxConcurrentWebViews`）

#### `_onWebViewResult(String sourceName, VideoExtractResult result)`
- 处理单个 WebView 的提取结果
- 成功时将结果添加到可用源列表
- 自动启动下一个待提取的源

#### `_startNextWebViewExtraction()`
- 当一个 WebView 完成时自动调用
- 在不超过并发上限的情况下启动下一个源的提取
- 所有提取完成后更新最终状态

#### `_buildWebViewExtractors()`
- 构建所有活动 WebView 的 Widget 列表
- 支持多个 WebView 同时运行在后台

### UI 改进
- 显示当前并发运行的 WebView 数量
- 列出所有正在提取的源的状态
- 实时更新提取进度

## 使用效果

1. **更快的加载速度**: 多个源并发提取，大幅减少总等待时间
2. **更好的用户体验**: 无需手动切换 tab，自动在后台完成
3. **实时反馈**: UI 显示所有并发提取的实时状态

## 配置参数

可以通过修改 `_maxConcurrentWebViews` 常量来调整并发数量：
- 较小的值（1-2）：减少资源占用，适合低端设备
- 较大的值（3-5）：更快的提取速度，适合高端设备

## 注意事项

1. WebView 会在后台持续运行，直到所有需要提取的源都完成
2. 每个 WebView 有 20 秒超时限制
3. 按 Tier 优先级排序，优先提取高优先级源
4. 首个成功提取的源会自动开始播放
