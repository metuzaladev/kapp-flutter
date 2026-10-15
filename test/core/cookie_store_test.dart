import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/core/auth/cookie_store.dart';

void main() {
  final now = DateTime.utc(2026, 10, 2, 12);

  test('splits combined Set-Cookie headers without breaking Expires dates', () {
    const header =
        'kapp.session_token=abc; Path=/; Expires=Wed, 21 Oct 2026 07:28:00 GMT; HttpOnly, kapp.session_data=xyz; Max-Age=300';
    expect(splitSetCookieHeader(header), hasLength(2));
  });

  test('stores cookies with their expiry and builds the cookie header', () {
    final stored = applySetCookie('kapp.session_token=abc; Max-Age=3600, other=1', null, now: now);
    expect(cookieHeader(stored, now: now), 'kapp.session_token=abc; other=1');
    // An hour later the token has expired and is not sent.
    expect(cookieHeader(stored, now: now.add(const Duration(hours: 2))), 'other=1');
  });

  test('Max-Age=0 or a past Expires deletes a cookie', () {
    var stored = applySetCookie('kapp.session_token=abc', null, now: now);
    stored = applySetCookie('kapp.session_token=; Max-Age=0', stored, now: now);
    expect(cookieHeader(stored, now: now), '');
    stored = applySetCookie('a=1', null, now: now);
    stored = applySetCookie('a=1; Expires=Thu, 01 Jan 2020 00:00:00 GMT', stored, now: now);
    expect(cookieHeader(stored, now: now), '');
  });

  test('recognises Better Auth cookies and session changes', () {
    expect(hasAuthCookies('__Secure-kapp.session_token=1', 'kapp'), isTrue);
    expect(hasAuthCookies('_ga=1', 'kapp'), isFalse);
    final a = applySetCookie('kapp.session_token=one', null, now: now);
    final b = applySetCookie('kapp.session_token=one; Max-Age=999', a, now: now);
    final c = applySetCookie('kapp.session_token=two', a, now: now);
    expect(sessionCookieChanged(a, b), isFalse);
    expect(sessionCookieChanged(a, c), isTrue);
  });
}
