import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/main.dart' as app;
import 'package:kapp/router.dart';

/// Shared steps for the end-to-end tests (run against a development API, simulator in English).
///
/// The app has endless animations (skeleton pulse, map tiles), so pumpAndSettle never returns:
/// these helpers pump for a while instead.
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

/// Marks a screen worth a screenshot (the runner script watches for `STEP:` lines).
Future<void> step(WidgetTester tester, String name) async {
  debugPrint('STEP:$name');
  await pumpFor(tester, const Duration(seconds: 3));
}

Future<void> tapFinder(WidgetTester tester, Finder finder) async {
  try {
    await waitFor(tester, finder.hitTestable(), timeout: const Duration(seconds: 6));
  } on TestFailure {
    // Lists build lazily: scroll the screen's list until the target exists.
    // The visible screen's list; other tabs keep theirs alive offstage.
    final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    final visible = vertical.hitTestable();
    final scrollable = visible.evaluate().isNotEmpty ? visible.first : vertical.last;
    // The target may be below or (after an earlier scroll) above the viewport.
    try {
      await tester.scrollUntilVisible(finder, 300, scrollable: scrollable, maxScrolls: 20);
    } on StateError {
      await tester.scrollUntilVisible(finder, -300, scrollable: scrollable, maxScrolls: 40);
    }
    await pumpFor(tester, const Duration(milliseconds: 500));
  }
  await tester.ensureVisible(finder.first);
  await pumpFor(tester, const Duration(milliseconds: 300));
  await tester.tap(finder.hitTestable().first);
  await pumpFor(tester, const Duration(milliseconds: 800));
}

Future<void> tapText(WidgetTester tester, String text) => tapFinder(tester, find.text(text));

/// Closes the top screen (back button or a modal's close button).
Future<void> goBack(WidgetTester tester) async {
  rootNavigatorKey.currentState!.pop();
  await pumpFor(tester, const Duration(milliseconds: 800));
}

/// Starts the app and ends on Home with a fresh account.
Future<void> startSignedUp(WidgetTester tester) async {
  await app.main();
  await pumpFor(tester, const Duration(seconds: 2));
  // A session left in the Keychain (also one from the React Native build) opens Home: sign out first.
  if (find.text('Updates').evaluate().isNotEmpty) {
    await tapText(tester, 'Profile');
    await tapText(tester, 'Settings');
    await tapText(tester, 'Sign out');
    await pumpFor(tester, const Duration(seconds: 3));
  }
  if (find.text('Skip').evaluate().isNotEmpty) await tapText(tester, 'Skip');
  await tapText(tester, 'Let’s go');
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Mari Test');
  await tester.enterText(fields.at(1), 'mari.${DateTime.now().millisecondsSinceEpoch}@example.com');
  await tester.enterText(fields.at(2), 'koerad123');
  // "Go" on the password field submits the form, like the keyboard's return key.
  await tester.testTextInput.receiveAction(TextInputAction.go);
  await waitFor(tester, find.text('Home'), timeout: const Duration(seconds: 30));
  await pumpFor(tester, const Duration(seconds: 2));
}
