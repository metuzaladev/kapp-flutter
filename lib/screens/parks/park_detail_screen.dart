import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/icon.dart';
import '../../components/list_row.dart';
import '../../components/photo_tile.dart';
import '../../components/pressable.dart';
import '../../components/screen.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../core/api/api_client.dart';
import '../../core/directions.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../hooks/parks.dart';
import '../../hooks/visits.dart';
import '../../models/visits.dart';

/// Route to a park modal with the park's id and name as query parameters.
String parkRoute(String path, String parkId, String parkName) =>
    Uri(path: path, queryParameters: {'parkId': parkId, 'parkName': parkName}).toString();

/// Figma 02 / Park / Overview, with the Visitors and Reviews tabs as sections of one scroll.
class ParkDetailScreen extends HookWidget {
  const ParkDetailScreen({super.key, required this.parkId});
  final String parkId;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final detail = useParkDetail(parkId);
    final park = detail.data;
    final favorite = useToggleFavorite(parkId);
    final active = useActiveCheckIn();
    final endVisit = useEndCheckIn();
    final visitors = useParkVisitors(parkId);
    final reviews = useParkReviews(parkId);
    final hereNow = active.data?.park.id == parkId ? active.data : null;
    final isFavorite = park?.isFavorite ?? false;

    final features = park == null
        ? const <String>[]
        : [
            if (park.fenced) 'fenced',
            if (park.smallDogArea) 'smallDogArea',
            if (park.water) 'water',
            if (park.lighting) 'lighting',
          ];

    return AppScreen(
      navBar: true,
      navTitle: park?.name,
      actions: [
        if (park != null)
          Pressable(
            semanticLabel: isFavorite ? context.t('park.favoriteRemove') : context.t('park.favoriteAdd'),
            selected: isFavorite,
            onPressed: favorite.isPending
                ? null
                : () {
                    haptic(HapticReason.selection);
                    favorite.mutate(!isFavorite);
                  },
            dimWhenDisabled: false,
            child: SizedBox(
              width: 48,
              height: 44,
              child: Center(
                // Re-keyed on change so it pops when toggled; static with Reduce Motion.
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(isFavorite),
                  tween: Tween(begin: MediaQuery.of(context).disableAnimations ? 1 : 0.6, end: 1),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: AppIcon(isFavorite ? IconName.heartFilled : IconName.heart, size: 26, color: c.brand),
                ),
              ),
            ),
          ),
      ],
      onRefresh: park == null
          ? null
          : () => refreshAll([detail.refetch, visitors.refetch, reviews.refetch, active.refetch]),
      children: [
        const OfflineBanner(),
        if (detail.error != null && park == null)
          ErrorState(message: errorMessage(detail.error), onRetry: detail.refetch, retrying: detail.isFetching),
        if (favorite.error != null) FormError(errorMessage(favorite.error)),
        if (detail.isPending && detail.error == null) const SkeletonList(rows: 2, rowHeight: 120),
        if (park != null) ...[
          Entering(
            child: Semantics(
              image: true,
              label: context.t('park.photoLabel'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.r16),
                child: Image.asset('assets/images/park-placeholder.jpg', height: 200, fit: BoxFit.cover),
              ),
            ),
          ),
          Entering(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(park.name, type: TextType.title, header: true),
                // Figma: "1,2 km · Kesklinn, Tallinn".
                if (park.address != null || park.distanceKm != null) ...[
                  const SizedBox(height: Spacing.one),
                  AppText([?formatKm(park.distanceKm), ?park.address].join(' · '), themeColor: TextColor.muted),
                ],
              ],
            ),
          ),
          if (hereNow != null)
            _Summary(
              color: c.tint,
              children: [
                AppText(
                  context.t('park.hereUntil', params: {'time': formatTime(hereNow.expiresAt)}),
                  type: TextType.heading,
                ),
                AppText(hereNow.dogs.map((d) => d.name).join(', '), type: TextType.caption),
                const SizedBox(height: Spacing.two),
                AppButton(
                  label: context.t('park.endVisit'),
                  variant: ButtonVariant.secondary,
                  loading: endVisit.isPending,
                  onPressed: () => endVisit.mutate(hereNow.id),
                ),
              ],
            ),
          if (endVisit.error != null) FormError(errorMessage(endVisit.error)),
          _Summary(
            color: c.soft,
            children: [
              AppText(context.t('park.dogsNow', count: park.activeDogs ?? 0), type: TextType.heading),
              AppText(
                park.reviewCount > 0 && park.ratingAverage != null
                    ? context.t(
                        'park.rating',
                        params: {
                          'rating': formatRating(park.ratingAverage!),
                          'reviews': reviewsLabel(park.reviewCount),
                        },
                      )
                    : context.t('park.noReviews'),
                type: TextType.caption,
                themeColor: TextColor.muted,
              ),
            ],
          ),
          if (hereNow == null)
            AppButton(
              label: context.t('park.checkIn'),
              onPressed: () => context.push(parkRoute('/check-in', parkId, park.name)),
            ),
          AppButton(
            label: context.t('park.plan'),
            variant: ButtonVariant.secondary,
            onPressed: () => context.push(parkRoute('/plan-visit', parkId, park.name)),
          ),
          AppButton(
            label: context.t('park.directions'),
            variant: ButtonVariant.secondary,
            onPressed: () => openDirections(name: park.name, lat: park.lat, lng: park.lng),
          ),
          if (features.isNotEmpty || park.description != null) ...[
            AppText(context.t('park.goodToKnow'), type: TextType.heading),
            Wrap(
              spacing: Spacing.two,
              runSpacing: Spacing.two,
              children: [
                for (final key in features)
                  Container(
                    constraints: const BoxConstraints(minHeight: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.full),
                      border: Border.all(color: c.border, width: 0.5),
                    ),
                    child: AppText(context.t('park.feature.$key'), type: TextType.caption),
                  ),
              ],
            ),
            if (park.description != null) AppText(park.description!),
          ],
          if (visitors.data case final v? when v.visitors.isNotEmpty || v.hiddenDogs > 0) ...[
            AppText(context.t('park.visitorsTitle'), type: TextType.heading),
            for (final (i, visitor) in v.visitors.indexed)
              Entering(
                index: i,
                // Visitors' dog photos are not in the API (names only): the first dog's initial stands in.
                // The own row is not tappable; others open the profile.
                child: ListRow(
                  title: [
                    visitor.isMe ? context.t('common.you') : visitor.ownerFirstName,
                    visitor.dogs.map((d) => d.name).join(', '),
                  ].join(' · '),
                  subtitle: context.t(
                    'park.visitorDetails',
                    params: {
                      'breeds': visitor.dogs.map((d) => d.breed).whereType<String>().join(', ').isNotEmpty
                          ? visitor.dogs.map((d) => d.breed).whereType<String>().join(', ')
                          : context.t('common.dog'),
                      'time': formatTime(visitor.until),
                    },
                  ),
                  showPhoto: true,
                  photoName: visitor.dogs.firstOrNull?.name ?? visitor.ownerFirstName,
                  hint: visitor.isMe ? null : context.t('park.visitorHint'),
                  onPressed: visitor.isMe ? null : () => context.push('/users/${visitor.userId}'),
                ),
              ),
            if (v.hiddenDogs > 0)
              AppText(
                context.t('park.hiddenDogs', count: v.hiddenDogs),
                type: TextType.caption,
                themeColor: TextColor.muted,
              ),
            _Summary(
              color: c.soft,
              children: [
                AppText(context.t('park.firstMeetTitle'), type: TextType.label),
                AppText(context.t('park.firstMeetBody'), type: TextType.caption, themeColor: TextColor.muted),
              ],
            ),
          ],
          AppText(context.t('park.reviewsTitle'), type: TextType.heading),
          if (reviews.data?.isEmpty ?? false) AppText(context.t('park.reviewsEmpty'), themeColor: TextColor.muted),
          for (final r in (reviews.data ?? const <Review>[]).take(3))
            Semantics(
              label: [
                context.t('park.reviewA11y', params: {'name': r.authorFirstName, 'rating': r.rating}),
                ?r.body,
              ].join('. '),
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.all(Spacing.three),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.r16),
                  border: Border.all(color: c.border, width: 0.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PhotoTile(name: r.authorFirstName, size: 44, radius: 14),
                    const SizedBox(width: Spacing.three),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              AppText(r.authorFirstName, type: TextType.label),
                              const SizedBox(width: 4),
                              for (var n = 1; n <= 5; n++)
                                AppIcon(
                                  n <= r.rating ? IconName.starFilled : IconName.star,
                                  size: 14,
                                  color: n <= r.rating ? c.accent : c.border,
                                ),
                            ],
                          ),
                          if (r.body != null) ...[const SizedBox(height: 2), AppText(r.body!, type: TextType.caption)],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          AppButton(
            label: context.t('park.addReview'),
            variant: ButtonVariant.tertiary,
            onPressed: () => context.push(parkRoute('/review', parkId, park.name)),
          ),
          AppButton(
            label: context.t('park.report'),
            variant: ButtonVariant.tertiary,
            onPressed: () => context.push(parkRoute('/report', parkId, park.name)),
          ),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.color, required this.children});
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Spacing.three),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.r16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}
