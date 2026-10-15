import 'json.dart';

enum Relation { none, friend, outgoing, incoming }

/// Another person as shown in lists: first name only, area and dog names.
class PersonSummary {
  const PersonSummary({required this.id, required this.firstName, required this.area, required this.dogNames});
  factory PersonSummary.fromJson(Json j) => PersonSummary(
    id: j['id']! as String,
    firstName: j['firstName']! as String,
    area: j['area'] as String?,
    dogNames: stringList(j['dogNames'] ?? const <Object?>[]),
  );
  final String id;
  final String firstName;
  final String? area;
  final List<String> dogNames;
}

const userSearchMin = 3;
const messageMax = 2000;

class UserSearchResult extends PersonSummary {
  const UserSearchResult({
    required super.id,
    required super.firstName,
    required super.area,
    required super.dogNames,
    required this.relation,
    required this.acceptsRequests,
  });
  factory UserSearchResult.fromJson(Json j) {
    final p = PersonSummary.fromJson(j);
    return UserSearchResult(
      id: p.id,
      firstName: p.firstName,
      area: p.area,
      dogNames: p.dogNames,
      relation: Relation.values.byName(j['relation']! as String),
      acceptsRequests: j['acceptsRequests']! as bool,
    );
  }
  final Relation relation;
  final bool acceptsRequests;
}

class PublicDog {
  const PublicDog({
    required this.id,
    required this.name,
    required this.breed,
    required this.birthDate,
    required this.temperament,
  });
  factory PublicDog.fromJson(Json j) => PublicDog(
    id: j['id']! as String,
    name: j['name']! as String,
    breed: j['breed'] as String?,
    birthDate: j['birthDate'] as String?,
    temperament: j['temperament'] as String?,
  );
  final String id;
  final String name;
  final String? breed;
  final String? birthDate;
  final String? temperament;
}

/// GET /users/:userId — "Community / Friend Profile". bio and dog details only for friends.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.area,
    required this.bio,
    required this.relation,
    required this.friendsSince,
    required this.acceptsRequests,
    required this.dogs,
  });
  factory UserProfile.fromJson(Json j) => UserProfile(
    id: j['id']! as String,
    firstName: j['firstName']! as String,
    area: j['area'] as String?,
    bio: j['bio'] as String?,
    relation: Relation.values.byName(j['relation']! as String),
    friendsSince: j['friendsSince'] as String?,
    acceptsRequests: j['acceptsRequests']! as bool,
    dogs: listOf(j['dogs'], PublicDog.fromJson),
  );
  final String id;
  final String firstName;
  final String? area;
  final String? bio;
  final Relation relation;
  final String? friendsSince;
  final bool acceptsRequests;
  final List<PublicDog> dogs;
}

class Friend extends PersonSummary {
  const Friend({
    required super.id,
    required super.firstName,
    required super.area,
    required super.dogNames,
    required this.since,
  });
  factory Friend.fromJson(Json j) {
    final p = PersonSummary.fromJson(j);
    return Friend(id: p.id, firstName: p.firstName, area: p.area, dogNames: p.dogNames, since: j['since']! as String);
  }
  final String since;
}

class FriendRequest {
  const FriendRequest({required this.user, required this.createdAt});
  factory FriendRequest.fromJson(Json j) =>
      FriendRequest(user: PersonSummary.fromJson(asJson(j['user'])), createdAt: j['createdAt']! as String);
  final PersonSummary user;
  final String createdAt;
}

class FriendRequests {
  const FriendRequests({required this.incoming, required this.outgoing});
  factory FriendRequests.fromJson(Json j) => FriendRequests(
    incoming: listOf(j['incoming'], FriendRequest.fromJson),
    outgoing: listOf(j['outgoing'], FriendRequest.fromJson),
  );
  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;
}

/// Friends' upcoming plans for Home ("Täna võiks koos mängida").
class FriendPlan {
  const FriendPlan({
    required this.id,
    required this.friendId,
    required this.friendFirstName,
    required this.parkId,
    required this.parkName,
    required this.startsAt,
    required this.endsAt,
    required this.note,
  });
  factory FriendPlan.fromJson(Json j) {
    final friend = asJson(j['friend']);
    final park = asJson(j['park']);
    return FriendPlan(
      id: j['id']! as String,
      friendId: friend['id']! as String,
      friendFirstName: friend['firstName']! as String,
      parkId: park['id']! as String,
      parkName: park['name']! as String,
      startsAt: j['startsAt']! as String,
      endsAt: j['endsAt']! as String,
      note: j['note'] as String?,
    );
  }
  final String id;
  final String friendId;
  final String friendFirstName;
  final String parkId;
  final String parkName;
  final String startsAt;
  final String endsAt;
  final String? note;
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });
  factory Message.fromJson(Json j) => Message(
    id: j['id']! as String,
    conversationId: j['conversationId']! as String,
    senderId: j['senderId'] as String?,
    body: j['body']! as String,
    createdAt: j['createdAt']! as String,
  );
  final String id;
  final String conversationId;

  /// Null when the sender has deleted their account (M10).
  final String? senderId;
  final String body;
  final String createdAt;
}

class MessagePage {
  const MessagePage({required this.messages, required this.nextCursor});
  factory MessagePage.fromJson(Json j) =>
      MessagePage(messages: listOf(j['messages'], Message.fromJson), nextCursor: j['nextCursor'] as String?);

  /// Newest first.
  final List<Message> messages;
  final String? nextCursor;

  MessagePage withMessages(List<Message> messages) => MessagePage(messages: messages, nextCursor: nextCursor);
}

class ConversationPeer {
  const ConversationPeer({required this.id, required this.firstName, required this.dogNames});
  factory ConversationPeer.fromJson(Json j) => ConversationPeer(
    id: j['id']! as String,
    firstName: j['firstName']! as String,
    dogNames: stringList(j['dogNames'] ?? const <Object?>[]),
  );
  final String id;
  final String firstName;
  final List<String> dogNames;
}

class Conversation {
  const Conversation({
    required this.id,
    required this.other,
    required this.lastMessage,
    required this.unreadCount,
    required this.canMessage,
  });
  factory Conversation.fromJson(Json j) => Conversation(
    id: j['id']! as String,
    other: j['other'] == null ? null : ConversationPeer.fromJson(asJson(j['other'])),
    lastMessage: j['lastMessage'] == null ? null : Message.fromJson(asJson(j['lastMessage'])),
    unreadCount: toInt(j['unreadCount']),
    canMessage: j['canMessage']! as bool,
  );
  final String id;

  /// Null when the other person has deleted their account (M10).
  final ConversationPeer? other;
  final Message? lastMessage;
  final int unreadCount;
  final bool canMessage;
}

/// Feed row (`anyNotificationSchema`): M5 types plus the opt-in M9b reward types.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.actor,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });
  factory AppNotification.fromJson(Json j) {
    final actor = j['actor'] == null ? null : asJson(j['actor']);
    return AppNotification(
      id: j['id']! as String,
      type: j['type']! as String,
      actor: actor == null ? null : (id: actor['id']! as String, firstName: actor['firstName']! as String),
      data: {
        for (final e in asJson(j['data']).entries)
          if (e.value != null) e.key: '${e.value}',
      },
      readAt: j['readAt'] as String?,
      createdAt: j['createdAt']! as String,
    );
  }
  final String id;
  final String type;
  final ({String id, String firstName})? actor;
  final Map<String, String> data;
  final String? readAt;
  final String createdAt;
}

class NotificationPage {
  const NotificationPage({required this.items, required this.nextCursor});
  factory NotificationPage.fromJson(Json j) =>
      NotificationPage(items: listOf(j['items'], AppNotification.fromJson), nextCursor: j['nextCursor'] as String?);
  final List<AppNotification> items;
  final String? nextCursor;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.messages,
    required this.friendRequests,
    required this.friendPlans,
    required this.bookings,
    required this.rewards,
  });
  factory NotificationPreferences.fromJson(Json j) => NotificationPreferences(
    messages: j['messages']! as bool,
    friendRequests: j['friendRequests']! as bool,
    friendPlans: j['friendPlans']! as bool,
    bookings: j['bookings']! as bool,
    rewards: (j['rewards'] as bool?) ?? true,
  );
  final bool messages;
  final bool friendRequests;
  final bool friendPlans;
  final bool bookings;
  final bool rewards;

  Json toJson() => {
    'messages': messages,
    'friendRequests': friendRequests,
    'friendPlans': friendPlans,
    'bookings': bookings,
    'rewards': rewards,
  };
}

class BlockedUser {
  const BlockedUser({required this.id, required this.firstName, required this.blockedAt});
  factory BlockedUser.fromJson(Json j) =>
      BlockedUser(id: j['id']! as String, firstName: j['firstName']! as String, blockedAt: j['blockedAt']! as String);
  final String id;
  final String firstName;
  final String blockedAt;
}

const userReportReasons = ['spam', 'harassment', 'other'];
