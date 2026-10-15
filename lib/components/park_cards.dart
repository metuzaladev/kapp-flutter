import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_client.dart';
import '../core/directions.dart';
import '../core/format.dart';
import '../core/haptics.dart';
import '../core/i18n/i18n.dart';
import '../core/logic/explore.dart';
import '../core/logic/home_activity.dart';
import '../core/query/hooks.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import '../hooks/community.dart';
import '../hooks/parks.dart';
import '../hooks/visits.dart';
import '../models/explore.dart';
import '../models/parks.dart';
import '../state/explore_view.dart';
import 'button.dart';
import 'icon.dart';
import 'list_row.dart';
import 'photo_tile.dart';
import 'pressable.dart';
import 'states.dart';
import 'text.dart';

const _features = ['fenced', 'water', 'smallDogArea', 'lighting'];

/// The tag stays one short line on the photo ("Aiaga · vesi"); the park page lists every feature.
String? featureTag(BuildContext context, Park park) {
  final on = {'fenced': park.fenced, 'water': park.water, 'smallDogArea': park.smallDogArea, 'lighting': park.lighting};
  final labels = [
    for (final (i, key) in _features.where((k) => on[k]!).take(2).indexed)
      i == 0 ? context.t('parkCard.tag.$key') : context.t('parkCard.tag.$key').toLowerCase(),
  ];
  return labels.isEmpty ? null : labels.join(' · ');
}

/// Figma "Park Card" (4:39): photo with a feature tag and a favourite heart, name with ★ rating,
/// "1,2 km · 6 koera praegu", and friends in the park (up to three faces + "3 sõpra pargis").
/// Parts without data are hidden, never faked. Two screen-reader elements: the card and the heart.
class ParkCard extends HookWidget {
  const ParkCard({super.key, required this.park, this.rating});
  final Park park;

  /// Only the park detail API has ratings; lists pass nothing and the ★ is hidden.
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tag = featureTag(context, park);
    final dogs = park.activeDogs ?? 0;
    // No dogs → nobody can be there; skip the visitors request.
    final friends = useFriendsInPark(park.id, enabled: dogs > 0);
    final favorites = useFavoriteParks();
    final toggle = useToggleFavorite(park.id);
    final savedFavorite = favorites.data?.any((p) => p.id == park.id) ?? false;
    // Optimistic: show the requested state while the request runs.
    final isFavorite = toggle.isPending && toggle.variables != null ? toggle.variables! : savedFavorite;

    final presence = dogs > 0
        ? context.t('parkRow.dogsNow', params: {'dogs': dogsLabel(dogs)})
        : context.t('parkRow.quiet');
    final subtitle = [?formatKm(park.distanceKm), presence].join(' · ');
    final friendsText = friends.isNotEmpty ? friendsInParkLabel(friends.length) : null;
    final ratingText = rating == null ? null : formatRating(rating!);
    final label = [
      park.name,
      if (ratingText != null) context.t('parkCard.ratingA11y', params: {'rating': ratingText}),
      subtitle,
      ?tag,
      ?friendsText,
    ].join(', ');

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.r16),
        border: Border.all(color: c.border),
      ),
      child: Stack(
        children: [
          Pressable(
            semanticLabel: label,
            semanticHint: context.t('parkRow.hint'),
            onPressed: () => context.push('/parks/${park.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 140,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Parks have no photos in the API yet: the same licensed placeholder as the park page.
                          Image.asset('assets/images/park-placeholder.jpg', fit: BoxFit.cover),
                          if (tag != null)
                            Positioned(
                              top: 10,
                              left: 10,
                              right: 60,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.only(left: Spacing.two, right: 10, top: 5, bottom: 5),
                                  decoration: BoxDecoration(
                                    color: c.mapPark,
                                    borderRadius: BorderRadius.circular(Radii.full),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AppIcon(IconName.trees, size: 14, color: c.mapPinInk),
                                      const SizedBox(width: 6),
                                      // White on map.park is 4.1 : 1, so the tag uses Label (15 pt bold) = large text.
                                      Flexible(
                                        child: AppText(tag, type: TextType.label, color: c.mapPinInk, maxLines: 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.two),
                  Row(
                    children: [
                      Expanded(child: AppText(park.name, type: TextType.heading)),
                      if (ratingText != null) ...[
                        AppIcon(IconName.star, size: 14, color: c.accent),
                        const SizedBox(width: Spacing.one),
                        AppText(ratingText, type: TextType.caption),
                      ],
                    ],
                  ),
                  const SizedBox(height: Spacing.two),
                  AppText(subtitle, type: TextType.caption, themeColor: TextColor.muted),
                  if (friendsText != null) ...[
                    const SizedBox(height: Spacing.two),
                    Row(
                      children: [
                        SizedBox(
                          width: 26 + (friends.take(3).length - 1) * 18,
                          height: 26,
                          child: Stack(
                            children: [
                              for (final (i, f) in friends.take(3).indexed)
                                Positioned(
                                  left: i * 18.0,
                                  child: PhotoTile(
                                    // Visitors' dog photos are not in the API (only names): the dog's initial stands in.
                                    name: f.dogs.isNotEmpty ? f.dogs.first.name : f.ownerFirstName,
                                    size: 26,
                                    radius: 8,
                                    border: (width: 2, color: c.surface),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Spacing.two),
                        AppText(friendsText, type: TextType.caption, color: c.accent),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 34 pt circle as in Figma; the padding makes the touch target 44 pt.
          Positioned(
            top: 17,
            right: 17,
            child: Pressable(
              semanticLabel: isFavorite ? context.t('park.favoriteRemove') : context.t('park.favoriteAdd'),
              selected: isFavorite,
              dimWhenDisabled: false,
              onPressed: toggle.isPending
                  ? null
                  : () {
                      haptic(HapticReason.selection);
                      toggle.mutate(!isFavorite);
                    },
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: AppIcon(
                    isFavorite ? IconName.heartFilled : IconName.heart,
                    size: 18,
                    color: isFavorite ? c.brand : c.text,
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

/// Figma "Lähim park" card (Home / Today and Explore / Map): photo, name, "0,4 km · 6 koera" and one
/// main action that follows the distance (core/logic/home_activity.dart): within 300 m "Oleme siin",
/// further "Juhata kohale", without the real position "Vaata parki", already checked in "Oled siin".
class NearestParkCard extends HookWidget {
  const NearestParkCard({super.key, required this.park, required this.usingFallback, this.floating = false});
  final Park park;
  final bool usingFallback;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final active = useActiveCheckIn().data;
    final action = nearestParkAction(
      checkedInHere: active?.park.id == park.id,
      distanceKm: park.distanceKm,
      usingFallback: usingFallback,
    );
    final dogs = park.activeDogs ?? 0;
    final meta = [?formatKm(park.distanceKm), dogs > 0 ? dogsLabel(dogs) : context.t('parkRow.quiet')].join(' · ');
    void openPark() => context.push('/parks/${park.id}');
    final (label, hint, onPressed) = switch (action) {
      NearestParkAction.here => (context.t('nearestPark.hereNow'), context.t('parkRow.hint'), openPark),
      NearestParkAction.checkIn => (
        context.t('park.checkIn'),
        context.t('nearestPark.checkInHint', params: {'name': park.name}),
        () => context.push(
          Uri(path: '/check-in', queryParameters: {'parkId': park.id, 'parkName': park.name}).toString(),
        ),
      ),
      NearestParkAction.directions => (
        context.t('park.directions'),
        context.t('nearestPark.directionsHint'),
        () => openDirections(name: park.name, lat: park.lat, lng: park.lng),
      ),
      NearestParkAction.open => (context.t('nearestPark.open'), context.t('parkRow.hint'), openPark),
    };
    // Brand fill only for the action Figma highlights (check in); the others are secondary.
    final primary = action == NearestParkAction.checkIn;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.r16),
        border: Border.all(color: c.border),
        boxShadow: floating ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))] : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              semanticLabel: '${context.t('nearestPark.label')}: ${park.name}, $meta',
              semanticHint: context.t('parkRow.hint'),
              onPressed: openPark,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/images/park-placeholder.jpg', width: 62, height: 50, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(park.name, type: TextType.heading),
                        AppText(
                          '${context.t('nearestPark.label')} · $meta',
                          type: TextType.caption,
                          themeColor: TextColor.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.4),
            child: Pressable(
              semanticLabel: label,
              semanticHint: hint,
              onPressed: onPressed,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.three, vertical: Spacing.two),
                decoration: BoxDecoration(color: primary ? c.brand : c.soft, borderRadius: BorderRadius.circular(14)),
                // Shrink-wraps the label (no fixed width: "Мы здесь" / "Проложить маршрут").
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: textStyle(TextType.label, color: primary ? c.onBrand : c.text),
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

/// M11 Home "Lemmikparkides täna" (docs/18): for each favourite park (or the two nearest parks when
/// there are none) the dogs there now and today's planned visits by part of day, with friends named.
class ParkActivitySection extends StatelessWidget {
  const ParkActivitySection({super.key, required this.query, required this.source, required this.loading});
  final QueryResult<ParkActivityResponse> query;
  final ActivitySource source;
  final bool loading;

  String _lines(BuildContext context, ParkActivity park) {
    final out = [
      park.activeDogs > 0
          ? context.t('home.activity.now', params: {'dogs': dogsLabel(park.activeDogs)})
          : context.t('home.activity.nowQuiet'),
      for (final p in plannedParts(park.planned))
        context.t(
          'home.activity.planned',
          params: {'part': context.t('home.activity.parts.${p.part.name}'), 'visits': plannedVisitsLabel(p.count)},
        ),
    ];
    if (park.friends.isNotEmpty) {
      out.add(
        context.t(
          'home.activity.friends',
          count: park.friends.length,
          params: {'names': formatList(park.friends.map((f) => f.firstName).toList())},
        ),
      );
    } else if (isQuiet(park)) {
      out.add(context.t('home.activity.noPlans'));
    }
    return out.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final parks = query.data?.parks ?? const <ParkActivity>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          source == ActivitySource.favorites || loading
              ? context.t('home.activity.title')
              : context.t('home.activity.titleNearby'),
          type: TextType.heading,
          header: true,
        ),
        const SizedBox(height: Spacing.two),
        if (loading) const SkeletonList(rows: 2, rowHeight: 88),
        if (!loading && query.error != null && parks.isEmpty)
          ErrorState(message: errorMessage(query.error), onRetry: query.refetch, retrying: query.isFetching),
        for (final (i, park) in parks.indexed) ...[
          Entering(
            index: i,
            child: ListRow(
              icon: IconName.trees,
              title: park.name,
              subtitle: _lines(context, park),
              onPressed: () => context.push('/parks/${park.id}'),
              hint: context.t('parkRow.hint'),
            ),
          ),
          const SizedBox(height: Spacing.two),
        ],
        if (!loading)
          source == ActivitySource.nearby
              // No favourites yet: the useful next step is choosing favourites.
              ? EmptyState(
                  title: context.t('home.activity.noFavorites'),
                  body: context.t('home.activity.noFavoritesBody'),
                  actionLabel: context.t('home.activity.addFavorite'),
                  actionHint: context.t('home.activity.addFavoriteHint'),
                  onAction: () => context.push('/parks'),
                )
              : AppButton(
                  label: context.t('home.activity.manageFavorites'),
                  variant: ButtonVariant.tertiary,
                  onPressed: () => context.push('/favorites'),
                ),
      ],
    );
  }
}

/// M11 Home "Kogukonna soovitused" (docs/18): the three newest approved place posts near the user as
/// compact rows and "Vaata kõiki" to the Avasta feed.
class CommunityPicks extends StatelessWidget {
  const CommunityPicks({super.key, required this.posts, required this.loading, this.error, required this.onSuggest});
  final List<PlacePost> posts;
  final bool loading;

  /// Set when the feed failed and nothing is cached.
  final ({String message, VoidCallback retry, bool retrying})? error;
  final VoidCallback onSuggest;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(context.t('home.picks.title'), type: TextType.heading, header: true),
        const SizedBox(height: Spacing.two),
        if (loading) const SkeletonList(rows: 3, rowHeight: 72),
        if (error != null) ErrorState(message: error!.message, onRetry: error!.retry, retrying: error!.retrying),
        if (!loading && error == null && posts.isEmpty)
          EmptyState(
            title: context.t('home.picks.empty'),
            body: context.t('home.picks.emptyBody'),
            actionLabel: context.t('home.picks.suggest'),
            onAction: onSuggest,
          ),
        for (final (i, post) in posts.indexed) ...[
          Entering(
            index: i,
            child: Builder(
              builder: (context) {
                final category = context.t('explore.categories.${post.category.name}');
                final meta = [
                  ?formatKm(post.distanceKm),
                  context.t('home.picks.by', params: {'name': post.authorFirstName}),
                ].join(' · ');
                final likes = context.t('explore.post.likes', count: post.likeCount);
                return Pressable(
                  semanticLabel: [post.name, category, meta, likes].join(', '),
                  semanticHint: context.t('home.picks.openHint'),
                  onPressed: () => context.push('/place-posts/${post.id}'),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.r16),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        PhotoTile(url: post.photos.firstOrNull?.thumbnailUrl, name: post.name, size: 56, radius: 14),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(post.name, type: TextType.label, maxLines: 2),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  CategoryPill(category: post.category, label: category, small: true),
                                  AppText(meta, type: TextType.caption, themeColor: TextColor.muted),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        AppIcon(post.liked ? IconName.heartFilled : IconName.heart, size: 16, color: c.brand),
                        const SizedBox(width: 4),
                        AppText(formatNumber(post.likeCount), type: TextType.caption),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Spacing.two),
        ],
        if (posts.isNotEmpty)
          AppButton(
            label: context.t('home.picks.seeAll'),
            variant: ButtonVariant.tertiary,
            hint: context.t('explore.communityEntryHint'),
            onPressed: () {
              // Opens the Kaart tab on its Avasta half, without a new screen.
              setExploreView(ExploreView.feed);
              context.go('/map');
            },
          ),
      ],
    );
  }
}

/// The category pill of a place post (same `map*` colour as its pin on the map).
class CategoryPill extends StatelessWidget {
  const CategoryPill({super.key, required this.category, required this.label, this.small = false});
  final PlaceCategory category;
  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final kind = switch (category) {
      PlaceCategory.cafe => c.mapCafe,
      PlaceCategory.park => c.mapPark,
      PlaceCategory.beach => c.mapBeach,
      PlaceCategory.shop || PlaceCategory.other => c.mapService,
    };
    return Container(
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
          : const EdgeInsets.only(left: 10, right: 12, top: 6, bottom: 6),
      decoration: BoxDecoration(color: kind, borderRadius: BorderRadius.circular(Radii.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(placeCategoryIcon[category]!, size: small ? 12 : 16, color: c.mapPinInk),
          SizedBox(width: small ? 4 : 6),
          Text(label, style: textStyle(TextType.caption, color: c.mapPinInk)),
        ],
      ),
    );
  }
}
