# FRB 迁移前 API 基线快照

记录迁移开始前 Dart 业务依赖的顶层 API 签名（commit `785aa28`）。
迁移阶段三必须保持本快照中列出的函数名、参数名、参数类型和返回类型稳定。

## `lib/src/rust/api/bangumi.dart` — 15 个函数

| Dart 函数 | 参数 | 返回 |
| --- | --- | --- |
| `fetchBangumiEpisodes` | `subjectId: PlatformInt64` | `Future<List<BangumiEpisode>>` |
| `fetchBangumiCharacters` | `subjectId: PlatformInt64` | `Future<List<BangumiCharacter>>` |
| `fetchBangumiRelations` | `subjectId: PlatformInt64` | `Future<List<BangumiRelatedSubject>>` |
| `fetchBangumiComments` | `subjectId: PlatformInt64`, `page: int` | `Future<List<BangumiComment>>` |
| `fetchBangumiPersons` | `subjectId: PlatformInt64` | `Future<List<BangumiPerson>>` |
| `fetchBangumiEpisodeComments` | `episodeId: PlatformInt64` | `Future<List<BangumiEpisodeComment>>` |
| `fetchCharacterDetails` | `characterId: PlatformInt64` | `Future<CharacterDetails>` |
| `fetchPersonDetails` | `personId: PlatformInt64` | `Future<PersonDetails>` |
| `fetchPersonSubjects` | `personId: PlatformInt64` | `Future<List<PersonSubject>>` |
| `fetchPersonCharacters` | `personId: PlatformInt64` | `Future<List<PersonCharacter>>` |
| `fetchCharacterSubjects` | `characterId: PlatformInt64` | `Future<List<CharacterSubject>>` |
| `fetchBangumiUserInfo` | `username: String` | `Future<BangumiUserInfo>` |
| `fetchBangumiUserCollections` | `username: String`, `subjectType: int`, `limit: int`, `offset: int` | `Future<List<BangumiUserCollectionEntry>>` |
| `fetchBangumiSubjectImage` | `subjectId: PlatformInt64`, `imageType: String` | `Future<Uint8List>` |
| `fetchBangumiImageUrl` | `url: String` | `Future<Uint8List>` |

DTO 类：`BangumiActor`, `BangumiCharacter`, `BangumiComment`, `BangumiEpisode`, `BangumiEpisodeComment`, `BangumiImages`, `BangumiPerson`, `BangumiRelatedSubject`, `BangumiUserCollectionEntry`, `BangumiUserInfo`, `CharacterDetails`, `CharacterStat`, `CharacterSubject`, `CharacterSubjectPerson`, `InfoboxItem`, `PersonCharacter`, `PersonDetails`, `PersonSubject`.

## `lib/src/rust/api/crawler.dart` — 17 个函数

| Dart 函数 | 参数 | 返回 |
| --- | --- | --- |
| `fetchArchiveList` | — | `Future<List<ArchiveQuarter>>` |
| `fetchScheduleBasic` | `yearQuarter: String` | `Future<List<AnimeInfo>>` |
| `fetchScheduleBasicApiOnly` | `yearQuarter: String` | `Future<List<AnimeInfo>>` |
| `fetchScheduleBasicFromLocalJson` | `yearQuarter: String` | `Future<List<AnimeInfo>>` |
| `fetchScheduleBasicFromLocalJsonNodl` | `yearQuarter: String` | `Future<List<AnimeInfo>>` |
| `spawnSitesIndexBackground` | — | `Future<void>` |
| `buildSitesIndex` | — | `Future<BigInt>` |
| `invalidateSitesIndex` | — | `Future<void>` |
| `fetchBangumiDataSites` | `bangumiId: PlatformInt64` | `Future<List<BangumiDataSiteEntry>>` |
| `fetchBangumiDataSitesByMikan` | `mikanId: PlatformInt64` | `Future<List<BangumiDataSiteEntry>>` |
| `lookupMikanId` | `bangumiId: PlatformInt64` | `Future<PlatformInt64?>` |
| `fillAnimeDetails` | `animes: List<AnimeInfo>` | `Future<List<AnimeInfo>>` |
| `fetchLightSubjectDetails` | `subjectId: PlatformInt64` | `Future<AnimeInfo>` |
| `fetchExtraSubjects` | `yearQuarter: String`, `existingIds: List<String>` | `Future<List<AnimeInfo>>` |
| `getBangumiDataCacheStatus` | — | `Future<BangumiDataCacheStatus>` |
| `refreshBangumiDataCache` | — | `Future<bool>` |
| `ensureBangumiDataCache` | `maxAgeSecs: BigInt` | `Future<bool>` |

DTO 类：`AnimeInfo`, `ArchiveQuarter`, `BangumiDataCacheStatus`, `BangumiDataSiteEntry`.

## `lib/src/rust/api/generic_scraper.dart` — 18 个函数

| Dart 函数 | 参数 | 返回 |
| --- | --- | --- |
| `invalidateSourceConfigCache` | — | `Future<void>` |
| `refreshPlaybackSourceConfig` | — | `Future<String>` |
| `preloadPlaybackSources` | — | `Future<void>` |
| `getPlaybackSources` | — | `Future<List<SourceState>>` |
| `updateSingleSourceConfig` | `update: SourceConfigUpdate` | `Future<void>` |
| `addSourceConfig` | `newConfig: SourceConfigUpdate` | `Future<void>` |
| `genericSearchPlayPages` | `animeName: String`, `absoluteEpisode: int?`, `relativeEpisode: int?` | `Future<List<SearchPlayResult>>` |
| `genericSearchPlayPagesStream` | 同上 | `Stream<SearchPlayResult>` |
| `getEnabledSourceNames` | — | `Future<List<String>>` |
| `genericSearchWithProgress` | `animeName: String`, `absoluteEpisode: int?`, `relativeEpisode: int?` | `Stream<SourceSearchProgress>` |
| `genericSearchWithProgressRuntime` | 同上 + `targetSourceNames: List<String>?`, `runtimeOverrides: List<SourceRuntimeOverride>` | `Stream<SourceSearchProgress>` |
| `debugSearchWithLocalJson` | `jsonPath: String`, `animeName: String`, `absoluteEpisode: int?`, `relativeEpisode: int?`, `sourceNameFilter: String?` | `Stream<SourceSearchProgress>` |
| `debugSearchWithLocalJsonRuntime` | 同上 + `runtimeOverrides: List<SourceRuntimeOverride>` | `Stream<SourceSearchProgress>` |
| `genericSearchAndPlayWithEpisode` | `animeName: String`, `absoluteEpisode: int?`, `relativeEpisode: int?` | `Future<String>` |
| `genericSearchAndPlay` | `animeName: String` | `Future<String>` |
| `genericSearchWithChannels` | `animeName: String` | `Future<List<SearchResultWithChannels>>` |
| `genericSearchWithChannelsStream` | `animeName: String` | `Stream<SearchResultWithChannels>` |
| `getEpisodePlayUrl` | `sourceName: String`, `animeName: String`, `channelIndex: BigInt`, `episodeNumber: int?`, `runtimeOverride: SourceRuntimeOverride?` | `Future<SearchPlayResult>` |

DTO 类：`ChannelInfo`, `EpisodeInfo`, `SearchPlayResult`, `SearchResultWithChannels`, `SearchStep` (enum), `SourceConfigUpdate`, `SourceRuntimeOverride`, `SourceSearchProgress`, `SourceState`.

## `lib/src/rust/api/network.dart` — 业务唯一在用

- `getSystemProxy` → `Future<String?>`

`getSharedClient`, `invalidateEchClient`, `getEchClient`, `clientForBangumi`, `selectClient`
是 FRB 把返回 `&'static Client` 的内部 helper 误导出为 `Future<void>`，
本次迁移将它们从 Dart API 中移除（只保留 Rust 内部 `pub(crate)` 使用）。

## 当前 dart 调用路径（迁移后应保留为 barrel）

业务代码使用：

```dart
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/src/rust/api/network.dart' as network;
```

`RustLib.instance.api.crateApi{Bangumi,Crawler,GenericScraper,Network}...`
是 frb_generated 内部低层方法名，迁移后可能变成 `crateFrbApi{Bangumi,...}...`，
属于生成代码内部细节，业务代码不依赖即可。
