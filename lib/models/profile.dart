import '../core/i18n/i18n.dart';
import 'json.dart';

enum PresenceSharing { nobody, friends, everyone }

class LegalAcceptance {
  const LegalAcceptance({required this.termsVersion, required this.privacyVersion, required this.acceptedAt});
  factory LegalAcceptance.fromJson(Json j) => LegalAcceptance(
    termsVersion: j['termsVersion'] as String?,
    privacyVersion: j['privacyVersion'] as String?,
    acceptedAt: j['acceptedAt'] as String?,
  );
  final String? termsVersion;
  final String? privacyVersion;
  final String? acceptedAt;
}

/// What the signed-in user sees about themselves (GET /me).
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.email,
    required this.image,
    required this.area,
    required this.bio,
    required this.presenceSharing,
    required this.allowFriendRequests,
    required this.language,
    required this.emailVerified,
    required this.hasPassword,
    required this.legal,
  });

  factory Profile.fromJson(Json j) => Profile(
    id: j['id']! as String,
    name: j['name']! as String,
    email: j['email']! as String,
    image: j['image'] as String?,
    area: j['area'] as String?,
    bio: j['bio'] as String?,
    presenceSharing: PresenceSharing.values.byName(j['presenceSharing']! as String),
    allowFriendRequests: j['allowFriendRequests']! as bool,
    language: Language.tryParse(j['language'] as String?) ?? defaultLanguage,
    emailVerified: j['emailVerified']! as bool,
    hasPassword: j['hasPassword']! as bool,
    legal: LegalAcceptance.fromJson(asJson(j['legal'])),
  );

  final String id;
  final String name;
  final String email;
  final String? image;
  final String? area;
  final String? bio;
  final PresenceSharing presenceSharing;

  /// Settings / Privacy "Luba sõbrakutseid". (M5)
  final bool allowFriendRequests;
  final Language language;

  /// M10: false until the user opens the link in the confirmation email.
  final bool emailVerified;

  /// M10: an email + password account confirms deletion with the password.
  final bool hasPassword;
  final LegalAcceptance legal;

  Profile copyWith({LegalAcceptance? legal}) => Profile(
    id: id,
    name: name,
    email: email,
    image: image,
    area: area,
    bio: bio,
    presenceSharing: presenceSharing,
    allowFriendRequests: allowFriendRequests,
    language: language,
    emailVerified: emailVerified,
    hasPassword: hasPassword,
    legal: legal ?? this.legal,
  );
}
