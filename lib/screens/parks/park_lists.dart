import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/chip.dart';
import '../../components/icon.dart';
import '../../components/park_cards.dart';
import '../../components/screen.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/i18n/i18n.dart';
import '../../core/query/hooks.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../hooks/device_location.dart';
import '../../hooks/parks.dart';
import '../../state/park_filters.dart';

/// "Lähedal" shows only parks within walking distance (same rule as before M9).
const _nearRadiusKm = 2.0;

/// Figma 02 / Explore / Park List (10:227): "Pargid sinu ümber" with Park Cards and filter chips
/// Lähedal / Aktiivsed / Lemmikud (toggles, combinable). Also the accessible alternative to the map.
class ParkListScreen extends HookWidget {
  const ParkListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final location = useDeviceLocation();
    final filters = useStore(parkFilters);
    final nearby = useNearbyParks(location.origin, filters);
    final favorites = useFavoriteParks();
    final parks = nearby.data ?? const [];
    final activeOnly = useState(false);
    final favoritesOnly = useState(false);
    final nearOnly = filters.radiusKm == _nearRadiusKm;
    final favoriteIds = (favorites.data ?? const []).map((p) => p.id).toSet();
    final shown = parks
        .where(
          (p) => (!activeOnly.value || (p.activeDogs ?? 0) > 0) && (!favoritesOnly.value || favoriteIds.contains(p.id)),
        )
        .toList();

    return AppScreen(
      navBar: true,
      title: context.t('map.listTitle'),
      subtitle: context.t('map.count', count: shown.length),
      onRefresh: () => refreshAll([nearby.refetch, favorites.refetch]),
      children: [
        const OfflineBanner(),
        ChipRow(
          children: [
            IconChip(
              icon: IconName.navigation,
              label: context.t('map.near'),
              selected: nearOnly,
              onPressed: () => parkFilters.value = filters.copyWith(
                radiusKm: nearOnly ? defaultParkFilters.radiusKm : _nearRadiusKm,
              ),
            ),
            IconChip(
              icon: IconName.dog,
              label: context.t('map.active'),
              selected: activeOnly.value,
              onPressed: () => activeOnly.value = !activeOnly.value,
            ),
            IconChip(
              icon: IconName.heart,
              label: context.t('map.favorites'),
              selected: favoritesOnly.value,
              onPressed: () => favoritesOnly.value = !favoritesOnly.value,
            ),
          ],
        ),
        if (location.usingFallback)
          AppText(context.t('map.fallbackNote'), type: TextType.caption, themeColor: TextColor.muted),
        if (nearby.error != null && parks.isNotEmpty) FormError(errorMessage(nearby.error)),
        if (nearby.error != null && parks.isEmpty)
          ErrorState(message: errorMessage(nearby.error), onRetry: nearby.refetch, retrying: nearby.isFetching),
        if (nearby.isPending && nearby.error == null) const SkeletonList(rows: 3, rowHeight: 240),
        if (!nearby.isPending && nearby.error == null && shown.isEmpty)
          EmptyState(
            title: context.t('map.empty'),
            actionLabel: context.t('map.emptyAction'),
            onAction: () {
              activeOnly.value = false;
              favoritesOnly.value = false;
              parkFilters.value = defaultParkFilters;
            },
          ),
        for (final (i, park) in shown.indexed)
          Entering(
            key: ValueKey(park.id),
            index: i,
            child: ParkCard(park: park),
          ),
      ],
    );
  }
}

/// Figma 05 / Saved / Favorite Parks.
class FavoritesScreen extends HookWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = useFavoriteParks();
    final parks = favorites.data;
    return AppScreen(
      navBar: true,
      title: context.t('favorites.title'),
      subtitle: context.t('favorites.subtitle'),
      onRefresh: favorites.refetch,
      children: [
        const OfflineBanner(),
        if (favorites.error != null && parks == null)
          ErrorState(
            message: errorMessage(favorites.error),
            onRetry: favorites.refetch,
            retrying: favorites.isFetching,
          ),
        if (favorites.isPending && favorites.error == null) const SkeletonList(),
        if (parks?.isEmpty ?? false) EmptyState(title: context.t('favorites.empty')),
        for (final (i, park) in (parks ?? const []).indexed)
          Entering(
            key: ValueKey(park.id),
            index: i,
            child: ParkCard(park: park),
          ),
        if (parks != null)
          AppButton(
            label: context.t('favorites.explore'),
            variant: ButtonVariant.secondary,
            onPressed: () => context.go('/map'),
          ),
      ],
    );
  }
}

const _distances = [1.0, 5.0, 10.0];
const _features = ['smallDogArea', 'water', 'lighting', 'fenced'];

/// Figma 02 / Explore / Filters, presented as a modal. Edits a local draft and applies it on
/// "Näita parke", so the map behind does not refetch on every toggle.
class ParkFiltersScreen extends HookWidget {
  const ParkFiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final draft = useState(parkFilters.value);
    bool on(String key) => switch (key) {
      'fenced' => draft.value.fenced,
      'smallDogArea' => draft.value.smallDogArea,
      'water' => draft.value.water,
      _ => draft.value.lighting,
    };
    void toggle(String key, bool v) => draft.value = switch (key) {
      'fenced' => draft.value.copyWith(fenced: v),
      'smallDogArea' => draft.value.copyWith(smallDogArea: v),
      'water' => draft.value.copyWith(water: v),
      _ => draft.value.copyWith(lighting: v),
    };

    return AppScreen(
      navBar: true,
      navTitle: context.t('nav.filters'),
      title: context.t('filters.title'),
      subtitle: context.t('filters.subtitle'),
      children: [
        AppText(context.t('filters.features'), type: TextType.heading),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.r16),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Column(
            children: [
              for (final (i, key) in _features.indexed) ...[
                if (i > 0) Divider(height: 0.5, thickness: 0.5, color: c.border),
                MergeSemantics(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.three),
                    child: Row(
                      children: [
                        Expanded(child: AppText(context.t('filters.$key'), type: TextType.label)),
                        Switch.adaptive(value: on(key), onChanged: (v) => toggle(key, v), activeTrackColor: c.brand),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        AppText(context.t('filters.distance'), type: TextType.heading),
        Row(
          children: [
            for (final (i, km) in _distances.indexed) ...[
              if (i > 0) const SizedBox(width: Spacing.two),
              Expanded(
                child: AppChip(
                  label: formatKm(km)!,
                  selected: draft.value.radiusKm == km,
                  onPressed: () => draft.value = draft.value.copyWith(radiusKm: km),
                ),
              ),
            ],
          ],
        ),
        AppButton(
          label: context.t('filters.apply'),
          onPressed: () {
            parkFilters.value = draft.value;
            context.pop();
          },
        ),
        AppButton(
          label: context.t('filters.clear'),
          variant: ButtonVariant.tertiary,
          onPressed: () => draft.value = defaultParkFilters,
        ),
      ],
    );
  }
}
