import 'json.dart';

/// GET /parks/nearby, /me/favorites (`parkSchema`).
class Park {
  const Park({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.lat,
    required this.lng,
    required this.fenced,
    required this.smallDogArea,
    required this.water,
    required this.lighting,
    required this.status,
    this.distanceKm,
    this.activeDogs,
  });

  factory Park.fromJson(Json j) => Park(
    id: j['id']! as String,
    name: j['name']! as String,
    description: j['description'] as String?,
    address: j['address'] as String?,
    lat: toDouble(j['lat']),
    lng: toDouble(j['lng']),
    fenced: j['fenced']! as bool,
    smallDogArea: j['smallDogArea']! as bool,
    water: j['water']! as bool,
    lighting: j['lighting']! as bool,
    status: j['status']! as String,
    distanceKm: toDoubleOrNull(j['distanceKm']),
    activeDogs: toIntOrNull(j['activeDogs']),
  );

  final String id;
  final String name;
  final String? description;
  final String? address;
  final double lat;
  final double lng;
  final bool fenced;
  final bool smallDogArea;
  final bool water;
  final bool lighting;
  final String status;
  final double? distanceKm;
  final int? activeDogs;
}

/// GET /parks/:parkId — adds review summary and, for signed-in users, favourite state.
class ParkDetail extends Park {
  const ParkDetail({
    required super.id,
    required super.name,
    required super.description,
    required super.address,
    required super.lat,
    required super.lng,
    required super.fenced,
    required super.smallDogArea,
    required super.water,
    required super.lighting,
    required super.status,
    super.distanceKm,
    super.activeDogs,
    required this.ratingAverage,
    required this.reviewCount,
    this.isFavorite,
  });

  factory ParkDetail.fromJson(Json j) {
    final p = Park.fromJson(j);
    return ParkDetail(
      id: p.id,
      name: p.name,
      description: p.description,
      address: p.address,
      lat: p.lat,
      lng: p.lng,
      fenced: p.fenced,
      smallDogArea: p.smallDogArea,
      water: p.water,
      lighting: p.lighting,
      status: p.status,
      distanceKm: p.distanceKm,
      activeDogs: p.activeDogs,
      ratingAverage: toDoubleOrNull(j['ratingAverage']),
      reviewCount: toInt(j['reviewCount']),
      isFavorite: j['isFavorite'] as bool?,
    );
  }

  final double? ratingAverage;
  final int reviewCount;
  final bool? isFavorite;

  ParkDetail withFavorite(bool favorite) => ParkDetail(
    id: id,
    name: name,
    description: description,
    address: address,
    lat: lat,
    lng: lng,
    fenced: fenced,
    smallDogArea: smallDogArea,
    water: water,
    lighting: lighting,
    status: status,
    distanceKm: distanceKm,
    activeDogs: activeDogs,
    ratingAverage: ratingAverage,
    reviewCount: reviewCount,
    isFavorite: favorite,
  );
}

/// Parts of a Tallinn day: hommik < 12, päev 12–17, õhtu ≥ 17.
enum DayPart { morning, day, evening }

/// M11 "Lemmikparkides täna" (`parkActivitySchema`).
class ParkActivity {
  const ParkActivity({
    required this.id,
    required this.name,
    required this.activeDogs,
    required this.planned,
    required this.friends,
  });

  factory ParkActivity.fromJson(Json j) {
    final planned = asJson(j['planned']);
    return ParkActivity(
      id: j['id']! as String,
      name: j['name']! as String,
      activeDogs: toInt(j['activeDogs']),
      planned: {for (final p in DayPart.values) p: toInt(planned[p.name])},
      friends: [
        for (final f in asJsonList(j['friends']))
          (firstName: f['firstName']! as String, part: DayPart.values.byName(f['part']! as String)),
      ],
    );
  }

  final String id;
  final String name;
  final int activeDogs;
  final Map<DayPart, int> planned;
  final List<({String firstName, DayPart part})> friends;
}

class ParkActivityResponse {
  const ParkActivityResponse({required this.date, required this.parks});
  factory ParkActivityResponse.fromJson(Json j) =>
      ParkActivityResponse(date: j['date']! as String, parks: listOf(j['parks'], ParkActivity.fromJson));
  final String date;
  final List<ParkActivity> parks;
}
