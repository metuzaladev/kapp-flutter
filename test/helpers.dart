import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/core/i18n/i18n.dart';
import 'package:kapp/models/explore.dart';
import 'package:kapp/models/parks.dart';

/// Loads the real translation tables (assets/i18n) once for tests that format text.
Future<void> loadI18n() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!I18n.instance.isLoaded) await I18n.instance.load();
}

Park park(
  String id, {
  bool fenced = true,
  bool water = false,
  double? distanceKm,
  int? activeDogs,
  double lat = 59.43,
  double lng = 24.75,
}) => Park(
  id: id,
  name: 'Park $id',
  description: null,
  address: null,
  lat: lat,
  lng: lng,
  fenced: fenced,
  smallDogArea: false,
  water: water,
  lighting: false,
  status: 'approved',
  distanceKm: distanceKm,
  activeDogs: activeDogs,
);

PlacePost post(
  String id, {
  PlacePostStatus status = PlacePostStatus.approved,
  bool liked = false,
  bool saved = false,
  int likeCount = 0,
}) => PlacePost(
  id: id,
  authorId: 'u1',
  authorFirstName: 'Mari',
  isMine: false,
  name: 'Place $id',
  category: PlaceCategory.cafe,
  lat: 59.43,
  lng: 24.75,
  address: null,
  amenities: const [],
  body: null,
  photos: const [],
  status: status,
  likeCount: likeCount,
  liked: liked,
  saved: saved,
  createdAt: '2026-10-01T10:00:00Z',
);
