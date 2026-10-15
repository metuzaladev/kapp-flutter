import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The Better Auth session cookie, kept in the iOS Keychain / Android Keystore — never in
/// SharedPreferences, which is unencrypted.
///
/// Same format and rules as `@better-auth/expo` (`getSetCookie` / `getCookie`): a JSON map of cookie
/// name → `{ value, expires }`; `Max-Age<=0` or a past `Expires` deletes a cookie; expired cookies are
/// never sent.
class StoredCookie {
  const StoredCookie(this.value, this.expires);
  final String value;
  final DateTime? expires;

  Map<String, Object?> toJson() => {'value': value, 'expires': expires?.toUtc().toIso8601String()};
}

/// Splits a combined Set-Cookie header into single cookies. Commas also appear inside `Expires`
/// dates ("Wed, 21 Oct 2026 …"), so a comma only separates cookies when a `name=` follows it.
List<String> splitSetCookieHeader(String header) {
  final parts = <String>[];
  var start = 0;
  final separator = RegExp(r',\s*(?=[^;,\s=]+=)');
  for (final match in separator.allMatches(header)) {
    // A comma right after "Expires=Wed" belongs to the date.
    final before = header.substring(start, match.start);
    if (RegExp(r'expires=\w{3}$', caseSensitive: false).hasMatch(before.trimRight())) continue;
    parts.add(before.trim());
    start = match.end;
  }
  parts.add(header.substring(start).trim());
  return parts.where((p) => p.isNotEmpty).toList();
}

/// Applies a Set-Cookie header to the stored map (JSON string in, JSON string out).
String applySetCookie(String header, String? previous, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final cookies = <String, Object?>{...?(_decode(previous))};
  for (final raw in splitSetCookieHeader(header)) {
    final segments = raw.split(';').map((s) => s.trim()).toList();
    final eq = segments.first.indexOf('=');
    if (eq <= 0) continue;
    final name = segments.first.substring(0, eq).trim();
    final value = segments.first.substring(eq + 1).trim();
    DateTime? expires;
    int? maxAge;
    for (final attr in segments.skip(1)) {
      final i = attr.indexOf('=');
      final key = (i == -1 ? attr : attr.substring(0, i)).trim().toLowerCase();
      final v = i == -1 ? '' : attr.substring(i + 1).trim();
      if (key == 'max-age') maxAge = int.tryParse(v);
      if (key == 'expires') expires = _parseHttpDate(v);
    }
    if (maxAge != null && maxAge <= 0) {
      cookies.remove(name);
      continue;
    }
    final until = maxAge != null ? at.add(Duration(seconds: maxAge)) : expires;
    if (until != null && !until.isAfter(at)) {
      cookies.remove(name);
      continue;
    }
    cookies[name] = StoredCookie(value, until).toJson();
  }
  return jsonEncode(cookies);
}

/// The `cookie` request header from the stored map; expired cookies are left out.
String cookieHeader(String? stored, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final parts = <String>[];
  (_decode(stored) ?? const {}).forEach((name, raw) {
    if (raw is! Map) return;
    final expires = raw['expires'] is String ? DateTime.tryParse(raw['expires'] as String) : null;
    if (expires != null && expires.isBefore(at)) return;
    parts.add('$name=${raw['value']}');
  });
  return parts.join('; ');
}

/// Whether a Set-Cookie header carries Better Auth cookies (prefix `kapp`, also `__Secure-kapp`).
bool hasAuthCookies(String header, String prefix) => splitSetCookieHeader(header).any((c) {
  final name = c.split('=').first.trim().replaceFirst('__Secure-', '');
  return name.startsWith(prefix);
});

/// Session token or data changed (expiry refreshes alone do not count).
bool sessionCookieChanged(String? previous, String next) {
  final a = _decode(previous) ?? const {};
  final b = _decode(next) ?? const {};
  final keys = {...a.keys, ...b.keys}.where((k) => k.contains('session_token') || k.contains('session_data'));
  for (final k in keys) {
    if ((a[k] as Map?)?['value'] != (b[k] as Map?)?['value']) return true;
  }
  return false;
}

Map<String, Object?>? _decode(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final v = jsonDecode(json);
    return v is Map<String, Object?> ? v : null;
  } catch (_) {
    return null;
  }
}

DateTime? _parseHttpDate(String value) {
  try {
    return HttpDateParser.parse(value);
  } catch (_) {
    return null;
  }
}

/// RFC 1123 dates ("Wed, 21 Oct 2026 07:28:00 GMT") without dart:io, so this file stays testable.
class HttpDateParser {
  static const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

  static DateTime parse(String value) {
    final m = RegExp(r'(\d{1,2})[ -](\w{3})[ -](\d{2,4}) (\d{2}):(\d{2}):(\d{2})').firstMatch(value);
    if (m == null) throw FormatException('Not an HTTP date: $value');
    var year = int.parse(m.group(3)!);
    if (year < 100) year += 2000;
    final month = _months.indexOf(m.group(2)!.toLowerCase()) + 1;
    if (month == 0) throw FormatException('Not an HTTP date: $value');
    return DateTime.utc(
      year,
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  }
}

/// Secure storage of the cookie map; a Keychain failure must not break public endpoints.
class CookieStore {
  CookieStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'kapp_cookie';
  final FlutterSecureStorage _storage;
  String? _cache;
  bool _loaded = false;

  Future<String?> read() async {
    if (_loaded) return _cache;
    try {
      _cache = await _storage.read(key: _key);
    } catch (e) {
      debugPrint('Could not read the session cookie: $e');
    }
    _loaded = true;
    return _cache;
  }

  Future<String> header() async => cookieHeader(await read());

  /// Stores a Set-Cookie header; returns whether the session itself changed.
  Future<bool> apply(String setCookie) async {
    final previous = await read();
    final next = applySetCookie(setCookie, previous);
    _cache = next;
    try {
      await _storage.write(key: _key, value: next);
    } catch (e) {
      debugPrint('Could not save the session cookie: $e');
    }
    return sessionCookieChanged(previous, next);
  }

  Future<void> clear() async {
    _cache = '{}';
    _loaded = true;
    try {
      await _storage.write(key: _key, value: '{}');
    } catch (_) {}
  }
}
