import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/core/i18n/i18n.dart';
import 'package:kapp/core/i18n/language_preference.dart';
import 'package:kapp/core/storage/preferences.dart';
import 'package:kapp/router.dart';
import 'package:kapp/state/appearance.dart';
import 'package:kapp/state/onboarding.dart';

void main() {
  group('onboarding flag', () {
    test('unseen until marked, persisted, and seen when storage fails', () async {
      final storage = MemoryPreferenceStorage();
      final store = OnboardingStore(storage);
      expect(store.value, isNull);
      expect(await store.load(), isFalse);
      await store.markSeen();
      expect(await OnboardingStore(storage).load(), isTrue);
      final broken = MemoryPreferenceStorage()..failReads = true;
      expect(await OnboardingStore(broken).load(), isTrue);
    });

    test('confirmsAccount only for a real user in the auth answer', () {
      expect(
        confirmsAccount({
          'user': {'id': 'u1'},
          'token': 't',
        }),
        isTrue,
      );
      expect(confirmsAccount({'user': null}), isFalse);
      expect(confirmsAccount(null), isFalse);
    });
  });

  group('appearance', () {
    test('defaults to light, survives a restart, ignores junk and storage failures', () async {
      final storage = MemoryPreferenceStorage();
      expect(await AppearanceStore(storage).load(), AppearancePreference.light);
      await AppearanceStore(storage).set(AppearancePreference.dark);
      expect(await AppearanceStore(storage).load(), AppearancePreference.dark);
      expect(
        await AppearanceStore(MemoryPreferenceStorage({appearanceStorageKey: 'neon'})).load(),
        AppearancePreference.light,
      );
      final broken = MemoryPreferenceStorage()..failWrites = true;
      final store = AppearanceStore(broken);
      await store.set(AppearancePreference.system);
      expect(store.value.themeMode, ThemeMode.system);
    });
  });

  group('language preference', () {
    test('"automatic" follows the device, a fixed language is stored', () async {
      final storage = MemoryPreferenceStorage();
      final store = LanguagePreferenceStore(storage, deviceLanguage: () => Language.ru);
      await store.load();
      expect(store.value, const AutoLanguage());
      expect(I18n.instance.language, Language.ru);
      await store.set(const FixedLanguage(Language.en));
      expect(storage.values[languageStorageKey], 'en');
      expect(I18n.instance.language, Language.en);
      await store.set(const AutoLanguage());
      expect(storage.values.containsKey(languageStorageKey), isFalse);
      I18n.instance.setLanguage(Language.et);
    });

    test('device locale tags match by their primary subtag', () {
      expect(Language.match('ru-RU'), Language.ru);
      expect(Language.match('en_GB'), Language.en);
      expect(Language.match('ET'), Language.et);
      expect(Language.match('fi-FI'), isNull);
    });
  });

  group('auth redirect', () {
    test('signed out: only the account screens and legal texts; the intro first on a new device', () {
      expect(authRedirect(signedIn: false, onboardingSeen: true, location: '/'), '/welcome');
      expect(authRedirect(signedIn: false, onboardingSeen: false, location: '/'), '/onboarding');
      expect(authRedirect(signedIn: false, onboardingSeen: false, location: '/welcome'), '/onboarding');
      expect(authRedirect(signedIn: false, onboardingSeen: true, location: '/welcome/sign-in'), isNull);
      expect(authRedirect(signedIn: false, onboardingSeen: true, location: '/legal/terms'), isNull);
    });

    test('signed in: never the account screens', () {
      expect(authRedirect(signedIn: true, onboardingSeen: true, location: '/welcome'), '/');
      expect(authRedirect(signedIn: true, onboardingSeen: true, location: '/onboarding'), '/');
      expect(authRedirect(signedIn: true, onboardingSeen: true, location: '/parks/a'), isNull);
      expect(authRedirect(signedIn: true, onboardingSeen: true, location: '/legal/privacy'), isNull);
    });
  });
}
