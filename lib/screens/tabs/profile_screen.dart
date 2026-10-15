import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/icon.dart';
import '../../components/list_row.dart';
import '../../components/screen.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/i18n/i18n.dart';
import '../../core/logic/rewards.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../hooks/community.dart';
import '../../hooks/dogs.dart';
import '../../hooks/services.dart';
import '../../hooks/visits.dart';

/// Figma 07 / Profile / Overview: greeting, counts and the user's areas. Account settings (edit
/// profile, language, sign out) live on the Settings screen like in Figma.
class ProfileScreen extends HookWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = useOwnProfile();
    final profile = me.data;
    final dogs = useMyDogs().data;
    final visits = useVisitHistory().data;
    final incoming = useFriendRequests().data?.incoming.length ?? 0;
    final upcomingBookings = useBookings('upcoming').data?.length ?? 0;
    final unreadMessages = (useConversations().data ?? const []).fold<int>(0, (sum, conv) => sum + conv.unreadCount);
    final rewards = useRewards().data;
    final firstName = profile?.name.split(' ').first;
    final stats = dogs != null && visits != null
        ? context.t('profile.stats', params: {'dogs': dogsLabel(dogs.length), 'visits': visitsLabel(visits.length)})
        : null;

    return AppScreen(
      title: firstName != null
          ? context.t('profile.greeting', params: {'name': firstName})
          : context.t('profile.greetingNoName'),
      // Dog names are never declined, so the count decides.
      subtitle: context.t('profile.subtitle', count: dogs?.length ?? 0),
      onRefresh: me.refetch,
      children: [
        if (me.error != null && profile == null) FormError(errorMessage(me.error)),
        if (profile != null)
          Container(
            padding: const EdgeInsets.all(Spacing.three),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.r16),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(profile.name, type: TextType.heading),
                AppText(profile.email, type: TextType.caption, themeColor: TextColor.muted),
                if (profile.area != null) AppText(profile.area!, type: TextType.caption),
                if (profile.bio != null) AppText(profile.bio!),
                AppText(
                  context.t(
                    'profile.presence',
                    params: {'who': context.t('profile.presenceWho.${profile.presenceSharing.name}')},
                  ),
                  type: TextType.caption,
                  themeColor: TextColor.muted,
                ),
                if (stats != null) AppText(stats, type: TextType.label),
              ],
            ),
          ),
        ListRow(
          title: context.t('profile.myDogs'),
          subtitle: dogs == null ? null : (dogs.isNotEmpty ? dogs.map((d) => d.name).join(', ') : dogsLabel(0)),
          showPhoto: dogs?.isNotEmpty ?? false,
          photoUrl: dogs?.firstOrNull?.profilePhoto?.thumbnailUrl,
          photoName: dogs?.firstOrNull?.name,
          icon: dogs?.isNotEmpty ?? false ? null : IconName.dog,
          onPressed: () => context.push('/dogs'),
        ),
        ListRow(
          icon: IconName.users,
          title: context.t('profile.friends'),
          subtitle: incoming > 0
              ? context.t('profile.friendRequests', count: incoming)
              : context.t('profile.friendsSub'),
          onPressed: () => context.push('/friends'),
        ),
        ListRow(
          icon: IconName.messageCircle,
          title: context.t('profile.messages'),
          subtitle: unreadMessages > 0
              ? context.t('profile.unreadMessages', count: unreadMessages)
              : context.t('profile.messagesSub'),
          onPressed: () => context.push('/messages'),
        ),
        ListRow(
          icon: IconName.calendar,
          title: context.t('profile.myVisits'),
          subtitle: context.t('profile.myVisitsSub'),
          onPressed: () => context.push('/visits'),
        ),
        // Figma "Minu broneeringud / Hooldus ja kohtumised" (M6).
        ListRow(
          icon: IconName.scissors,
          title: context.t('profile.bookings'),
          subtitle: upcomingBookings > 0
              ? context.t('profile.upcomingBookings', count: upcomingBookings)
              : context.t('profile.bookingsSub'),
          onPressed: () => context.push('/bookings'),
        ),
        // M9b: Käpad (balance + level from the server), Pood and the user's recommendations.
        ListRow(
          icon: IconName.pawPrint,
          title: context.t('profile.rewards'),
          subtitle: rewards != null
              ? context.t(
                  'profile.rewardsSub',
                  params: {'paws': pawsLabel(rewards.balance), 'level': context.t(levelNameKey(rewards.level.id))},
                )
              : context.t('profile.rewardsSubEmpty'),
          onPressed: () => context.push('/rewards'),
        ),
        ListRow(
          icon: IconName.store,
          title: context.t('profile.shop'),
          subtitle: context.t('profile.shopSub'),
          onPressed: () => context.push('/shop'),
        ),
        ListRow(
          icon: IconName.sparkles,
          title: context.t('profile.myPosts'),
          subtitle: context.t('profile.myPostsSub'),
          onPressed: () => context.push('/place-posts/mine'),
        ),
        ListRow(
          icon: IconName.heart,
          title: context.t('profile.favorites'),
          subtitle: context.t('profile.favoritesSub'),
          onPressed: () => context.push('/favorites'),
        ),
        ListRow(
          icon: IconName.slidersHorizontal,
          title: context.t('profile.settings'),
          subtitle: context.t('profile.settingsSub'),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}
