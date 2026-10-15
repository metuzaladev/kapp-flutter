import 'package:shared_preferences/shared_preferences.dart';

/// The part of a key-value store the preference stores need; injected so tests can simulate
/// failures. Backed by SharedPreferences (UserDefaults / SharedPreferences): the choices are not
/// secret, and unlike the Keychain they do not survive an app reinstall (docs/11).
abstract class PreferenceStorage {
  Future<String?> getItem(String key);
  Future<void> setItem(String key, String value);
  Future<void> removeItem(String key);
}

class SharedPreferenceStorage implements PreferenceStorage {
  const SharedPreferenceStorage();

  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  @override
  Future<String?> getItem(String key) => _prefs.getString(key);

  @override
  Future<void> setItem(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> removeItem(String key) => _prefs.remove(key);
}

/// In-memory storage for tests.
class MemoryPreferenceStorage implements PreferenceStorage {
  MemoryPreferenceStorage([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> getItem(String key) async {
    if (failReads) throw StateError('read failed');
    return values[key];
  }

  @override
  Future<void> setItem(String key, String value) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }

  @override
  Future<void> removeItem(String key) async {
    if (failWrites) throw StateError('write failed');
    values.remove(key);
  }
}
