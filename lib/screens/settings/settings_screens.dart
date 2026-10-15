import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../components/button.dart';
import '../../components/chip.dart';
import '../../components/icon.dart';
import '../../components/legal_document.dart';
import '../../components/list_row.dart';
import '../../components/pressable.dart';
import '../../components/screen.dart';
import '../../components/social_sign_in.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../components/text_field.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_client.dart';
import '../../core/config.dart';
import '../../core/haptics.dart';
import '../../core/i18n/i18n.dart';
import '../../core/i18n/language_preference.dart';
import '../../core/logic/account.dart';
import '../../core/logic/legal.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/dialogs.dart';
import '../../core/validation.dart';
import '../../hooks/account.dart';
import '../../hooks/community.dart';
import '../../models/community.dart';
import '../../models/profile.dart';
import '../../state/appearance.dart';
import '../../state/session_notice.dart';

/// Icon chips for "Kes näeb, kui oled pargis?" (privacy settings and profile edit share the meaning).
const _presenceIcon = {
  PresenceSharing.nobody: IconName.lock,
  PresenceSharing.friends: IconName.heart,
  PresenceSharing.everyone: IconName.users,
};

/// One radio group card (language, appearance): one screen-reader radio per row, a check on the chosen one.
class _OptionGroup<T> extends StatelessWidget {
  const _OptionGroup({required this.options, required this.selected, required this.label, required this.onSelect});
  final List<T> options;
  final T selected;
  final String Function(T option) label;
  final void Function(T option) onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.r16),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (final (i, option) in options.indexed) ...[
            if (i > 0) Divider(height: 0.5, thickness: 0.5, color: c.border),
            Pressable(
              semanticLabel: label(option),
              checked: selected == option,
              onPressed: () {
                haptic(HapticReason.selection);
                onSelect(option);
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.three),
                child: Row(
                  children: [
                    Expanded(child: AppText(label(option), type: TextType.label)),
                    if (selected == option) AppIcon(IconName.check, size: 20, color: c.brand),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Figma 07 / Settings / Overview: edit profile, notifications, privacy, language, appearance, and
/// (M10) the "Konto" section: privacy & terms, sign out, delete account.
class SettingsScreen extends HookWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final preference = useValueListenable(LanguagePreferenceStore.instance);
    final appearance = useValueListenable(AppearanceStore.instance);
    final signingOut = useState(false);
    final language = context.language;

    Future<void> signOut() async {
      signingOut.value = true;
      // Clears the session server-side and in the Keychain; the router then shows Welcome.
      await AuthClient.instance.signOut();
    }

    // Language names are endonyms ("eesti", "English", "русский") so everyone finds their own.
    String optionLabel(LanguagePreference option) => switch (option) {
      AutoLanguage() => context.t(
        'settings.languageAutoCurrent',
        params: {'language': context.t('settings.languageNames.${language.name}')},
      ),
      FixedLanguage(:final language) => context.t('settings.languageNames.${language.name}'),
    };

    return AppScreen(
      navBar: true,
      title: context.t('settings.title'),
      subtitle: context.t('settings.subtitle'),
      children: [
        ListRow(
          icon: IconName.user,
          title: context.t('settings.editProfile'),
          subtitle: context.t('settings.editProfileSub'),
          onPressed: () => context.push('/profile-edit'),
        ),
        ListRow(
          icon: IconName.bell,
          title: context.t('settings.notifications'),
          subtitle: context.t('settings.notificationsSub'),
          onPressed: () => context.push('/settings-notifications'),
        ),
        ListRow(
          icon: IconName.lock,
          title: context.t('settings.privacy'),
          subtitle: context.t('settings.privacySub'),
          onPressed: () => context.push('/settings-privacy'),
        ),
        AppText(context.t('settings.language'), type: TextType.heading, header: true),
        _OptionGroup<LanguagePreference>(
          options: [const AutoLanguage(), for (final l in Language.values) FixedLanguage(l)],
          selected: preference,
          label: optionLabel,
          onSelect: LanguagePreferenceStore.instance.set,
        ),
        // Default light: the redesign is drawn in light mode; dark and "follow the system" are opt-in.
        AppText(context.t('settings.appearance'), type: TextType.heading, header: true),
        _OptionGroup<AppearancePreference>(
          options: AppearancePreference.values,
          selected: appearance,
          label: (o) => context.t('settings.appearanceOptions.${o.name}'),
          onSelect: AppearanceStore.instance.set,
        ),
        // M10 (docs/17): legal texts, data export and account deletion; deletion is the last, red row.
        AppText(context.t('settings.account'), type: TextType.heading, header: true),
        ListRow(
          icon: IconName.shield,
          title: context.t('settings.legal'),
          subtitle: context.t('settings.legalSub'),
          onPressed: () => context.push('/privacy-terms'),
        ),
        AppButton(
          label: context.t('settings.signOut'),
          variant: ButtonVariant.tertiary,
          loading: signingOut.value,
          onPressed: signOut,
        ),
        ListRow(
          icon: IconName.trash2,
          danger: true,
          title: context.t('settings.deleteAccount'),
          subtitle: context.t('settings.deleteAccountSub'),
          onPressed: () => context.push('/delete-account'),
        ),
      ],
    );
  }
}

/// Figma 07 / Profile / Edit — presented as a modal (iOS pattern for a focused edit task). The form
/// mounts once the profile is known, so its fields start with the stored values.
class ProfileEditScreen extends HookWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = useOwnProfile();
    final profile = me.data;
    if (profile == null) {
      return AppScreen(
        navBar: true,
        navTitle: context.t('nav.profileEdit'),
        children: [
          if (me.error != null)
            ErrorState(message: errorMessage(me.error), onRetry: me.refetch, retrying: me.isFetching),
          if (me.isPending && me.error == null) const SkeletonList(rows: 3, rowHeight: 72),
        ],
      );
    }
    return _ProfileForm(profile: profile);
  }
}

class _ProfileForm extends HookWidget {
  const _ProfileForm({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final update = useUpdateOwnProfile();
    final name = useTextEditingController(text: profile.name);
    final area = useTextEditingController(text: profile.area ?? '');
    final bio = useTextEditingController(text: profile.bio ?? '');
    final presence = useState(profile.presenceSharing);
    final errors = useState<FieldErrors>({});
    final formError = useState<String?>(null);

    Future<void> save() async {
      final invalid = validateProfile(name: name.text, area: area.text, bio: bio.text);
      errors.value = invalid;
      formError.value = null;
      if (invalid.isNotEmpty) return;
      try {
        await update.mutateAsync({
          'name': name.text.trim(),
          // "" clears the field on the server (patchText), as in the React Native form.
          'area': area.text.trim(),
          'bio': bio.text.trim(),
          'presenceSharing': presence.value.name,
        });
        if (context.mounted) context.pop();
      } catch (e) {
        formError.value = errorMessage(e);
      }
    }

    return AppScreen(
      navBar: true,
      navTitle: context.t('nav.profileEdit'),
      title: context.t('profileEdit.title'),
      subtitle: context.t('profileEdit.subtitle'),
      children: [
        FormError(formError.value),
        AppTextField(
          label: context.t('profileEdit.name'),
          controller: name,
          error: errors.value['name'],
          autofillHints: const [AutofillHints.name],
          capitalization: TextCapitalization.words,
        ),
        AppTextField(
          label: context.t('profileEdit.area'),
          placeholder: context.t('profileEdit.areaPlaceholder'),
          controller: area,
          error: errors.value['area'],
        ),
        AppTextField(
          label: context.t('profileEdit.bio'),
          placeholder: context.t('profileEdit.bioPlaceholder'),
          controller: bio,
          error: errors.value['bio'],
          maxLines: null,
          minLines: 3,
          maxLength: 300,
        ),
        AppText(context.t('profileEdit.presenceTitle'), type: TextType.label),
        ChipRow(
          children: [
            for (final option in PresenceSharing.values)
              IconChip(
                radio: true,
                icon: _presenceIcon[option]!,
                label: context.t('profileEdit.presence.${option.name}'),
                selected: presence.value == option,
                onPressed: () => presence.value = option,
              ),
          ],
        ),
        AppButton(label: context.t('profileEdit.save'), loading: update.isPending, onPressed: save),
      ],
    );
  }
}

/// Figma 07 / Settings / Privacy: friend requests, presence sharing, blocked users.
class PrivacySettingsScreen extends HookWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final profile = useOwnProfile();
    final update = useUpdateOwnProfile();
    final blocked = useBlockedUsers();
    final unblock = useUnblockUser();
    final error = profile.error ?? update.error ?? blocked.error ?? unblock.error;

    return AppScreen(
      navBar: true,
      title: context.t('privacy.title'),
      subtitle: context.t('privacy.subtitle'),
      children: [
        if (error != null) FormError(errorMessage(error)),
        Container(
          padding: const EdgeInsets.all(Spacing.three),
          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.r16)),
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(context.t('privacy.healthTitle'), type: TextType.label),
                const SizedBox(height: Spacing.one),
                AppText(context.t('privacy.healthBody'), themeColor: TextColor.muted),
              ],
            ),
          ),
        ),
        SwitchRow(
          label: context.t('privacy.allowRequests'),
          hint: context.t('privacy.allowRequestsHint'),
          value: profile.data?.allowFriendRequests ?? true,
          disabled: profile.data == null || update.isPending,
          onChanged: (v) => update.mutate({'allowFriendRequests': v}),
        ),
        AppText(context.t('privacy.presence'), type: TextType.heading),
        AppText(context.t('privacy.presenceHint'), type: TextType.caption, themeColor: TextColor.muted),
        ChipRow(
          children: [
            for (final option in PresenceSharing.values)
              IconChip(
                radio: true,
                icon: _presenceIcon[option]!,
                label: context.t('profileEdit.presence.${option.name}'),
                selected: profile.data?.presenceSharing == option,
                onPressed: () => update.mutate({'presenceSharing': option.name}),
              ),
          ],
        ),
        AppText(context.t('privacy.blocked'), type: TextType.heading),
        AppText(context.t('privacy.blockedHint'), type: TextType.caption, themeColor: TextColor.muted),
        if (blocked.data?.isEmpty ?? false) AppText(context.t('privacy.blockedEmpty'), themeColor: TextColor.muted),
        for (final b in blocked.data ?? const <BlockedUser>[])
          Container(
            padding: const EdgeInsets.only(
              left: Spacing.three,
              right: Spacing.two,
              top: Spacing.two,
              bottom: Spacing.two,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.r16),
              border: Border.all(color: c.border, width: 0.5),
            ),
            // Wraps at large text sizes: the name and "Разблокировать" do not fit side by side.
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Spacing.three,
              runSpacing: Spacing.two,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 120),
                  child: AppText(b.firstName, type: TextType.label),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 140),
                  child: AppButton(
                    label: context.t('privacy.unblock'),
                    variant: ButtonVariant.secondary,
                    onPressed: unblock.isPending ? null : () => unblock.mutate(b.id),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// `rewards` (M9b): level-ups, badges and "Sinu soovitus on avaldatud".
const _notificationKeys = ['messages', 'friendPlans', 'friendRequests', 'bookings', 'rewards'];

/// Figma 07 / Settings / Notifications: which pushes to receive. The in-app feed always shows
/// everything. (Push delivery itself is not wired up in the Flutter port yet — see the README.)
class NotificationSettingsScreen extends HookWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final saved = useNotificationPreferences();
    final save = useSaveNotificationPreferences();
    // Local edits on top of the saved values; nothing is sent until "Salvesta eelistused".
    final draft = useState<Map<String, Object?>?>(null);
    final values = draft.value ?? saved.data?.toJson();

    Future<void> submit() async {
      if (values == null) return;
      try {
        await save.mutateAsync(NotificationPreferences.fromJson(values));
        if (context.mounted) context.pop();
      } catch (_) {
        // Shown below from save.error.
      }
    }

    return AppScreen(
      navBar: true,
      title: context.t('notificationSettings.title'),
      subtitle: context.t('notificationSettings.subtitle'),
      children: [
        if (saved.error != null) FormError(errorMessage(saved.error)),
        if (save.error != null) FormError(errorMessage(save.error)),
        for (final key in _notificationKeys)
          SwitchRow(
            label: context.t('notificationSettings.$key'),
            value: (values?[key] as bool?) ?? true,
            disabled: values == null,
            onChanged: (on) => draft.value = {...?values, key: on},
          ),
        AppText(context.t('notificationSettings.feedNote'), type: TextType.caption, themeColor: TextColor.muted),
        AppButton(
          label: context.t('notificationSettings.save'),
          loading: save.isPending,
          onPressed: values == null ? null : submit,
        ),
      ],
    );
  }
}

/// Settings → "Privaatsus ja tingimused" (M10, docs/17): the two documents and "Laadi minu andmed
/// alla" (GDPR art. 15/20). The export goes through the system share sheet; the JSON is never stored.
class PrivacyTermsScreen extends HookWidget {
  const PrivacyTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final exportData = useExportData();
    final error = useState<String?>(null);

    Future<void> download() async {
      error.value = null;
      try {
        final data = await exportData.mutateAsync(null);
        if (!context.mounted) return;
        await SharePlus.instance.share(
          ShareParams(
            title: context.t('legal.exportShareTitle'),
            text: const JsonEncoder.withIndent('  ').convert(data),
          ),
        );
      } catch (e) {
        haptic(HapticReason.error);
        error.value = errorMessage(e);
      }
    }

    return AppScreen(
      navBar: true,
      title: context.t('legal.title'),
      subtitle: context.t('legal.subtitle'),
      children: [
        ListRow(
          icon: IconName.shield,
          title: context.t('legal.privacy'),
          subtitle: context.t('legal.version', params: {'version': legalVersions.privacy}),
          hint: context.t('legal.openHint'),
          onPressed: () => context.push('/legal/privacy'),
        ),
        ListRow(
          icon: IconName.info,
          title: context.t('legal.terms'),
          subtitle: context.t('legal.version', params: {'version': legalVersions.terms}),
          hint: context.t('legal.openHint'),
          onPressed: () => context.push('/legal/terms'),
        ),
        AppText(context.t('legal.yourData'), type: TextType.heading, header: true),
        AppText(context.t('legal.exportSub'), themeColor: TextColor.muted),
        FormError(error.value),
        AppButton(
          label: context.t('legal.export'),
          variant: ButtonVariant.secondary,
          loading: exportData.isPending,
          onPressed: download,
        ),
        AppText(context.t('legal.deleteHint'), type: TextType.caption, themeColor: TextColor.muted),
      ],
    );
  }
}

const _deletedItems = ['profile', 'dogs', 'visits', 'community', 'explore', 'services', 'reports'];

/// Settings → Konto → "Kustuta konto" (M10, docs/17; App Store 5.1.1(v), Google Play, GDPR art. 17).
///
/// Says exactly what is deleted and that it is permanent, then asks for the password (email
/// accounts) or a fresh Apple/Google sign-in. The final step is the system's destructive confirmation
/// with "Loobu" as the cancel button — cancelling is always one tap.
class DeleteAccountScreen extends HookWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = useOwnProfile();
    final remove = useDeleteAccount();
    final password = useTextEditingController();
    final typed = useValueListenable(password).text;
    final error = useState<String?>(null);
    final reauthenticated = useState(false);

    if (me.isPending && me.error == null) {
      return AppScreen(navBar: true, title: context.t('account.deleteTitle'), children: const [SkeletonList()]);
    }
    if (me.data == null) {
      return AppScreen(
        navBar: true,
        title: context.t('account.deleteTitle'),
        children: [ErrorState(message: errorMessage(me.error), onRetry: me.refetch, retrying: me.isFetching)],
      );
    }
    final mode = reauthMode(me.data!);
    const socialAvailable = authAppleEnabled || authGoogleEnabled;

    /// The account is gone: leave a notice for Welcome and drop the local session (the router swaps).
    Future<void> finish() async {
      haptic(HapticReason.success);
      sessionNotice.value = SessionNotice.accountDeleted;
      await AuthClient.instance.forgetSession();
    }

    Future<void> run() async {
      error.value = null;
      try {
        await remove.mutateAsync(deleteAccountBody(mode, password.text));
        await finish();
      } catch (e) {
        if (e is ApiRequestError && deletionMeansGone(e.status)) return finish();
        haptic(HapticReason.error);
        error.value = errorMessage(e);
      }
    }

    void confirm() {
      haptic(HapticReason.warning);
      showAlert(
        context,
        context.t('account.confirmTitle'),
        message: context.t('account.confirmBody'),
        actions: [
          AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
          AlertAction(context.t('account.confirmAction'), style: AlertStyle.destructive, onPressed: run),
        ],
      );
    }

    return AppScreen(
      navBar: true,
      title: context.t('account.deleteTitle'),
      subtitle: context.t('account.deleteSubtitle'),
      children: [
        Container(
          padding: const EdgeInsets.all(Spacing.three),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.r16),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(context.t('account.whatGoes'), type: TextType.heading, header: true),
              for (final item in _deletedItems) ...[
                const SizedBox(height: Spacing.two),
                MergeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(IconName.trash2, size: 18, color: c.danger),
                      const SizedBox(width: Spacing.two),
                      Expanded(child: AppText(context.t('account.items.$item'))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        AppText(context.t('account.messagesNote'), themeColor: TextColor.muted),
        AppText(context.t('account.afterNote'), themeColor: TextColor.muted),
        AppText(context.t('account.exportFirst'), type: TextType.label),
        AppButton(
          label: context.t('legal.export'),
          variant: ButtonVariant.secondary,
          onPressed: () => context.push('/privacy-terms'),
        ),
        if (mode == ReauthMode.password)
          AppTextField(
            label: context.t('account.passwordLabel'),
            placeholder: context.t('account.passwordPlaceholder'),
            controller: password,
            obscure: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
          )
        else ...[
          AppText(context.t('account.reauthTitle'), type: TextType.heading, header: true),
          AppText(
            socialAvailable ? context.t('account.reauthBody') : context.t('account.reauthUnavailable'),
            themeColor: TextColor.muted,
          ),
          SocialSignIn(
            signInMode: true,
            onError: (e) => error.value = e,
            onSuccess: () {
              reauthenticated.value = true;
              haptic(HapticReason.success);
            },
          ),
          if (reauthenticated.value)
            Semantics(
              liveRegion: true,
              child: AppText(context.t('account.reauthDone'), type: TextType.label, themeColor: TextColor.link),
            ),
        ],
        FormError(error.value),
        AppButton(
          label: context.t('account.submit'),
          variant: ButtonVariant.danger,
          loading: remove.isPending,
          onPressed: canRequestDeletion(mode, typed) ? confirm : null,
        ),
        AppButton(label: context.t('common.cancel'), variant: ButtonVariant.tertiary, onPressed: () => context.pop()),
      ],
    );
  }
}

/// Privacy policy or terms of use (M10, docs/17), in the app's language. Reachable signed out (sign-up
/// links, Welcome) and signed in (Settings → Privaatsus ja tingimused).
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.doc});
  final String doc;

  @override
  Widget build(BuildContext context) {
    final document = LegalDocument.values.where((d) => d.name == doc).firstOrNull;
    return AppScreen(
      navBar: true,
      children: [
        if (document != null)
          LegalDocumentView(blocks: legalBlocks(document, context.language))
        else
          EmptyState(title: context.t('errors.generic')),
      ],
    );
  }
}
