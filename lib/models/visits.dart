import 'json.dart';

const checkInDurations = [30, 60, 90, 120];
const planMaxDaysAhead = 30;
const planMaxHours = 4;

class DogSummary {
  const DogSummary({required this.id, required this.name, required this.breed});
  factory DogSummary.fromJson(Json j) =>
      DogSummary(id: j['id']! as String, name: j['name']! as String, breed: j['breed'] as String?);
  final String id;
  final String name;
  final String? breed;
}

class ParkRef {
  const ParkRef({required this.id, required this.name});
  factory ParkRef.fromJson(Json j) => ParkRef(id: j['id']! as String, name: j['name']! as String);
  final String id;
  final String name;
}

class ActiveCheckIn {
  const ActiveCheckIn({
    required this.id,
    required this.park,
    required this.dogs,
    required this.startedAt,
    required this.expiresAt,
  });
  factory ActiveCheckIn.fromJson(Json j) => ActiveCheckIn(
    id: j['id']! as String,
    park: ParkRef.fromJson(asJson(j['park'])),
    dogs: listOf(j['dogs'], DogSummary.fromJson),
    startedAt: j['startedAt']! as String,
    expiresAt: j['expiresAt']! as String,
  );
  final String id;
  final ParkRef park;
  final List<DogSummary> dogs;
  final String startedAt;
  final String expiresAt;
}

/// Someone currently in a park, as the viewer is allowed to see them.
class ParkVisitor {
  const ParkVisitor({
    required this.checkInId,
    required this.userId,
    required this.isMe,
    required this.ownerFirstName,
    required this.dogs,
    required this.until,
  });
  factory ParkVisitor.fromJson(Json j) => ParkVisitor(
    checkInId: j['checkInId']! as String,
    userId: j['userId']! as String,
    isMe: j['isMe']! as bool,
    ownerFirstName: j['ownerFirstName']! as String,
    dogs: listOf(j['dogs'], DogSummary.fromJson),
    until: j['until']! as String,
  );
  final String checkInId;
  final String userId;
  final bool isMe;
  final String ownerFirstName;
  final List<DogSummary> dogs;
  final String until;
}

class ParkVisitors {
  const ParkVisitors({required this.visitors, required this.hiddenDogs});
  factory ParkVisitors.fromJson(Json j) =>
      ParkVisitors(visitors: listOf(j['visitors'], ParkVisitor.fromJson), hiddenDogs: toInt(j['hiddenDogs']));
  final List<ParkVisitor> visitors;

  /// Dogs of people who do not share their presence with the viewer — counted, never named.
  final int hiddenDogs;
}

class VisitHistoryItem {
  const VisitHistoryItem({
    required this.id,
    required this.park,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
    required this.dogs,
    required this.hasReview,
  });
  factory VisitHistoryItem.fromJson(Json j) => VisitHistoryItem(
    id: j['id']! as String,
    park: ParkRef.fromJson(asJson(j['park'])),
    startedAt: j['startedAt']! as String,
    endedAt: j['endedAt']! as String,
    durationMinutes: toInt(j['durationMinutes']),
    dogs: listOf(j['dogs'], DogSummary.fromJson),
    hasReview: j['hasReview']! as bool,
  );
  final String id;
  final ParkRef park;
  final String startedAt;
  final String endedAt;
  final int durationMinutes;
  final List<DogSummary> dogs;
  final bool hasReview;
}

class PlannedVisit {
  const PlannedVisit({
    required this.id,
    required this.park,
    required this.startsAt,
    required this.endsAt,
    required this.note,
  });
  factory PlannedVisit.fromJson(Json j) => PlannedVisit(
    id: j['id']! as String,
    park: ParkRef.fromJson(asJson(j['park'])),
    startsAt: j['startsAt']! as String,
    endsAt: j['endsAt']! as String,
    note: j['note'] as String?,
  );
  final String id;
  final ParkRef park;
  final String startsAt;
  final String endsAt;
  final String? note;
}

class Review {
  const Review({
    required this.id,
    required this.authorFirstName,
    required this.rating,
    required this.body,
    required this.createdAt,
  });
  factory Review.fromJson(Json j) => Review(
    id: j['id']! as String,
    authorFirstName: j['authorFirstName']! as String,
    rating: toInt(j['rating']),
    body: j['body'] as String?,
    createdAt: j['createdAt']! as String,
  );
  final String id;
  final String authorFirstName;
  final int rating;
  final String? body;
  final String createdAt;
}
