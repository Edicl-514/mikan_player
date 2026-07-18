# L10N-0 candidate classifier roll-up

> Heuristic first-pass audit created from the scanner baseline. Treat every label as a *suggestion*, not a final verdict — L10N-1..5 packages revisit borderline rows when actually touching the file.

## Summary

- Total candidates: 684
- High: 216
- Medium: 468

## Per-file audit

### `lib/ui/pages/bangumi_details/bangumi_details_controller.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 513:25 | MEDIUM | CJK literal in UI source | `主角` | `protocol` | Bangumi character role token — used for matching, do not localize |
| 514:25 | MEDIUM | CJK literal in UI source | `配角` | `protocol` | Bangumi character role token — used for matching, do not localize |

### `lib/ui/pages/bangumi_details/bangumi_details_helpers.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 15:42 | MEDIUM | CJK literal in UI source | `[简介原文]` | `protocol` | Bangumi-style summary marker square-brackets — these survive as visual decoration only when displayed |
| 23:55 | MEDIUM | CJK literal in UI source | `[简介原文]` | `protocol` | Bangumi-style summary marker square-brackets — these survive as visual decoration only when displayed |
| 91:12 | MEDIUM | CJK literal in UI source | `${date.year}年 ${date.month}月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 112:12 | MEDIUM | CJK literal in UI source | `全 $total 话` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 114:10 | MEDIUM | CJK literal in UI source | `0话` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/bangumi_details/layouts/mobile_layout.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 397:22 | HIGH | title argument | `Characters` | `localize` | high-confidence UI surface (scanner title argument) |
| 429:40 | HIGH | title argument | `评论` | `localize` | high-confidence UI surface (scanner title argument) |
| 445:15 | HIGH | Text/SelectableText | `加载中...` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 465:40 | HIGH | title argument | `评论` | `localize` | high-confidence UI surface (scanner title argument) |
| 470:15 | HIGH | Text/SelectableText | `暂无评论` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 505:45 | HIGH | title argument | `评论` | `localize` | high-confidence UI surface (scanner title argument) |
| 170:35 | MEDIUM | CJK literal in UI source | `详情` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 171:35 | MEDIUM | CJK literal in UI source | `评论` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 295:37 | MEDIUM | CJK literal in UI source | `2026年 1月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 360:17 | MEDIUM | CJK literal in UI source | `暂无简介` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 401:27 | MEDIUM | CJK literal in UI source | `角色` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/bangumi_details/layouts/wide_layout.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 298:16 | HIGH | title argument | `Characters` | `localize` | high-confidence UI surface (scanner title argument) |
| 351:41 | HIGH | title argument | `评论` | `localize` | high-confidence UI surface (scanner title argument) |
| 353:16 | HIGH | title argument | `Comments` | `localize` | high-confidence UI surface (scanner title argument) |
| 302:21 | MEDIUM | CJK literal in UI source | `角色` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/bangumi_details/widgets/characters_section.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 309:11 | HIGH | Text/SelectableText | `CV:` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 149:27 | MEDIUM | CJK literal in UI source | `主角` | `protocol` | Bangumi character role token — used for matching, do not localize |
| 149:41 | MEDIUM | CJK literal in UI source | `主角` | `protocol` | Bangumi character role token — used for matching, do not localize |
| 150:27 | MEDIUM | CJK literal in UI source | `配角` | `protocol` | Bangumi character role token — used for matching, do not localize |
| 150:41 | MEDIUM | CJK literal in UI source | `配角` | `protocol` | Bangumi character role token — used for matching, do not localize |
| 151:37 | MEDIUM | CJK literal in UI source | `闲角` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 354:29 | MEDIUM | CJK literal in UI source | `主角` | `protocol` | Bangumi character role token — used for matching, do not localize |
| 355:35 | MEDIUM | CJK literal in UI source | `配角` | `protocol` | Bangumi character role token — used for matching, do not localize |

### `lib/ui/pages/bangumi_details/widgets/episodes_section.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 112:29 | HIGH | Text/SelectableText | `EP ${ep.sort % 1 == 0 ? ep.sort.toInt() : ep.sort}` | `keep` | EP-style English episode label — product lexicon |

### `lib/ui/pages/bangumi_details/widgets/header_actions.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 37:43 | MEDIUM | CJK literal in UI source | `已收藏` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 37:51 | MEDIUM | CJK literal in UI source | `收藏` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/bangumi_details/widgets/header_collection_stats.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 53:23 | HIGH | Text/SelectableText | `$wish 收藏 / $doing 在看 / $dropped 抛弃` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 101:41 | MEDIUM | CJK literal in UI source | `已收藏` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 101:49 | MEDIUM | CJK literal in UI source | `收藏` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/bangumi_details/widgets/header_rating.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 111:13 | HIGH | Text/SelectableText | `$count votes` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 117:15 | HIGH | Text/SelectableText | `Ranked #$rank` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 47:44 | MEDIUM | CJK literal in UI source | `$total 人评 \| #$rank` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 47:67 | MEDIUM | CJK literal in UI source | `$total 人评` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 130:39 | MEDIUM | CJK literal in UI source | `收藏` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 131:39 | MEDIUM | CJK literal in UI source | `在看` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 132:39 | MEDIUM | CJK literal in UI source | `抛弃` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/bangumi_details/widgets/placeholder_section.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 47:17 | HIGH | Text/SelectableText | `Loading $title...` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 55:17 | HIGH | Text/SelectableText | `(Coming Soon)` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |

### `lib/ui/pages/bangumi_details/widgets/sites_section.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 209:14 | MEDIUM | CJK literal in UI source | `放送` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 211:14 | MEDIUM | CJK literal in UI source | `资料` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 213:14 | MEDIUM | CJK literal in UI source | `资源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/bangumi_details/widgets/summary_tags.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 244:21 | HIGH | Text/SelectableText | `Information` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 289:25 | HIGH | Text/SelectableText | `还有 $hiddenCount 项，点击展开查看完整信息` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 57:34 | MEDIUM | CJK literal in UI source | `点击显示翻译` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 57:45 | MEDIUM | CJK literal in UI source | `点击显示原文` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 263:46 | MEDIUM | CJK literal in UI source | `收起` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 263:53 | MEDIUM | CJK literal in UI source | `展开` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/character_detail_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 1114:45 | HIGH | Text/SelectableText | `CV: ${person.name}` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 145:33 | MEDIUM | CJK literal in UI source | `$year年` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 146:34 | MEDIUM | CJK literal in UI source | `$month月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 147:32 | MEDIUM | CJK literal in UI source | `$day日` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 552:23 | MEDIUM | CJK literal in UI source | `${_characterDetails?.stat.comments ?? 0} 评论` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 558:23 | MEDIUM | CJK literal in UI source | `${_characterDetails?.stat.collects ?? 0} 收藏` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 661:13 | MEDIUM | CJK literal in UI source | `评论` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 667:13 | MEDIUM | CJK literal in UI source | `收藏` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 846:37 | MEDIUM | CJK literal in UI source | `简介` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 871:37 | MEDIUM | CJK literal in UI source | `资料` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 885:43 | MEDIUM | CJK literal in UI source | `别名` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 946:39 | MEDIUM | CJK literal in UI source | `出演作品` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 966:37 | MEDIUM | CJK literal in UI source | `出演作品` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1021:63 | MEDIUM | CJK literal in UI source | `主角` | `protocol` | Bangumi character role token — used for matching, do not localize |
| 1030:65 | MEDIUM | CJK literal in UI source | `主角` | `protocol` | Bangumi character role token — used for matching, do not localize |
| 1173:12 | MEDIUM | CJK literal in UI source | `男` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1176:12 | MEDIUM | CJK literal in UI source | `女` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1186:16 | MEDIUM | CJK literal in UI source | `男性` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1188:16 | MEDIUM | CJK literal in UI source | `女性` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/data_source_config_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 620:53 | HIGH | Text/SelectableText | `配置已保存` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 627:47 | HIGH | Text/SelectableText | `保存失败: $e` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 798:18 | HIGH | label argument | `名称` | `localize` | high-confidence UI surface (scanner label argument) |
| 799:19 | HIGH | helper argument | `显示在数据源列表中的名称` | `localize` | high-confidence UI surface (scanner helper argument) |
| 804:18 | HIGH | label argument | `优先级` | `localize` | high-confidence UI surface (scanner label argument) |
| 805:19 | HIGH | helper argument | `数字越小优先级越高` | `localize` | high-confidence UI surface (scanner helper argument) |
| 812:16 | HIGH | label argument | `图标链接` | `localize` | high-confidence UI surface (scanner label argument) |
| 815:54 | HIGH | label argument | `描述` | `localize` | high-confidence UI surface (scanner label argument) |
| 823:16 | HIGH | label argument | `搜索链接` | `localize` | high-confidence UI surface (scanner label argument) |
| 825:17 | HIGH | helper argument | `{keyword} 会替换为条目名称` | `localize` | high-confidence UI surface (scanner helper argument) |
| 831:16 | HIGH | label argument | `Base URL` | `localize` | high-confidence UI surface (scanner label argument) |
| 832:17 | HIGH | helper argument | `可选。用于拼接条目详情页链接，留空时通常从搜索链接推断` | `localize` | high-confidence UI surface (scanner helper argument) |
| 835:16 | HIGH | title argument | `仅使用第一个词` | `localize` | high-confidence UI surface (scanner title argument) |
| 836:19 | HIGH | subtitle argument | `以空格分割条目名后只用第一个词搜索` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 841:16 | HIGH | title argument | `去除特殊字符` | `localize` | high-confidence UI surface (scanner title argument) |
| 842:19 | HIGH | subtitle argument | `清理符号和部分常见干扰词，提升搜索兼容性` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 850:18 | HIGH | label argument | `尝试条目名称数量` | `localize` | high-confidence UI surface (scanner label argument) |
| 851:19 | HIGH | helper argument | `留空使用默认值。1 表示仅使用主名称` | `localize` | high-confidence UI surface (scanner helper argument) |
| 857:18 | HIGH | label argument | `请求间隔 (毫秒)` | `localize` | high-confidence UI surface (scanner label argument) |
| 858:19 | HIGH | helper argument | `每次请求后的等待时间` | `localize` | high-confidence UI surface (scanner helper argument) |
| 876:18 | HIGH | label argument | `条目链接选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 877:19 | HIGH | helper argument | `从搜索结果页选择条目详情链接` | `localize` | high-confidence UI surface (scanner helper argument) |
| 881:18 | HIGH | title argument | `优先匹配较短名称` | `localize` | high-confidence UI surface (scanner title argument) |
| 890:20 | HIGH | label argument | `名称 JsonPath` | `localize` | high-confidence UI surface (scanner label argument) |
| 895:20 | HIGH | label argument | `链接 JsonPath` | `localize` | high-confidence UI surface (scanner label argument) |
| 900:18 | HIGH | title argument | `优先匹配较短名称` | `localize` | high-confidence UI surface (scanner title argument) |
| 909:20 | HIGH | label argument | `条目名称选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 914:20 | HIGH | label argument | `条目链接选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 919:18 | HIGH | title argument | `优先匹配较短名称` | `localize` | high-confidence UI surface (scanner title argument) |
| 939:20 | HIGH | label argument | `线路名称选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 940:21 | HIGH | helper argument | `例如线路、字幕组、播放源 tab` | `localize` | high-confidence UI surface (scanner helper argument) |
| 944:20 | HIGH | label argument | `线路名称正则` | `localize` | high-confidence UI surface (scanner label argument) |
| 950:18 | HIGH | label argument | `剧集列表选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 957:20 | HIGH | label argument | `列表内剧集选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 962:20 | HIGH | label argument | `列表内链接选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 963:21 | HIGH | helper argument | `留空时使用剧集元素自身 href` | `localize` | high-confidence UI surface (scanner helper argument) |
| 968:18 | HIGH | label argument | `剧集序号正则` | `localize` | high-confidence UI surface (scanner label argument) |
| 974:18 | HIGH | label argument | `剧集选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 981:20 | HIGH | label argument | `剧集链接选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 982:21 | HIGH | helper argument | `留空时使用剧集元素自身 href` | `localize` | high-confidence UI surface (scanner helper argument) |
| 986:20 | HIGH | label argument | `剧集序号正则` | `localize` | high-confidence UI surface (scanner label argument) |
| 1000:18 | HIGH | label argument | `标记分辨率` | `localize` | high-confidence UI surface (scanner label argument) |
| 1001:19 | HIGH | helper argument | `用于播放器内偏好和过滤` | `localize` | high-confidence UI surface (scanner helper argument) |
| 1006:18 | HIGH | label argument | `标记字幕语言` | `localize` | high-confidence UI surface (scanner label argument) |
| 1007:19 | HIGH | helper argument | `用于播放器内偏好和过滤` | `localize` | high-confidence UI surface (scanner helper argument) |
| 1012:16 | HIGH | title argument | `使用条目名称过滤` | `localize` | high-confidence UI surface (scanner title argument) |
| 1013:19 | HIGH | subtitle argument | `要求资源标题包含条目名称` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1018:16 | HIGH | title argument | `使用剧集序号过滤` | `localize` | high-confidence UI surface (scanner title argument) |
| 1019:19 | HIGH | subtitle argument | `要求资源标题包含剧集序号，通常建议开启` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1024:16 | HIGH | title argument | `区分条目名称` | `localize` | high-confidence UI surface (scanner title argument) |
| 1025:19 | HIGH | subtitle argument | `关闭后，不同搜索结果中同名剧集会被去重` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1030:16 | HIGH | title argument | `区分线路名称` | `localize` | high-confidence UI surface (scanner title argument) |
| 1031:19 | HIGH | subtitle argument | `关闭后，不同线路中的同名剧集会被去重` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1042:16 | HIGH | label argument | `视频 URL 正则` | `localize` | high-confidence UI surface (scanner label argument) |
| 1048:16 | HIGH | title argument | `启用嵌套 URL 匹配` | `localize` | high-confidence UI surface (scanner title argument) |
| 1049:19 | HIGH | subtitle argument | `先从播放器页找到内层播放页，再匹配视频地址` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1055:16 | HIGH | label argument | `嵌套 URL 正则` | `localize` | high-confidence UI surface (scanner label argument) |
| 1060:16 | HIGH | label argument | `Cookie` | `localize` | high-confidence UI surface (scanner label argument) |
| 1061:17 | HIGH | helper argument | `播放视频请求携带的 Cookie，可留空` | `localize` | high-confidence UI surface (scanner helper argument) |
| 1068:18 | HIGH | label argument | `Referer` | `localize` | high-confidence UI surface (scanner label argument) |
| 1069:19 | HIGH | helper argument | `播放视频请求的 Referer` | `localize` | high-confidence UI surface (scanner helper argument) |
| 1073:18 | HIGH | label argument | `User-Agent` | `localize` | high-confidence UI surface (scanner label argument) |
| 1074:19 | HIGH | helper argument | `播放视频请求的 User-Agent` | `localize` | high-confidence UI surface (scanner helper argument) |
| 1084:16 | HIGH | title argument | `启用验证码处理` | `localize` | high-confidence UI surface (scanner title argument) |
| 1085:19 | HIGH | subtitle argument | `需要绕过详情页验证码时开启` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1092:65 | HIGH | label argument | `类型` | `localize` | high-confidence UI surface (scanner label argument) |
| 1095:20 | HIGH | label argument | `初始等待 (毫秒)` | `localize` | high-confidence UI surface (scanner label argument) |
| 1101:18 | HIGH | title argument | `详情页使用 WebView` | `localize` | high-confidence UI surface (scanner title argument) |
| 1107:18 | HIGH | label argument | `验证码检测选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 1112:18 | HIGH | label argument | `成功页面选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 1119:20 | HIGH | label argument | `验证码图片选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 1123:20 | HIGH | label argument | `刷新图片选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 1130:20 | HIGH | label argument | `输入框选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 1134:20 | HIGH | label argument | `提交按钮选择器` | `localize` | high-confidence UI surface (scanner label argument) |
| 1141:20 | HIGH | label argument | `验证码长度` | `localize` | high-confidence UI surface (scanner label argument) |
| 1145:73 | HIGH | label argument | `允许字符` | `localize` | high-confidence UI surface (scanner label argument) |
| 1155:14 | HIGH | title argument | `生成的 JSON` | `localize` | high-confidence UI surface (scanner title argument) |
| 1156:17 | HIGH | subtitle argument | `用于核对保存内容` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1159:14 | HIGH | Text/SelectableText | `searchConfig` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 1169:14 | HIGH | Text/SelectableText | `captchaConfig` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 1187:25 | HIGH | title argument | `基本信息` | `localize` | high-confidence UI surface (scanner title argument) |
| 1189:18 | HIGH | title argument | `步骤 1：搜索条目` | `localize` | high-confidence UI surface (scanner title argument) |
| 1190:21 | HIGH | subtitle argument | `配置搜索链接和搜索词处理规则` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1194:18 | HIGH | title argument | `步骤 1：解析搜索结果` | `localize` | high-confidence UI surface (scanner title argument) |
| 1195:21 | HIGH | subtitle argument | `从搜索结果中提取条目名称和详情页链接` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1199:18 | HIGH | title argument | `步骤 2：解析线路和剧集` | `localize` | high-confidence UI surface (scanner title argument) |
| 1200:21 | HIGH | subtitle argument | `从详情页提取线路、剧集和播放页链接` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1204:18 | HIGH | title argument | `过滤和播放器选择` | `localize` | high-confidence UI surface (scanner title argument) |
| 1208:18 | HIGH | title argument | `步骤 3：匹配视频` | `localize` | high-confidence UI surface (scanner title argument) |
| 1209:21 | HIGH | subtitle argument | `从播放页提取最终视频地址和请求头` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1213:18 | HIGH | title argument | `验证码` | `localize` | high-confidence UI surface (scanner title argument) |
| 1214:21 | HIGH | subtitle argument | `可选。仅数据源存在验证码时需要配置` | `localize` | high-confidence UI surface (scanner subtitle argument) |
| 1235:22 | HIGH | tooltip argument | `保存` | `localize` | high-confidence UI surface (scanner tooltip argument) |
| 81:10 | MEDIUM | CJK literal in UI source | `单标签` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 82:16 | MEDIUM | CJK literal in UI source | `多标签` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 87:22 | MEDIUM | CJK literal in UI source | `线路分组` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 88:19 | MEDIUM | CJK literal in UI source | `不区分线路` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 639:55 | MEDIUM | CJK literal in UI source | `必填` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 644:55 | MEDIUM | CJK literal in UI source | `必填` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 645:52 | MEDIUM | CJK literal in UI source | `请输入整数` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 651:52 | MEDIUM | CJK literal in UI source | `请输入整数` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 702:40 | MEDIUM | CJK literal in UI source | `不标记` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1177:48 | MEDIUM | CJK literal in UI source | `未配置` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1231:35 | MEDIUM | CJK literal in UI source | `新建数据源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1231:45 | MEDIUM | CJK literal in UI source | `配置: ${widget.source!.name}` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/download_settings_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 159:33 | HIGH | Text/SelectableText | `rqbit` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 163:33 | HIGH | Text/SelectableText | `libtorrent` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 185:27 | MEDIUM | CJK literal in UI source | `rqbit 基于 Rust 构建，内存占用低，启动快速，擅长边下边播（串流）场景，适合快速预览视频内容。` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 186:27 | MEDIUM | CJK literal in UI source | `libtorrent 是成熟的 C++ BT 引擎，下载稳定高效，兼容性好，擅长完整下载和资源做种，适合长期保种场景。` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/favorites_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 321:16 | MEDIUM | CJK literal in UI source | `想看` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 323:16 | MEDIUM | CJK literal in UI source | `看过` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 325:16 | MEDIUM | CJK literal in UI source | `在看` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 327:16 | MEDIUM | CJK literal in UI source | `搁置` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 329:16 | MEDIUM | CJK literal in UI source | `抛弃` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 331:16 | MEDIUM | CJK literal in UI source | `未知` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/history_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 109:13 | HIGH | Text/SelectableText | `暂无播放记录` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 114:13 | HIGH | Text/SelectableText | `在播放页开始观看后会自动记录` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 187:23 | HIGH | Text/SelectableText | `$episodeLabel ${item.episodeNameCn.isNotEmpty ? item.episodeNameCn : item.episodeName}${item.last...` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |

### `lib/ui/pages/home_mobile_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 883:29 | HIGH | Text/SelectableText | `EP ${item.episodeSort % 1 == 0 ? item.episodeSort.toInt() : item.episodeSort} \| ${item.episodeName}` | `keep` | EP-style English episode label — product lexicon |
| 139:25 | MEDIUM | CJK literal in UI source | `周一` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 139:31 | MEDIUM | CJK literal in UI source | `周二` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 139:37 | MEDIUM | CJK literal in UI source | `周三` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 139:43 | MEDIUM | CJK literal in UI source | `周四` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 139:49 | MEDIUM | CJK literal in UI source | `周五` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 139:55 | MEDIUM | CJK literal in UI source | `周六` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 139:61 | MEDIUM | CJK literal in UI source | `周日` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 489:30 | MEDIUM | CJK literal in UI source | `导演` | `protocol` | Bangumi staff role token — used for matching, do not localize |
| 494:37 | MEDIUM | CJK literal in UI source | `原作` | `protocol` | Bangumi staff role token — used for matching, do not localize |
| 504:62 | MEDIUM | CJK literal in UI source | `原作: $original` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 505:62 | MEDIUM | CJK literal in UI source | `导演: $director` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/home_pc_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 871:31 | HIGH | Text/SelectableText | `EP ${item.episodeSort % 1 == 0 ? item.episodeSort.toInt() : item.episodeSort} \| ${item.episodeName}` | `keep` | EP-style English episode label — product lexicon |
| 132:25 | MEDIUM | CJK literal in UI source | `周一` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 132:31 | MEDIUM | CJK literal in UI source | `周二` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 132:37 | MEDIUM | CJK literal in UI source | `周三` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 132:43 | MEDIUM | CJK literal in UI source | `周四` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 132:49 | MEDIUM | CJK literal in UI source | `周五` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 132:55 | MEDIUM | CJK literal in UI source | `周六` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 132:61 | MEDIUM | CJK literal in UI source | `周日` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 435:30 | MEDIUM | CJK literal in UI source | `导演` | `protocol` | Bangumi staff role token — used for matching, do not localize |
| 440:37 | MEDIUM | CJK literal in UI source | `原作` | `protocol` | Bangumi staff role token — used for matching, do not localize |
| 450:62 | MEDIUM | CJK literal in UI source | `原作: $original` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 451:62 | MEDIUM | CJK literal in UI source | `导演: $director` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/index_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 955:15 | HIGH | Text/SelectableText | `时间` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 1291:15 | HIGH | Text/SelectableText | `类型` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 22:5 | MEDIUM | CJK literal in UI source | `分类` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 22:11 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 23:5 | MEDIUM | CJK literal in UI source | `来源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 23:11 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 24:5 | MEDIUM | CJK literal in UI source | `类型` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 24:11 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 25:5 | MEDIUM | CJK literal in UI source | `地区` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 25:11 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 26:5 | MEDIUM | CJK literal in UI source | `排序` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 26:11 | MEDIUM | CJK literal in UI source | `排名` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 29:26 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 30:27 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 37:5 | MEDIUM | CJK literal in UI source | `分类` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 37:12 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 37:38 | MEDIUM | CJK literal in UI source | `剧场版` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 37:45 | MEDIUM | CJK literal in UI source | `其他` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 38:5 | MEDIUM | CJK literal in UI source | `来源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 38:12 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 38:18 | MEDIUM | CJK literal in UI source | `原创` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 38:24 | MEDIUM | CJK literal in UI source | `漫画改` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 38:31 | MEDIUM | CJK literal in UI source | `游戏改` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 38:38 | MEDIUM | CJK literal in UI source | `小说改` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 38:45 | MEDIUM | CJK literal in UI source | `影视改` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 39:5 | MEDIUM | CJK literal in UI source | `类型` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 40:7 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 41:7 | MEDIUM | CJK literal in UI source | `科幻` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 42:7 | MEDIUM | CJK literal in UI source | `喜剧` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 43:7 | MEDIUM | CJK literal in UI source | `同人` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 44:7 | MEDIUM | CJK literal in UI source | `百合` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 45:7 | MEDIUM | CJK literal in UI source | `校园` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 46:7 | MEDIUM | CJK literal in UI source | `惊悚` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 47:7 | MEDIUM | CJK literal in UI source | `后宫` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 48:7 | MEDIUM | CJK literal in UI source | `机战` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 49:7 | MEDIUM | CJK literal in UI source | `悬疑` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 50:7 | MEDIUM | CJK literal in UI source | `恋爱` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 51:7 | MEDIUM | CJK literal in UI source | `奇幻` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 52:7 | MEDIUM | CJK literal in UI source | `推理` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 53:7 | MEDIUM | CJK literal in UI source | `运动` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 54:7 | MEDIUM | CJK literal in UI source | `耽美` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 55:7 | MEDIUM | CJK literal in UI source | `音乐` | `protocol` | Bangumi staff role token — used for matching, do not localize |
| 56:7 | MEDIUM | CJK literal in UI source | `战斗` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 57:7 | MEDIUM | CJK literal in UI source | `冒险` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 58:7 | MEDIUM | CJK literal in UI source | `萌系` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 59:7 | MEDIUM | CJK literal in UI source | `穿越` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 60:7 | MEDIUM | CJK literal in UI source | `玄幻` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 61:7 | MEDIUM | CJK literal in UI source | `乙女` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 62:7 | MEDIUM | CJK literal in UI source | `恐怖` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 63:7 | MEDIUM | CJK literal in UI source | `历史` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 64:7 | MEDIUM | CJK literal in UI source | `日常` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 65:7 | MEDIUM | CJK literal in UI source | `剧情` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 66:7 | MEDIUM | CJK literal in UI source | `武侠` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 67:7 | MEDIUM | CJK literal in UI source | `美食` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 68:7 | MEDIUM | CJK literal in UI source | `职场` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 70:5 | MEDIUM | CJK literal in UI source | `地区` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 71:7 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 72:7 | MEDIUM | CJK literal in UI source | `日本` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 73:7 | MEDIUM | CJK literal in UI source | `欧美` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 74:7 | MEDIUM | CJK literal in UI source | `中国` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 75:7 | MEDIUM | CJK literal in UI source | `美国` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 76:7 | MEDIUM | CJK literal in UI source | `韩国` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 77:7 | MEDIUM | CJK literal in UI source | `法国` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 78:7 | MEDIUM | CJK literal in UI source | `中国香港` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 79:7 | MEDIUM | CJK literal in UI source | `英国` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 80:7 | MEDIUM | CJK literal in UI source | `俄罗斯` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 81:7 | MEDIUM | CJK literal in UI source | `苏联` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 82:7 | MEDIUM | CJK literal in UI source | `捷克` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 83:7 | MEDIUM | CJK literal in UI source | `中国台湾` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 84:7 | MEDIUM | CJK literal in UI source | `马来西亚` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 86:5 | MEDIUM | CJK literal in UI source | `排序` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 86:12 | MEDIUM | CJK literal in UI source | `排名` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 86:18 | MEDIUM | CJK literal in UI source | `相关度` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 86:25 | MEDIUM | CJK literal in UI source | `收藏数` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 90:5 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 121:5 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 122:5 | MEDIUM | CJK literal in UI source | `1月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 123:5 | MEDIUM | CJK literal in UI source | `2月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 124:5 | MEDIUM | CJK literal in UI source | `3月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 125:5 | MEDIUM | CJK literal in UI source | `4月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 126:5 | MEDIUM | CJK literal in UI source | `5月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 127:5 | MEDIUM | CJK literal in UI source | `6月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 128:5 | MEDIUM | CJK literal in UI source | `7月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 129:5 | MEDIUM | CJK literal in UI source | `8月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 130:5 | MEDIUM | CJK literal in UI source | `9月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 131:5 | MEDIUM | CJK literal in UI source | `10月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 132:5 | MEDIUM | CJK literal in UI source | `11月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 133:5 | MEDIUM | CJK literal in UI source | `12月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 204:44 | MEDIUM | CJK literal in UI source | `排序` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 204:53 | MEDIUM | CJK literal in UI source | `排名` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 207:14 | MEDIUM | CJK literal in UI source | `排名` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 210:14 | MEDIUM | CJK literal in UI source | `热度` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 213:14 | MEDIUM | CJK literal in UI source | `收藏` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 214:14 | MEDIUM | CJK literal in UI source | `收藏数` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 217:14 | MEDIUM | CJK literal in UI source | `日期` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 220:14 | MEDIUM | CJK literal in UI source | `名称` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 223:14 | MEDIUM | CJK literal in UI source | `相关度` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 236:20 | MEDIUM | CJK literal in UI source | `类型` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 236:35 | MEDIUM | CJK literal in UI source | `排序` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 236:52 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 236:69 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 237:22 | MEDIUM | CJK literal in UI source | `分类` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 244:33 | MEDIUM | CJK literal in UI source | `剧场版` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 303:23 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 303:45 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 319:15 | MEDIUM | CJK literal in UI source | `排名` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 319:21 | MEDIUM | CJK literal in UI source | `热度` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 319:27 | MEDIUM | CJK literal in UI source | `收藏` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 319:33 | MEDIUM | CJK literal in UI source | `日期` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 319:39 | MEDIUM | CJK literal in UI source | `名称` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 321:13 | MEDIUM | CJK literal in UI source | `排名` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 321:19 | MEDIUM | CJK literal in UI source | `相关度` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 321:26 | MEDIUM | CJK literal in UI source | `收藏数` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 326:33 | MEDIUM | CJK literal in UI source | `排序` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 328:19 | MEDIUM | CJK literal in UI source | `排序` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 340:40 | MEDIUM | CJK literal in UI source | `类型` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 344:51 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 351:25 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 375:19 | MEDIUM | CJK literal in UI source | `类型` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 375:49 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 384:15 | MEDIUM | CJK literal in UI source | `${_rangeStart!.month}月` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 385:15 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 387:25 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 388:26 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 395:29 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 414:38 | MEDIUM | CJK literal in UI source | `类型` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 415:49 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 422:33 | MEDIUM | CJK literal in UI source | `类型` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 424:38 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 454:18 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 456:25 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 457:26 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 470:26 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 483:24 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 491:26 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 491:43 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 497:20 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 498:30 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 517:18 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 518:29 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 520:26 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 543:26 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 602:18 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 633:33 | MEDIUM | CJK literal in UI source | `时间` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 635:20 | MEDIUM | CJK literal in UI source | `月份` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 650:18 | MEDIUM | CJK literal in UI source | `时间` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 665:18 | MEDIUM | CJK literal in UI source | `月份` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 709:26 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 730:51 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 742:71 | MEDIUM | CJK literal in UI source | `类型` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 748:36 | MEDIUM | CJK literal in UI source | `排序` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 944:44 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1013:35 | MEDIUM | CJK literal in UI source | `不限` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1014:36 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1042:33 | MEDIUM | CJK literal in UI source | `时间` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1126:33 | MEDIUM | CJK literal in UI source | `月份` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1252:33 | MEDIUM | CJK literal in UI source | `类型` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1254:37 | MEDIUM | CJK literal in UI source | `全部` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/my_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 1022:25 | HIGH | Text/SelectableText | `第${task.episodeNumber}集` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 1409:23 | MEDIUM | CJK literal in UI source | `此任务正在运行中，确定要停止并删除吗？` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/network_settings_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 557:35 | HIGH | Text/SelectableText | `旧版` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 561:35 | HIGH | Text/SelectableText | `混合（推荐）` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 565:35 | HIGH | Text/SelectableText | `新版` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 647:39 | HIGH | Text/SelectableText | `离线放送数据` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 200:44 | MEDIUM | CJK literal in UI source | `已更新离线放送数据` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 200:58 | MEDIUM | CJK literal in UI source | `更新失败，请检查网络` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 418:14 | MEDIUM | CJK literal in UI source | `加载中…` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 421:14 | MEDIUM | CJK literal in UI source | `未缓存 · 点击下载离线兜底数据` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 427:28 | MEDIUM | CJK literal in UI source | `已缓存 $sizeStr` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 433:17 | MEDIUM | CJK literal in UI source | `同步于 ${DateFormat(` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 439:19 | MEDIUM | CJK literal in UI source | `${ageMins.round()}分钟前同步失败` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 442:19 | MEDIUM | CJK literal in UI source | `${ageHours.round()}小时前同步失败` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 549:32 | MEDIUM | CJK literal in UI source | `Bangumi 请求方式` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/person_detail_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 1062:27 | HIGH | Text/SelectableText | `${uniqueAppearances.length} 部作品` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 228:16 | MEDIUM | CJK literal in UI source | `声优` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 229:22 | MEDIUM | CJK literal in UI source | `声优` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 230:19 | MEDIUM | CJK literal in UI source | `制作人` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 231:18 | MEDIUM | CJK literal in UI source | `漫画家` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 232:17 | MEDIUM | CJK literal in UI source | `音乐人` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 233:17 | MEDIUM | CJK literal in UI source | `作者` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 234:22 | MEDIUM | CJK literal in UI source | `插画家` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 532:23 | MEDIUM | CJK literal in UI source | `${_details?.stat.comments ?? 0} 评论` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 538:23 | MEDIUM | CJK literal in UI source | `${_details?.stat.collects ?? 0} 收藏` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 667:13 | MEDIUM | CJK literal in UI source | `评论` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 673:13 | MEDIUM | CJK literal in UI source | `收藏` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 787:32 | MEDIUM | CJK literal in UI source | `简介` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 823:32 | MEDIUM | CJK literal in UI source | `资料` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 834:43 | MEDIUM | CJK literal in UI source | `别名` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 899:40 | MEDIUM | CJK literal in UI source | `配音角色` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 924:38 | MEDIUM | CJK literal in UI source | `配音角色` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1164:35 | MEDIUM | CJK literal in UI source | `主角` | `protocol` | Bangumi character role token — used for matching, do not localize |
| 1261:37 | MEDIUM | CJK literal in UI source | `出演作品` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1261:46 | MEDIUM | CJK literal in UI source | `相关作品` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_bt_source_loader.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 41:24 | MEDIUM | CJK literal in UI source | `别名` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 42:24 | MEDIUM | CJK literal in UI source | `別名` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 43:24 | MEDIUM | CJK literal in UI source | `别称` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_page_autoplay_host.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 87:11 | MEDIUM | CJK literal in UI source | `搜索完成，共找到 ${_sampleSourceController.sampleSuccessfulSources.length} 个可用源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_page_episode_host.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 13:46 | MEDIUM | CJK literal in UI source | `已播放本地资源，可手动搜索在线源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 93:33 | MEDIUM | CJK literal in UI source | `${widget.anime.title} - 第${ep.sort.toInt()}集` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 130:46 | MEDIUM | CJK literal in UI source | `已播放本地资源，可手动搜索在线源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_page_playback_host.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 110:20 | HIGH | label argument | `在线源下载` | `localize` | high-confidence UI surface (scanner label argument) |
| 157:63 | HIGH | label argument | `BT下载` | `localize` | high-confidence UI surface (scanner label argument) |
| 207:53 | HIGH | Text/SelectableText | `没有可下载的在线源` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 237:53 | HIGH | Text/SelectableText | `添加下载任务失败，请稍后重试` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 245:51 | HIGH | Text/SelectableText | `已添加到下载任务` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 255:53 | HIGH | Text/SelectableText | `没有可复制的下载链接` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 263:51 | HIGH | Text/SelectableText | `下载链接已复制` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 47:46 | MEDIUM | CJK literal in UI source | `已播放本地资源，可手动搜索在线源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_page_sample_source_panel.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 48:37 | HIGH | title argument | `${task.label} - 正在跳过验证码` | `localize` | high-confidence UI surface (scanner title argument) |
| 69:42 | MEDIUM | CJK literal in UI source | `等待匹配播放页...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 104:21 | MEDIUM | CJK literal in UI source | `等待匹配播放页...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 121:19 | MEDIUM | CJK literal in UI source | `正在跳过验证码` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_page_search_host.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 405:48 | MEDIUM | CJK literal in UI source | `已播放本地资源，点击刷新可手动搜索在线源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 429:48 | MEDIUM | CJK literal in UI source | `在线搜索已关闭，可手动搜索在线源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 491:44 | MEDIUM | CJK literal in UI source | `正在获取播放源列表...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 508:59 | MEDIUM | CJK literal in UI source | `未启用任何播放源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 544:15 | MEDIUM | CJK literal in UI source | `正在搜索 ${enabledSources.length} 个源...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 545:15 | MEDIUM | CJK literal in UI source | `非验证码源先行搜索，验证码源并发预处理中...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_page_side_panel_host.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 81:45 | MEDIUM | CJK literal in UI source | `前传` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 81:67 | MEDIUM | CJK literal in UI source | `续集` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 84:45 | MEDIUM | CJK literal in UI source | `前传` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 84:67 | MEDIUM | CJK literal in UI source | `续集` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_page_side_panel_widgets.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 43:53 | HIGH | Text/SelectableText | `磁力链接已复制` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 48:53 | HIGH | Text/SelectableText | `开始下载，可在「我的」页面查看进度` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 86:69 | HIGH | label argument | `BT` | `protocol` | All-caps acronym (e.g. EP/CV/BT) — industry-domain term, not UI prose |
| 79:49 | MEDIUM | CJK literal in UI source | `无法获取播放地址` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_page_webview_result_host.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 68:13 | MEDIUM | CJK literal in UI source | `提取中: $completed/$total 完成，$active 并发运行` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 163:11 | MEDIUM | CJK literal in UI source | `提取中: $completed/$total 完成，$active 并发运行` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_page_webview_scheduler_host.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 252:37 | MEDIUM | CJK literal in UI source | `正在跳过验证码...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 376:45 | MEDIUM | CJK literal in UI source | `正在提取...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 390:31 | MEDIUM | CJK literal in UI source | `正在提取...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 485:12 | MEDIUM | CJK literal in UI source | `搜索进度: ${_completedSearchSourceCount()}/${_sampleSourceController.enabledSourceNames.length}` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 489:12 | MEDIUM | CJK literal in UI source | `验证码进行中 ${_captchaCoordinator.activeTasks.length}` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 496:12 | MEDIUM | CJK literal in UI source | `提取并发 $active/$_maxConcurrentWebViews` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_playback_controller.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 229:32 | MEDIUM | CJK literal in UI source | `未播放` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 676:21 | MEDIUM | CJK literal in UI source | `播放失败: $error` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 741:21 | MEDIUM | CJK literal in UI source | `当前线路启动超时，请切换其他源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_search_session_coordinator.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 55:10 | MEDIUM | CJK literal in UI source | `搜索进度: $completedCount/$enabledCount，` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 56:7 | MEDIUM | CJK literal in UI source | `验证码 $activeCaptcha 运行/$pendingCaptcha 排队` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 72:51 | MEDIUM | CJK literal in UI source | `未在任何源中找到该动画` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 75:51 | MEDIUM | CJK literal in UI source | `所有源都无法提取视频链接` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 78:13 | MEDIUM | CJK literal in UI source | `搜索完成，共找到 $successfulSourceCount 个可用源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_side_panel_loader.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 243:35 | MEDIUM | CJK literal in UI source | `前传` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 243:57 | MEDIUM | CJK literal in UI source | `续集` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 246:35 | MEDIUM | CJK literal in UI source | `前传` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 246:57 | MEDIUM | CJK literal in UI source | `续集` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_source_controller.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 184:19 | MEDIUM | CJK literal in UI source | `未找到番剧` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/player_source_helpers.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 101:44 | MEDIUM | CJK literal in UI source | `日本` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 101:50 | MEDIUM | CJK literal in UI source | `中国` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 101:56 | MEDIUM | CJK literal in UI source | `动画` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/widgets/bt_resource_tags.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 34:25 | MEDIUM | CJK literal in UI source | `简体\|简中\|CHS(?!T)\|GB\|S_CHS` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 35:25 | MEDIUM | CJK literal in UI source | `繁体\|繁中\|CHT\|BIG5\|T_CHT` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 36:25 | MEDIUM | CJK literal in UI source | `日文\|日语\|日本語` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 41:15 | MEDIUM | CJK literal in UI source | `简繁日` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 43:15 | MEDIUM | CJK literal in UI source | `简日` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 45:15 | MEDIUM | CJK literal in UI source | `繁日` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 47:15 | MEDIUM | CJK literal in UI source | `简繁` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 49:15 | MEDIUM | CJK literal in UI source | `简繁` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 51:15 | MEDIUM | CJK literal in UI source | `简中` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 53:15 | MEDIUM | CJK literal in UI source | `繁中` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 55:15 | MEDIUM | CJK literal in UI source | `日语` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 57:15 | MEDIUM | CJK literal in UI source | `生肉` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 63:5 | MEDIUM | CJK literal in UI source | `内嵌\|内挂\|硬字幕\|HARDSUB\|HARD.?SUB\|ASS.?SUB\|字幕内嵌\|内字\|内置字幕` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 65:29 | MEDIUM | CJK literal in UI source | `内封\|软字幕\|SOFTSUB\|SOFT.?SUB\|字幕内封` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 70:15 | MEDIUM | CJK literal in UI source | `内封` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 72:15 | MEDIUM | CJK literal in UI source | `内嵌` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 137:12 | MEDIUM | CJK literal in UI source | `生肉` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 141:12 | MEDIUM | CJK literal in UI source | `简中` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 145:12 | MEDIUM | CJK literal in UI source | `繁中` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 149:12 | MEDIUM | CJK literal in UI source | `简繁` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 153:12 | MEDIUM | CJK literal in UI source | `日语` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/widgets/player_comment_sort_button.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 36:17 | HIGH | Text/SelectableText | `默认排序` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 56:17 | HIGH | Text/SelectableText | `按时间排序` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 76:37 | MEDIUM | CJK literal in UI source | `默认排序` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 76:46 | MEDIUM | CJK literal in UI source | `按时间排序` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/widgets/player_comments.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 182:11 | HIGH | Text/SelectableText | `加载失败: $error` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 189:21 | HIGH | Text/SelectableText | `暂无评论` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 200:17 | HIGH | Text/SelectableText | `全部评论` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |

### `lib/ui/pages/player/widgets/player_current_source_actions.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 73:42 | HIGH | label argument | `下载` | `localize` | high-confidence UI surface (scanner label argument) |
| 75:38 | HIGH | label argument | `复制下载链接` | `localize` | high-confidence UI surface (scanner label argument) |

### `lib/ui/pages/player/widgets/player_mobile_layout.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 51:17 | HIGH | Text/SelectableText | `选集` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 126:31 | HIGH | Text/SelectableText | `EP ${ep.sort % 1 == 0 ? ep.sort.toInt() : ep.sort}` | `keep` | EP-style English episode label — product lexicon |
| 269:19 | HIGH | Text/SelectableText | `EP ${currentEpisode.sort % 1 == 0 ? currentEpisode.sort.toInt() : currentEpisode.sort}` | `keep` | EP-style English episode label — product lexicon |
| 279:17 | HIGH | Text/SelectableText | `$playableEpisodeCount Episodes` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 302:27 | MEDIUM | CJK literal in UI source | `暂无简介` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 320:53 | MEDIUM | CJK literal in UI source | `收起` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 320:60 | MEDIUM | CJK literal in UI source | `展开` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 343:37 | MEDIUM | CJK literal in UI source | `播放源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 350:39 | MEDIUM | CJK literal in UI source | `官方播放源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 355:37 | MEDIUM | CJK literal in UI source | `相关推荐` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 416:37 | MEDIUM | CJK literal in UI source | `简介 & 推荐` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 417:31 | MEDIUM | CJK literal in UI source | `评论 ($commentsCount)` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/widgets/player_pc_layout.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 301:31 | HIGH | Text/SelectableText | `加载失败: $commentsError` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 313:31 | HIGH | Text/SelectableText | `暂无评论` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 356:23 | HIGH | Text/SelectableText | `选集` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 201:49 | MEDIUM | CJK literal in UI source | `暂无简介` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 227:57 | MEDIUM | CJK literal in UI source | `收起` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 228:57 | MEDIUM | CJK literal in UI source | `展开` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 253:59 | MEDIUM | CJK literal in UI source | `播放源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 260:61 | MEDIUM | CJK literal in UI source | `官方播放源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 278:31 | MEDIUM | CJK literal in UI source | `评论区` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 353:47 | MEDIUM | CJK literal in UI source | `播放列表` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 388:47 | MEDIUM | CJK literal in UI source | `相关推荐` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/widgets/player_recommendations.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 46:11 | HIGH | Text/SelectableText | `暂无相关推荐` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |

### `lib/ui/pages/player/widgets/player_resource_list.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 115:19 | HIGH | Text/SelectableText | `尚未开始搜索BT源` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 120:19 | HIGH | Text/SelectableText | `点击下方按钮开始搜索` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 127:37 | HIGH | Text/SelectableText | `搜索BT源` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 275:25 | HIGH | Text/SelectableText | `复制` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 308:25 | HIGH | Text/SelectableText | `下载` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 83:23 | MEDIUM | CJK literal in UI source | `正在搜索BT源...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 85:29 | MEDIUM | CJK literal in UI source | `已找到 $btCount 个BT源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 86:41 | MEDIUM | CJK literal in UI source | `BT搜索失败` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 86:52 | MEDIUM | CJK literal in UI source | `尚未开始搜索BT源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 351:51 | MEDIUM | CJK literal in UI source | `加载中` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 351:59 | MEDIUM | CJK literal in UI source | `播放` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/widgets/player_sample_source_panel.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 226:21 | HIGH | Text/SelectableText | `per-source [p\|a\|c]: $perSourceStatusLabel` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 268:28 | HIGH | Text/SelectableText | `显示 WebView (调试)` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 282:19 | HIGH | Text/SelectableText | `统一 Worker 调度 (Round 7)` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 305:23 | HIGH | Text/SelectableText | `可用源 (${successfulSources.length})` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 475:37 | HIGH | Text/SelectableText | `搜索在线源` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 110:33 | MEDIUM | CJK literal in UI source | `已播放本地资源，在线源搜索待手动触发` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 112:39 | MEDIUM | CJK literal in UI source | `在线搜索已关闭，可手动搜索在线源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 113:39 | MEDIUM | CJK literal in UI source | `尚未开始搜索在线源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 114:27 | MEDIUM | CJK literal in UI source | `搜索完成 (${successfulSources.length}/${enabledSourceNames.length} 个可用)` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 118:50 | MEDIUM | CJK literal in UI source | `搜索失败` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 200:25 | MEDIUM | CJK literal in UI source | `并发WebView任务 ($activeWebViewTaskCount/$maxConcurrentWebViews)` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 201:25 | MEDIUM | CJK literal in UI source | `并发WebView任务 ($activeWebViewTaskCount/$maxConcurrentWebViews) · $workerPoolLabel` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 452:25 | MEDIUM | CJK literal in UI source | `已使用本地资源播放` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 453:46 | MEDIUM | CJK literal in UI source | `在线搜索已关闭` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 453:58 | MEDIUM | CJK literal in UI source | `尚未开始搜索在线源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 462:25 | MEDIUM | CJK literal in UI source | `如需在线源，请点击下方按钮手动搜索` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 463:46 | MEDIUM | CJK literal in UI source | `点击下方按钮手动搜索在线源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 463:64 | MEDIUM | CJK literal in UI source | `点击下方按钮开始搜索` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 493:43 | MEDIUM | CJK literal in UI source | `播放 -` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 497:14 | MEDIUM | CJK literal in UI source | `播放 - ${source.sourceName}(${source.channelName})` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 499:12 | MEDIUM | CJK literal in UI source | `播放 - ${source.sourceName}` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/widgets/player_source_progress_item.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 35:20 | MEDIUM | CJK literal in UI source | `等待中` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 41:24 | MEDIUM | CJK literal in UI source | `等待中` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 46:24 | MEDIUM | CJK literal in UI source | `搜索中...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 51:24 | MEDIUM | CJK literal in UI source | `获取详情页...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 56:24 | MEDIUM | CJK literal in UI source | `获取剧集列表...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 61:24 | MEDIUM | CJK literal in UI source | `提取视频链接...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 66:59 | MEDIUM | CJK literal in UI source | `成功` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 66:66 | MEDIUM | CJK literal in UI source | `找到播放页` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 71:24 | MEDIUM | CJK literal in UI source | `失败` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/player/widgets/player_source_selector.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 64:29 | HIGH | Text/SelectableText | `已找到` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 110:31 | HIGH | Text/SelectableText | `当前：$currentLabel` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 123:25 | HIGH | Text/SelectableText | `已找到 $btCount 个BT源， $onlineCount 个订阅源，当前源：$currentLabel` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 155:22 | HIGH | label argument | `BT` | `protocol` | All-caps acronym (e.g. EP/CV/BT) — industry-domain term, not UI prose |
| 169:22 | HIGH | label argument | `订阅源` | `localize` | high-confidence UI surface (scanner label argument) |

### `lib/ui/pages/player/widgets/player_video_area.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 151:19 | HIGH | Text/SelectableText | `正在初始化播放...` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 156:19 | HIGH | Text/SelectableText | `正在连接种子网络...` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 174:19 | HIGH | Text/SelectableText | `播放失败` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 204:19 | HIGH | Text/SelectableText | `选择播放源开始观看` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 212:19 | HIGH | Text/SelectableText | `在下方「播放源」中选择资源` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |

### `lib/ui/pages/player_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 209:5 | MEDIUM | CJK literal in UI source | `未播放` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 273:7 | MEDIUM | CJK literal in UI source | `${widget.anime.title} - 第${_episodeController.currentEpisode.sort.toInt()}集` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/search_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 226:35 | MEDIUM | CJK literal in UI source | `日期` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 227:36 | MEDIUM | CJK literal in UI source | `名称` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/search_settings_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 111:21 | HIGH | Text/SelectableText | `WebView Scraper设置 (仅针对Dynamic Webview源)` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |

### `lib/ui/pages/settings_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 106:12 | MEDIUM | CJK literal in UI source | `条目: $subjects, 角色: $characters, 关联: $relations\n` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 107:9 | MEDIUM | CJK literal in UI source | `时间表: $timetables, 排行榜: $rankings\n` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 108:9 | MEDIUM | CJK literal in UI source | `图片缓存: $imageSize` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 164:15 | MEDIUM | CJK literal in UI source | `订阅调试（本地JSON）` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 165:15 | MEDIUM | CJK literal in UI source | `手动测试订阅源搜索和可播放URL提取` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/subscription_debug_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 696:27 | HIGH | hintText argument | `D:\temp\online.json，或留空` | `localize` | high-confidence UI surface (scanner hintText argument) |
| 924:21 | HIGH | Text/SelectableText | `直链: ${result.directVideoUrl!}` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 1008:18 | HIGH | Text/SelectableText | `来源: ${_extractTarget!.sourceName}` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 1070:29 | HIGH | Text/SelectableText | `Headers: ${_extractHeaders.keys.join(` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 1198:15 | HIGH | Text/SelectableText | `当前构建未启用订阅调试。\n请使用 --dart-define=ENABLE_SUBSCRIPTION_DEBUG=true 启动。` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 1225:17 | HIGH | Text/SelectableText | `此页面仅用于调试：优先读取本地 JSON，留空时读取程序缓存中的 JSON，不会修改缓存文件、不会覆盖订阅设置、不会影响正式播放流程。` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 148:49 | MEDIUM | CJK literal in UI source | `搜索直链 Probe` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 156:14 | MEDIUM | CJK literal in UI source | `Probe 中...` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 159:14 | MEDIUM | CJK literal in UI source | `未 Probe` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 162:25 | MEDIUM | CJK literal in UI source | `可播放` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 162:33 | MEDIUM | CJK literal in UI source | `不可播放` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 346:19 | MEDIUM | CJK literal in UI source | `缓存 JSON 不存在: $resolvedJsonPath` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 347:19 | MEDIUM | CJK literal in UI source | `文件不存在: $resolvedJsonPath` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 373:9 | MEDIUM | CJK literal in UI source | `开始调试搜索: anime=$animeName, abs=${absoluteEpisode ??` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 417:39 | MEDIUM | CJK literal in UI source | `搜索异常: $error` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 426:39 | MEDIUM | CJK literal in UI source | `搜索结束` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 451:32 | MEDIUM | CJK literal in UI source | `页面已关闭，无法完成验证码预处理` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 597:13 | MEDIUM | CJK literal in UI source | `${source.name} -> 正在进行验证码预处理 (${i + 1}/${captchaSources.length})` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 627:31 | MEDIUM | CJK literal in UI source | `解析captcha源失败: $e` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 660:32 | MEDIUM | CJK literal in UI source | `开始提取: ${progress.sourceName}` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 765:69 | MEDIUM | CJK literal in UI source | `开始调试搜索` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 969:65 | MEDIUM | CJK literal in UI source | `手动 Probe` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 972:45 | MEDIUM | CJK literal in UI source | `Probe 中` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1109:25 | MEDIUM | CJK literal in UI source | `提取成功: ${result.videoUrl}` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1114:55 | MEDIUM | CJK literal in UI source | `提取失败` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1117:25 | MEDIUM | CJK literal in UI source | `提取失败: ${result.error}` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 1145:36 | MEDIUM | CJK literal in UI source | `提取后 Probe` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/pages/timetable_page.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 110:20 | HIGH | title argument | `$currentYear年$currentQuarter月` | `localize` | high-confidence UI surface (scanner title argument) |
| 29:5 | MEDIUM | CJK literal in UI source | `周一` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 30:5 | MEDIUM | CJK literal in UI source | `周二` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 31:5 | MEDIUM | CJK literal in UI source | `周三` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 32:5 | MEDIUM | CJK literal in UI source | `周四` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 33:5 | MEDIUM | CJK literal in UI source | `周五` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 34:5 | MEDIUM | CJK literal in UI source | `周六` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 35:5 | MEDIUM | CJK literal in UI source | `周日` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 36:5 | MEDIUM | CJK literal in UI source | `其他` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 177:37 | MEDIUM | CJK literal in UI source | `其他` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 206:37 | MEDIUM | CJK literal in UI source | `其他` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 327:41 | MEDIUM | CJK literal in UI source | `其他` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 331:16 | MEDIUM | CJK literal in UI source | `其他` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/widgets/video_player_controls.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 169:18 | HIGH | tooltip argument | `返回` | `localize` | high-confidence UI surface (scanner tooltip argument) |
| 180:20 | HIGH | label argument | `弹幕` | `localize` | high-confidence UI surface (scanner label argument) |
| 201:18 | HIGH | tooltip argument | `返回` | `localize` | high-confidence UI surface (scanner tooltip argument) |
| 260:18 | HIGH | label argument | `选集` | `localize` | high-confidence UI surface (scanner label argument) |
| 275:16 | HIGH | label argument | `空降-85s` | `localize` | high-confidence UI surface (scanner label argument) |
| 282:16 | HIGH | label argument | `空降+85s` | `localize` | high-confidence UI surface (scanner label argument) |
| 298:16 | HIGH | label argument | `空降-85s` | `localize` | high-confidence UI surface (scanner label argument) |
| 305:16 | HIGH | label argument | `空降+85s` | `localize` | high-confidence UI surface (scanner label argument) |
| 580:34 | HIGH | tooltip argument | `解锁` | `localize` | high-confidence UI surface (scanner tooltip argument) |
| 866:23 | HIGH | barrierLabel argument | `关闭设置` | `localize` | high-confidence UI surface (scanner barrierLabel argument) |
| 948:21 | HIGH | barrierLabel argument | `关闭设置` | `localize` | high-confidence UI surface (scanner barrierLabel argument) |
| 995:21 | HIGH | barrierLabel argument | `关闭选集` | `localize` | high-confidence UI surface (scanner barrierLabel argument) |
| 82:31 | MEDIUM | CJK literal in UI source | `未知` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/widgets/video_player_controls/episode_side_panel.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 85:25 | HIGH | Text/SelectableText | `选集` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 94:25 | HIGH | Text/SelectableText | `共${allEpisodes.length}集` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |

### `lib/ui/widgets/video_player_controls/mobile_gesture_and_lock_layer.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 114:28 | HIGH | tooltip argument | `锁定` | `localize` | high-confidence UI surface (scanner tooltip argument) |
| 318:43 | MEDIUM | CJK literal in UI source | `快退 85s` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 321:41 | MEDIUM | CJK literal in UI source | `快退 10s` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 330:25 | MEDIUM | CJK literal in UI source | `暂停` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 330:32 | MEDIUM | CJK literal in UI source | `播放` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 337:44 | MEDIUM | CJK literal in UI source | `快进 85s` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 340:42 | MEDIUM | CJK literal in UI source | `快进 10s` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 371:38 | MEDIUM | CJK literal in UI source | `亮度 $percent%` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 381:24 | MEDIUM | CJK literal in UI source | `音量 $percent%` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 446:23 | MEDIUM | CJK literal in UI source | `长按快进 2x` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/widgets/video_player_controls/settings_panel.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 391:18 | HIGH | title argument | `弹幕设置` | `localize` | high-confidence UI surface (scanner title argument) |
| 397:18 | HIGH | title argument | `字幕设置` | `localize` | high-confidence UI surface (scanner title argument) |
| 403:18 | HIGH | title argument | `播放速度` | `localize` | high-confidence UI surface (scanner title argument) |
| 412:18 | HIGH | title argument | `播放源` | `localize` | high-confidence UI surface (scanner title argument) |
| 427:20 | HIGH | title argument | `自动连播` | `localize` | high-confidence UI surface (scanner title argument) |
| 451:18 | HIGH | title argument | `播放速度` | `localize` | high-confidence UI surface (scanner title argument) |
| 461:11 | HIGH | Text/SelectableText | `常用倍速` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 482:11 | HIGH | Text/SelectableText | `提示：播放速度会同时影响视频与弹幕的时间同步。` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 607:22 | HIGH | title argument | `显示字幕` | `localize` | high-confidence UI surface (scanner title argument) |
| 618:15 | HIGH | Text/SelectableText | `字幕轨道` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 639:23 | HIGH | Text/SelectableText | `当前视频没有内嵌字幕` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 659:24 | HIGH | title argument | `关闭字幕` | `localize` | high-confidence UI surface (scanner title argument) |
| 671:15 | HIGH | Text/SelectableText | `字幕样式` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 682:22 | HIGH | title argument | `字体大小` | `localize` | high-confidence UI surface (scanner title argument) |
| 695:22 | HIGH | title argument | `背景透明度` | `localize` | high-confidence UI surface (scanner title argument) |
| 708:22 | HIGH | title argument | `底部边距` | `localize` | high-confidence UI surface (scanner title argument) |
| 721:22 | HIGH | title argument | `描边宽度` | `localize` | high-confidence UI surface (scanner title argument) |
| 740:19 | HIGH | Text/SelectableText | `字体颜色` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 774:29 | HIGH | Text/SelectableText | `字幕预览效果` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
| 211:14 | MEDIUM | CJK literal in UI source | `${sourceDisplayLabel(_availableSources[activeOnlineSourceIndex])} (${_availableSources.length}个可用)` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 216:25 | MEDIUM | CJK literal in UI source | `未知` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 217:25 | MEDIUM | CJK literal in UI source | `未播放` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 219:13 | MEDIUM | CJK literal in UI source | `当前：$currentLabel` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 220:13 | MEDIUM | CJK literal in UI source | `当前：$currentLabel (${_availableSources.length}个在线源可切换)` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 228:14 | MEDIUM | CJK literal in UI source | `${sourceDisplayLabel(_availableSources[fallbackIndex])} (${_availableSources.length}个可用)` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 231:12 | MEDIUM | CJK literal in UI source | `暂无可用源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 294:17 | MEDIUM | CJK literal in UI source | `弹幕设置` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 297:17 | MEDIUM | CJK literal in UI source | `字幕设置` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 300:17 | MEDIUM | CJK literal in UI source | `播放源` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 303:17 | MEDIUM | CJK literal in UI source | `播放速度` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 306:17 | MEDIUM | CJK literal in UI source | `设置` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 377:15 | MEDIUM | CJK literal in UI source | `已开启` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 379:26 | MEDIUM | CJK literal in UI source | `已关闭` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 382:24 | MEDIUM | CJK literal in UI source | `暂无字幕` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 392:62 | MEDIUM | CJK literal in UI source | `已开启` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 392:70 | MEDIUM | CJK literal in UI source | `已关闭` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 474:56 | MEDIUM | CJK literal in UI source | `正常速度` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |
| 506:14 | MEDIUM | CJK literal in UI source | `$label (正常)` | `localize` | medium CJK literal in UI source — likely user-facing; confirm by reading the line and apply \`i18n-ignore: <reason>\` if not. |

### `lib/ui/widgets/video_player_controls/source_list_panel.dart`

| Line | Confidence | Reason | Literal | Label | Rationale |
|---:|---|---|---|---|---|
| 260:15 | HIGH | Text/SelectableText | `暂无可用播放源` | `localize` | high-confidence UI surface (scanner Text/SelectableText) |
