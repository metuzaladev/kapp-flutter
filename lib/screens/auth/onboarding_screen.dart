import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/button.dart';
import '../../components/icon.dart';
import '../../components/map_tiles.dart';
import '../../components/photo_tile.dart';
import '../../components/screen.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../core/format.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../state/onboarding.dart';

const _pages = ['discover', 'connect'];

/// Figma page dots: the current page is a wide brand pill. Screen readers hear "Samm 1, kokku 2".
class _PageDots extends StatelessWidget {
  const _PageDots({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: context.t('onboarding.step', params: {'current': index + 1, 'total': _pages.length}),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < _pages.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? c.brand : c.border,
                borderRadius: BorderRadius.circular(Radii.full),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Figma Onboarding / Connect collage: tilted rounded-square photos and a floating invite card.
/// Marketing illustration with sample content, hidden from screen readers.
class _Collage extends StatelessWidget {
  const _Collage();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ExcludeSemantics(
      child: SizedBox(
        height: 260,
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              Positioned(
                left: 0,
                top: 10,
                width: box.maxWidth * 0.52,
                height: 170,
                child: Transform.rotate(
                  angle: -0.07,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/images/sample-dogs/luna.jpg', fit: BoxFit.cover),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                width: box.maxWidth * 0.58,
                height: 200,
                child: Transform.rotate(
                  angle: 0.07,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/images/welcome-dog.jpg', fit: BoxFit.cover),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
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
                      const PhotoTile(asset: 'assets/images/sample-dogs/luna.jpg', size: 40, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(context.t('onboarding.connect.sampleTitle'), type: TextType.label),
                            AppText(
                              context.t('onboarding.connect.sampleSubtitle'),
                              type: TextType.caption,
                              themeColor: TextColor.muted,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(12)),
                        child: AppText(
                          context.t('onboarding.connect.sampleAction'),
                          type: TextType.caption,
                          color: c.onBrand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma Onboarding / Discover + Connect: shown once, on the first launch of a signed-out device,
/// before Welcome. Swipe or "Edasi" pages; "Jäta vahele" and the last page's actions mark it seen
/// and leave it for good — it is replaced, so "back" cannot return here.
class OnboardingScreen extends HookWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final controller = usePageController();
    final index = useState(0);
    final last = index.value == _pages.length - 1;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Future<void> finish(String? next) async {
      await OnboardingStore.instance.markSeen();
      if (!context.mounted) return;
      // Welcome becomes the root of the auth stack, so "back" from sign-up/sign-in lands there.
      context.go(next == null ? '/welcome' : '/welcome/$next');
    }

    Widget page(String name, int i) => SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Entering(child: AppText(context.t('onboarding.$name.title'), type: TextType.title, header: true)),
          const SizedBox(height: Spacing.three),
          Entering(index: 1, child: AppText(context.t('onboarding.$name.body'), themeColor: TextColor.muted)),
          const SizedBox(height: Spacing.three),
          if (name == 'discover') const MapPreview(dogsLabel: dogsLabel) else const _Collage(),
          const SizedBox(height: Spacing.three),
          _PageDots(index: i),
          const SizedBox(height: Spacing.three),
          if (name == 'discover') ...[
            FeatureRow(
              icon: IconName.mapPin,
              title: context.t('onboarding.discover.seeTitle'),
              body: context.t('onboarding.discover.seeBody'),
            ),
            const SizedBox(height: Spacing.three),
            FeatureRow(
              icon: IconName.users,
              title: context.t('onboarding.discover.crewTitle'),
              body: context.t('onboarding.discover.crewBody'),
            ),
          ] else ...[
            FeatureRow(
              icon: IconName.calendar,
              title: context.t('onboarding.connect.planTitle'),
              body: context.t('onboarding.connect.planBody'),
            ),
            const SizedBox(height: Spacing.three),
            FeatureRow(
              icon: IconName.pawPrint,
              title: context.t('onboarding.connect.pawsTitle'),
              body: context.t('onboarding.connect.pawsBody'),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          const PawBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: controller,
                    onPageChanged: (i) => index.value = i,
                    children: [for (final (i, name) in _pages.indexed) page(name, i)],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.screen, 0, Spacing.screen, Spacing.three),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: last
                        ? [
                            AppButton(
                              label: context.t('onboarding.createAccount'),
                              trailingIcon: IconName.arrowRight,
                              onPressed: () => finish('sign-up'),
                            ),
                            const SizedBox(height: Spacing.two),
                            AppButton(
                              label: context.t('auth.welcome.haveAccount'),
                              variant: ButtonVariant.tertiary,
                              onPressed: () => finish('sign-in'),
                            ),
                          ]
                        : [
                            AppButton(
                              label: context.t('onboarding.next'),
                              trailingIcon: IconName.arrowRight,
                              onPressed: () {
                                final next = index.value + 1;
                                if (reduceMotion) {
                                  controller.jumpToPage(next);
                                } else {
                                  controller.animateToPage(
                                    next,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: Spacing.two),
                            AppButton(
                              label: context.t('onboarding.skip'),
                              variant: ButtonVariant.tertiary,
                              onPressed: () => finish(null),
                            ),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
