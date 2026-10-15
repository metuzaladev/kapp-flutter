import 'dart:math' as math;

import '../../components/icon.dart';
import '../../models/explore.dart';
import 'map_categories.dart';

/// Pure helpers for M9b Avasta and the map places (docs/16-avasta-ja-kapad.md). Unit-tested in
/// test/logic/explore_test.dart.

/// [west, south, east, north] — the visible map bounds.
typedef LngLatBox = ({double west, double south, double east, double north});

class Bbox {
  const Bbox({required this.minLat, required this.minLng, required this.maxLat, required this.maxLng});
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  Map<String, Object> toJson() => {'minLat': minLat, 'minLng': minLng, 'maxLat': maxLat, 'maxLng': maxLng};

  @override
  bool operator ==(Object other) =>
      other is Bbox &&
      other.minLat == minLat &&
      other.minLng == minLng &&
      other.maxLat == maxLat &&
      other.maxLng == maxLng;

  @override
  int get hashCode => Object.hash(minLat, minLng, maxLat, maxLng);

  @override
  String toString() => 'Bbox($minLat, $minLng, $maxLat, $maxLng)';
}

/// Grid the box is snapped to (0.02° ≈ 2 km north–south): small pans reuse the cached request.
const _grid = 0.02;
double _snapDown(double n) => (n / _grid).floorToDouble() * _grid;
double _snapUp(double n) => (n / _grid).ceilToDouble() * _grid;
double _round(double n) => (n * 1000).roundToDouble() / 1000;
double _clamp(double n, double min, double max) => math.min(max, math.max(min, n));

/// The /map/places query box for what is on screen. The API accepts at most 1° per side: a
/// zoomed-out view is shrunk around its centre instead of failing with 400. Invalid input gives null.
Bbox? bboxFromRegion(LngLatBox bounds, {double maxSpan = mapMaxSpanDegrees}) {
  final (:west, :south, :east, :north) = bounds;
  if (![west, south, east, north].every((n) => n.isFinite)) return null;
  final centerLat = (south + north) / 2;
  final centerLng = (west + east) / 2;
  // Half of the allowed span minus one grid cell, so snapping outwards cannot exceed the limit.
  final half = maxSpan / 2 - _grid;
  final latHalf = math.min((north - south).abs() / 2, half);
  final lngHalf = math.min((east - west).abs() / 2, half);
  final minLat = _round(_clamp(_snapDown(centerLat - latHalf), -90, 90));
  var maxLat = _round(_clamp(_snapUp(centerLat + latHalf), -90, 90));
  final minLng = _round(_clamp(_snapDown(centerLng - lngHalf), -180, 180));
  var maxLng = _round(_clamp(_snapUp(centerLng + lngHalf), -180, 180));
  // A zero-size box (a single point) is widened by one cell so maxLat > minLat holds.
  if (maxLat <= minLat) maxLat = _round(minLat + _grid);
  if (maxLng <= minLng) maxLng = _round(minLng + _grid);
  return Bbox(minLat: minLat, minLng: minLng, maxLat: maxLat, maxLng: maxLng);
}

/// Box around a point before the map has reported its region (≈ city-district view).
Bbox bboxAround({required double lat, required double lng, double halfSpan = 0.06}) =>
    bboxFromRegion((west: lng - halfSpan * 2, south: lat - halfSpan, east: lng + halfSpan * 2, north: lat + halfSpan))!;

/// Which /map/places tags a Kaart chip asks for; null = every tag ("Kõik").
List<MapTag>? mapTagsFor(MapCategory category) => switch (category) {
  MapCategory.all => null,
  MapCategory.parks => [MapTag.parks],
  MapCategory.cafes => [MapTag.cafes],
  MapCategory.beaches => [MapTag.beaches],
  MapCategory.services => [MapTag.services],
  MapCategory.vets => [MapTag.clinics],
};

/// Pin variant (Figma "Map Pin / Place") for a place from /map/places, decided by its tag.
PlaceKind placeKindOf(MapTag tag) => switch (tag) {
  MapTag.parks => PlaceKind.park,
  MapTag.cafes => PlaceKind.cafe,
  MapTag.beaches => PlaceKind.beach,
  MapTag.services => PlaceKind.service,
  MapTag.clinics => PlaceKind.vet,
  MapTag.other => PlaceKind.shop,
};

/// Route that opens a map place: `kind` says which detail endpoint the id belongs to.
String placeRoute({required String id, required String kind}) => switch (kind) {
  'provider' => '/services/$id',
  'post' => '/place-posts/$id',
  _ => '/parks/$id',
};

/// The Kaart chip that shows a post's pin ("Kaardil"): shops and others only appear under "Kõik".
MapCategory mapCategoryForPost(PlaceCategory category) => switch (category) {
  PlaceCategory.cafe => MapCategory.cafes,
  PlaceCategory.park => MapCategory.parks,
  PlaceCategory.beach => MapCategory.beaches,
  PlaceCategory.shop || PlaceCategory.other => MapCategory.all,
};

const Map<PlaceCategory, IconName> placeCategoryIcon = {
  PlaceCategory.cafe: IconName.coffee,
  PlaceCategory.park: IconName.trees,
  PlaceCategory.beach: IconName.waves,
  PlaceCategory.shop: IconName.store,
  PlaceCategory.other: IconName.mapPin,
};

/// Figma "Feed / Place Post" amenity chips: 14 pt Lucide icon + label.
const Map<PlaceAmenity, IconName> amenityIcon = {
  PlaceAmenity.dogsInside: IconName.dog,
  PlaceAmenity.waterBowl: IconName.droplet,
  PlaceAmenity.terrace: IconName.sun,
  PlaceAmenity.dogTreats: IconName.cookie,
  PlaceAmenity.fencedArea: IconName.fence,
  PlaceAmenity.offLeash: IconName.footprints,
  PlaceAmenity.shade: IconName.trees,
  PlaceAmenity.stream: IconName.waves,
};

/// Categories offered in "Soovita kohta" (Figma: Kohvik, Park, Rand, Pood) plus "Muu".
const suggestCategories = [
  PlaceCategory.cafe,
  PlaceCategory.park,
  PlaceCategory.beach,
  PlaceCategory.shop,
  PlaceCategory.other,
];

/// Avasta filter chips (Figma 84:7825): Lähedal, Kohvikud, Pargid, Rannad, Poed; Sõbrad.
const feedCategoryChips = [PlaceCategory.cafe, PlaceCategory.park, PlaceCategory.beach, PlaceCategory.shop];

class FeedFilters {
  const FeedFilters({this.near = true, this.category, this.friends = false});

  /// "Lähedal": only posts within the radius of the user (or Tallinn's centre).
  final bool near;

  /// One category at a time; tapping the chosen chip again clears it.
  final PlaceCategory? category;

  /// "Sõbrad": posts of accepted friends only.
  final bool friends;

  FeedFilters copyWith({bool? near, PlaceCategory? Function()? category, bool? friends}) => FeedFilters(
    near: near ?? this.near,
    category: category != null ? category() : this.category,
    friends: friends ?? this.friends,
  );

  @override
  bool operator ==(Object other) =>
      other is FeedFilters && other.near == near && other.category == category && other.friends == friends;

  @override
  int get hashCode => Object.hash(near, category, friends);
}

const defaultFeedFilters = FeedFilters();

/// Feed radius for "Lähedal": Tallinn and its edges.
const _nearRadiusKm = 15;

/// Query parameters for GET /place-posts (without the paging cursor).
Map<String, Object> feedQueryParams(FeedFilters filters, ({double lat, double lng}) origin) => {
  if (filters.near) ...{'lat': origin.lat, 'lng': origin.lng, 'radiusKm': _nearRadiusKm},
  if (filters.category != null) 'category': filters.category!.name,
  if (filters.friends) 'scope': 'friends',
};

/// Category chip toggle: exclusive, a second tap clears.
FeedFilters toggleCategory(FeedFilters filters, PlaceCategory category) =>
    filters.copyWith(category: () => filters.category == category ? null : category);

/// The provider sheet's "Vabad ajad": the earliest free starts across the week (M6 slots).
List<String> nextFreeSlots(Iterable<Iterable<String>> days, {int count = 3}) {
  final all = days.expand((d) => d).toList()..sort();
  return all.take(count).toList();
}

/// The optimistic state after tapping the heart.
({bool liked, int likeCount}) toggledLike({required bool liked, required int likeCount}) =>
    liked ? (liked: false, likeCount: math.max(0, likeCount - 1)) : (liked: true, likeCount: likeCount + 1);

/// Amenity chip toggle in "Soovita kohta", kept in the schema's order so the request is stable.
List<PlaceAmenity> toggleAmenity(List<PlaceAmenity> list, PlaceAmenity amenity) {
  final set = {...list};
  if (!set.remove(amenity)) set.add(amenity);
  return PlaceAmenity.values.where(set.contains).toList();
}
