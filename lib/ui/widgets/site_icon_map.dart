/// Bangumi-data `site` key → asset filename under `assets/images/sites/`.
/// Adding a new entry here is enough to make the icon show up; missing
/// entries fall back to a generic globe icon.
const Map<String, String> kSiteIconMap = {
  'bangumi': 'bangumi.png',
  'bangumi_moe': 'bangumi_moe.png',
  'bilibili': 'bilibili.png',
  'bilibili_hk_mo': 'bilibili.png',
  'bilibili_hk_mo_tw': 'bilibili.png',
  'bilibili_tw': 'bilibili.png',
  'acfun': 'acfun.png',
  'youku': 'youku.png',
  'qq': 'qq.png',
  'iqiyi': 'iqiyi.png',
  'letv': 'letv.png',
  'mgtv': 'mgtv.png',
  'nicovideo': 'nicovideo.png',
  'netflix': 'netflix.png',
  'gamer': 'gamer.png',
  'gamer_hk': 'gamer.png',
  'gamer_tw': 'gamer.png',
  'muse_hk': 'muse.png',
  'muse_tw': 'muse.png',
  'ani_one': 'ani_one.png',
  'ani_one_asia': 'ani_one.png',
  'viu': 'viu.png',
  'mytv': 'mytv.png',
  'disneyplus': 'disneyplus.png',
  'abema': 'abema.png',
  'unext': 'unext.png',
  'tropics': 'tropics.png',
  'prime': 'prime.png',
  'danime': 'danime.png',
  'dmhy': 'dmhy.png',
  'mikan': 'mikan.png',
  'tmdb': 'tmdb.png',
  'mal': 'mal.png',
  'anidb': 'anidb.png',
  'aniList': 'anilist.png',
  'crunchyroll': 'crunchyroll.png',
  'youtube': 'youtube.png',
};

String? siteIconAssetPath(String siteKey) {
  final entry = kSiteIconMap[siteKey];
  if (entry == null) return null;
  return 'assets/images/sites/$entry';
}
