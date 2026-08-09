# 滚动条拖动时 thumb 跳动

## 现象

用鼠标拖动 scrollbar 的 thumb 时，thumb 不跟随鼠标，会自己跳开一段距离，往上往下拖都会出现。不同页面严重程度不一样，长内容的页面更明显 —— 典型例子是 bangumi 详情页里长评的内页弹窗（`bangumi_blog_detail_dialog.dart`），以及详情页宽布局右侧那根 scrollbar（评论 / 长评 / 讨论 tab）。

滚轮滚动不受影响，只有拖 thumb 会出问题。

## 根因

Flutter 的 `Scrollbar` 把 thumb 的拖动量换算成滚动偏移时，用的是**当前帧的** `maxScrollExtent`，但拖动的锚点是**按下那一刻**记录的。这两者一旦不一致，映射关系就变了。

相关代码在 `packages/flutter/lib/src/widgets/scrollbar.dart`（下面行号对应 Flutter 3.44.8）：

```dart
// RawScrollbarState.handleThumbPressStart:1749 —— 按下时记录锚点
_startDragThumbOffset = scrollbarPainter.getThumbScrollOffset();

// RawScrollbarState._getPrimaryDelta:1665 —— 每次移动用当前 metrics 换算
double scrollOffsetGlobal = scrollbarPainter.getTrackToScroll(
  _startDragThumbOffset! + primaryDeltaFromDragStart,
);
```

而 `getTrackToScroll`（`scrollbar.dart:682`）和 thumb 的绘制位置、长度，全部都从 `maxScrollExtent` 推导：

```dart
// getTrackToScroll:682
scrollableExtent = maxScrollExtent - minScrollExtent
thumbMovableExtent = 可动轨道长 - thumbExtent
返回 scrollableExtent * thumbOffsetLocal / thumbMovableExtent

// _setThumbExtent:430
thumbExtent = 可动轨道长 × viewport / (maxScrollExtent + viewport)

// _getScrollToTrack:705
thumbOffset = pixels / scrollableExtent × (可动轨道长 - thumbExtent)
```

所以 `maxScrollExtent` 一变：

1. `thumbExtent` 变 → thumb 长度变；
2. `thumbMovableExtent` 跟着变 → 鼠标位移到滚动量的换算比例变；
3. 而 `_startDragThumbOffset` 还是按下时的旧值。

结果就是拖动途中比例被重算，thumb 从鼠标底下"跳"走。内容变长时往一个方向跳，变短时往另一个方向跳 —— 对应"往上往下都会"。

### 为什么 `maxScrollExtent` 会在拖动途中变

这不是 bug，是 lazy 布局的固有性质。三个来源在本项目里都存在：

**1. 懒构建列表的外推估计（主因）**

`SliverList` / `ListView.builder` 没法知道还没布局的 child 有多高，于是拿**当前已实体化的 child 的平均高度**去外推剩下的（`packages/flutter/lib/src/widgets/sliver.dart:1119` `_extrapolateMaxScrollOffset`）：

```dart
final double averageExtent = (trailingScrollOffset - leadingScrollOffset) / reifiedCount;
return trailingScrollOffset + averageExtent * remainingCount;
```

拖动会实体化不同的 child，平均值就变，`maxScrollExtent` 每帧被改写一次。本项目里这些卡片高度差异极大（评论有没有子回复、有没有图、长评正文长度不一），所以估计值抖得很厉害。

涉及位置：
- `bangumi_blog_detail_dialog.dart` 底部评论的 `SliverList.builder`
- `comments_section.dart` / `reviews_section.dart` / `topics_section.dart` 里的 `SliverChildBuilderDelegate`

**2. 图片异步加载撑开高度**

`BangumiCommentHtml` 里的正文图片只约束了 `max-width: 100%` / `max-height: 350px`（`bangumi_comment_html.dart:405`），真实宽高要等图片解码完才知道。头像同理。图片加载完成的时机是随机的，可能正好落在拖动过程中。

**3. 分页追加内容**

滚到底自动加载下一页，列表变长；loading 行出现和消失也各算一次高度变化。

## 修复

新增 `lib/ui/widgets/stable_thumb_scrollbar.dart`，思路是：**thumb 被按住期间，把 painter 用于换算的 extent 钉在按下那一刻的值上，只让 `pixels` 保持实时** —— 这样整个手势期间映射是一条固定的线性函数，正好符合拖动锚点本来的假设。Windows 原生 scrollbar 也是这个行为，拖动中 thumb 不会改变长度。

关键实现（`StableThumbScrollbar`）：

```dart
@override
void handleThumbPressStart(Offset localPosition) {
  // 必须在 super 之前，因为 super 会读 getThumbScrollOffset() 作为锚点，
  // 锚点和钉住的 extent 必须描述同一套几何
  _pinnedExtents = _currentMetrics();
  super.handleThumbPressStart(localPosition);
}

void _repin(ScrollMetrics live) {
  final pinned = _pinnedExtents;
  if (pinned == null) return;
  scrollbarPainter.update(
    pinned.copyWith(pixels: live.pixels),  // extent 用钉住的，pixels 用实时的
    pinned.axisDirection,
  );
}
```

`_repin` 的调用点在 `build()` 里包了两层 NotificationListener，**包在 `super.build(context)` 外面**。因为通知是从内往外冒泡的，框架自己那层 listener 在内侧、先执行，我们在外侧、后执行，所以钉住的值是 painter 被绘制、以及下一次 `getTrackToScroll` 读回之前的**最后一次写入**。

两种通知都要监听，这一点是踩过坑的：

| 通知 | 携带 | 是否必须 |
| --- | --- | --- |
| `ScrollNotification` | 拖动自身的位置更新 | 是 |
| `ScrollMetricsNotification` | **内容尺寸变化** | 是 —— 它不是 `ScrollNotification` 的子类 |

`ScrollMetricsNotification` 恰恰就是本问题要吸收的那个事件，框架在 `_handleScrollMetricsNotification`（`scrollbar.dart:1913`）里会用实时 metrics 覆盖 painter。只监听 `ScrollNotification` 的话钉不住 —— 实测拖动第一步正确（100px/步），后续步骤直接跳到 629px/步。

### 保证不破坏其他行为

- **钉住只影响 scrollbar 自己的几何**。真实 `ScrollPosition` 完全没动，懒构建、分页、overscroll 判定用的都是真实 extent。
- **内容真正的末尾仍然可达**：`_getPrimaryDelta` 每一步都用 `position.maxScrollExtent` 做 clamp（`scrollbar.dart:1687`）。
- **松手即解除**：`handleThumbPressEnd` 解钉；拖动被取消（指针捕获丢失、scrollable 被销毁）不会走到 `handleThumbPressEnd`，所以额外在 `ScrollEndNotification` 上也解钉，`dispose()` 里兜底。

### 已知取舍

内容在拖动中变长很多时，钉住的映射走完整条轨道也只覆盖到按下时的 extent，剩下的距离由框架自己的 shrink guard 接管。实测数据（4000px 内容拖动中长到 10000px）：

```
step 0   offset=533.33   max=3400     ← 钉住的映射，533.33/步
step 1-6 offset=1066→3733 max=9400    ← 内容已变长，但映射保持不变
step 7+  offset=3885→9347 max=9400    ← 轨道走完，转由 shrink guard 接管，467.35/步
```

也就是说这种情况下拖到底需要比平时多一点鼠标位移。换来的是 thumb 全程不跳，这个取舍是划算的 —— 而且这只在"拖动中内容翻倍变长"时才出现。

## 已改动的文件

| 文件 | 改动 |
| --- | --- |
| `lib/ui/widgets/stable_thumb_scrollbar.dart` | 新增。`StableThumbScrollbar` + `StableThumbScrollBehavior` |
| `lib/main.dart` | `MaterialApp` 加 `scrollBehavior: const StableThumbScrollBehavior()` |
| `test/ui/widgets/stable_thumb_scrollbar_test.dart` | 新增，7 个测试全通过 |
| `lib/ui/widgets/video_player_controls/settings_panel.dart` | 顺带修的 controller 泄漏，见下 |
| `lib/ui/widgets/video_player_controls/source_list_panel.dart` | 同上 |

`StableThumbScrollBehavior` 继承 `MaterialScrollBehavior`，只覆写 `buildScrollbar`，平台判断和原版一致（桌面三平台的纵向滚动加 scrollbar，移动端和横向不加）。所以：

- 全局生效，所有 scrollbar 一起修好，不用逐个页面改；
- 现有的 `ScrollConfiguration.copyWith(scrollbars: false)` 调用点照旧工作 —— `copyWith` 返回的包装类是委托实现（`scroll_configuration.dart:326`），不受影响；
- 项目里现存的显式 `Scrollbar(...)`（`episodes_section` 等）都包在**横向**列表上，横向本来就不加自动 scrollbar，不会出现双 scrollbar。

### 顺带修的 controller 泄漏

`settings_panel.dart` 和 `source_list_panel.dart` 之前在 build 方法里写 `widget.scrollController ?? createPlatformScrollController()` —— 每帧新建一个 controller 且从不 dispose，scrollbar 也就永远绑不到稳定的 position 上。改成 state 持有一个：

```dart
ScrollController? _ownedScrollController;

ScrollController get _effectiveScrollController =>
    widget.scrollController ??
    (_ownedScrollController ??= createPlatformScrollController());
```

`dispose()` 里释放。

## 测试

`test/ui/widgets/stable_thumb_scrollbar_test.dart`。测试用一个"首次滚动时长高 6000px"的 scroll view 模拟懒构建的 extent 修正 —— 观测到的事件和真实场景一样（拖动途中报告更大的 `maxScrollExtent`），但不依赖估计算法的启发式细节。

核心断言是**同样的鼠标位移必须产生同样的滚动位移**：

- `keeps one constant drag mapping when content grows mid-drag` —— 每一步的滚动量相等（±1px）
- `Material Scrollbar rescales mid-drag in the same scenario` —— **基线测试**，断言框架原版在同场景下会漂移。如果哪天 Flutter 上游修了这个问题，这条会失败，那时就可以考虑删掉 `StableThumbScrollbar`
- `drag still reaches the true end of grown content` —— 钉住不影响真实末尾可达
- `releases the pin when a drag is cancelled` —— 取消的拖动不会留下陈旧的钉子

## 剩下可做的（非必须）

全局修复已经消除了 thumb 跳动，下面这些是"让 extent 本身更稳"的优化，属于锦上添花：

1. **给正文图片预留尺寸**。`bangumi_comment_html.dart` 里非表情图片没有占位尺寸，加载完成会撑开高度。表情图已经有了（`placeholder: SizedBox(width: size.width, height: size.height)`），普通图片因为宽高比未知做不到精确预留，但可以考虑读 `width`/`height` 属性或给个固定占位高度。这不影响拖动了，但能减少静态浏览时的内容跳动。

2. **工作区里那几个 `ScrollEndNotification` 改动**。`comments_section.dart` / `reviews_section.dart` / `topics_section.dart` 把 load-more 触发从"任意滚动事件"收窄到了 `ScrollEndNotification`，`wide_layout.dart` 加了 `_loadMoreCheckTimer` + `isScrollingNotifier` 门控。这些是之前为了绕开本问题做的缓解，现在不再必需 —— 留着也无害（避免拖动中追加内容仍然是好事），但如果觉得 120ms 延迟影响了加载手感，可以放心回退到原来的即时触发。

3. **`bangumi_blog_detail_dialog.dart` 正文的渲染模式**。工作区里从 `RenderMode.sliverList` 改成了 `SliverToBoxAdapter`。两种都行：`SliverToBoxAdapter` 让正文高度精确（不参与外推估计）但首帧要全量布局；`sliverList` 更懒但参与估计。长评正文通常不长，现在这个选择没问题。
