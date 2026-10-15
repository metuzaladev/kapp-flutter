import 'package:flutter/foundation.dart';

import '../core/storage/preferences.dart';

/// "Has this device seen the intro?" (Figma Onboarding / Discover + Connect, shown once).
///
/// SharedPreferences, not the Keychain: the flag is not secret, and a Keychain item would survive an
/// app reinstall, so a fresh install would wrongly skip the intro. Per device, not per account.
const onboardingStorageKey = 'kapp.onboardingSeen';
const _seen = '1';

class OnboardingStore extends ValueNotifier<bool?> {
  OnboardingStore(this._storage) : super(null);

  final PreferenceStorage _storage;

  static final OnboardingStore instance = OnboardingStore(const SharedPreferenceStorage());

  /// Reads the stored flag once; returns whether the intro was already seen. Never throws.
  Future<bool> load() async {
    try {
      value = await _storage.getItem(onboardingStorageKey) == _seen;
    } catch (_) {
      // Unreadable storage: treat as seen. Showing the intro on every launch would be worse.
      value = true;
    }
    return value == true;
  }

  /// Marks the intro as seen for this session immediately and persists it best-effort.
  Future<void> markSeen() async {
    value = true;
    try {
      await _storage.setItem(onboardingStorageKey, _seen);
    } catch (_) {
      // At worst the intro shows once more after a restart.
    }
  }
}

/// Whether an auth API response body proves this device has a signed-in account: sign-in/sign-up
/// return `{ user, token }`, get-session `{ user, session }` or `null`.
bool confirmsAccount(Object? body) {
  if (body is! Map) return false;
  final user = body['user'];
  return user is Map && user['id'] is String;
}
