import 'package:intl/intl.dart';

import '../../components/icon.dart';
import '../../models/explore.dart';

/// Pure helpers for the Käpad screen (docs/16-avasta-ja-kapad.md). Amounts, levels and limits always
/// come from the server (GET /me/rewards); this file only maps ids to i18n keys and icons.

/// i18n key of a level name ("Pargisõber"); the server sends only the id.
String levelNameKey(RewardLevelId id) => 'rewards.levels.${id.wire}';

/// "Tase 2": the server's index is 0-based.
int levelNumber(int index) => (index < 0 ? 0 : index) + 1;

String badgeNameKey(RewardBadgeId id) => 'rewards.badges.${id.wire}.name';
String badgeBodyKey(RewardBadgeId id) => 'rewards.badges.${id.wire}.body';

const Map<RewardBadgeId, IconName> badgeIcon = {
  RewardBadgeId.earlyBird: IconName.sun,
  RewardBadgeId.tenParks: IconName.trees,
  RewardBadgeId.explorer: IconName.compass,
  RewardBadgeId.kadriorgLegend: IconName.trophy,
};

/// "Kuidas teenida" and history rows: icon + i18n key per ledger reason.
const Map<RewardReason, IconName> reasonIcon = {
  RewardReason.checkIn: IconName.mapPin,
  RewardReason.streak: IconName.flame,
  RewardReason.planHonoured: IconName.calendar,
  RewardReason.review: IconName.star,
  RewardReason.placePost: IconName.sparkles,
  RewardReason.invite: IconName.users,
  RewardReason.redemption: IconName.ticket,
  RewardReason.redemptionRefund: IconName.gift,
};

String reasonTitleKey(RewardReason reason) => 'rewards.reasons.${reason.wire}.title';
String reasonBodyKey(RewardReason reason) => 'rewards.reasons.${reason.wire}.body';

/// The points one action earns, from the server's rule table (null if missing).
int? pointsFor(RewardsSummary? summary, RewardReason reason) {
  if (summary == null) return null;
  for (final w in summary.waysToEarn) {
    if (w.reason == reason) return w.points;
  }
  return null;
}

/// Badge progress 0…1 for the progress bar (the server caps `progress` at `target` once unlocked).
double badgeProgress({required bool unlocked, required int progress, required int target}) {
  if (unlocked) return 1;
  if (target <= 0) return 0;
  return (progress / target).clamp(0, 1).toDouble();
}

class StreakDay {
  const StreakDay({required this.date, required this.active, required this.isToday, required this.letter});
  final String date;
  final bool active;
  final bool isToday;
  final String letter;
}

/// The streak card's seven paws (Figma "Streak Tile"): oldest first, the last is today.
List<StreakDay> streakDays(
  List<({String date, bool active})> lastDays,
  String Function(String isoDate) weekdayLetter,
) => [
  for (var i = 0; i < lastDays.length; i++)
    StreakDay(
      date: lastDays[i].date,
      active: lastDays[i].active,
      isToday: i == lastDays.length - 1,
      letter: weekdayLetter(lastDays[i].date),
    ),
];

/// One-letter weekday of a calendar date in the app language (et: E T K N R L P). The date is a
/// Tallinn calendar day without a time, so it is read in UTC: no time zone can shift it.
String Function(String isoDate) weekdayLetterIn(String intlLocale) {
  final format = DateFormat.EEEEE(intlLocale);
  return (isoDate) => format.format(DateTime.parse('${isoDate}T12:00:00Z')).toUpperCase();
}
