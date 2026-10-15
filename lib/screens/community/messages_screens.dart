import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/chip.dart';
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
import '../../core/validation.dart';
import '../../hooks/community.dart';
import '../../models/community.dart';

/// Figma 05 / Messages / Inbox. The search filters loaded conversations by the friend's or dog's name.
class InboxScreen extends HookWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final conversations = useConversations();
    final data = conversations.data;
    final filter = useTextEditingController();
    final needle = useValueListenable(filter).text.trim().toLowerCase();
    // `other` is null when the friend deleted their account (M10): listed as "Kustutatud kasutaja".
    String nameOf(Conversation conv) => conv.other != null
        ? personTitle(conv.other!.firstName, conv.other!.dogNames)
        : context.t('conversation.deletedUser');
    final shown = (data ?? const <Conversation>[]).where((conv) {
      if (needle.isEmpty) return true;
      final names = conv.other != null
          ? [conv.other!.firstName, ...conv.other!.dogNames]
          : [context.t('conversation.deletedUser')];
      return names.any((n) => n.toLowerCase().contains(needle));
    }).toList();

    return AppScreen(
      navBar: true,
      title: context.t('inbox.title'),
      subtitle: context.t('inbox.subtitle'),
      onRefresh: conversations.refetch,
      children: [
        const OfflineBanner(),
        if (conversations.error != null && data == null)
          ErrorState(
            message: errorMessage(conversations.error),
            onRetry: conversations.refetch,
            retrying: conversations.isFetching,
          ),
        if (conversations.isPending && conversations.error == null) const SkeletonList(),
        if (data != null && data.isNotEmpty)
          AppTextField(
            label: context.t('inbox.search'),
            placeholder: context.t('inbox.searchPlaceholder'),
            controller: filter,
            maxLength: 50,
          ),
        if (data?.isEmpty ?? false)
          EmptyState(
            title: context.t('inbox.empty'),
            actionLabel: context.t('inbox.emptyAction'),
            onAction: () => context.push('/friends'),
          ),
        for (final (i, conv) in shown.indexed)
          Entering(
            index: i,
            child: ListRow(
              showPhoto: true,
              photoName: conv.other != null ? (conv.other!.dogNames.firstOrNull ?? conv.other!.firstName) : null,
              title: nameOf(conv),
              subtitle: conv.lastMessage != null
                  ? '${conv.lastMessage!.body} · ${formatMessageTime(conv.lastMessage!.createdAt)}'
                  : context.t('inbox.noMessages'),
              hint: conv.unreadCount > 0 ? context.t('inbox.unread', count: conv.unreadCount) : null,
              leading: conv.unreadCount > 0
                  ? ExcludeSemantics(
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.one),
                        decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(Radii.full)),
                        alignment: Alignment.center,
                        child: AppText('${conv.unreadCount}', type: TextType.micro, color: c.onBrand),
                      ),
                    )
                  : null,
              onPressed: () => context.push('/messages/${conv.id}'),
            ),
          ),
      ],
    );
  }
}

/// Figma 05 / Messages / Conversation. New messages arrive over the socket (or by polling every 15 s
/// while it is down); older ones load when scrolling up. The list is reversed, so the newest message
/// sits at the bottom next to the composer.
class ConversationScreen extends HookWidget {
  const ConversationScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final conversation = useConversation(conversationId);
    final messages = useMessages(conversationId);
    final send = useSendMessage(conversationId);
    final markRead = useMarkConversationRead(conversationId);
    final draft = useTextEditingController();
    final draftText = useValueListenable(draft).text;
    final error = useState<String?>(null);
    final list = [for (final p in messages.pages) ...p.messages];
    final other = conversation.data?.other;
    final newestId = list.firstOrNull?.id;
    final scroll = useScrollController();

    // Opening the conversation and every newly arrived message mark it read.
    useEffect(() {
      if (newestId != null) markRead.mutate(null);
      return null;
    }, [newestId]);

    useEffect(() {
      void onScroll() {
        if (scroll.position.extentAfter < 300 && messages.hasNextPage && !messages.isFetchingNextPage) {
          messages.fetchNextPage();
        }
      }

      scroll.addListener(onScroll);
      return () => scroll.removeListener(onScroll);
    }, [scroll, messages.hasNextPage, messages.isFetchingNextPage]);

    Future<void> submit() async {
      final body = draft.text.trim();
      final invalid = body.isEmpty ? issue('validation.messageEmpty') : optionalMaxError(body, messageMax);
      if (invalid != null) {
        error.value = invalid;
        return;
      }
      error.value = null;
      try {
        await send.mutateAsync(body);
        draft.clear();
      } catch (e) {
        error.value = errorMessage(e);
      }
    }

    final canMessage = conversation.data?.canMessage ?? true;
    // `other` null = the friend deleted their account (M10); while loading the conversation is unknown.
    final title = other != null
        ? personTitle(other.firstName, other.dogNames)
        : conversation.data != null
        ? context.t('conversation.deletedUser')
        : '';

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(title), backgroundColor: c.background),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Spacing.three),
              child: OfflineBanner(),
            ),
            if (messages.error != null && messages.data == null) FormError(errorMessage(messages.error)),
            Expanded(
              child: list.isEmpty && !messages.isPending
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.four),
                        child: AppText(
                          context.t('conversation.empty'),
                          themeColor: TextColor.muted,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scroll,
                      reverse: true,
                      padding: const EdgeInsets.all(Spacing.three),
                      itemCount: list.length + (messages.isFetchingNextPage ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: Spacing.two),
                      itemBuilder: (context, i) {
                        if (i == list.length) return const Center(child: CircularProgressIndicator.adaptive());
                        final m = list[i];
                        // A null sender is the deleted account (M10), never this user.
                        final mine = m.senderId != null && m.senderId != other?.id;
                        final who = mine
                            ? context.t('common.you')
                            : (other?.firstName ?? context.t('conversation.deletedUser'));
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Semantics(
                            label: context.t(
                              'conversation.a11y',
                              params: {'who': who, 'time': formatMessageTime(m.createdAt), 'text': m.body},
                            ),
                            excludeSemantics: true,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                              child: Container(
                                padding: const EdgeInsets.all(Spacing.three),
                                decoration: BoxDecoration(
                                  color: mine ? c.brand : c.surface,
                                  borderRadius: BorderRadius.circular(Radii.r16),
                                  border: Border.all(color: c.border, width: 0.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(
                                      '$who · ${formatMessageTime(m.createdAt)}',
                                      type: TextType.caption,
                                      color: mine ? c.onBrand : c.muted,
                                    ),
                                    const SizedBox(height: 2),
                                    AppText(m.body, color: mine ? c.onBrand : c.text),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (error.value != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.three),
                child: FormError(error.value),
              ),
            if (canMessage)
              Container(
                padding: const EdgeInsets.all(Spacing.three),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border, width: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Semantics(
                        label: context.t('conversation.message'),
                        textField: true,
                        child: TextField(
                          controller: draft,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: messageMax,
                          style: textStyle(TextType.body, color: c.text),
                          cursorColor: c.brand,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: context.t('conversation.placeholder'),
                            hintStyle: textStyle(TextType.body, color: c.muted),
                            filled: true,
                            fillColor: c.surface,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.three, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(Radii.r16),
                              borderSide: BorderSide(color: c.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(Radii.r16),
                              borderSide: BorderSide(color: c.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(Radii.r16),
                              borderSide: BorderSide(color: c.brand),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.two),
                    // Grows with the label ("Отправить" is longer than "Saada") instead of wrapping.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 96),
                      child: AppButton(
                        label: context.t('conversation.send'),
                        loading: send.isPending,
                        onPressed: draftText.trim().isEmpty ? null : submit,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(Spacing.three),
                child: AppText(
                  other == null ? context.t('conversation.accountDeleted') : context.t('conversation.notFriends'),
                  themeColor: TextColor.muted,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Figma 08 / Safety / Report or Block — modal.
class ReportUserScreen extends HookWidget {
  const ReportUserScreen({super.key, required this.userId, this.name});
  final String userId;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final report = useReportUser(userId);
    final block = useBlockUser();
    final reason = useState('spam');
    final details = useTextEditingController();
    final detailsError = useState<String?>(null);
    final formError = useState<String?>(null);
    final sent = useState(false);

    Future<void> submit() async {
      final text = details.text.trim();
      // "Muu" says nothing by itself; a moderator needs a description to act on it.
      detailsError.value = reason.value == 'other' ? describeError(text) : optionalMaxError(text, 1000);
      formError.value = null;
      if (detailsError.value != null) return;
      try {
        await report.mutateAsync({'reason': reason.value, 'details': text.isEmpty ? null : text});
        sent.value = true;
      } catch (e) {
        formError.value = errorMessage(e);
      }
    }

    void confirmBlock() {
      haptic(HapticReason.warning);
      showAlert(
        context,
        context.t('safety.blockTitle'),
        message: context.t('safety.blockBody'),
        actions: [
          AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
          AlertAction(
            context.t('safety.block'),
            style: AlertStyle.destructive,
            onPressed: () async {
              try {
                await block.mutateAsync(userId);
                // The profile is now hidden (404): leave both the modal and the profile.
                if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              } catch (e) {
                formError.value = errorMessage(e);
              }
            },
          ),
        ],
      );
    }

    Widget card(Color color, List<Widget> children) => Container(
      padding: const EdgeInsets.all(Spacing.three),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.r16)),
      child: MergeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );

    return AppScreen(
      navBar: true,
      navTitle: context.t('nav.reportUser'),
      title: context.t('safety.title'),
      subtitle: context.t('safety.subtitle'),
      children: [
        FormError(formError.value),
        card(c.surface, [
          AppText(name ?? '', type: TextType.label),
          AppText(context.t('safety.selectedUser'), type: TextType.caption, themeColor: TextColor.muted),
        ]),
        if (sent.value)
          Semantics(
            liveRegion: true,
            child: card(c.soft, [
              AppText(context.t('safety.thanksTitle'), type: TextType.heading),
              AppText(context.t('safety.thanksBody'), themeColor: TextColor.muted),
            ]),
          )
        else ...[
          ChipWrap(
            children: [
              for (final r in userReportReasons)
                AppChip(
                  radio: true,
                  label: context.t('safety.reasons.$r'),
                  selected: reason.value == r,
                  onPressed: () => reason.value = r,
                ),
            ],
          ),
          AppTextField(
            label: context.t('safety.what'),
            placeholder: context.t('safety.whatPlaceholder'),
            controller: details,
            error: detailsError.value,
            maxLines: null,
            minLines: 3,
            maxLength: 1000,
          ),
          card(c.soft, [
            AppText(context.t('safety.privateTitle'), type: TextType.label),
            AppText(context.t('safety.privateBody'), themeColor: TextColor.muted),
          ]),
          AppButton(label: context.t('safety.send'), loading: report.isPending, onPressed: submit),
        ],
        AppButton(
          label: context.t('safety.block'),
          variant: ButtonVariant.secondary,
          loading: block.isPending,
          onPressed: confirmBlock,
        ),
      ],
    );
  }
}
