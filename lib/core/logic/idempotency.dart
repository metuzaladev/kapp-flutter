import 'dart:math' as math;

/// Idempotency keys for "Lunasta" (POST /me/redemptions, docs/16). The server returns the first
/// redemption when it sees a key again, so the app must:
/// - make a new key once per user tap (one tap = one intended redemption);
/// - keep the same key while the outcome is unknown (network error, timeout, 5xx);
/// - forget it after an answer that settles the tap (success, or a 4xx such as 409 "not enough paws").

/// RFC 4122 version 4 UUID (the API validates `z.uuid()`).
String uuidV4([int Function()? randomByte]) {
  final random = math.Random.secure();
  final next = randomByte ?? () => random.nextInt(256);
  final bytes = List<int>.generate(16, (_) => next() & 0xff);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class IdempotencyTracker {
  IdempotencyTracker([String Function()? makeKey]) : _makeKey = makeKey ?? uuidV4;

  final String Function() _makeKey;
  String? _key;

  /// The key for this attempt: the pending one (a retry) or a new one.
  String begin() => _key ??= _makeKey();

  /// Call with the outcome; `retryable` keeps the key for the next attempt.
  void settle({required bool retryable}) {
    if (!retryable) _key = null;
  }

  /// The key waiting for a retry, if any.
  String? get pending => _key;
}

/// Whether a failed request may have reached the server: network/timeout (status 0) and 5xx.
bool isRetryableStatus(int? status) => status == null || status == 0 || status >= 500;
