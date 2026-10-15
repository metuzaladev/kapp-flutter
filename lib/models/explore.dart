import 'dogs.dart';
import 'json.dart';
import 'services.dart';

/// Rough bounding box of Estonia including the islands. Place posts must lie inside it.
const estoniaBbox = (minLat: 57.3, maxLat: 59.95, minLng: 21.5, maxLng: 28.5);
bool isInEstonia(double lat, double lng) =>
    lat >= estoniaBbox.minLat && lat <= estoniaBbox.maxLat && lng >= estoniaBbox.minLng && lng <= estoniaBbox.maxLng;

enum PlaceCategory { cafe, park, beach, shop, other }

/// Amenities a recommender can tick (wire names are snake_case).
enum PlaceAmenity {
  dogsInside('dogs_inside'),
  waterBowl('water_bowl'),
  terrace('terrace'),
  dogTreats('dog_treats'),
  fencedArea('fenced_area'),
  offLeash('off_leash'),
  shade('shade'),
  stream('stream');

  const PlaceAmenity(this.wire);
  final String wire;

  /// Old app builds simply do not show an icon for a new value.
  static PlaceAmenity? tryParse(String value) {
    for (final a in values) {
      if (a.wire == value) return a;
    }
    return null;
  }
}

enum PlacePostStatus { pending, approved, rejected }

const placeNameMin = 2;
const placeNameMax = 80;
const placeAddressMax = 200;
const placePostBodyMax = 1000;
const placePostMaxPhotos = 5;

class PlacePost {
  const PlacePost({
    required this.id,
    required this.authorId,
    required this.authorFirstName,
    required this.isMine,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.address,
    required this.amenities,
    required this.body,
    required this.photos,
    required this.status,
    required this.likeCount,
    required this.liked,
    required this.saved,
    this.distanceKm,
    required this.createdAt,
  });

  factory PlacePost.fromJson(Json j) {
    final author = asJson(j['author']);
    return PlacePost(
      id: j['id']! as String,
      authorId: author['id']! as String,
      authorFirstName: author['firstName']! as String,
      isMine: j['isMine']! as bool,
      name: j['name']! as String,
      category: PlaceCategory.values.byName(j['category']! as String),
      lat: toDouble(j['lat']),
      lng: toDouble(j['lng']),
      address: j['address'] as String?,
      amenities: [for (final a in stringList(j['amenities'])) ?PlaceAmenity.tryParse(a)],
      body: j['body'] as String?,
      photos: listOf(j['photos'], ImageUrls.fromJson),
      status: PlacePostStatus.values.byName(j['status']! as String),
      likeCount: toInt(j['likeCount']),
      liked: j['liked']! as bool,
      saved: j['saved']! as bool,
      distanceKm: toDoubleOrNull(j['distanceKm']),
      createdAt: j['createdAt']! as String,
    );
  }

  final String id;
  final String authorId;
  final String authorFirstName;
  final bool isMine;
  final String name;
  final PlaceCategory category;
  final double lat;
  final double lng;
  final String? address;
  final List<PlaceAmenity> amenities;
  final String? body;
  final List<ImageUrls> photos;
  final PlacePostStatus status;
  final int likeCount;
  final bool liked;
  final bool saved;
  final double? distanceKm;
  final String createdAt;

  PlacePost withReactions({bool? liked, bool? saved, int? likeCount}) => PlacePost(
    id: id,
    authorId: authorId,
    authorFirstName: authorFirstName,
    isMine: isMine,
    name: name,
    category: category,
    lat: lat,
    lng: lng,
    address: address,
    amenities: amenities,
    body: body,
    photos: photos,
    status: status,
    likeCount: likeCount ?? this.likeCount,
    liked: liked ?? this.liked,
    saved: saved ?? this.saved,
    distanceKm: distanceKm,
    createdAt: createdAt,
  );
}

class PlacePostPage {
  const PlacePostPage({required this.items, required this.nextCursor});
  factory PlacePostPage.fromJson(Json j) =>
      PlacePostPage(items: listOf(j['items'], PlacePost.fromJson), nextCursor: j['nextCursor'] as String?);
  final List<PlacePost> items;
  final String? nextCursor;

  PlacePostPage withItems(List<PlacePost> items) => PlacePostPage(items: items, nextCursor: nextCursor);
}

/// Result of PUT/DELETE …/like and …/save — the new state, so the app needs no refetch.
class PlacePostReactions {
  const PlacePostReactions({required this.liked, required this.saved, required this.likeCount});
  factory PlacePostReactions.fromJson(Json j) =>
      PlacePostReactions(liked: j['liked']! as bool, saved: j['saved']! as bool, likeCount: toInt(j['likeCount']));
  final bool liked;
  final bool saved;
  final int likeCount;
}

const placeReportReasons = ['spam', 'inappropriate', 'wrong_info', 'other'];

/// Figma tags: Pargid, Kohvikud, Rannad, Teenused, Kliinikud (+ other recommendations).
enum MapTag { parks, cafes, beaches, services, clinics, other }

/// One degree is ~110 km north–south: plenty for a city map, small enough to keep responses bounded.
const mapMaxSpanDegrees = 1.0;

class MapPlace {
  const MapPlace({
    required this.id,
    required this.kind,
    required this.tag,
    required this.category,
    required this.name,
    required this.lat,
    required this.lng,
  });
  factory MapPlace.fromJson(Json j) => MapPlace(
    id: j['id']! as String,
    kind: j['kind']! as String,
    tag: MapTag.values.byName(j['tag']! as String),
    category: j['category']! as String,
    name: j['name']! as String,
    lat: toDouble(j['lat']),
    lng: toDouble(j['lng']),
  );
  final String id;

  /// What the id refers to: `park`, `post` or `provider`.
  final String kind;
  final MapTag tag;
  final String category;
  final String name;
  final double lat;
  final double lng;
}

enum RewardReason {
  checkIn('check_in'),
  planHonoured('plan_honoured'),
  placePost('place_post'),
  review('review'),
  invite('invite'),
  streak('streak'),
  redemption('redemption'),
  redemptionRefund('redemption_refund');

  const RewardReason(this.wire);
  final String wire;
  static RewardReason parse(String value) => values.firstWhere((r) => r.wire == value);
}

enum RewardLevelId {
  puppy('puppy'),
  parkFriend('park_friend'),
  parkLegend('park_legend'),
  packLeader('pack_leader');

  const RewardLevelId(this.wire);
  final String wire;
  static RewardLevelId parse(String value) => values.firstWhere((r) => r.wire == value);
}

enum RewardBadgeId {
  earlyBird('early_bird'),
  tenParks('ten_parks'),
  explorer('explorer'),
  kadriorgLegend('kadriorg_legend');

  const RewardBadgeId(this.wire);
  final String wire;
  static RewardBadgeId parse(String value) => values.firstWhere((r) => r.wire == value);
}

class RewardLevel {
  const RewardLevel({
    required this.id,
    required this.index,
    required this.minPoints,
    required this.next,
    required this.progress,
  });
  factory RewardLevel.fromJson(Json j) {
    final next = j['next'] == null ? null : asJson(j['next']);
    return RewardLevel(
      id: RewardLevelId.parse(j['id']! as String),
      index: toInt(j['index']),
      minPoints: toInt(j['minPoints']),
      next: next == null
          ? null
          : (
              id: RewardLevelId.parse(next['id']! as String),
              minPoints: toInt(next['minPoints']),
              pointsToGo: toInt(next['pointsToGo']),
            ),
      progress: toDouble(j['progress']),
    );
  }
  final RewardLevelId id;
  final int index;
  final int minPoints;
  final ({RewardLevelId id, int minPoints, int pointsToGo})? next;
  final double progress;
}

class RewardBadge {
  const RewardBadge({required this.id, required this.unlocked, required this.progress, required this.target});
  factory RewardBadge.fromJson(Json j) => RewardBadge(
    id: RewardBadgeId.parse(j['id']! as String),
    unlocked: j['unlocked']! as bool,
    progress: toInt(j['progress']),
    target: toInt(j['target']),
  );
  final RewardBadgeId id;
  final bool unlocked;
  final int progress;
  final int target;
}

class RewardsSummary {
  const RewardsSummary({
    required this.balance,
    required this.lifetimeEarned,
    required this.level,
    required this.streakCurrent,
    required this.streakLastDays,
    required this.badges,
    required this.waysToEarn,
  });
  factory RewardsSummary.fromJson(Json j) {
    final streak = asJson(j['streak']);
    return RewardsSummary(
      balance: toInt(j['balance']),
      lifetimeEarned: toInt(j['lifetimeEarned']),
      level: RewardLevel.fromJson(asJson(j['level'])),
      streakCurrent: toInt(streak['current']),
      streakLastDays: [
        for (final d in asJsonList(streak['lastDays'])) (date: d['date']! as String, active: d['active']! as bool),
      ],
      badges: listOf(j['badges'], RewardBadge.fromJson),
      waysToEarn: [
        for (final w in asJsonList(j['waysToEarn']))
          (
            reason: RewardReason.parse(w['reason']! as String),
            points: toInt(w['points']),
            dailyLimit: toIntOrNull(w['dailyLimit']),
          ),
      ],
    );
  }
  final int balance;
  final int lifetimeEarned;
  final RewardLevel level;
  final int streakCurrent;

  /// Oldest first, the last entry is today (Europe/Tallinn).
  final List<({String date, bool active})> streakLastDays;
  final List<RewardBadge> badges;
  final List<({RewardReason reason, int points, int? dailyLimit})> waysToEarn;
}

class RewardEntry {
  const RewardEntry({
    required this.id,
    required this.reason,
    required this.delta,
    required this.day,
    required this.createdAt,
  });
  factory RewardEntry.fromJson(Json j) => RewardEntry(
    id: j['id']! as String,
    reason: RewardReason.parse(j['reason']! as String),
    delta: toInt(j['delta']),
    day: j['day']! as String,
    createdAt: j['createdAt']! as String,
  );
  final String id;
  final RewardReason reason;
  final int delta;
  final String day;
  final String createdAt;
}

class RewardHistoryPage {
  const RewardHistoryPage({required this.items, required this.nextCursor});
  factory RewardHistoryPage.fromJson(Json j) =>
      RewardHistoryPage(items: listOf(j['items'], RewardEntry.fromJson), nextCursor: j['nextCursor'] as String?);
  final List<RewardEntry> items;
  final String? nextCursor;
}

final inviteCodePattern = RegExp(r'^[A-HJ-NP-Z2-9]{8}$');

class Invite {
  const Invite({required this.code, required this.points});
  factory Invite.fromJson(Json j) => Invite(code: j['code']! as String, points: toInt(j['points']));
  final String code;
  final int points;
}

enum ProductCategory { food, treats, toys, accessories, care }

const maxDiscountPercent = 15;
const pointsPerDiscountPercent = 10;
int redemptionPointsCost(int discountPercent) => discountPercent * pointsPerDiscountPercent;
const redemptionValidDays = 30;

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.priceCents,
    required this.discountPercent,
    required this.discountedPriceCents,
    required this.pointsCost,
    required this.imageUrl,
    required this.provider,
  });
  factory Product.fromJson(Json j) {
    final p = asJson(j['provider']);
    return Product(
      id: j['id']! as String,
      name: j['name']! as String,
      description: j['description'] as String?,
      category: ProductCategory.values.byName(j['category']! as String),
      priceCents: toInt(j['priceCents']),
      discountPercent: toInt(j['discountPercent']),
      discountedPriceCents: toInt(j['discountedPriceCents']),
      pointsCost: toInt(j['pointsCost']),
      imageUrl: j['imageUrl'] as String?,
      provider: (id: p['id']! as String, name: p['name']! as String, area: p['area']! as String),
    );
  }
  final String id;
  final String name;
  final String? description;
  final ProductCategory category;
  final int priceCents;
  final int discountPercent;
  final int discountedPriceCents;
  final int pointsCost;
  final String? imageUrl;
  final ({String id, String name, String area}) provider;
}

/// A service provider that takes paw discounts on bookings.
class ShopPartner extends ProviderSummary {
  const ShopPartner({
    required super.id,
    required super.name,
    required super.category,
    required super.tagline,
    required super.area,
    required super.lat,
    required super.lng,
    required super.photoUrl,
    required super.ratingAverage,
    required super.ratingCount,
    required super.priceFromCents,
    super.distanceKm,
    required this.pawDiscountPercent,
    required this.pointsCost,
  });
  factory ShopPartner.fromJson(Json j) {
    final s = ProviderSummary.fromJson(j);
    return ShopPartner(
      id: s.id,
      name: s.name,
      category: s.category,
      tagline: s.tagline,
      area: s.area,
      lat: s.lat,
      lng: s.lng,
      photoUrl: s.photoUrl,
      ratingAverage: s.ratingAverage,
      ratingCount: s.ratingCount,
      priceFromCents: s.priceFromCents,
      distanceKm: s.distanceKm,
      pawDiscountPercent: toInt(j['pawDiscountPercent']),
      pointsCost: toInt(j['pointsCost']),
    );
  }
  final int pawDiscountPercent;
  final int pointsCost;
}

class Shop {
  const Shop({required this.categories, required this.partners, required this.products});
  factory Shop.fromJson(Json j) => Shop(
    categories: [
      for (final c in asJsonList(j['categories']))
        (id: ProductCategory.values.byName(c['id']! as String), productCount: toInt(c['productCount'])),
    ],
    partners: listOf(j['partners'], ShopPartner.fromJson),
    products: listOf(j['products'], Product.fromJson),
  );
  final List<({ProductCategory id, int productCount})> categories;
  final List<ShopPartner> partners;
  final List<Product> products;
}

enum RedemptionStatus { active, used, cancelled, expired }

class Redemption {
  const Redemption({
    required this.id,
    required this.offerType,
    required this.provider,
    required this.product,
    required this.discountPercent,
    required this.pointsCost,
    required this.code,
    required this.status,
    required this.expiresAt,
    required this.bookingId,
    required this.createdAt,
  });
  factory Redemption.fromJson(Json j) {
    final p = asJson(j['provider']);
    final product = j['product'] == null ? null : asJson(j['product']);
    return Redemption(
      id: j['id']! as String,
      offerType: j['offerType']! as String,
      provider: (id: p['id']! as String, name: p['name']! as String),
      product: product == null ? null : (id: product['id']! as String, name: product['name']! as String),
      discountPercent: toInt(j['discountPercent']),
      pointsCost: toInt(j['pointsCost']),
      code: j['code']! as String,
      status: RedemptionStatus.values.byName(j['status']! as String),
      expiresAt: j['expiresAt']! as String,
      bookingId: j['bookingId'] as String?,
      createdAt: j['createdAt']! as String,
    );
  }
  final String id;

  /// `booking` = paw discount on a booking at the provider; `product` = a product.
  final String offerType;
  final ({String id, String name}) provider;
  final ({String id, String name})? product;
  final int discountPercent;
  final int pointsCost;
  final String code;
  final RedemptionStatus status;
  final String expiresAt;
  final String? bookingId;
  final String createdAt;
}

const searchMinLength = 2;
const searchMaxLength = 80;

class SearchResult {
  const SearchResult({
    required this.kind,
    required this.id,
    required this.name,
    required this.subtitle,
    required this.category,
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.distanceKm,
  });
  factory SearchResult.fromJson(Json j) => SearchResult(
    kind: j['kind']! as String,
    id: j['id'] as String?,
    name: j['name']! as String,
    subtitle: j['subtitle'] as String?,
    category: j['category'] as String?,
    lat: toDouble(j['lat']),
    lng: toDouble(j['lng']),
    zoom: toDouble(j['zoom']),
    distanceKm: toDoubleOrNull(j['distanceKm']),
  );

  /// `park`, `provider`, `post` or `address`.
  final String kind;
  final String? id;
  final String name;
  final String? subtitle;
  final String? category;
  final double lat;
  final double lng;
  final double zoom;
  final double? distanceKm;
}

class SearchResponse {
  const SearchResponse({required this.results, required this.addressesAvailable});
  factory SearchResponse.fromJson(Json j) => SearchResponse(
    results: listOf(j['results'], SearchResult.fromJson),
    addressesAvailable: j['addressesAvailable']! as bool,
  );
  final List<SearchResult> results;
  final bool addressesAvailable;
}
