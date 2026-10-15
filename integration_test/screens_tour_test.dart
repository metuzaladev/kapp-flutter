import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kapp/components/service_cards.dart';
import 'package:kapp/core/i18n/language_preference.dart';
import 'package:kapp/state/appearance.dart';

import 'helpers.dart';

/// A tour through the rest of the app with a fresh account: add a dog, its profile and health, the
/// park list, a park page and a check-in, services and booking, Käpad and the shop, friends and
/// messages, and the language and appearance settings. Same setup as app_flow_test.dart.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screens tour', (tester) async {
    await startSignedUp(tester);

    // Dogs: add one, open its profile and health records.
    await tapText(tester, 'Profile');
    await tapText(tester, 'My dogs');
    await tapText(tester, 'Add a dog');
    await step(tester, 'dog-edit');
    await tester.enterText(find.byType(TextField).first, 'Luna');
    await tapText(tester, 'Add dog');
    await waitFor(tester, find.text('Luna'));
    await step(tester, 'dogs');
    await tapText(tester, 'Luna');
    await step(tester, 'dog-profile');
    await tapText(tester, 'Health and vaccinations');
    await step(tester, 'dog-health');
    await goBack(tester);
    await goBack(tester);
    await goBack(tester);

    // Parks: the list, a park page, a check-in with the one dog preselected.
    await tapText(tester, 'Home');
    await tapText(tester, 'See all parks');
    await step(tester, 'parks');
    await tapFinder(tester, find.byType(Image).first);
    await step(tester, 'park');
    await tapText(tester, 'We’re here');
    await step(tester, 'check-in');
    await tapText(tester, 'Check in');
    await waitFor(tester, find.text('See playmates'));
    await step(tester, 'checked-in');
    await tapText(tester, 'See playmates');
    await step(tester, 'park-here');
    await goBack(tester);
    await goBack(tester);

    // Services: the list, a provider, the booking modal.
    await tapText(tester, 'Services');
    await waitFor(tester, find.byType(ProviderRow));
    await step(tester, 'services');
    await tapFinder(tester, find.byType(ProviderRow));
    await step(tester, 'provider');
    await tapText(tester, 'Choose a time');
    await step(tester, 'book');
    await goBack(tester);
    await goBack(tester);
    await goBack(tester);

    // Käpad and the shop.
    await tapText(tester, 'Profile');
    await tapText(tester, 'Paws');
    await step(tester, 'rewards');
    await tapText(tester, 'Spend in the shop');
    await step(tester, 'shop');
    await goBack(tester);
    await goBack(tester);

    // Community.
    await tapText(tester, 'Your pack');
    await step(tester, 'friends');
    await goBack(tester);
    await tapText(tester, 'Messages');
    await step(tester, 'inbox');
    await goBack(tester);

    // Language and appearance: Estonian and dark, then back to the defaults.
    await tapText(tester, 'Settings');
    await tapText(tester, 'eesti');
    await step(tester, 'settings-et');
    await tapText(tester, 'Tume');
    await step(tester, 'settings-dark');
    await goBack(tester);
    await step(tester, 'profile-dark-et');
    await LanguagePreferenceStore.instance.set(const AutoLanguage());
    await AppearanceStore.instance.set(AppearancePreference.light);
    await pumpFor(tester, const Duration(seconds: 1));
  });
}
