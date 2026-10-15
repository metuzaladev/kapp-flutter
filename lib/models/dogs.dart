import 'json.dart';

enum DogSex { male, female }

/// Short-lived signed URLs (photos are private): `url` ~1600 px, `thumbnailUrl` ~400 px.
class ImageUrls {
  const ImageUrls({required this.url, required this.thumbnailUrl});
  factory ImageUrls.fromJson(Json j) => ImageUrls(url: j['url']! as String, thumbnailUrl: j['thumbnailUrl']! as String);
  final String url;
  final String thumbnailUrl;
}

class Dog {
  const Dog({
    required this.id,
    required this.name,
    required this.breed,
    required this.sex,
    required this.birthDate,
    required this.weightKg,
    required this.temperament,
    required this.profilePhoto,
  });

  factory Dog.fromJson(Json j) => Dog(
    id: j['id']! as String,
    name: j['name']! as String,
    breed: j['breed'] as String?,
    sex: j['sex'] == null ? null : DogSex.values.byName(j['sex']! as String),
    birthDate: j['birthDate'] as String?,
    weightKg: toDoubleOrNull(j['weightKg']),
    temperament: j['temperament'] as String?,
    profilePhoto: j['profilePhoto'] == null ? null : ImageUrls.fromJson(asJson(j['profilePhoto'])),
  );

  final String id;
  final String name;
  final String? breed;
  final DogSex? sex;
  final String? birthDate;
  final double? weightKg;
  final String? temperament;
  final ImageUrls? profilePhoto;
}

/// Upper bound per owner: protects the API and covers every real household.
const maxDogsPerUser = 10;

class DogPhoto extends ImageUrls {
  const DogPhoto({
    required super.url,
    required super.thumbnailUrl,
    required this.id,
    required this.caption,
    required this.createdAt,
  });
  factory DogPhoto.fromJson(Json j) => DogPhoto(
    url: j['url']! as String,
    thumbnailUrl: j['thumbnailUrl']! as String,
    id: j['id']! as String,
    caption: j['caption'] as String?,
    createdAt: j['createdAt']! as String,
  );
  final String id;
  final String? caption;
  final String createdAt;
}

/// Presigned upload: PUT the bytes to `url` with exactly these `headers`.
class PhotoUpload {
  const PhotoUpload({required this.uploadKey, required this.url, required this.headers, required this.expiresAt});
  factory PhotoUpload.fromJson(Json j) => PhotoUpload(
    uploadKey: j['uploadKey']! as String,
    url: j['url']! as String,
    headers: (j['headers']! as Map<String, Object?>).cast<String, String>(),
    expiresAt: j['expiresAt']! as String,
  );
  final String uploadKey;
  final String url;
  final Map<String, String> headers;
  final String expiresAt;
}

const maxPhotoBytes = 10 * 1024 * 1024;
const maxPhotosPerDog = 50;

enum HealthRecordKind {
  vaccination('vaccination'),
  vetVisit('vet_visit');

  const HealthRecordKind(this.wire);
  final String wire;
  static HealthRecordKind parse(String value) => values.firstWhere((k) => k.wire == value);
}

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.dogId,
    required this.kind,
    required this.title,
    required this.date,
    required this.nextDue,
    required this.clinic,
    required this.notes,
    required this.createdAt,
  });

  factory HealthRecord.fromJson(Json j) => HealthRecord(
    id: j['id']! as String,
    dogId: j['dogId']! as String,
    kind: HealthRecordKind.parse(j['kind']! as String),
    title: j['title']! as String,
    date: j['date']! as String,
    nextDue: j['nextDue'] as String?,
    clinic: j['clinic'] as String?,
    notes: j['notes'] as String?,
    createdAt: j['createdAt']! as String,
  );

  final String id;
  final String dogId;
  final HealthRecordKind kind;
  final String title;
  final String date;
  final String? nextDue;
  final String? clinic;
  final String? notes;
  final String createdAt;
}

/// GET /me/health-reminders — due within 30 days or overdue, across all own dogs.
class HealthReminder {
  const HealthReminder({
    required this.recordId,
    required this.dogId,
    required this.dogName,
    required this.kind,
    required this.title,
    required this.nextDue,
    required this.overdue,
  });

  factory HealthReminder.fromJson(Json j) {
    final dog = asJson(j['dog']);
    return HealthReminder(
      recordId: j['recordId']! as String,
      dogId: dog['id']! as String,
      dogName: dog['name']! as String,
      kind: HealthRecordKind.parse(j['kind']! as String),
      title: j['title']! as String,
      nextDue: j['nextDue']! as String,
      overdue: j['overdue']! as bool,
    );
  }

  final String recordId;
  final String dogId;
  final String dogName;
  final HealthRecordKind kind;
  final String title;
  final String nextDue;
  final bool overdue;
}
