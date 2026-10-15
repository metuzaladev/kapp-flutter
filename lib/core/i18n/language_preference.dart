import 'package:flutter/foundation.dart';

import '../storage/preferences.dart';
import 'i18n.dart';

/// The language picker in Settings: "automaatne" follows the device, or a fixed language.
///
/// Stored with SharedPreferences, not the Keychain: the choice is not secret, and a Keychain item
/// would outlive an app reinstall. Per device, not per account, so it also applies on the sign-in
/// screens.
sealed class LanguagePreference {
  const LanguagePreference();
}

class AutoLanguage extends LanguagePreference {
  const AutoLanguage();

  @override
  bool operator ==(Object other) => other is AutoLanguage;

  @override
  int get hashCode => 0;
}

class FixedLanguage extends LanguagePreference {
  const FixedLanguage(this.language);
  final Language language;

  @override
  bool operator ==(Object other) => other is FixedLanguage && other.language == language;

  @override
  int get hashCode => language.hashCode;
}

const languageStorageKey = 'kapp.language';

class LanguagePreferenceStore extends ValueNotifier<LanguagePreference> {
  LanguagePreferenceStore(this._storage, {Language Function()? deviceLanguage})
    : _deviceLanguage = deviceLanguage ?? I18n.deviceLanguage,
      super(const AutoLanguage());

  final PreferenceStorage _storage;
  final Language Function() _deviceLanguage;

  static final LanguagePreferenceStore instance = LanguagePreferenceStore(const SharedPreferenceStorage());

  Language get resolved => switch (value) {
    AutoLanguage() => _deviceLanguage(),
    FixedLanguage(:final language) => language,
  };

  void _apply() => I18n.instance.setLanguage(resolved);

  /// Reads the stored choice before the first screen renders; a storage failure means "automatic".
  Future<void> load() async {
    try {
      final stored = Language.tryParse(await _storage.getItem(languageStorageKey));
      if (stored != null) value = FixedLanguage(stored);
    } catch (e) {
      debugPrint('Could not read the language preference: $e');
    }
    _apply();
  }

  Future<void> set(LanguagePreference next) async {
    value = next;
    _apply();
    try {
      switch (next) {
        case AutoLanguage():
          await _storage.removeItem(languageStorageKey);
        case FixedLanguage(:final language):
          await _storage.setItem(languageStorageKey, language.name);
      }
    } catch (e) {
      // The change still applies for this session.
      debugPrint('Could not save the language preference: $e');
    }
  }

  /// Android lets the user change the device (or per-app) language without restarting the app, so
  /// "automatic" is re-evaluated whenever the app returns to the foreground.
  void onResumed() {
    if (value is AutoLanguage) _apply();
  }
}
