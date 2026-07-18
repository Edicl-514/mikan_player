// Upstream Bangumi/bgmlist broadcast-day protocol tokens.
// Used for matching timetable payloads; display strings go through l10n.

// i18n-ignore: upstream broadcast day token used for matching
const broadcastDayTokenMonday = '周一';
// i18n-ignore: upstream broadcast day token used for matching
const broadcastDayTokenTuesday = '周二';
// i18n-ignore: upstream broadcast day token used for matching
const broadcastDayTokenWednesday = '周三';
// i18n-ignore: upstream broadcast day token used for matching
const broadcastDayTokenThursday = '周四';
// i18n-ignore: upstream broadcast day token used for matching
const broadcastDayTokenFriday = '周五';
// i18n-ignore: upstream broadcast day token used for matching
const broadcastDayTokenSaturday = '周六';
// i18n-ignore: upstream broadcast day token used for matching
const broadcastDayTokenSunday = '周日';
// i18n-ignore: upstream broadcast day token used for matching
const broadcastDayTokenOther = '其他';

/// Monday-first tokens matching `DateTime.weekday` (1=Mon ... 7=Sun).
const List<String> broadcastDayTokensMonToSun = [
  broadcastDayTokenMonday,
  broadcastDayTokenTuesday,
  broadcastDayTokenWednesday,
  broadcastDayTokenThursday,
  broadcastDayTokenFriday,
  broadcastDayTokenSaturday,
  broadcastDayTokenSunday,
];

/// Timetable day tokens including the "other" bucket.
const List<String> broadcastDayTokensWithOther = [
  ...broadcastDayTokensMonToSun,
  broadcastDayTokenOther,
];

String broadcastDayTokenForWeekday(int weekday) {
  // DateTime.weekday: 1=Mon ... 7=Sun
  final index = weekday - 1;
  if (index < 0 || index >= broadcastDayTokensMonToSun.length) {
    return broadcastDayTokenOther;
  }
  return broadcastDayTokensMonToSun[index];
}
