import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_client.dart';
import '../config.dart';
import '../i18n/i18n.dart';

/// The only place in the app that talks to our REST API.
/// Why: base URL, session cookie, language, timeout and the `{ error, message }` contract are handled
/// once, so screens only deal with data or an [ApiRequestError] whose message is safe to show.
class ApiRequestError implements Exception {
  const ApiRequestError(this.message, this.status);

  final String message;

  /// HTTP status; 0 = network down, DNS failure or timeout.
  final int status;

  @override
  String toString() => 'ApiRequestError($status): $message';
}

const _timeout = Duration(seconds: 10);
const String apiBaseUrl = '$apiOrigin/api/v1';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static final ApiClient instance = ApiClient();

  final http.Client _client;

  Uri uri(String path, [Map<String, Object?>? params]) {
    final base = Uri.parse('$apiBaseUrl$path');
    if (params == null || params.isEmpty) return base;
    return base.replace(
      queryParameters: {
        for (final e in params.entries)
          if (e.value != null) e.key: '${e.value}',
      },
    );
  }

  Future<T> request<T>(String method, String path, {Object? body, Map<String, Object?>? params}) async {
    // The API translates error messages per Accept-Language, so they match the app's language.
    final headers = <String, String>{'accept': 'application/json', 'accept-language': currentLanguage().name};
    final cookie = await AuthClient.instance.cookieHeader();
    if (cookie.isNotEmpty) headers['cookie'] = cookie;
    if (body != null) headers['content-type'] = 'application/json';

    final http.Response res;
    try {
      final req = http.Request(method, uri(path, params))..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _client.send(req).timeout(_timeout)).timeout(_timeout);
    } catch (e) {
      // Network down, DNS failure or timeout — the "Offline State" screen in Figma covers this.
      throw ApiRequestError(tr('errors.network'), 0);
    }

    Object? data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // A protected endpoint answering 401 means the session ended on the server: re-check it, so
      // the router can take the user back to the sign-in screens.
      if (res.statusCode == 401) unawaited(AuthClient.instance.refreshSession());
      final message = data is Map && data['error'] == true && data['message'] is String
          ? data['message'] as String
          : null;
      throw ApiRequestError(message ?? tr('errors.unknown'), res.statusCode);
    }
    return data as T;
  }

  Future<T> get<T>(String path, [Map<String, Object?>? params]) => request<T>('GET', path, params: params);

  Future<T> send<T>(String method, String path, [Object? body]) => request<T>(method, path, body: body);
}

Future<T> apiGet<T>(String path, [Map<String, Object?>? params]) => ApiClient.instance.get<T>(path, params);

Future<T> apiSend<T>(String method, String path, [Object? body]) => ApiClient.instance.send<T>(method, path, body);

/// A user-facing message for any error.
String errorMessage(Object? error) {
  if (error is ApiRequestError) return error.message;
  // Unexpected (programming) errors: show the cause in debug builds only.
  return kDebugMode ? tr('errors.genericDev', params: {'detail': '$error'}) : tr('errors.generic');
}
