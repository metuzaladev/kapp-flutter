import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_client.dart';
import '../core/format.dart';
import '../core/i18n/i18n.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import '../hooks/account.dart';
import '../hooks/community.dart';
import '../hooks/services.dart';
import '../state/session_notice.dart';
import 'button.dart';
import 'icon.dart';
import 'icon_button.dart';
import 'pressable.dart';
import 'states.dart';
import 'text.dart';

/// Whether the device has a network connection (null while unknown at start-up).
final ValueNotifier<bool?> online = ValueNotifier(null);

/// Starts listening to connectivity changes; `onReconnect` refetches what is on screen.
void watchConnectivity(void Function() onReconnect) {
  final connectivity = Connectivity();
  void apply(List<ConnectivityResult> r) {
    final next = !r.contains(ConnectivityResult.none);
    final was = online.value;
    online.value = next;
    if (next && was == false) onReconnect();
  }

  connectivity.checkConnectivity().then(apply).catchError((Object _) {});
  connectivity.onConnectivityChanged.listen(apply);
}

/// Figma "Offline State", compact: the cached data stays visible underneath.
class OfflineBanner extends HookWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = useValueListenable(online);
    // Unknown at start-up: do not flash the banner.
    if (isOnline != false) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.three),
        decoration: BoxDecoration(color: context.c.tint, borderRadius: BorderRadius.circular(Radii.r12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(context.t('offline.title'), type: TextType.label),
            const SizedBox(height: 2),
            AppText(context.t('offline.body'), type: TextType.caption),
          ],
        ),
      ),
    );
  }
}

/// Figma "Points Badge" (56:113): soft brand pill with a paw and the Käpad balance. While the
/// balance is unknown the badge renders nothing, so no invented number is ever shown.
class PointsBadge extends HookWidget {
  const PointsBadge({super.key, this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final points = usePointsBalance();
    if (points == null) return const SizedBox.shrink();
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.only(left: 10, right: 12),
      decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(IconName.pawPrint, size: 16, color: c.brand),
          const SizedBox(width: 6),
          Text(formatNumber(points), maxLines: 1, style: textStyle(TextType.label, color: c.accent)),
        ],
      ),
    );
    final label = context.t('points.balance', count: points);
    if (onPressed == null) return Semantics(label: label, excludeSemantics: true, child: pill);
    return Pressable(
      onPressed: onPressed,
      semanticLabel: label,
      semanticHint: context.t('points.openHint'),
      hitSlop: 8,
      child: pill,
    );
  }
}

/// "Kinnita e-post" (M10, docs/17): shown on Home until the address is confirmed. Sign-in is never
/// blocked by it; the banner only nudges.
class VerifyEmailBanner extends HookWidget {
  const VerifyEmailBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = useOwnProfile().data;
    final resend = useResendVerification();
    if (me == null || me.emailVerified) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(Spacing.three),
      decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.r16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(IconName.mail, size: 22, color: c.accent),
                const SizedBox(width: Spacing.three),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(context.t('verifyEmail.title'), type: TextType.label),
                      const SizedBox(height: 2),
                      AppText(
                        context.t('verifyEmail.body', params: {'email': me.email}),
                        type: TextType.caption,
                        themeColor: TextColor.muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.two),
          if (resend.isSuccess)
            Semantics(
              liveRegion: true,
              child: AppText(context.t('verifyEmail.sent'), type: TextType.caption, themeColor: TextColor.link),
            )
          else
            AppButton(
              label: context.t('verifyEmail.resend'),
              variant: ButtonVariant.tertiary,
              loading: resend.isPending,
              onPressed: () => resend.mutate(null),
            ),
          if (resend.error != null) ...[const SizedBox(height: Spacing.two), FormError(errorMessage(resend.error))],
        ],
      ),
    );
  }
}

/// The "toast" after a deliberate sign-out (M10: account deleted), shown on Welcome. It stays until
/// dismissed (a timed toast can vanish before a screen-reader user hears it).
class SessionNoticeBanner extends HookWidget {
  const SessionNoticeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final notice = useValueListenable(sessionNotice);
    if (notice != SessionNotice.accountDeleted) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Spacing.three),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.r16),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            AppIcon(IconName.check, size: 24, color: c.brand),
            const SizedBox(width: Spacing.three),
            Expanded(child: AppText(context.t('account.deletedNotice'), type: TextType.label)),
            AppIconButton(
              icon: IconName.x,
              label: context.t('common.close'),
              onPressed: () => sessionNotice.value = null,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Kasutustingimused · Privaatsuspoliitika" (M10) under the sign-up form and on Welcome. Separate
/// buttons instead of links inside a sentence: word order differs between et/en/ru.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        for (final doc in ['terms', 'privacy'])
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140),
            child: AppButton(
              label: context.t('legal.$doc'),
              variant: ButtonVariant.tertiary,
              onPressed: () => context.push('/legal/$doc'),
            ),
          ),
      ],
    );
  }
}
