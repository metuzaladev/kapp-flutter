import 'json.dart';

/// One rule for both directions: a time can be booked, and a booking cancelled, until this many
/// minutes before it starts.
const bookingCutoffMinutes = 120;
const bookingHorizonDays = 60;
const maxBookingDogs = 3;
const bookingNoteMax = 300;

enum ServiceCategory { grooming, training, vet, other }

class Service {
  const Service({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.priceCents,
    required this.priceIsFrom,
  });
  factory Service.fromJson(Json j) => Service(
    id: j['id']! as String,
    name: j['name']! as String,
    description: j['description'] as String?,
    durationMinutes: toInt(j['durationMinutes']),
    priceCents: toInt(j['priceCents']),
    priceIsFrom: j['priceIsFrom']! as bool,
  );
  final String id;
  final String name;
  final String? description;
  final int durationMinutes;
  final int priceCents;

  /// true → "alates 35 €" (final price agreed with the provider).
  final bool priceIsFrom;
}

/// A provider in the "Services / Discover" list.
class ProviderSummary {
  const ProviderSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.tagline,
    required this.area,
    required this.lat,
    required this.lng,
    required this.photoUrl,
    required this.ratingAverage,
    required this.ratingCount,
    required this.priceFromCents,
    this.distanceKm,
  });
  factory ProviderSummary.fromJson(Json j) => ProviderSummary(
    id: j['id']! as String,
    name: j['name']! as String,
    category: ServiceCategory.values.byName(j['category']! as String),
    tagline: j['tagline'] as String?,
    area: j['area']! as String,
    lat: toDouble(j['lat']),
    lng: toDouble(j['lng']),
    photoUrl: j['photoUrl'] as String?,
    ratingAverage: toDoubleOrNull(j['ratingAverage']),
    ratingCount: toInt(j['ratingCount']),
    priceFromCents: toIntOrNull(j['priceFromCents']),
    distanceKm: toDoubleOrNull(j['distanceKm']),
  );
  final String id;
  final String name;
  final ServiceCategory category;
  final String? tagline;
  final String area;
  final double lat;
  final double lng;
  final String? photoUrl;
  final double? ratingAverage;
  final int ratingCount;
  final int? priceFromCents;
  final double? distanceKm;
}

class ProviderDetail extends ProviderSummary {
  const ProviderDetail({
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
    required this.description,
    required this.address,
    required this.timeZone,
    required this.services,
  });
  factory ProviderDetail.fromJson(Json j) {
    final s = ProviderSummary.fromJson(j);
    return ProviderDetail(
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
      description: j['description'] as String?,
      address: j['address'] as String?,
      timeZone: j['timeZone']! as String,
      services: listOf(j['services'], Service.fromJson),
    );
  }
  final String? description;
  final String? address;

  /// IANA zone of the opening hours and slots, e.g. "Europe/Tallinn".
  final String timeZone;
  final List<Service> services;
}

class Slot {
  const Slot({required this.startsAt, required this.endsAt});
  factory Slot.fromJson(Json j) => Slot(startsAt: j['startsAt']! as String, endsAt: j['endsAt']! as String);
  final String startsAt;
  final String endsAt;
}

/// Every requested day is listed, also closed or full ones (empty `slots`).
class SlotDay {
  const SlotDay({required this.date, required this.slots});
  factory SlotDay.fromJson(Json j) => SlotDay(date: j['date']! as String, slots: listOf(j['slots'], Slot.fromJson));
  final String date;
  final List<Slot> slots;
}

class ServiceSlots {
  const ServiceSlots({required this.serviceId, required this.timeZone, required this.days});
  factory ServiceSlots.fromJson(Json j) => ServiceSlots(
    serviceId: j['serviceId']! as String,
    timeZone: j['timeZone']! as String,
    days: listOf(j['days'], SlotDay.fromJson),
  );
  final String serviceId;
  final String timeZone;
  final List<SlotDay> days;
}

enum BookingStatus { confirmed, cancelled, completed }

class BookingDiscount {
  const BookingDiscount({
    required this.redemptionId,
    required this.discountPercent,
    required this.discountedPriceCents,
  });
  factory BookingDiscount.fromJson(Json j) => BookingDiscount(
    redemptionId: j['redemptionId'] as String?,
    discountPercent: toInt(j['discountPercent']),
    discountedPriceCents: toInt(j['discountedPriceCents']),
  );
  final String? redemptionId;
  final int discountPercent;
  final int discountedPriceCents;
}

class Booking {
  const Booking({
    required this.id,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.timeZone,
    required this.note,
    required this.priceCents,
    required this.priceIsFrom,
    required this.provider,
    required this.service,
    required this.dogs,
    required this.cancellable,
    required this.cancelUntil,
    required this.cancelledAt,
    required this.createdAt,
    this.discount,
  });

  factory Booking.fromJson(Json j) {
    final p = asJson(j['provider']);
    final s = asJson(j['service']);
    return Booking(
      id: j['id']! as String,
      status: BookingStatus.values.byName(j['status']! as String),
      startsAt: j['startsAt']! as String,
      endsAt: j['endsAt']! as String,
      timeZone: j['timeZone']! as String,
      note: j['note'] as String?,
      priceCents: toInt(j['priceCents']),
      priceIsFrom: j['priceIsFrom']! as bool,
      provider: (
        id: p['id']! as String,
        name: p['name']! as String,
        category: ServiceCategory.values.byName(p['category']! as String),
        area: p['area']! as String,
        address: p['address'] as String?,
      ),
      service: (id: s['id']! as String, name: s['name']! as String, durationMinutes: toInt(s['durationMinutes'])),
      dogs: [for (final d in asJsonList(j['dogs'])) (id: d['id']! as String, name: d['name']! as String)],
      cancellable: j['cancellable']! as bool,
      cancelUntil: j['cancelUntil']! as String,
      cancelledAt: j['cancelledAt'] as String?,
      createdAt: j['createdAt']! as String,
      discount: j['discount'] == null ? null : BookingDiscount.fromJson(asJson(j['discount'])),
    );
  }

  final String id;

  /// "completed" = confirmed and already over (derived by the server).
  final BookingStatus status;
  final String startsAt;
  final String endsAt;
  final String timeZone;
  final String? note;
  final int priceCents;
  final bool priceIsFrom;
  final ({String id, String name, ServiceCategory category, String area, String? address}) provider;
  final ({String id, String name, int durationMinutes}) service;
  final List<({String id, String name})> dogs;

  /// Whether "Tühista" is still allowed — the app does not redo the rule.
  final bool cancellable;
  final String cancelUntil;
  final String? cancelledAt;
  final String createdAt;
  final BookingDiscount? discount;
}
