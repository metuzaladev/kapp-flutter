import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/api/api_client.dart';
import '../core/query/hooks.dart';
import '../core/query/query_client.dart';
import '../core/realtime.dart';
import '../models/community.dart';
import '../models/json.dart';
import '../models/profile.dart';
import '../models/visits.dart';
import 'visits.dart';

/// Friends, requests, people search, profiles and friends' plans. Every change to a relation
/// invalidates the whole ['friends'] and ['users'] tree (one tap changes several lists).
class FriendKeys {
  static const all = ['friends'];
  static const list = ['friends', 'list'];
  static const requests = ['friends', 'requests'];
  static const plans = ['friends', 'plans'];
}

class UserKeys {
  static const all = ['users'];
  static QueryKey search(String q) => ['users', 'search', q];
  static QueryKey profile(String userId) => ['users', 'profile', userId];
}

class ConversationKeys {
  static const all = ['conversations'];
  static const list = ['conversations', 'list'];
  static QueryKey detail(String id) => ['conversations', 'detail', id];
  static QueryKey messages(String id) => ['conversations', 'messages', id];
}

class NotificationKeys {
  static const all = ['notifications'];
  static const feed = ['notifications', 'feed'];
  static const unread = ['notifications', 'unread'];
  static const preferences = ['notification-preferences'];
}

const ownProfileKey = ['me'];
const blocksKey = ['blocks'];

/// Fallback when the socket is down (docs/12): an open conversation refetches every 15 s.
const _pollInterval = Duration(seconds: 15);

QueryResult<List<Friend>> useFriends() =>
    useQuery(FriendKeys.list, () async => listOf(await apiGet<List<Object?>>('/me/friends'), Friend.fromJson));

QueryResult<FriendRequests> useFriendRequests() => useQuery(
  FriendKeys.requests,
  () async => FriendRequests.fromJson(await apiGet<Json>('/me/friend-requests')),
  staleTime: const Duration(seconds: 30),
);

QueryResult<List<FriendPlan>> useFriendPlans() => useQuery(
  FriendKeys.plans,
  () async => listOf(await apiGet<List<Object?>>('/me/friends/plans'), FriendPlan.fromJson),
);

/// Search starts at 3 letters (the API's minimum); the caller debounces typing.
QueryResult<List<UserSearchResult>> useUserSearch(String query) {
  final q = query.trim();
  return useQuery(
    UserKeys.search(q),
    () async => listOf(await apiGet<List<Object?>>('/users/search', {'q': q}), UserSearchResult.fromJson),
    enabled: q.length >= userSearchMin,
    staleTime: const Duration(seconds: 30),
  );
}

QueryResult<UserProfile> useUserProfile(String userId) =>
    useQuery(UserKeys.profile(userId), () async => UserProfile.fromJson(await apiGet<Json>('/users/$userId')));

void _invalidateRelations() {
  queryClient.invalidateQueries(FriendKeys.all);
  queryClient.invalidateQueries(UserKeys.all);
  queryClient.invalidateQueries(ConversationKeys.all);
}

/// Returns 'pending' or 'accepted' (the other person had already asked — asking back accepts).
MutationHandle<String, String> useSendFriendRequest() => useMutation<String, String>(
  (userId) async => (await apiSend<Json>('POST', '/me/friend-requests', {'userId': userId}))['status']! as String,
  onSuccess: (_, _) => _invalidateRelations(),
);

MutationHandle<String, void> useAcceptFriendRequest() => useMutation<String, void>(
  (userId) => apiSend<void>('POST', '/me/friend-requests/$userId/accept'),
  onSuccess: (_, _) => _invalidateRelations(),
);

/// Decline an incoming or cancel an outgoing request.
MutationHandle<String, void> useDeleteFriendRequest() => useMutation<String, void>(
  (userId) => apiSend<void>('DELETE', '/me/friend-requests/$userId'),
  onSuccess: (_, _) => _invalidateRelations(),
);

MutationHandle<String, void> useRemoveFriend() => useMutation<String, void>(
  (userId) => apiSend<void>('DELETE', '/me/friends/$userId'),
  onSuccess: (_, _) => _invalidateRelations(),
);

/// Friends who are in a park right now (Figma Park Card "3 sõpra pargis"): the park's visible
/// visitors intersected with the friends list. `enabled: false` skips the visitors request.
List<ParkVisitor> useFriendsInPark(String parkId, {bool enabled = true}) {
  final visitors = useParkVisitors(parkId, enabled: enabled);
  final friends = useFriends();
  return useMemoized(() {
    if (visitors.data == null || friends.data == null) return const <ParkVisitor>[];
    final ids = friends.data!.map((f) => f.id).toSet();
    return visitors.data!.visitors.where((v) => !v.isMe && ids.contains(v.userId)).toList();
  }, [visitors.data, friends.data]);
}

/* ---------- messages ---------- */

QueryResult<List<Conversation>> useConversations() {
  final live = useValueListenable(realtimeConnected);
  return useQuery(
    ConversationKeys.list,
    () async => listOf(await apiGet<List<Object?>>('/me/conversations'), Conversation.fromJson),
    refetchInterval: live ? null : _pollInterval,
  );
}

QueryResult<Conversation> useConversation(String id) => useQuery(
  ConversationKeys.detail(id),
  () async => Conversation.fromJson(await apiGet<Json>('/me/conversations/$id')),
);

/// Newest first, older pages with the `before` cursor.
InfiniteQueryResult<MessagePage> useMessages(String conversationId) {
  final live = useValueListenable(realtimeConnected);
  return useInfiniteQuery<MessagePage>(
    ConversationKeys.messages(conversationId),
    (cursor) async => MessagePage.fromJson(
      await apiGet<Json>('/me/conversations/$conversationId/messages', {'limit': 30, 'before': ?cursor}),
    ),
    (last) => last.nextCursor,
    refetchInterval: live ? null : _pollInterval,
  );
}

/// Puts a message into the cached first page (from the socket or our own send), without duplicates.
void addMessageToCache(Message message) {
  final key = ConversationKeys.messages(message.conversationId);
  final data = queryClient.getQueryData<InfiniteData<MessagePage>>(key);
  if (data == null || data.pages.isEmpty || data.pages.any((p) => p.messages.any((m) => m.id == message.id))) return;
  final first = data.pages.first;
  queryClient.setQueryData<InfiniteData<MessagePage>>(
    key,
    (_) => data.copyWithPages([
      first.withMessages([message, ...first.messages]),
      ...data.pages.skip(1),
    ]),
  );
}

MutationHandle<String, Message> useSendMessage(String conversationId) => useMutation<String, Message>(
  (body) async =>
      Message.fromJson(await apiSend<Json>('POST', '/me/conversations/$conversationId/messages', {'body': body})),
  onSuccess: (message, _) {
    addMessageToCache(message);
    queryClient.invalidateQueries(ConversationKeys.list);
  },
);

MutationHandle<void, void> useMarkConversationRead(String conversationId) => useMutation<void, void>(
  (_) => apiSend<void>('PUT', '/me/conversations/$conversationId/read'),
  onSuccess: (_, _) {
    queryClient.invalidateQueries(ConversationKeys.list);
    queryClient.invalidateQueries(NotificationKeys.all);
  },
);

MutationHandle<String, Conversation> useStartConversation() => useMutation<String, Conversation>(
  (userId) async => Conversation.fromJson(await apiSend<Json>('POST', '/me/conversations', {'userId': userId})),
);

/// "Kutsu parki": opens (or creates) the conversation with a friend and sends the invitation text.
MutationHandle<({String userId, String body}), Message> useSendInvitation() =>
    useMutation<({String userId, String body}), Message>(
      (input) async {
        final conversation = Conversation.fromJson(
          await apiSend<Json>('POST', '/me/conversations', {'userId': input.userId}),
        );
        return Message.fromJson(
          await apiSend<Json>('POST', '/me/conversations/${conversation.id}/messages', {'body': input.body}),
        );
      },
      onSuccess: (message, _) {
        addMessageToCache(message);
        queryClient.invalidateQueries(ConversationKeys.list);
      },
    );

/* ---------- notifications ---------- */

/// `include=rewards` (M9b) adds reward_level_up, reward_badge and place_post_approved rows.
const _include = {'include': 'rewards'};

InfiniteQueryResult<NotificationPage> useNotificationFeed() => useInfiniteQuery<NotificationPage>(
  NotificationKeys.feed,
  (cursor) async =>
      NotificationPage.fromJson(await apiGet<Json>('/me/notifications', {..._include, 'before': ?cursor})),
  (last) => last.nextCursor,
);

/// The tab badge: pushed live over the socket, polled while it is down. Reward rows are not pushed,
/// so it polls slowly even while connected.
QueryResult<int> useUnreadCount({bool enabled = true}) {
  final live = useValueListenable(realtimeConnected);
  return useQuery(
    NotificationKeys.unread,
    () async => toInt((await apiGet<Json>('/me/notifications/unread-count', _include))['count']),
    refetchInterval: live ? const Duration(minutes: 5) : const Duration(minutes: 1),
    enabled: enabled,
  );
}

MutationHandle<String, void> useMarkNotificationRead() => useMutation<String, void>(
  (id) => apiSend<void>('PUT', '/me/notifications/$id/read'),
  onSuccess: (_, _) => queryClient.invalidateQueries(NotificationKeys.all),
);

MutationHandle<void, void> useMarkAllNotificationsRead() => useMutation<void, void>(
  (_) => apiSend<void>('PUT', '/me/notifications/read-all'),
  onSuccess: (_, _) => queryClient.invalidateQueries(NotificationKeys.all),
);

QueryResult<NotificationPreferences> useNotificationPreferences() => useQuery(
  NotificationKeys.preferences,
  () async => NotificationPreferences.fromJson(await apiGet<Json>('/me/notification-preferences')),
);

MutationHandle<NotificationPreferences, NotificationPreferences> useSaveNotificationPreferences() =>
    useMutation<NotificationPreferences, NotificationPreferences>(
      (p) async =>
          NotificationPreferences.fromJson(await apiSend<Json>('PUT', '/me/notification-preferences', p.toJson())),
      onSuccess: (saved, _) =>
          queryClient.setQueryData<NotificationPreferences>(NotificationKeys.preferences, (_) => saved),
    );

/* ---------- safety and own profile ---------- */

QueryResult<List<BlockedUser>> useBlockedUsers() =>
    useQuery(blocksKey, () async => listOf(await apiGet<List<Object?>>('/me/blocks'), BlockedUser.fromJson));

/// A block changes almost every social list, so everything social is refetched (M9b: place posts
/// and map pins of a blocked author disappear too).
void _invalidateSocial() {
  for (final key in [
    blocksKey,
    FriendKeys.all,
    UserKeys.all,
    ConversationKeys.all,
    NotificationKeys.all,
    VisitKeys.all,
    ['place-posts'],
    ['map-places'],
  ]) {
    queryClient.invalidateQueries(key);
  }
}

MutationHandle<String, void> useBlockUser() => useMutation<String, void>(
  (userId) => apiSend<void>('PUT', '/me/blocks/$userId'),
  onSuccess: (_, _) => _invalidateSocial(),
);

MutationHandle<String, void> useUnblockUser() => useMutation<String, void>(
  (userId) => apiSend<void>('DELETE', '/me/blocks/$userId'),
  onSuccess: (_, _) => _invalidateSocial(),
);

MutationHandle<Json, void> useReportUser(String userId) =>
    useMutation<Json, void>((input) => apiSend<void>('POST', '/users/$userId/reports', input));

/// Own profile as a cached query (settings switches, the consent gate, the "Kinnita e-post" banner).
QueryResult<Profile> useOwnProfile({bool enabled = true}) =>
    useQuery(ownProfileKey, () async => Profile.fromJson(await apiGet<Json>('/me')), enabled: enabled);

MutationHandle<Json, Profile> useUpdateOwnProfile() => useMutation<Json, Profile>(
  (patch) async => Profile.fromJson(await apiSend<Json>('PATCH', '/me', patch)),
  onSuccess: (profile, _) => queryClient.setQueryData<Profile>(ownProfileKey, (_) => profile),
);
