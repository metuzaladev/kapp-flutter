import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_client.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/reset_password_screens.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/community/friends_screens.dart';
import 'screens/community/messages_screens.dart';
import 'screens/dogs/dog_screens.dart';
import 'screens/dogs/health_screens.dart';
import 'screens/dogs/photos_screen.dart';
import 'screens/explore/explore_screens.dart';
import 'screens/parks/park_detail_screen.dart';
import 'screens/parks/park_lists.dart';
import 'screens/parks/visit_screens.dart';
import 'screens/rewards/rewards_screens.dart';
import 'screens/services/services_screens.dart';
import 'screens/settings/settings_screens.dart';
import 'screens/tabs/app_shell.dart';
import 'screens/tabs/home_screen.dart';
import 'screens/tabs/map_screen.dart';
import 'screens/tabs/notifications_screen.dart';
import 'screens/tabs/profile_screen.dart';
import 'state/onboarding.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Modals: focused edit tasks with an explicit "done" action (HIG), sliding up with a close button.
Page<void> _modal(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, fullscreenDialog: true, child: child);

GoRoute _push(String path, Widget Function(GoRouterState state) build) =>
    GoRoute(path: path, builder: (_, s) => build(s));

GoRoute _sheet(String path, Widget Function(GoRouterState state) build) =>
    GoRoute(path: path, pageBuilder: (_, s) => _modal(s, build(s)));

String? _q(GoRouterState s, String name) => s.uri.queryParameters[name];

/// Signed-out users can only reach Welcome (and the first-launch intro), the account screens and the
/// legal texts; signed-in users only the app. The redirect runs again whenever the session or the
/// onboarding flag changes, so screens never navigate after sign-in/sign-out themselves.
String? authRedirect({required bool signedIn, required bool? onboardingSeen, required String location}) {
  final authArea = location == '/onboarding' || location == '/welcome' || location.startsWith('/welcome/');
  final legal = location.startsWith('/legal/');
  if (!signedIn) {
    if (location == '/welcome' && onboardingSeen == false) return '/onboarding';
    if (authArea || legal) return null;
    return onboardingSeen == false ? '/onboarding' : '/welcome';
  }
  if (authArea) return '/';
  return null;
}

GoRouter createRouter() => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: Listenable.merge([AuthClient.instance, OnboardingStore.instance]),
  redirect: (context, state) => authRedirect(
    signedIn: AuthClient.instance.value.signedIn,
    onboardingSeen: OnboardingStore.instance.value,
    location: state.matchedLocation,
  ),
  routes: [
    _push('/onboarding', (_) => const OnboardingScreen()),
    GoRoute(
      path: '/welcome',
      builder: (_, _) => const WelcomeScreen(),
      routes: [
        _push('sign-in', (s) => SignInScreen(notice: _q(s, 'notice'))),
        _push('sign-up', (_) => const SignUpScreen()),
        _push('reset-password', (_) => const ResetPasswordScreen()),
        _push('reset-sent', (_) => const ResetSentScreen()),
        _push('new-password', (s) => NewPasswordScreen(token: _q(s, 'token'), linkError: _q(s, 'error'))),
      ],
    ),
    // M10: privacy policy and terms are readable signed out (sign-up, Welcome) and signed in.
    _push('/legal/:doc', (s) => LegalDocumentScreen(doc: s.pathParameters['doc']!)),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [_push('/', (_) => const HomeScreen())]),
        StatefulShellBranch(routes: [_push('/map', (_) => const KaartTab())]),
        StatefulShellBranch(routes: [_push('/notifications', (_) => const NotificationsScreen())]),
        StatefulShellBranch(routes: [_push('/profile', (_) => const ProfileScreen())]),
      ],
    ),
    _push('/parks', (_) => const ParkListScreen()),
    _push('/parks/:parkId', (s) => ParkDetailScreen(parkId: s.pathParameters['parkId']!)),
    _push('/favorites', (_) => const FavoritesScreen()),
    _push('/visits', (_) => const VisitsScreen()),
    _push('/dogs', (_) => const MyDogsScreen()),
    // Before /dogs/:dogId, which would otherwise take "edit" as an id.
    _sheet('/dogs/edit', (s) => DogEditScreen(dogId: _q(s, 'dogId'))),
    _push('/dogs/:dogId', (s) => DogProfileScreen(dogId: s.pathParameters['dogId']!)),
    _push('/dogs/:dogId/photos', (s) => DogPhotosScreen(dogId: s.pathParameters['dogId']!)),
    _push('/dogs/:dogId/health', (s) => DogHealthScreen(dogId: s.pathParameters['dogId']!)),
    _sheet(
      '/dogs/:dogId/health-edit',
      (s) => HealthEditScreen(dogId: s.pathParameters['dogId']!, recordId: _q(s, 'recordId'), kind: _q(s, 'kind')),
    ),
    _push('/settings', (_) => const SettingsScreen()),
    _push('/friends', (_) => const FriendsScreen()),
    _push('/users/:userId', (s) => UserProfileScreen(userId: s.pathParameters['userId']!)),
    _push('/messages', (_) => const InboxScreen()),
    _push('/messages/:conversationId', (s) => ConversationScreen(conversationId: s.pathParameters['conversationId']!)),
    _push('/settings-privacy', (_) => const PrivacySettingsScreen()),
    _push('/settings-notifications', (_) => const NotificationSettingsScreen()),
    _push('/invite-park', (s) => InviteParkScreen(userId: _q(s, 'userId') ?? '', name: _q(s, 'name'))),
    // M6 services and bookings (docs/13-teenused.md).
    _push('/services', (s) => ServicesScreen(initialCategory: _q(s, 'category'))),
    _push('/services/:providerId', (s) => ProviderScreen(providerId: s.pathParameters['providerId']!)),
    _push('/bookings', (_) => const BookingsScreen()),
    // M9b Avasta, Käpad and Pood (docs/16-avasta-ja-kapad.md). "mine" before ":postId".
    _push('/place-posts/mine', (_) => const MyPlacePostsScreen()),
    _push('/place-posts/:postId', (s) => PlacePostScreen(postId: s.pathParameters['postId']!)),
    _push('/rewards', (_) => const RewardsScreen()),
    _push('/rewards/history', (_) => const RewardHistoryScreen()),
    _push('/shop', (_) => const ShopScreen()),
    _push('/shop/:productId', (s) => ProductScreen(productId: s.pathParameters['productId']!)),
    _push('/redemptions', (_) => const RedemptionsScreen()),
    _push(
      '/redemptions/:redemptionId',
      (s) => RedemptionScreen(redemptionId: s.pathParameters['redemptionId']!, fresh: _q(s, 'fresh') == '1'),
    ),
    // M10 account (docs/17).
    _push('/privacy-terms', (_) => const PrivacyTermsScreen()),
    _push('/delete-account', (_) => const DeleteAccountScreen()),
    // Modals: focused edit tasks with an explicit "done" action (HIG).
    _sheet('/profile-edit', (_) => const ProfileEditScreen()),
    _sheet('/park-filters', (_) => const ParkFiltersScreen()),
    _sheet('/check-in', (s) => CheckInScreen(parkId: _q(s, 'parkId') ?? '', parkName: _q(s, 'parkName'))),
    _sheet(
      '/plan-visit',
      (s) => PlanVisitScreen(
        parkId: _q(s, 'parkId') ?? '',
        parkName: _q(s, 'parkName'),
        inviteUserId: _q(s, 'inviteUserId'),
      ),
    ),
    _sheet('/review', (s) => ReviewScreen(parkId: _q(s, 'parkId') ?? '', parkName: _q(s, 'parkName'))),
    _sheet('/report', (s) => ReportParkScreen(parkId: _q(s, 'parkId') ?? '', parkName: _q(s, 'parkName'))),
    _sheet('/report-user', (s) => ReportUserScreen(userId: _q(s, 'userId') ?? '', name: _q(s, 'name'))),
    _sheet(
      '/book',
      (s) => BookScreen(
        providerId: _q(s, 'providerId') ?? '',
        serviceId: _q(s, 'serviceId') ?? '',
        preset: _q(s, 'startsAt'),
      ),
    ),
    _sheet('/suggest-place', (_) => const SuggestPlaceScreen()),
    _sheet('/report-post', (s) => ReportPostScreen(postId: _q(s, 'postId') ?? '', name: _q(s, 'name'))),
  ],
);
