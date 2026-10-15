import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'components/banners.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_client.dart';
import 'core/i18n/i18n.dart';
import 'core/i18n/language_preference.dart';
import 'core/query/query_client.dart';
import 'core/realtime.dart';
import 'core/theme/theme.dart';
import 'hooks/community.dart';
import 'router.dart';
import 'state/appearance.dart';

/// Root widget: theme (Settings → Välimus), language (Settings → Keel), the router, and everything
/// that runs while signed in — the realtime socket feeding the cache and the stored language for
/// push texts (`useCommunityRuntime` in the React Native app).
class KappApp extends HookWidget {
  const KappApp({super.key, this.router});

  /// Injected in widget tests.
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    final appRouter = useMemoized(() => router ?? createRouter());
    final appearance = useValueListenable(AppearanceStore.instance);
    final language = useListenable(I18n.instance).language;
    final signedIn = useValueListenable(AuthClient.instance).signedIn;

    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed) {
        LanguagePreferenceStore.instance.onResumed();
        // Treat "app came back to the foreground" as window focus, so stale data refreshes.
        queryClient.refetchStaleObserved();
        unawaited(AuthClient.instance.refreshSession());
      }
    });

    // Cached server data belongs to one user: never show the previous user's favourites.
    useEffect(() {
      if (!signedIn) queryClient.clear();
      return null;
    }, [signedIn]);

    // Realtime: new messages go straight into the cache, notifications refresh the badge and lists.
    useEffect(() {
      if (!signedIn) return null;
      unawaited(
        connectRealtime(
          onMessage: (message) {
            addMessageToCache(message);
            queryClient.invalidateQueries(ConversationKeys.list);
          },
          onNotification: () {
            queryClient.invalidateQueries(NotificationKeys.unread);
            queryClient.invalidateQueries(NotificationKeys.feed);
            // A request or acceptance changes the friends lists too.
            queryClient.invalidateQueries(FriendKeys.all);
          },
        ),
      );
      return disconnectRealtime;
    }, [signedIn]);

    // Push and e-mail texts are composed on the server in the stored language: keep it in sync.
    useEffect(() {
      if (signedIn) unawaited(apiSend<void>('PATCH', '/me', {'language': language.name}).catchError((Object _) {}));
      return null;
    }, [signedIn, language]);

    // kapp://new-password?token=… from the password reset e-mail.
    useEffect(() {
      final sub = AppLinks().uriLinkStream.listen((uri) {
        if (uri.scheme == 'kapp' && uri.host == 'new-password') {
          appRouter.go(
            Uri(
              path: '/welcome/new-password',
              queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
            ).toString(),
          );
        }
      });
      return sub.cancel;
    }, [appRouter]);

    return I18nScope(
      child: MaterialApp.router(
        title: 'Käpp',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        themeMode: appearance.themeMode,
        locale: switch (language) {
          Language.et => const Locale('et'),
          Language.en => const Locale('en', 'GB'),
          Language.ru => const Locale('ru'),
        },
        supportedLocales: const [Locale('et'), Locale('en', 'GB'), Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Respect the user's text size, but cap it so layouts built for 390 pt stay usable.
        builder: (context, child) =>
            MediaQuery.withClampedTextScaling(maxScaleFactor: 1.6, child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Starts the connectivity watcher (offline banner, refetch on reconnect).
void startConnectivity() => watchConnectivity(queryClient.refetchStaleObserved);
