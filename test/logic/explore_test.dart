import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/core/logic/explore.dart';
import 'package:kapp/core/logic/map_categories.dart';
import 'package:kapp/core/query/query_client.dart';
import 'package:kapp/hooks/explore.dart';
import 'package:kapp/models/explore.dart';

import '../helpers.dart';

const tallinn = (lat: 59.437, lng: 24.7536);

void main() {
  group('bbox from the visible map region', () {
    test('snaps a city view outwards to the grid, so small pans reuse the cached request', () {
      final a = bboxFromRegion((west: 24.705, south: 59.415, east: 24.795, north: 59.455))!;
      final b = bboxFromRegion((west: 24.707, south: 59.417, east: 24.797, north: 59.457))!;
      expect(a, b);
      expect(a.minLat, lessThanOrEqualTo(59.415));
      expect(a.maxLat, greaterThanOrEqualTo(59.457));
      expect(a.minLng, lessThanOrEqualTo(24.705));
      expect(a.maxLng, greaterThanOrEqualTo(24.797));
    });

    test('never asks for more than the API allows (≤ 1° per side), shrinking around the centre', () {
      final box = bboxFromRegion((west: 21.0, south: 57.0, east: 28.0, north: 60.0))!;
      expect(box.maxLat - box.minLat, lessThanOrEqualTo(mapMaxSpanDegrees));
      expect(box.maxLng - box.minLng, lessThanOrEqualTo(mapMaxSpanDegrees));
      expect((box.minLat + box.maxLat) / 2, closeTo(58.5, 0.05));
      expect((box.minLng + box.maxLng) / 2, closeTo(24.5, 0.05));
    });

    test('keeps max > min for a point-sized view (the API rejects an empty box)', () {
      final box = bboxFromRegion((west: 24.75, south: 59.43, east: 24.75, north: 59.43))!;
      expect(box.maxLat, greaterThan(box.minLat));
      expect(box.maxLng, greaterThan(box.minLng));
    });

    test('rejects invalid bounds instead of sending NaN', () {
      expect(bboxFromRegion((west: double.nan, south: 59, east: 25, north: 60)), isNull);
    });

    test('builds a starting box around the user before the map reports its region', () {
      final box = bboxAround(lat: tallinn.lat, lng: tallinn.lng);
      expect(box.minLat, lessThan(tallinn.lat));
      expect(box.maxLat, greaterThan(tallinn.lat));
      expect(box.maxLng - box.minLng, lessThanOrEqualTo(mapMaxSpanDegrees));
    });
  });

  group('map chips, tags and pins', () {
    test('maps every chip to API tags; "Kõik" asks for all', () {
      expect(mapTagsFor(MapCategory.all), isNull);
      expect(mapTagsFor(MapCategory.vets), [MapTag.clinics]);
    });

    test('draws every API tag as a pin variant', () {
      expect(MapTag.values.map(placeKindOf).toList(), [
        PlaceKind.park,
        PlaceKind.cafe,
        PlaceKind.beach,
        PlaceKind.service,
        PlaceKind.vet,
        PlaceKind.shop,
      ]);
    });

    test('opens the detail screen that matches the place kind', () {
      expect(placeRoute(id: 'p', kind: 'park'), '/parks/p');
      expect(placeRoute(id: 's', kind: 'provider'), '/services/s');
      expect(placeRoute(id: 'x', kind: 'post'), '/place-posts/x');
    });

    test('"Kaardil" selects the chip that shows the post (shops only under Kõik)', () {
      expect(mapCategoryForPost(PlaceCategory.cafe), MapCategory.cafes);
      expect(mapCategoryForPost(PlaceCategory.beach), MapCategory.beaches);
      expect(mapCategoryForPost(PlaceCategory.shop), MapCategory.all);
    });

    test('lists the earliest free times across the week', () {
      final days = [
        ['2026-10-03T07:00:00Z'],
        <String>[],
        ['2026-10-02T13:30:00Z', '2026-10-02T14:00:00Z'],
      ];
      expect(nextFreeSlots(days), ['2026-10-02T13:30:00Z', '2026-10-02T14:00:00Z', '2026-10-03T07:00:00Z']);
      expect(nextFreeSlots(days, count: 1), ['2026-10-02T13:30:00Z']);
    });
  });

  group('Avasta categories, amenities and filters', () {
    test('has an icon for every category and amenity in the shared contract', () {
      for (final c in PlaceCategory.values) {
        expect(placeCategoryIcon[c], isNotNull);
      }
      for (final a in PlaceAmenity.values) {
        expect(amenityIcon[a], isNotNull);
      }
    });

    test('builds feed query params from the chips', () {
      expect(feedQueryParams(defaultFeedFilters, tallinn), {'lat': tallinn.lat, 'lng': tallinn.lng, 'radiusKm': 15});
      expect(feedQueryParams(const FeedFilters(near: false, category: PlaceCategory.cafe, friends: true), tallinn), {
        'category': 'cafe',
        'scope': 'friends',
      });
    });

    test('category chips are exclusive and a second tap clears', () {
      final cafe = toggleCategory(defaultFeedFilters, PlaceCategory.cafe);
      expect(cafe.category, PlaceCategory.cafe);
      expect(toggleCategory(cafe, PlaceCategory.park).category, PlaceCategory.park);
      expect(toggleCategory(cafe, PlaceCategory.cafe).category, isNull);
    });

    test('amenity toggles keep the schema order and never duplicate', () {
      var list = toggleAmenity([], PlaceAmenity.terrace);
      list = toggleAmenity(list, PlaceAmenity.dogsInside);
      expect(list, [PlaceAmenity.dogsInside, PlaceAmenity.terrace]);
      expect(toggleAmenity(list, PlaceAmenity.terrace), [PlaceAmenity.dogsInside]);
    });
  });

  group('optimistic like / save', () {
    final a = post('a', likeCount: 2);
    final b = post('b', liked: true, saved: true, likeCount: 5);

    test('toggles the heart and never goes below zero', () {
      expect(toggledLike(liked: false, likeCount: 2), (liked: true, likeCount: 3));
      expect(toggledLike(liked: true, likeCount: 0), (liked: false, likeCount: 0));
    });

    test('patches the post inside paged lists and keeps other pages untouched', () {
      final data = InfiniteData(
        [
          PlacePostPage(items: [a], nextCursor: 'x'),
          PlacePostPage(items: [b], nextCursor: null),
        ],
        const [null, 'x'],
      );
      final next = patchPostData(data, 'a', (p) => p.withReactions(saved: true))! as InfiniteData<PlacePostPage>;
      expect(next.pages[0].items[0].saved, isTrue);
      expect(identical(next.pages[1], data.pages[1]), isTrue);
    });

    test('returns the same object when the post is not cached there (no needless rebuild)', () {
      final data = InfiniteData(
        [
          PlacePostPage(items: [b], nextCursor: null),
        ],
        const [null],
      );
      expect(identical(patchPostData(data, 'a', (p) => p.withReactions(saved: true)), data), isTrue);
      expect(identical(patchPostData(b, 'a', (p) => p.withReactions(saved: false)), b), isTrue);
    });

    test('patches a single post (detail query)', () {
      final next = patchPostData(a, 'a', (p) => p.withReactions(liked: true, likeCount: 3))! as PlacePost;
      expect(next.liked, isTrue);
      expect(next.likeCount, 3);
    });
  });
}
