import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../state/onboarding.dart';
import '../config.dart';
import '../i18n/i18n.dart';
import 'cookie_store.dart';

/// The signed-in user as Better Auth's get-session returns it.
@immutable
class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});

  factory AuthUser.fromJson(Map<String, Object?> json) =>
      AuthUser(id: json['id']! as String, name: (json['name'] ?? '') as String, email: (json['email'] ?? '') as String);

  final String id;
  final String name;
  final String email;
}

@immutable
class AuthSession {
  const AuthSession({required this.user, required this.expiresAt});

  static AuthSession? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final user = json['user'];
    final session = json['session'];
    if (user is! Map<String, Object?> || session is! Map<String, Object?> || user['id'] is! String) return null;
    final expires = DateTime.tryParse('${session['expiresAt']}');
    return AuthSession(user: AuthUser.fromJson(user), expiresAt: expires);
  }

  final AuthUser user;
  final DateTime? expiresAt;
}

/// `isPending` until the stored session has been checked (the splash stays up meanwhile).
@immutable
class AuthState {
  const AuthState({this.session, this.isPending = false});
  final AuthSession? session;
  final bool isPending;
  bool get signedIn => session != null;
}

/// Result of a Better Auth call: our API rewrites every auth error to `{ error: true, message }` in
/// the Accept-Language we send, so `error` is already user-facing.
@immutable
class AuthResult {
  const AuthResult({this.data, this.error});
  final Object? data;
  final String? error;
  bool get ok => error == null;
}

/// Better Auth client (port of `better-auth/react` + `@better-auth/expo/client`).
///
/// - The session cookie lives in the Keychain/Keystore ([CookieStore]) and is attached manually,
///   exactly like the Expo plugin does, with `expo-origin: kapp://` so the server's origin check
///   accepts the request (`trustedOrigins` contains `kapp://`).
/// - The last session is cached in secure storage too, so a cold start offline still opens the app.
class AuthClient extends ValueNotifier<AuthState> {
  AuthClient({http.Client? client, CookieStore? cookies, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _cookies = cookies ?? CookieStore(),
      _storage = storage ?? const FlutterSecureStorage(),
      super(const AuthState(isPending: true));

  static final AuthClient instance = AuthClient();

  static const _sessionCacheKey = 'kapp_session_data';
  static const _basePath = '/api/v1/auth';

  final http.Client _client;
  final CookieStore _cookies;
  final FlutterSecureStorage _storage;

  /// Called on sign-out, before the cookie is dropped (push token removal needs the session).
  final List<Future<void> Function()> beforeSignOut = [];

  Future<String> cookieHeader() => _cookies.header();

  /// Restores the cached session (offline start). With a cached session the app opens at once and
  /// the server is asked in the background; without one the first screen waits for the answer, so a
  /// signed-in user never sees Welcome flash.
  Future<void> init() async {
    AuthSession? cached;
    try {
      cached = AuthSession.fromJson(jsonDecode(await _storage.read(key: _sessionCacheKey) ?? 'null'));
    } catch (_) {}
    if (cached != null && (cached.expiresAt?.isAfter(DateTime.now()) ?? false)) {
      value = AuthState(session: cached);
      unawaited(refreshSession());
      return;
    }
    await refreshSession();
  }

  /// GET get-session. A network failure keeps the current (cached) state.
  Future<void> refreshSession() async {
    final result = await _call('GET', '/get-session');
    // Offline or a server error: keep the current (cached) session instead of signing out.
    if (!result.ok) {
      value = AuthState(session: value.session);
      return;
    }
    final session = AuthSession.fromJson(result.data);
    value = AuthState(session: session);
    try {
      await _storage.write(key: _sessionCacheKey, value: jsonEncode(result.data));
    } catch (_) {}
  }

  Future<AuthResult> signInEmail({required String email, required String password}) =>
      _signIn('/sign-in/email', {'email': email, 'password': password});

  /// `extra`: M10 legal versions and the app language (Better Auth additionalFields).
  Future<AuthResult> signUpEmail({
    required String name,
    required String email,
    required String password,
    Map<String, Object?> extra = const {},
  }) => _signIn('/sign-up/email', {'name': name, 'email': email, 'password': password, ...extra});

  /// Apple: the identity token from the native sheet, verified by Better Auth.
  Future<AuthResult> signInWithIdToken({required String provider, required String token}) =>
      _signIn('/sign-in/social', {
        'provider': provider,
        'idToken': {'token': token},
      }, idToken: true);

  /// Starts a browser sign-in (Google). Returns the authorization URL to open, or an error.
  Future<AuthResult> socialAuthorizationUrl(String provider) async {
    final result = await _call('POST', '/sign-in/social', body: {'provider': provider, 'callbackURL': '$appScheme://'});
    if (!result.ok) return result;
    final data = result.data;
    final url = data is Map ? data['url'] : null;
    if (url is! String) return AuthResult(error: tr('errors.generic'));
    // The Expo proxy endpoint sets the OAuth state cookie on the browser before redirecting.
    final proxy = Uri.parse('$apiOrigin$_basePath/expo-authorization-proxy')
        .replace(queryParameters: {'authorizationURL': url});
    return AuthResult(data: proxy.toString());
  }

  /// After the browser returns to `kapp://?cookie=…` (the Expo server plugin adds the cookie).
  Future<void> completeBrowserSignIn(Uri callback) async {
    final cookie = callback.queryParameters['cookie'];
    if (cookie == null) return;
    await _cookies.apply(cookie);
    await refreshSession();
  }

  Future<AuthResult> requestPasswordReset({required String email, required String redirectTo}) =>
      _call('POST', '/request-password-reset', body: {'email': email, 'redirectTo': redirectTo});

  Future<AuthResult> resetPassword({required String token, required String newPassword}) =>
      _call('POST', '/reset-password', body: {'token': token, 'newPassword': newPassword});

  Future<void> signOut() async {
    for (final hook in beforeSignOut) {
      try {
        await hook();
      } catch (_) {}
    }
    await _call('POST', '/sign-out', body: const {});
    await _cookies.clear();
    try {
      await _storage.write(key: _sessionCacheKey, value: '{}');
    } catch (_) {}
    value = const AuthState();
  }

  /// Local sign-out without a request (the account is already gone on the server).
  Future<void> forgetSession() async {
    await _cookies.clear();
    try {
      await _storage.write(key: _sessionCacheKey, value: '{}');
    } catch (_) {}
    value = const AuthState();
  }

  Future<AuthResult> _signIn(String path, Map<String, Object?> body, {bool idToken = false}) async {
    final result = await _call('POST', path, body: body, idToken: idToken);
    if (result.ok) {
      // A server-confirmed account on this device: it no longer needs the intro after signing out.
      if (confirmsAccount(result.data)) unawaited(OnboardingStore.instance.markSeen());
      await refreshSession();
    }
    return result;
  }

  Future<AuthResult> _call(String method, String path, {Object? body, bool idToken = false}) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'accept-language': currentLanguage().name,
      'x-skip-oauth-proxy': 'true',
    };
    // Like the Expo plugin: an idToken sign-in sends no cookie and no origin override.
    if (!idToken) {
      final cookie = await _cookies.header();
      if (cookie.isNotEmpty) headers['cookie'] = cookie;
      headers['expo-origin'] = '$appScheme://';
    }
    if (body != null) headers['content-type'] = 'application/json';

    http.Response res;
    try {
      final req = http.Request(method, Uri.parse('$apiOrigin$_basePath$path'))..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 15)));
    } catch (_) {
      return AuthResult(error: tr('errors.network'));
    }

    final setCookie = res.headers['set-cookie'];
    if (setCookie != null && hasAuthCookies(setCookie, appScheme)) await _cookies.apply(setCookie);

    Object? data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300) return AuthResult(data: data);
    final message = data is Map && data['message'] is String ? data['message'] as String : null;
    return AuthResult(data: null, error: message ?? tr('errors.generic'));
  }
}
