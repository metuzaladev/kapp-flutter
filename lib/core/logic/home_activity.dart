import '../../models/explore.dart';
import '../../models/parks.dart';
import 'map_categories.dart';

/// Pure helpers for the two M11 Home sections (docs/18-avalehe-tegevus.md): "Lemmikparkides täna"
/// and "Kogukonna soovitused". Unit-tested in test/logic/home_activity_test.dart.

/// Favourite parks shown on Home (the screen has room for three rows before the reminders).
const maxActivityParks = 3;

/// Without favourites Home falls back to this many nearest dog parks.
const fallbackActivityParks = 2;
const communityPicksCount = 3;

enum ActivitySource { favorites, nearby }

/// Which parks the activity section asks about: the user's favourites (newest first, as the API lists
/// them), or — with no favourites — the nearest dog parks (swimming spots only if nothing else).
({List<String> ids, ActivitySource source}) activityParkIds(List<Park>? favorites, List<Park> nearby) {
  if (favorites != null && favorites.isNotEmpty) {
    return (ids: favorites.take(maxActivityParks).map((p) => p.id).toList(), source: ActivitySource.favorites);
  }
  final dogParks = nearby.where((p) => parkKindOf(fenced: p.fenced, water: p.water) == PlaceKind.park).toList();
  final pool = dogParks.isNotEmpty ? dogParks : nearby;
  return (ids: pool.take(fallbackActivityParks).map((p) => p.id).toList(), source: ActivitySource.nearby);
}

/// Parts of today that still have planned visits, in day order (past parts are 0 from the API).
List<({DayPart part, int count})> plannedParts(Map<DayPart, int> planned) => [
  for (final part in DayPart.values)
    if ((planned[part] ?? 0) > 0) (part: part, count: planned[part]!),
];

/// Nothing to tell about the park today: no dogs now, no plans.
bool isQuiet(ParkActivity activity) => activity.activeDogs == 0 && plannedParts(activity.planned).isEmpty;

/// Home's "Kogukonna soovitused": the newest approved posts (the viewer's own pending posts belong in
/// Avasta and "Minu soovitused", not here).
List<PlacePost> communityPicks(List<PlacePost> posts, {int count = communityPicksCount}) =>
    posts.where((p) => p.status == PlacePostStatus.approved).take(count).toList();

/// Whether "Oleme siin" (check in here) is the honest main action on the nearest-park card. From 1+ km
/// away "we are here" is simply not true, so the card offers directions instead; without the user's
/// real position (Tallinn fallback) it cannot know, so it opens the park page.
const checkInRadiusKm = 0.3;

enum NearestParkAction { here, checkIn, directions, open }

NearestParkAction nearestParkAction({
  required bool checkedInHere,
  required double? distanceKm,
  required bool usingFallback,
}) {
  if (checkedInHere) return NearestParkAction.here;
  if (usingFallback || distanceKm == null || !distanceKm.isFinite) return NearestParkAction.open;
  return distanceKm <= checkInRadiusKm ? NearestParkAction.checkIn : NearestParkAction.directions;
}
