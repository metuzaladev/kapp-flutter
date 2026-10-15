import 'package:flutter/material.dart';
import 'package:timezone/data/latest_10y.dart' as tz;

import 'app.dart';
import 'core/auth/auth_client.dart';
import 'core/i18n/i18n.dart';
import 'core/i18n/language_preference.dart';
import 'core/logic/legal.dart';
import 'state/appearance.dart';
import 'state/onboarding.dart';

/// The splash stays until the translations, the stored language, appearance and onboarding flag and
/// the session are known, so neither the wrong language, the wrong scheme nor Welcome flashes.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await I18n.instance.load();
  await loadLegal();
  await Future.wait([
    LanguagePreferenceStore.instance.load(),
    OnboardingStore.instance.load(),
    AppearanceStore.instance.load(),
  ]);
  await AuthClient.instance.init();
  startConnectivity();
  runApp(const KappApp());
}
