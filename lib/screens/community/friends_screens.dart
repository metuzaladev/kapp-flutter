import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/icon.dart';
import '../../components/list_row.dart';
import '../../components/screen.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../components/text_field.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/dialogs.dart';
import '../../hooks/community.dart';
import '../../hooks/explore.dart';
import '../../models/community.dart';

String? _subtitleOf(String? area, [String? extra]) {
  final parts = [?area, ?extra];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(Spacing.two),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.r16),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(height: Spacing.two), w],
        ],
      ),
    );
  }
}

/// Figma 05 / Community / Friends: search, incoming and outgoing requests, friends.
class FriendsScreen extends HookWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = useTextEditingController();
    final typed = useValueListenable(text).text;
    // Debounce: one request when the user pauses typing, not one per letter.
    final query = useSettledValue(typed.trim(), const Duration(milliseconds: 350));
    final friends = useFriends();
    final requests = useFriendRequests();
    final search = useUserSearch(query);
    final send = useSendFriendRequest();
    final accept = useAcceptFriendRequest();
    final remove = useDeleteFriendRequest();
    final mutationError = send.error ?? accept.error ?? remove.error;
    void openProfile(String id) => context.push('/users/$id');

    Widget? searchAction(UserSearchResult r) => switch (r.relation) {
      Relation.friend => null,
      Relation.outgoing => AppText(
        context.t('friends.requestSent'),
        type: TextType.caption,
        themeColor: TextColor.muted,
      ),
      Relation.incoming => AppButton(
        label: context.t('friends.accept'),
        variant: ButtonVariant.secondary,
        onPressed: accept.isPending ? null : () => accept.mutate(r.id),
      ),
      Relation.none when !r.acceptsRequests => AppText(
        context.t('friends.requestsOff'),
        type: TextType.caption,
        themeColor: TextColor.muted,
      ),
      Relation.none => AppButton(
        label: context.t('friends.add'),
        variant: ButtonVariant.secondary,
        onPressed: send.isPending ? null : () => send.mutate(r.id),
      ),
    };

    final incoming = requests.data?.incoming ?? const <FriendRequest>[];
    final outgoing = requests.data?.outgoing ?? const <FriendRequest>[];

    return AppScreen(
      navBar: true,
      title: context.t('friends.title'),
      subtitle: context.t('friends.subtitle'),
      onRefresh: () => refreshAll([friends.refetch, requests.refetch]),
      children: [
        const OfflineBanner(),
        if (mutationError != null) FormError(errorMessage(mutationError)),
        AppTextField(
          label: context.t('friends.search'),
          placeholder: context.t('friends.searchPlaceholder'),
          controller: text,
          capitalization: TextCapitalization.words,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          maxLength: 50,
        ),
        if (typed.trim().isNotEmpty && typed.trim().length < userSearchMin)
          AppText(
            context.t('friends.searchHint', params: {'min': userSearchMin}),
            type: TextType.caption,
            themeColor: TextColor.muted,
          ),
        if (search.error != null) FormError(errorMessage(search.error)),
        if (search.data?.isEmpty ?? false)
          Semantics(liveRegion: true, child: AppText(context.t('friends.noResults'), themeColor: TextColor.muted)),
        for (final r in search.data ?? const <UserSearchResult>[])
          _Card(
            children: [
              ListRow(
                showPhoto: true,
                photoName: r.dogNames.firstOrNull ?? r.firstName,
                title: personTitle(r.firstName, r.dogNames),
                subtitle: r.area,
                onPressed: () => openProfile(r.id),
              ),
              ?searchAction(r),
            ],
          ),
        if (incoming.isNotEmpty) ...[
          AppText(context.t('friends.incoming'), type: TextType.heading, header: true),
          for (final req in incoming)
            _Card(
              children: [
                ListRow(
                  showPhoto: true,
                  photoName: req.user.dogNames.firstOrNull ?? req.user.firstName,
                  title: personTitle(req.user.firstName, req.user.dogNames),
                  subtitle: _subtitleOf(req.user.area),
                  onPressed: () => openProfile(req.user.id),
                ),
                // Wraps at large text sizes: "Принять" / "Отклонить" side by side need room.
                Wrap(
                  spacing: Spacing.two,
                  runSpacing: Spacing.two,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 140),
                      child: AppButton(
                        label: context.t('friends.accept'),
                        onPressed: accept.isPending ? null : () => accept.mutate(req.user.id),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 140),
                      child: AppButton(
                        label: context.t('friends.decline'),
                        variant: ButtonVariant.secondary,
                        onPressed: remove.isPending ? null : () => remove.mutate(req.user.id),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
        if (outgoing.isNotEmpty) ...[
          AppText(context.t('friends.outgoing'), type: TextType.heading, header: true),
          for (final req in outgoing)
            _Card(
              children: [
                ListRow(
                  showPhoto: true,
                  photoName: req.user.dogNames.firstOrNull ?? req.user.firstName,
                  title: personTitle(req.user.firstName, req.user.dogNames),
                  subtitle: _subtitleOf(req.user.area, context.t('friends.requestSent')),
                  onPressed: () => openProfile(req.user.id),
                ),
                AppButton(
                  label: context.t('friends.cancelRequest'),
                  variant: ButtonVariant.tertiary,
                  onPressed: remove.isPending ? null : () => remove.mutate(req.user.id),
                ),
              ],
            ),
        ],
        AppText(context.t('friends.myFriends'), type: TextType.heading, header: true),
        if (friends.error != null && friends.data == null)
          ErrorState(message: errorMessage(friends.error), onRetry: friends.refetch, retrying: friends.isFetching),
        if (friends.isPending && friends.error == null) const SkeletonList(),
        if (friends.data?.isEmpty ?? false)
          EmptyState(title: context.t('friends.emptyTitle'), body: context.t('friends.emptyBody')),
        for (final (i, f) in (friends.data ?? const <Friend>[]).indexed)
          Entering(
            index: i,
            child: ListRow(
              showPhoto: true,
              photoName: f.dogNames.firstOrNull ?? f.firstName,
              title: personTitle(f.firstName, f.dogNames),
              subtitle: f.area,
              onPressed: () => openProfile(f.id),
            ),
          ),
      ],
    );
  }
}

/// Figma 05 / Community / Friend Profile — also the profile of anyone found in search or in a park.
class UserProfileScreen extends HookWidget {
  const UserProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final profile = useUserProfile(userId);
    final person = profile.data;
    final send = useSendFriendRequest();
    final accept = useAcceptFriendRequest();
    final cancel = useDeleteFriendRequest();
    final unfriend = useRemoveFriend();
    final start = useStartConversation();
    final actionError = send.error ?? accept.error ?? cancel.error ?? unfriend.error ?? start.error;
    final name = person == null ? '' : personTitle(person.firstName, person.dogs.map((d) => d.name).toList());

    Future<void> openChat() async {
      try {
        final conversation = await start.mutateAsync(userId);
        if (context.mounted) unawaited(context.push('/messages/${conversation.id}'));
      } catch (_) {}
    }

    void confirmUnfriend() {
      if (person == null) return;
      haptic(HapticReason.warning);
      showAlert(
        context,
        context.t('userProfile.unfriendTitle', params: {'name': person.firstName}),
        message: context.t('userProfile.unfriendBody'),
        actions: [
          AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
          AlertAction(
            context.t('userProfile.unfriend'),
            style: AlertStyle.destructive,
            onPressed: () => unfriend.mutate(userId),
          ),
        ],
      );
    }

    final subtitle = person == null
        ? null
        : [
            ?person.area,
            if (person.friendsSince != null)
              context.t('userProfile.friendsSince', params: {'date': formatFriendsSince(person.friendsSince!)}),
          ].join(' · ');

    return AppScreen(
      navBar: true,
      title: name,
      subtitle: subtitle == null || subtitle.isEmpty ? null : subtitle,
      children: [
        const OfflineBanner(),
        if (profile.error != null && person == null)
          ErrorState(message: errorMessage(profile.error), onRetry: profile.refetch, retrying: profile.isFetching),
        if (actionError != null) FormError(errorMessage(actionError)),
        if (profile.isPending && profile.error == null) const SkeletonList(rows: 2, rowHeight: 96),
        if (person != null) ...[
          if (person.bio != null) AppText(person.bio!),
          if (person.relation == Relation.friend) ...[
            AppButton(label: context.t('userProfile.message'), loading: start.isPending, onPressed: openChat),
            AppButton(
              label: context.t('userProfile.invite'),
              variant: ButtonVariant.secondary,
              onPressed: () => context.push(
                Uri(path: '/invite-park', queryParameters: {'userId': userId, 'name': person.firstName}).toString(),
              ),
            ),
          ],
          if (person.relation == Relation.none && person.acceptsRequests)
            AppButton(
              label: context.t('userProfile.addFriend'),
              loading: send.isPending,
              onPressed: () => send.mutate(userId),
            ),
          if (person.relation == Relation.none && !person.acceptsRequests)
            AppText(context.t('friends.requestsOff'), themeColor: TextColor.muted),
          if (person.relation == Relation.incoming)
            AppButton(
              label: context.t('userProfile.acceptRequest'),
              loading: accept.isPending,
              onPressed: () => accept.mutate(userId),
            ),
          if (person.relation == Relation.outgoing)
            AppButton(
              label: context.t('friends.cancelRequest'),
              variant: ButtonVariant.secondary,
              loading: cancel.isPending,
              onPressed: () => cancel.mutate(userId),
            ),
          for (final (i, dog) in person.dogs.indexed)
            Entering(
              index: i,
              // One screen-reader element per dog card.
              child: MergeSemantics(
                child: Container(
                  padding: const EdgeInsets.all(Spacing.three),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.r16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(context.t('userProfile.dogProfile', params: {'name': dog.name}), type: TextType.heading),
                      const SizedBox(height: Spacing.one),
                      AppText(
                        [?dog.breed, if (dog.birthDate != null) ageLabel(dog.birthDate!)].join(' · ').isNotEmpty
                            ? [?dog.breed, if (dog.birthDate != null) ageLabel(dog.birthDate!)].join(' · ')
                            : context.t('common.dog'),
                        themeColor: TextColor.muted,
                      ),
                      if (dog.temperament != null) ...[const SizedBox(height: Spacing.one), AppText(dog.temperament!)],
                    ],
                  ),
                ),
              ),
            ),
          if (person.relation != Relation.friend)
            AppText(context.t('userProfile.friendsOnlyDetails'), type: TextType.caption, themeColor: TextColor.muted),
          ListRow(
            icon: IconName.shield,
            title: context.t('userProfile.reportOrBlock'),
            subtitle: context.t('userProfile.reportOrBlockSub'),
            onPressed: () =>
                context.push(Uri(path: '/report-user', queryParameters: {'userId': userId, 'name': name}).toString()),
          ),
          if (person.relation == Relation.friend)
            AppButton(
              label: context.t('userProfile.unfriend'),
              variant: ButtonVariant.tertiary,
              onPressed: confirmUnfriend,
            ),
        ],
      ],
    );
  }
}
