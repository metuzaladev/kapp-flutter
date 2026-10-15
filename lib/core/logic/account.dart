import '../../models/profile.dart';
import 'legal.dart';

/// Pure rules behind the M10 account screens (docs/17), kept out of the widgets so they can be
/// unit-tested.

/// How deletion is confirmed: the password, or (Apple/Google accounts) a fresh sign-in.
enum ReauthMode { password, signIn }

ReauthMode reauthMode(Profile profile) => profile.hasPassword ? ReauthMode.password : ReauthMode.signIn;

/// The DELETE /me body: a password account sends the password, a social account `{}`.
Map<String, Object> deleteAccountBody(ReauthMode mode, String password) =>
    mode == ReauthMode.password ? {'password': password} : {};

/// The submit button is enabled once the chosen confirmation is possible (the dialog confirms again).
bool canRequestDeletion(ReauthMode mode, String password) => mode == ReauthMode.signIn || password.isNotEmpty;

/// After DELETE /me fails with these, the account is already gone: sign out locally like a success.
bool deletionMeansGone(int status) => status == 401 || status == 404;

/// The blocking consent sheet appears when the stored versions are not the current ones.
bool needsLegalAcceptance(Profile? profile) => profile != null && !legalAcceptanceCurrent(profile.legal);

enum LegalConsentKind { newConsent, updated }

/// First acceptance (social sign-up, accounts older than M10) or a changed text.
LegalConsentKind legalConsentKind(Profile profile) =>
    profile.legal.termsVersion == null && profile.legal.privacyVersion == null
    ? LegalConsentKind.newConsent
    : LegalConsentKind.updated;

Map<String, String> currentLegalVersions() => {
  'termsVersion': legalVersions.terms,
  'privacyVersion': legalVersions.privacy,
};
