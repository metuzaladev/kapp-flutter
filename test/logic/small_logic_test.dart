import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/core/logic/idempotency.dart';
import 'package:kapp/core/logic/map_categories.dart';
import 'package:kapp/core/logic/motion.dart';
import 'package:kapp/core/logic/upload_order.dart';
import 'package:kapp/models/services.dart';

void main() {
  group('idempotency keys for "Lunasta"', () {
    test('makes RFC 4122 v4 UUIDs', () {
      final id = uuidV4();
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id), isTrue);
      expect(uuidV4(() => 0), '00000000-0000-4000-8000-000000000000');
    });

    test('keeps the key while the outcome is unknown and forgets it once settled', () {
      var n = 0;
      final tracker = IdempotencyTracker(() => 'k${++n}');
      expect(tracker.begin(), 'k1');
      tracker.settle(retryable: true);
      expect(tracker.begin(), 'k1');
      tracker.settle(retryable: false);
      expect(tracker.pending, isNull);
      expect(tracker.begin(), 'k2');
    });

    test('network errors and 5xx may have reached the server, 4xx did not', () {
      expect(isRetryableStatus(null), isTrue);
      expect(isRetryableStatus(0), isTrue);
      expect(isRetryableStatus(503), isTrue);
      expect(isRetryableStatus(409), isFalse);
    });
  });

  group('photo upload order', () {
    test('uploads one after another, in order, reporting progress', () async {
      final progress = <String>[];
      final keys = await uploadInOrder<String>(
        ['a', 'b', 'c'],
        (item, i) async => '$item$i',
        onProgress: (d, t) => progress.add('$d/$t'),
      );
      expect(keys, ['a0', 'b1', 'c2']);
      expect(progress, ['0/3', '1/3', '2/3', '3/3']);
    });

    test('stops at the first failure', () async {
      final seen = <String>[];
      await expectLater(
        uploadInOrder<String>(['a', 'b', 'c'], (item, _) async {
          seen.add(item);
          if (item == 'b') throw StateError('fail');
          return item;
        }),
        throwsStateError,
      );
      expect(seen, ['a', 'b']);
    });

    test('makeCover moves a photo to the front without changing the others', () {
      expect(makeCover(['a', 'b', 'c', 'd'], 2), ['c', 'a', 'b', 'd']);
      expect(makeCover(['a', 'b'], 0), ['a', 'b']);
      expect(makeCover(['a', 'b'], 5), ['a', 'b']);
    });
  });

  group('motion', () {
    test('staggers the first rows and caps the delay', () {
      expect(staggerDelay(0), Duration.zero);
      expect(staggerDelay(-1), Duration.zero);
      expect(staggerDelay(2), const Duration(milliseconds: 80));
      expect(staggerDelay(100), const Duration(milliseconds: maxStaggeredRows * staggerMs));
    });

    test('Reduce Motion makes every animation instant', () {
      expect(motionDuration(MotionDurations.standard, reduceMotion: true), Duration.zero);
      expect(motionDuration(MotionDurations.standard, reduceMotion: false), MotionDurations.standard);
    });
  });

  group('map categories', () {
    test('every chip and place kind has an icon', () {
      for (final c in MapCategory.values) {
        expect(categoryIcon[c], isNotNull);
      }
      for (final k in PlaceKind.values) {
        expect(placeIcon[k], isNotNull);
      }
    });

    test('an unfenced park with water is a swimming spot under "Rannad"', () {
      expect(parkKindOf(fenced: false, water: true), PlaceKind.beach);
      expect(parkKindOf(fenced: true, water: true), PlaceKind.park);
      expect(categoryShows(MapCategory.beaches, PlaceKind.beach), isTrue);
      expect(categoryShows(MapCategory.parks, PlaceKind.beach), isFalse);
      expect(categoryShows(MapCategory.all, PlaceKind.shop), isTrue);
      expect(categoryShows(MapCategory.services, PlaceKind.shop), isFalse);
    });

    test('clinics have their own chip; providers are only fetched when shown', () {
      expect(providerPlaceKind(ServiceCategory.vet), PlaceKind.vet);
      expect(providerPlaceKind(ServiceCategory.grooming), PlaceKind.service);
      expect(needsProviders(MapCategory.parks), isFalse);
      expect(needsProviders(MapCategory.vets), isTrue);
    });

    test('dog pins: none → place pin, one face, up to three faces with a count pill', () {
      expect(parkPinModel(null), const PlacePinModel());
      expect(parkPinModel(0), const PlacePinModel());
      expect(parkPinModel(1), const DogsPinModel(faces: 1, showCount: false, count: 1));
      expect(parkPinModel(6), const DogsPinModel(faces: maxPinFaces, showCount: true, count: 6));
    });
  });
}
