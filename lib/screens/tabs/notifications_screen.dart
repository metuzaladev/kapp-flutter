import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/chip.dart';
import '../../components/icon.dart';
import '../../components/list_row.dart';
import '../../components/screen.dart';
import '../../components/states.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/i18n/i18n.dart';
import '../../core/logic/rewards.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../hooks/community.dart';
import '../../models/community.dart';
import '../../models/explore.dart';

enum _Filter { all, friends, messages }

const _filterIcon = {
  _Filter.all: IconName.layers,
  _Filter.friends: IconName.users,
  _Filter.messages: IconName.messageCircle,
};
const _friendTypes = ['friend_request', 'friend_accepted', 'friend_plan'];
const _rewardTypes = ['reward_level_up', 'reward_badge', 'place_post_approved'];

/// Booking (M6) and Käpad (M9b) rows only show under "Kõik": they are neither friends nor messages.
bool _matches(AppNotification n, _Filter filter) => switch (filter) {
  _Filter.all => true,
  _Filter.messages => n.type == 'message',
  _Filter.friends => _friendTypes.contains(n.type),
};

/// Figma 06 / Notifications / Activity: the feed, rendered in the app's language from type + data.
class NotificationsScreen extends HookWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final feed = useNotificationFeed();
    final unread = useUnreadCount();
    final markRead = useMarkNotificationRead();
    final markAll = useMarkAllNotificationsRead();
    final filter = useState(_Filter.all);
    final items = [
      for (final p in feed.pages)
        for (final n in p.items)
          if (_matches(n, filter.value)) n,
    ];

    ({String title, String subtitle}) text(AppNotification n) {
      final name = n.actor?.firstName ?? context.t('notifications.someone');
      final when = formatMessageTime(n.createdAt);
      final d = n.data;
      switch (n.type) {
        case 'friend_request':
          return (
            title: context.t('notifications.friendRequest'),
            subtitle: '${context.t('notifications.friendRequestBody', params: {'name': name})} · $when',
          );
        case 'friend_accepted':
          return (title: context.t('notifications.friendAccepted', params: {'name': name}), subtitle: when);
        case 'message':
          return (
            title: context.t('notifications.message', params: {'name': name}),
            subtitle: '${d['preview'] ?? ''} · $when',
          );
        case 'friend_plan':
          return (
            title: context.t('notifications.friendPlan', params: {'name': name}),
            subtitle: d['startsAt'] != null && d['endsAt'] != null
                ? '${d['parkName'] ?? ''} · ${formatDay(d['startsAt']!)} ${formatTime(d['startsAt']!)}–${formatTime(d['endsAt']!)}'
                : d['parkName'] ?? '',
          );
        case 'booking_confirmed' || 'booking_cancelled' || 'booking_reminder':
          final key = switch (n.type) {
            'booking_confirmed' => 'notifications.bookingConfirmed',
            'booking_cancelled' => 'notifications.bookingCancelled',
            _ => 'notifications.bookingReminder',
          };
          return (
            title: context.t(key),
            subtitle: context.t(
              'notifications.bookingBody',
              params: {
                'service': d['serviceName'] ?? '',
                'provider': d['providerName'] ?? '',
                'when': d['startsAt'] != null ? '${formatDay(d['startsAt']!)} ${formatTime(d['startsAt']!)}' : '',
              },
            ),
          );
        // M9b Käpad rows; names come from ids, amounts from the server.
        case 'reward_level_up':
          final level = d['levelId'] == null ? '' : context.t(levelNameKey(RewardLevelId.parse(d['levelId']!)));
          return (title: context.t('notifications.levelUp'), subtitle: '$level · $when');
        case 'reward_badge':
          final badge = d['badgeId'] == null ? '' : context.t(badgeNameKey(RewardBadgeId.parse(d['badgeId']!)));
          return (title: context.t('notifications.badge'), subtitle: '$badge · $when');
        case 'place_post_approved':
          final points = int.tryParse(d['points'] ?? '');
          return (
            title: context.t('notifications.postApproved'),
            subtitle: [
              ?d['placeName'],
              if (points != null && points > 0)
                context.t('notifications.postApprovedPoints', params: {'paws': pawsLabel(points)}),
              when,
            ].join(' · '),
          );
        default:
          return (title: name, subtitle: when);
      }
    }

    void open(AppNotification n) {
      if (n.readAt == null) markRead.mutate(n.id);
      final d = n.data;
      if (n.type == 'place_post_approved' && d['postId'] != null) {
        context.push('/place-posts/${d['postId']}');
      } else if (n.type == 'reward_level_up' || n.type == 'reward_badge') {
        context.push('/rewards');
      } else if (d['bookingId'] != null) {
        context.push('/bookings');
      } else if (n.type == 'message' && d['conversationId'] != null) {
        context.push('/messages/${d['conversationId']}');
      } else if (n.type == 'friend_request') {
        context.push('/friends');
      } else if (n.type == 'friend_plan' && d['parkId'] != null) {
        context.push('/parks/${d['parkId']}');
      } else if (n.actor != null) {
        context.push('/users/${n.actor!.id}');
      }
    }

    return AppScreen(
      title: context.t('notifications.title'),
      subtitle: context.t('notifications.subtitle'),
      onRefresh: () => refreshAll([feed.refetch, unread.refetch]),
      children: [
        const OfflineBanner(),
        ChipRow(
          children: [
            for (final f in _Filter.values)
              IconChip(
                radio: true,
                icon: _filterIcon[f]!,
                label: context.t('notifications.filters.${f.name}'),
                selected: filter.value == f,
                onPressed: () => filter.value = f,
              ),
          ],
        ),
        if ((unread.data ?? 0) > 0)
          AppButton(
            label: context.t('notifications.markAll'),
            variant: ButtonVariant.tertiary,
            loading: markAll.isPending,
            onPressed: () => markAll.mutate(null),
          ),
        if (feed.error != null && feed.data == null)
          ErrorState(message: errorMessage(feed.error), onRetry: feed.refetch, retrying: feed.isFetching),
        if (feed.isPending && feed.error == null) const SkeletonList(),
        if (feed.data != null && items.isEmpty) EmptyState(title: context.t('notifications.body')),
        for (final (i, n) in items.indexed)
          Entering(
            key: ValueKey(n.id),
            index: i,
            child: Builder(
              builder: (context) {
                final t = text(n);
                return ListRow(
                  title: t.title,
                  subtitle: t.subtitle,
                  // People get their initial; bookings the scissors, Käpad rows a trophy / sparkles.
                  showPhoto: n.actor != null,
                  photoName: n.actor?.firstName,
                  icon: n.actor != null
                      ? null
                      : _rewardTypes.contains(n.type)
                      ? (n.type == 'place_post_approved' ? IconName.sparkles : IconName.trophy)
                      : IconName.scissors,
                  hint: n.readAt == null ? context.t('notifications.unreadHint') : null,
                  leading: ExcludeSemantics(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: n.readAt == null ? c.brand : Colors.transparent,
                        borderRadius: BorderRadius.circular(Radii.full),
                      ),
                    ),
                  ),
                  onPressed: () => open(n),
                );
              },
            ),
          ),
        if (feed.hasNextPage)
          AppButton(
            label: context.t('notifications.more'),
            variant: ButtonVariant.secondary,
            loading: feed.isFetchingNextPage,
            onPressed: feed.fetchNextPage,
          ),
      ],
    );
  }
}
