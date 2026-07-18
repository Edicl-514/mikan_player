// Display-label helpers for IndexPage filters (L10N-4).
//
// Filter *state* and Bangumi API tags keep stable Chinese protocol tokens.
// Only the visible chip/section labels go through AppLocalizations.

import 'package:mikan_player/gen/app_localizations.dart';

// i18n-ignore: protocol filter group key used for matching/state
const indexFilterKeyCategory = '分类';
// i18n-ignore: protocol filter group key used for matching/state
const indexFilterKeySource = '来源';
// i18n-ignore: protocol filter group key used for matching/state
const indexFilterKeyType = '类型';
// i18n-ignore: protocol filter group key used for matching/state
const indexFilterKeyRegion = '地区';
// i18n-ignore: protocol filter group key used for matching/state
const indexFilterKeySort = '排序';
// i18n-ignore: protocol filter option token used for matching/state
const indexFilterAll = '全部';
// i18n-ignore: protocol filter option token used for matching/state
const indexFilterUnlimited = '不限';

/// Maps a protocol filter token (or group key) to the locale-aware UI label.
String indexFilterLabel(AppLocalizations l10n, String token) {
  switch (token) {
    case indexFilterKeyCategory:
      return l10n.indexFilterCategory;
    case indexFilterKeySource:
      return l10n.indexFilterSource;
    case indexFilterKeyType:
      return l10n.indexFilterType;
    case indexFilterKeyRegion:
      return l10n.indexFilterRegion;
    case indexFilterKeySort:
      return l10n.indexFilterSort;
    case indexFilterAll:
      return l10n.filterAll;
    case indexFilterUnlimited:
      return l10n.indexUnlimited;
    // i18n-ignore: product lexicon category codes kept as-is
    case 'TV':
    case 'WEB':
    case 'OVA':
      return token;
    // i18n-ignore: protocol category token used for matching/API
    case '剧场版':
      return l10n.indexCategoryMovie;
    // i18n-ignore: protocol category token used for matching/API
    case '其他':
      return l10n.indexCategoryOther;
    // i18n-ignore: protocol source token used for matching/API
    case '原创':
      return l10n.indexSourceOriginal;
    // i18n-ignore: protocol source token used for matching/API
    case '漫画改':
      return l10n.indexSourceManga;
    // i18n-ignore: protocol source token used for matching/API
    case '游戏改':
      return l10n.indexSourceGame;
    // i18n-ignore: protocol source token used for matching/API
    case '小说改':
      return l10n.indexSourceNovel;
    // i18n-ignore: protocol source token used for matching/API
    case '影视改':
      return l10n.indexSourceLiveAction;
    // i18n-ignore: protocol sort token used for matching/state
    case '排名':
      return l10n.indexSortRank;
    // i18n-ignore: protocol sort token used for matching/state
    case '相关度':
      return l10n.indexSortMatch;
    // i18n-ignore: protocol sort token used for matching/state
    case '收藏数':
      return l10n.indexSortHeat;
    // i18n-ignore: protocol sort token used for matching/state
    case '热度':
      return l10n.indexSortTrends;
    // i18n-ignore: protocol sort token used for matching/state
    case '收藏':
      return l10n.indexSortCollect;
    // i18n-ignore: protocol sort token used for matching/state
    case '日期':
      return l10n.indexSortDate;
    // i18n-ignore: protocol sort token used for matching/state
    case '名称':
      return l10n.indexSortTitle;
    // i18n-ignore: protocol region token used for matching/API
    case '日本':
      return l10n.indexRegionJapan;
    // i18n-ignore: protocol region token used for matching/API
    case '欧美':
      return l10n.indexRegionWestern;
    // i18n-ignore: protocol region token used for matching/API
    case '中国':
      return l10n.indexRegionChina;
    // i18n-ignore: protocol region token used for matching/API
    case '美国':
      return l10n.indexRegionUsa;
    // i18n-ignore: protocol region token used for matching/API
    case '韩国':
      return l10n.indexRegionKorea;
    // i18n-ignore: protocol region token used for matching/API
    case '法国':
      return l10n.indexRegionFrance;
    // i18n-ignore: protocol region token used for matching/API
    case '中国香港':
      return l10n.indexRegionHongKong;
    // i18n-ignore: protocol region token used for matching/API
    case '英国':
      return l10n.indexRegionUk;
    // i18n-ignore: protocol region token used for matching/API
    case '俄罗斯':
      return l10n.indexRegionRussia;
    // i18n-ignore: protocol region token used for matching/API
    case '苏联':
      return l10n.indexRegionSoviet;
    // i18n-ignore: protocol region token used for matching/API
    case '捷克':
      return l10n.indexRegionCzech;
    // i18n-ignore: protocol region token used for matching/API
    case '中国台湾':
      return l10n.indexRegionTaiwan;
    // i18n-ignore: protocol region token used for matching/API
    case '马来西亚':
      return l10n.indexRegionMalaysia;
    // i18n-ignore: protocol genre token used for matching/API
    case '科幻':
      return l10n.indexGenreScifi;
    // i18n-ignore: protocol genre token used for matching/API
    case '喜剧':
      return l10n.indexGenreComedy;
    // i18n-ignore: protocol genre token used for matching/API
    case '同人':
      return l10n.indexGenreDoujin;
    // i18n-ignore: protocol genre token used for matching/API
    case '百合':
      return l10n.indexGenreYuri;
    // i18n-ignore: protocol genre token used for matching/API
    case '校园':
      return l10n.indexGenreSchool;
    // i18n-ignore: protocol genre token used for matching/API
    case '惊悚':
      return l10n.indexGenreThriller;
    // i18n-ignore: protocol genre token used for matching/API
    case '后宫':
      return l10n.indexGenreHarem;
    // i18n-ignore: protocol genre token used for matching/API
    case '机战':
      return l10n.indexGenreMecha;
    // i18n-ignore: protocol genre token used for matching/API
    case '悬疑':
      return l10n.indexGenreMystery;
    // i18n-ignore: protocol genre token used for matching/API
    case '恋爱':
      return l10n.indexGenreRomance;
    // i18n-ignore: protocol genre token used for matching/API
    case '奇幻':
      return l10n.indexGenreFantasy;
    // i18n-ignore: protocol genre token used for matching/API
    case '推理':
      return l10n.indexGenreDetective;
    // i18n-ignore: protocol genre token used for matching/API
    case '运动':
      return l10n.indexGenreSports;
    // i18n-ignore: protocol genre token used for matching/API
    case '耽美':
      return l10n.indexGenreBoysLove;
    // i18n-ignore: protocol genre token used for matching/API
    case '音乐':
      return l10n.indexGenreMusic;
    // i18n-ignore: protocol genre token used for matching/API
    case '战斗':
      return l10n.indexGenreAction;
    // i18n-ignore: protocol genre token used for matching/API
    case '冒险':
      return l10n.indexGenreAdventure;
    // i18n-ignore: protocol genre token used for matching/API
    case '萌系':
      return l10n.indexGenreMoe;
    // i18n-ignore: protocol genre token used for matching/API
    case '穿越':
      return l10n.indexGenreIsekai;
    // i18n-ignore: protocol genre token used for matching/API
    case '玄幻':
      return l10n.indexGenreXuanhuan;
    // i18n-ignore: protocol genre token used for matching/API
    case '乙女':
      return l10n.indexGenreOtome;
    // i18n-ignore: protocol genre token used for matching/API
    case '恐怖':
      return l10n.indexGenreHorror;
    // i18n-ignore: protocol genre token used for matching/API
    case '历史':
      return l10n.indexGenreHistory;
    // i18n-ignore: protocol genre token used for matching/API
    case '日常':
      return l10n.indexGenreSliceOfLife;
    // i18n-ignore: protocol genre token used for matching/API
    case '剧情':
      return l10n.indexGenreDrama;
    // i18n-ignore: protocol genre token used for matching/API
    case '武侠':
      return l10n.indexGenreWuxia;
    // i18n-ignore: protocol genre token used for matching/API
    case '美食':
      return l10n.indexGenreFood;
    // i18n-ignore: protocol genre token used for matching/API
    case '职场':
      return l10n.indexGenreWorkplace;
    default:
      // Month protocol tokens like "3月"
      final monthMatch = RegExp(r'^(\d{1,2})月$').firstMatch(token);
      if (monthMatch != null) {
        final month = int.tryParse(monthMatch.group(1)!);
        if (month != null) return l10n.indexMonthLabel(month);
      }
      return token;
  }
}
