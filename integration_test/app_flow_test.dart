import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kapp/main.dart' as app;

/// End-to-end walk through the main flow against a running development API (`npm run dev:api` in the
/// ICD0018-kapp repository): first launch → sign up → the four tabs → settings → sign out.
///
/// Run on a simulator whose language is English:
///   flutter test integration_test/app_flow_test.dart -d SIMULATOR_ID
/// Each `STEP:` line marks a screen worth a screenshot (`xcrun simctl io booted screenshot`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The app has endless animations (skeleton pulse, map tiles), so pumpAndSettle never returns.
  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Timed out waiting for $finder');
  }

  Future<void> step(WidgetTester tester, String name) async {
    debugPrint('STEP:$name');
    await pumpFor(tester, const Duration(seconds: 3));
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).hitTestable();
    try {
      await waitFor(tester, finder, timeout: const Duration(seconds: 6));
    } on TestFailure {
      // Lists build lazily: scroll the screen's list until the row exists.
      await tester.scrollUntilVisible(find.text(text), 300, scrollable: find.byType(Scrollable).hitTestable().first, maxScrolls: 30);
      await pumpFor(tester, const Duration(milliseconds: 500));
    }
    await tester.ensureVisible(finder.first);
    await tester.tap(finder.first);
    await pumpFor(tester, const Duration(milliseconds: 800));
  }

  testWidgets('first launch, sign up, tabs, settings, sign out', (tester) async {
    await app.main();
    await pumpFor(tester, const Duration(seconds: 2));

    // A session left in the Keychain (also one from the React Native build) opens Home: sign out first.
    if (find.text('Updates').evaluate().isNotEmpty) {
      await tapText(tester, 'Profile');
      await tapText(tester, 'Settings');
      await tapText(tester, 'Sign out');
      await pumpFor(tester, const Duration(seconds: 3));
    }
    if (find.text('Skip').evaluate().isNotEmpty) {
      await step(tester, 'onboarding');
      await tapText(tester, 'Skip');
    }
    await step(tester, 'welcome');

    await tapText(tester, 'Let’s go');
    await step(tester, 'sign-up');
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mari Test');
    await tester.enterText(fields.at(1), 'mari.${DateTime.now().millisecondsSinceEpoch}@example.com');
    await tester.enterText(fields.at(2), 'koerad123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tapText(tester, 'Create account');

    await waitFor(tester, find.text('Home'), timeout: const Duration(seconds: 30));
    await pumpFor(tester, const Duration(seconds: 3));
    await step(tester, 'home');

    await tapText(tester, 'Map');
    if (find.text('Not now').evaluate().isNotEmpty) {
      await step(tester, 'location-prompt');
      await tapText(tester, 'Not now');
    }
    await pumpFor(tester, const Duration(seconds: 4));
    await step(tester, 'map');

    await tapText(tester, 'Updates');
    await step(tester, 'notifications');

    await tapText(tester, 'Profile');
    await step(tester, 'profile');

    await tapText(tester, 'Settings');
    await step(tester, 'settings');

    await tapText(tester, 'Sign out');
    await waitFor(tester, find.text('Let’s go'), timeout: const Duration(seconds: 20));
    await step(tester, 'signed-out');
  });
}
