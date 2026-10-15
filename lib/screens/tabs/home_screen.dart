import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/icon.dart';
import '../../components/list_row.dart';
import '../../components/park_cards.dart';
import '../../components/photo_tile.dart';
import '../../components/screen.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_client.dart';
import '../../core/format.dart';
import '../../core/i18n/i18n.dart';
import '../../core/logic/explore.dart';
import '../../core/logic/home_activity.dart';
import '../../core/logic/map_categories.dart';
import '../../core/query/hooks.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../hooks/community.dart';
import '../../hooks/device_location.dart';
import '../../hooks/dogs.dart';
import '../../hooks/explore.dart';
import '../../hooks/parks.dart';
import '../../hooks/visits.dart';
import '../../state/park_filters.dart';

/// Figma 02 / Home / Today (10:69, M9 light redesign): "käpp" + Käpad badge, greeting, a dog photo,
/// current visit, the "Lähim park" card (main action by distance), M11 "Lemmikparkides täna", own
/// plans, friends' plans (M5), M11 "Kogukonna soovitused", health reminders and nearby parks.
class HomeScreen extends HookWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final session = useValueListenable(AuthClient.instance).session;
    final location = useDeviceLocation();
    // Same query key as the map tab, so both screens share one cached request.
    final nearby = useNearbyParks(location.origin, useStore(parkFilters));
    final activeQuery = useActiveCheckIn();
    final plansQuery = usePlannedVisits();
    final remindersQuery = useHealthReminders();
    final dogs = useMyDogs().data;
    final friendPlansQuery = useFriendPlans();
    final favoritesQuery = useFavoriteParks();
    final parks = nearby.data ?? const [];
    final active = activeQuery.data;
    final plans = plansQuery.data ?? const [];
    final reminders = remindersQuery.data ?? const [];
    final friendPlans = friendPlansQuery.data ?? const [];
    // M11: favourites decide the activity parks; until they are known nothing is asked.
    final activityTarget = activityParkIds(favoritesQuery.data, parks);
    final activityEnabled = favoritesQuery.isSuccess && activityTarget.ids.isNotEmpty;
    final activityQuery = useParkActivity(activityEnabled ? activityTarget.ids : const []);
    // Same feed as Avasta "Lähedal", a few rows only (own pending posts are filtered out).
    final feedQuery = usePlacePostFeed({
      ...feedQueryParams(defaultFeedFilters, location.origin),
      'limit': communityPicksCount + 2,
    });
    final picks = communityPicks(feedQuery.pages.firstOrNull?.items ?? const []);

    // Figma asks the dog ("Õue, Freddy?"); with several dogs (or none) the owner is greeted instead.
    final greetName = dogs?.length == 1 ? dogs!.first.name : session?.user.name.split(' ').first;
    final heroPhoto = dogs?.where((d) => d.profilePhoto != null).firstOrNull?.profilePhoto?.url;
    final nearestPark =
        parks.where((p) => parkKindOf(fenced: p.fenced, water: p.water) == PlaceKind.park).firstOrNull ??
        parks.firstOrNull;

    return AppScreen(
      onRefresh: () => refreshAll([
        nearby.refetch,
        activeQuery.refetch,
        plansQuery.refetch,
        remindersQuery.refetch,
        friendPlansQuery.refetch,
        favoritesQuery.refetch,
        activityQuery.refetch,
        feedQuery.refetch,
      ]),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand wordmark, not translated.
                  const ExcludeSemantics(
                    child: AppText('käpp', type: TextType.label, themeColor: TextColor.muted),
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    greetName != null
                        ? context.t('home.greeting', params: {'name': greetName})
                        : context.t('home.greetingNoName'),
                    type: TextType.title,
                    header: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.three),
            PointsBadge(onPressed: () => context.push('/rewards')),
          ],
        ),
        AppText(context.t('home.subtitle', params: {'date': formatToday()}), themeColor: TextColor.muted),
        const OfflineBanner(),
        const VerifyEmailBanner(),
        // Figma hero photo: the user's dog when it has a profile photo, otherwise the brand corgi.
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.r24),
            child: AspectRatio(
              aspectRatio: 342 / 120,
              child: heroPhoto != null
                  ? SignedImage(heroPhoto)
                  : Image.asset('assets/images/welcome-dog.jpg', fit: BoxFit.cover),
            ),
          ),
        ),
        if (active != null)
          Semantics(
            liveRegion: true,
            child: _Card(
              color: c.tint,
              children: [
                // Park names are never declined, so the name stands on its own line.
                AppText(context.t('home.activeTitle'), type: TextType.heading),
                AppText(active.park.name, type: TextType.label),
                AppText(
                  context.t(
                    'home.activeDogs',
                    params: {'dogs': active.dogs.map((d) => d.name).join(', '), 'time': formatTime(active.expiresAt)},
                  ),
                ),
                AppButton(
                  label: context.t('home.openPark'),
                  variant: ButtonVariant.secondary,
                  onPressed: () => context.push('/parks/${active.park.id}'),
                ),
              ],
            ),
          ),
        // The nearest dog park right under today's card — the main action of the app.
        if (nearestPark != null)
          NearestParkCard(park: nearestPark, usingFallback: location.usingFallback)
        else
          AppButton(label: context.t('home.findPark'), onPressed: () => context.go('/map')),
        // Hidden when favourites cannot be loaded: "no favourites yet" would be wrong then.
        if (!(favoritesQuery.isError && favoritesQuery.data == null))
          ParkActivitySection(
            query: activityQuery,
            source: activityTarget.source,
            loading: favoritesQuery.isPending || (activityEnabled && activityQuery.isPending),
          ),
        for (final (i, p) in plans.take(2).indexed)
          Entering(
            index: i,
            child: MergeSemantics(
              child: _Card(
                color: c.surface,
                children: [
                  AppText(p.park.name, type: TextType.label),
                  AppText(
                    context.t(
                      'home.planned',
                      params: {
                        'day': formatDay(p.startsAt),
                        'from': formatTime(p.startsAt),
                        'to': formatTime(p.endsAt),
                      },
                    ),
                    type: TextType.caption,
                    themeColor: TextColor.muted,
                  ),
                ],
              ),
            ),
          ),
        // Figma "Täna võiks koos mängida": friends' plans in the next 48 hours (M5).
        _Card(
          color: c.soft,
          children: [
            AppText(context.t('home.friendsPlansTitle'), type: TextType.heading),
            if (friendPlans.isEmpty) AppText(context.t('home.friendsPlansEmpty'), themeColor: TextColor.muted),
            for (final p in friendPlans.take(3))
              ListRow(
                title: p.parkName,
                showPhoto: true,
                photoName: p.friendFirstName,
                subtitle: context.t(
                  'home.friendPlan',
                  params: {
                    'name': p.friendFirstName,
                    'day': formatDay(p.startsAt),
                    'from': formatTime(p.startsAt),
                    'to': formatTime(p.endsAt),
                  },
                ),
                onPressed: () => context.push('/parks/${p.parkId}'),
              ),
            AppButton(
              label: context.t('home.findFriends'),
              variant: ButtonVariant.secondary,
              onPressed: () => context.push('/friends'),
            ),
          ],
        ),
        CommunityPicks(
          posts: picks,
          loading: feedQuery.isPending && feedQuery.error == null,
          error: feedQuery.error != null && feedQuery.data == null
              ? (
                  message: errorMessage(feedQuery.error),
                  retry: () => feedQuery.refetch(),
                  retrying: feedQuery.isFetching,
                )
              : null,
          onSuggest: () => context.push('/suggest-place'),
        ),
        if (reminders.isNotEmpty) ...[
          AppText(context.t('home.remindersTitle'), type: TextType.heading, header: true),
          for (final r in reminders.take(3))
            ListRow(
              title: '${r.dogName} · ${r.title}',
              subtitle: context.t(
                'home.reminderDue',
                params: {'date': formatDate(r.nextDue), 'due': dueLabel(r.nextDue)},
              ),
              showPhoto: true,
              photoUrl: dogs?.where((d) => d.id == r.dogId).firstOrNull?.profilePhoto?.thumbnailUrl,
              photoName: r.dogName,
              alert: r.overdue,
              onPressed: () => context.push('/dogs/${r.dogId}/health'),
            ),
        ],
        // Not on the Figma Home: without it the services were reachable only via Profile → bookings.
        ListRow(
          icon: IconName.scissors,
          title: context.t('home.servicesTitle'),
          subtitle: context.t('home.servicesSub'),
          onPressed: () => context.push('/services'),
        ),
        if (parks.isNotEmpty) ...[
          AppText(context.t('home.nearby'), type: TextType.heading, header: true),
          for (final (i, park) in parks.take(3).indexed)
            Entering(
              index: i,
              child: ParkCard(park: park),
            ),
          if (parks.length > 3)
            AppButton(
              label: context.t('home.allParks'),
              variant: ButtonVariant.tertiary,
              onPressed: () => context.push('/parks'),
            ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.color, required this.children});
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Spacing.four),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.r16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(height: Spacing.two), child],
      ],
    ),
  );
}
