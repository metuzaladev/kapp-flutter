import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/core/logic/home_activity.dart';
import 'package:kapp/models/explore.dart';
import 'package:kapp/models/parks.dart';

import '../helpers.dart';

Park _dogPark(String id) => park(id);
Park _swim(String id) => park(id, fenced: false, water: true);

ParkActivity _activity({int dogs = 0, Map<DayPart, int> planned = const {}}) => ParkActivity(
  id: 'p',
  name: 'P',
  activeDogs: dogs,
  planned: {for (final p in DayPart.values) p: planned[p] ?? 0},
  friends: const [],
);

void main() {
  group('activityParkIds', () {
    test('uses favourites first, newest first as the API lists them, at most three', () {
      final favorites = ['f1', 'f2', 'f3', 'f4'].map(_dogPark).toList();
      final r = activityParkIds(favorites, [_dogPark('n1')]);
      expect(r.ids, ['f1', 'f2', 'f3']);
      expect(r.source, ActivitySource.favorites);
    });

    test('falls back to the two nearest dog parks, skipping swimming spots', () {
      final r = activityParkIds([], [_swim('swim'), _dogPark('n1'), _dogPark('n2'), _dogPark('n3')]);
      expect(r.ids, ['n1', 'n2']);
      expect(r.source, ActivitySource.nearby);
    });

    test('uses swimming spots only when nothing else is near; nothing near → no ids', () {
      expect(activityParkIds(null, [_swim('s1')]).ids, ['s1']);
      expect(activityParkIds(null, []).ids, isEmpty);
    });
  });

  test('plannedParts keeps parts with visits in day order', () {
    expect(plannedParts({DayPart.morning: 0, DayPart.day: 2, DayPart.evening: 4}), [
      (part: DayPart.day, count: 2),
      (part: DayPart.evening, count: 4),
    ]);
  });

  test('quiet = no dogs now and no plans', () {
    expect(isQuiet(_activity()), isTrue);
    expect(isQuiet(_activity(dogs: 1)), isFalse);
    expect(isQuiet(_activity(planned: {DayPart.evening: 1})), isFalse);
  });

  test('communityPicks drops own pending and rejected posts and keeps the newest three', () {
    final posts = [
      post('mine', status: PlacePostStatus.pending),
      post('a'),
      post('rej', status: PlacePostStatus.rejected),
      post('b'),
      post('c'),
      post('d'),
    ];
    expect(communityPicks(posts).map((p) => p.id), ['a', 'b', 'c']);
  });

  group('nearestParkAction ("Oleme siin" only when it is true)', () {
    test('within 300 m → check in', () {
      expect(
        nearestParkAction(checkedInHere: false, distanceKm: 0.12, usingFallback: false),
        NearestParkAction.checkIn,
      );
      expect(
        nearestParkAction(checkedInHere: false, distanceKm: checkInRadiusKm, usingFallback: false),
        NearestParkAction.checkIn,
      );
    });

    test('further away → directions', () {
      expect(
        nearestParkAction(checkedInHere: false, distanceKm: 0.31, usingFallback: false),
        NearestParkAction.directions,
      );
    });

    test('distance from the Tallinn fallback or unknown → open the park', () {
      expect(nearestParkAction(checkedInHere: false, distanceKm: 0.1, usingFallback: true), NearestParkAction.open);
      expect(nearestParkAction(checkedInHere: false, distanceKm: null, usingFallback: false), NearestParkAction.open);
      expect(
        nearestParkAction(checkedInHere: false, distanceKm: double.nan, usingFallback: false),
        NearestParkAction.open,
      );
    });

    test('already checked in there → "Oled siin", whatever the distance', () {
      expect(nearestParkAction(checkedInHere: true, distanceKm: 3, usingFallback: true), NearestParkAction.here);
    });
  });
}
