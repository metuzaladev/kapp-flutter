import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_client.dart';
import '../core/format.dart';
import '../core/i18n/i18n.dart';
import '../core/logic/explore.dart';
import '../core/logic/map_search.dart';
import '../core/logic/rewards.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import '../hooks/device_location.dart';
import '../hooks/explore.dart';
import '../hooks/services.dart';
import '../models/explore.dart';
import '../state/explore_view.dart';
import 'banners.dart';
import 'chip.dart';
import 'icon.dart';
import 'place_post_card.dart';
import 'pressable.dart';
import 'screen.dart';
import 'segmented_control.dart';
import 'states.dart';
import 'text.dart';

/// Kept for the session, so leaving for a post and coming back keeps the chosen chips.
FeedFilters _lastFilters = defaultFeedFilters;

/// Kaart / Avasta at the top of both halves of the Kaart tab.
class ExploreSwitch extends StatelessWidget {
  const ExploreSwitch({super.key, required this.value});
  final ExploreView value;

  @override
  Widget build(BuildContext context) => SegmentedControl<ExploreView>(
    semanticLabel: context.t('explore.switchLabel'),
    options: [
      (value: ExploreView.map, label: context.t('explore.switchMap')),
      (value: ExploreView.feed, label: context.t('explore.switchFeed')),
    ],
    value: value,
    onChanged: (v) {
      if (v != null) setExploreView(v);
    },
  );
}

/// Figma 09 / Explore / Avasta (84:7825), the feed half of the Kaart tab: the Kaart / Avasta switch,
/// filter chips (Lähedal, Kohvikud, Pargid, Rannad, Poed, Sõbrad), Place Post cards with infinite
/// paging, and the floating "Soovita kohta" button.
class ExploreFeed extends HookWidget {
  const ExploreFeed({super.key, required this.bottomInset});

  /// Space taken by the floating tab bar.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final location = useDeviceLocation();
    final filters = useState(_lastFilters);
    void setFilters(FeedFilters next) {
      _lastFilters = next;
      filters.value = next;
    }

    final feed = usePlacePostFeed(feedQueryParams(filters.value, location.origin));
    final rewards = useRewards();
    final earned = pointsFor(rewards.data, RewardReason.placePost);
    final actions = usePlacePostActions(context);
    final posts = [for (final p in feed.pages) ...p.items];
    final scroll = useScrollController();

    useEffect(() {
      void onScroll() {
        if (scroll.position.extentAfter < 600 && feed.hasNextPage && !feed.isFetchingNextPage) {
          unawaited(feed.fetchNextPage());
        }
      }

      scroll.addListener(onScroll);
      return () => scroll.removeListener(onScroll);
    }, [scroll, feed.hasNextPage, feed.isFetchingNextPage]);

    final header = <Widget>[
      AppText(context.t('explore.title'), type: TextType.title, header: true),
      AppText(context.t('explore.subtitle'), themeColor: TextColor.muted),
      const ExploreSwitch(value: ExploreView.feed),
      ChipRow(
        children: [
          IconChip(
            icon: IconName.navigation,
            label: context.t('explore.filters.near'),
            hint: location.usingFallback ? context.t('explore.filters.nearFallbackHint') : null,
            selected: filters.value.near,
            onPressed: () => setFilters(filters.value.copyWith(near: !filters.value.near)),
          ),
          for (final category in feedCategoryChips)
            IconChip(
              icon: placeCategoryIcon[category]!,
              label: context.t('explore.filters.${category.name}'),
              selected: filters.value.category == category,
              onPressed: () => setFilters(toggleCategory(filters.value, category)),
            ),
          IconChip(
            icon: IconName.users,
            label: context.t('explore.filters.friends'),
            selected: filters.value.friends,
            onPressed: () => setFilters(filters.value.copyWith(friends: !filters.value.friends)),
          ),
        ],
      ),
      const OfflineBanner(),
      if (feed.error != null && feed.data != null) FormError(errorMessage(feed.error)),
      if (feed.error != null && feed.data == null)
        ErrorState(message: errorMessage(feed.error), onRetry: feed.refetch, retrying: feed.isFetching),
      if (feed.isPending && feed.error == null) const SkeletonList(rows: 2, rowHeight: 420),
      if (feed.data != null && posts.isEmpty)
        EmptyState(
          title: filters.value.friends ? context.t('explore.emptyFriendsTitle') : context.t('explore.emptyTitle'),
          body: context.t('explore.emptyBody'),
          actionLabel: context.t('explore.suggest'),
          onAction: () => context.push('/suggest-place'),
        ),
    ];

    final items = [
      ...header,
      for (final (i, post) in posts.indexed)
        Entering(
          key: ValueKey(post.id),
          index: i,
          child: PlacePostCard(
            post: post,
            earnedPoints: earned,
            onOpen: () => context.push('/place-posts/${post.id}'),
            onShowOnMap: () => actions.showOnMap(post),
            onMore: () => actions.openMenu(post),
          ),
        ),
      if (feed.isFetchingNextPage) const SkeletonList(rows: 1, rowHeight: 420),
    ];

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          const PawBackground(),
          SafeArea(
            bottom: false,
            child: RefreshIndicator.adaptive(
              onRefresh: feed.refetch,
              color: c.brand,
              child: ListView.separated(
                controller: scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  Spacing.screen,
                  Spacing.three,
                  Spacing.screen,
                  bottomInset + 52 + Spacing.four,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Spacing.three),
                itemBuilder: (_, i) => items[i],
              ),
            ),
          ),
          // Figma floating "Soovita kohta" above the tab bar.
          Positioned(
            right: Spacing.screen,
            bottom: bottomInset,
            child: Pressable(
              semanticLabel: context.t('explore.suggest'),
              semanticHint: context.t('explore.suggestHint'),
              onPressed: () => context.push('/suggest-place'),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: Spacing.two),
                decoration: BoxDecoration(
                  color: c.brand,
                  borderRadius: BorderRadius.circular(Radii.r16),
                  boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 12, offset: Offset(0, 8))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(IconName.plus, size: 22, color: c.onBrand),
                    const SizedBox(width: Spacing.two),
                    AppText(context.t('explore.suggest'), type: TextType.label, color: c.onBrand),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Kogukonna soovitused" on the map: switches the tab to Avasta.
class CommunityEntry extends StatelessWidget {
  const CommunityEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      semanticLabel: context.t('explore.communityEntry'),
      semanticHint: context.t('explore.communityEntryHint'),
      onPressed: () => setExploreView(ExploreView.feed),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.three, vertical: Spacing.two),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
          boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 12, offset: Offset(0, 8))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(IconName.sparkles, size: 20, color: c.brand),
            const SizedBox(width: Spacing.two),
            Flexible(child: AppText(context.t('explore.communityEntry'), type: TextType.label)),
          ],
        ),
      ),
    );
  }
}

/// Suggestions under the Kaart search field (docs/19): the app's places first, then Estonian
/// addresses, each with an icon, the place's area and the distance. Tapping one moves the map there.
class SearchSuggestions extends StatelessWidget {
  const SearchSuggestions({
    super.key,
    required this.results,
    required this.loading,
    required this.addressesAvailable,
    required this.failed,
    required this.onSelect,
    required this.maxHeight,
  });

  final List<SearchResult>? results;
  final bool loading;
  final bool addressesAvailable;
  final bool failed;
  final ValueChanged<SearchResult> onSelect;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = results ?? const <SearchResult>[];
    final firstAddress = list.indexWhere((r) => r.kind == 'address');
    Widget status(Widget child) => Padding(padding: const EdgeInsets.all(Spacing.three), child: child);

    return Semantics(
      label: context.t('map.search.suggestions'),
      container: true,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.r16),
          border: Border.all(color: c.border),
          boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            for (final (index, r) in list.indexed) ...[
              if (index == firstAddress)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.three, Spacing.three, Spacing.three, Spacing.one),
                  child: Semantics(
                    header: true,
                    child: Text(
                      context.t('map.search.addresses').toUpperCase(),
                      style: textStyle(TextType.micro, color: c.muted).copyWith(letterSpacing: 0.4),
                    ),
                  ),
                ),
              if (index > 0 && index != firstAddress) Divider(height: 0.5, thickness: 0.5, color: c.border),
              Pressable(
                semanticLabel: [r.name, ?r.subtitle, if (r.distanceKm != null) formatKm(r.distanceKm)].join(', '),
                semanticHint: context.t('map.search.selectHint'),
                onPressed: () => onSelect(r),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.three, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: AppIcon(searchResultIcon(r.kind, r.category), size: 18, color: c.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(r.name, type: TextType.label, maxLines: 1),
                            if (r.subtitle != null)
                              AppText(r.subtitle!, type: TextType.caption, themeColor: TextColor.muted, maxLines: 1),
                          ],
                        ),
                      ),
                      if (r.distanceKm != null)
                        AppText(formatKm(r.distanceKm)!, type: TextType.caption, themeColor: TextColor.muted),
                    ],
                  ),
                ),
              ),
            ],
            if (loading && list.isEmpty)
              status(
                Row(
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.muted)),
                    const SizedBox(width: Spacing.two),
                    AppText(context.t('map.search.loading'), type: TextType.caption, themeColor: TextColor.muted),
                  ],
                ),
              ),
            if (!loading && !failed && list.isEmpty)
              status(AppText(context.t('map.search.empty'), type: TextType.caption, themeColor: TextColor.muted)),
            if (failed)
              status(AppText(context.t('map.search.failed'), type: TextType.caption, themeColor: TextColor.muted)),
            if (!failed && !addressesAvailable)
              status(
                AppText(
                  context.t('map.search.addressesUnavailable'),
                  type: TextType.caption,
                  themeColor: TextColor.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The search query is long enough to ask the API.
bool canSearch(String text) => searchableQuery(text) != null;
