import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/icon.dart';
import '../../components/photo_tile.dart';
import '../../components/screen.dart';
import '../../components/social_sign_in.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../core/format.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../hooks/device_location.dart';
import '../../hooks/parks.dart';
import '../../models/parks.dart';
import '../../state/park_filters.dart';

/// Figma: the hero photo covers ~60 % of the 844 pt frame and fades into the background.
const _heroShare = 0.62;

/// Figma "Live" card: the busiest park around Tallinn's centre right now, from the public
/// /parks/nearby endpoint (no account needed). Hidden while loading, on error or when no dogs are
/// out — never a made-up number. Dog names are not public before sign-in, so the faces are paws.
class _LiveCard extends HookWidget {
  const _LiveCard();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final data = useNearbyParks(tallinnCenter, defaultParkFilters).data;
    Park? busiest;
    for (final p in data ?? const <Park>[]) {
      if ((p.activeDogs ?? 0) > (busiest?.activeDogs ?? 0)) busiest = p;
    }
    final dogs = busiest?.activeDogs ?? 0;
    if (busiest == null || dogs == 0) return const SizedBox.shrink();
    return Semantics(
      label: context.t('auth.welcome.liveA11y', params: {'park': busiest.name, 'dogs': dogsLabel(dogs)}),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.r16),
          border: Border.all(color: c.border),
          boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28 + (dogs.clamp(1, 3) - 1) * 20,
              height: 28,
              child: Stack(
                children: [
                  for (var i = 0; i < dogs.clamp(1, 3); i++)
                    Positioned(
                      left: i * 20.0,
                      child: PhotoTile(size: 28, radius: 8, border: (width: 2, color: c.surface)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(context.t('auth.welcome.liveTitle', params: {'dogs': dogsLabel(dogs)}), type: TextType.label),
                  AppText(busiest.name, type: TextType.caption, themeColor: TextColor.muted, maxLines: 1),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c.mapPark, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma 01 / Welcome (6:6, M9): full-bleed corgi photo fading into the background, "Tallinn · Eesti"
/// tag, a live card, the "käpp" wordmark, hero and body text, "Alustame", Apple and "Mul on juba
/// konto". On a device that has never seen the intro, Onboarding comes first (router redirect).
class WelcomeScreen extends HookWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final error = useState<String?>(null);
    final media = MediaQuery.of(context);
    final heroHeight = (media.size.height * _heroShare).roundToDouble();

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          const PawBackground(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  image: true,
                  label: context.t('auth.welcome.photoLabel'),
                  child: Image.asset(
                    'assets/images/welcome-dog.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                Positioned(left: 0, right: 0, bottom: 0, child: Fade(height: heroHeight * 0.45)),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                Spacing.screen,
                media.padding.top + Spacing.three,
                Spacing.screen,
                media.padding.bottom + Spacing.three,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: box.maxHeight - media.padding.top - media.padding.bottom - Spacing.three * 2,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SessionNoticeBanner(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Opacity(
                          opacity: 0.92,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(Radii.full),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(IconName.mapPin, size: 14, color: c.text),
                                const SizedBox(width: 6),
                                AppText(context.t('auth.welcome.region'), type: TextType.caption),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Pushes the copy down to where the photo fades out; content still scrolls at large text sizes.
                      Expanded(child: SizedBox(height: heroHeight * 0.38)),
                      const _LiveCard(),
                      const SizedBox(height: Spacing.three),
                      const AppText('käpp', type: TextType.display, header: true),
                      AppText(context.t('auth.welcome.tagline'), type: TextType.hero),
                      const SizedBox(height: Spacing.three),
                      AppText(context.t('auth.welcome.intro'), themeColor: TextColor.muted),
                      const SizedBox(height: Spacing.three + Spacing.two),
                      FormError(error.value),
                      if (error.value != null) const SizedBox(height: Spacing.two),
                      AppButton(
                        label: context.t('auth.welcome.start'),
                        trailingIcon: IconName.arrowRight,
                        onPressed: () => context.push('/welcome/sign-up'),
                      ),
                      const SizedBox(height: Spacing.two),
                      SocialSignIn(onError: (e) => error.value = e, showGoogle: false),
                      const SizedBox(height: Spacing.two),
                      AppButton(
                        label: context.t('auth.welcome.haveAccount'),
                        variant: ButtonVariant.tertiary,
                        onPressed: () => context.push('/welcome/sign-in'),
                      ),
                      // M10: the store requires the privacy policy to be reachable before signing up.
                      const LegalLinks(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
