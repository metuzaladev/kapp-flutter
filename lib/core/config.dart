/// Runtime configuration from `--dart-define` values (compiled into the app — never put secrets here).
///
/// `flutter run --dart-define=API_URL=http://192.168.1.10:3000` on a physical phone; the default
/// works in the iOS simulator against `npm run dev:api` in the ICD0018-kapp repository.
const String apiOrigin = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');

/// Must match the API's APP_SCHEME (trusted origin for auth) and the iOS/Android URL scheme.
const String appScheme = 'kapp';

/// Social sign-in buttons appear only when the API has the matching credentials configured.
const bool authAppleEnabled = bool.fromEnvironment('AUTH_APPLE');
const bool authGoogleEnabled = bool.fromEnvironment('AUTH_GOOGLE');
