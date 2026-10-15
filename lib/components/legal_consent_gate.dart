import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/api/api_client.dart';
import '../core/auth/auth_client.dart';
import '../core/haptics.dart';
import '../core/i18n/i18n.dart';
import '../core/logic/account.dart';
import '../core/logic/legal.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import '../hooks/account.dart';
import '../hooks/community.dart';
import 'button.dart';
import 'icon.dart';
import 'legal_document.dart';
import 'list_row.dart';
import 'states.dart';
import 'text.dart';

/// Blocking sheet while the signed-in user has not accepted the current terms and privacy policy
/// (M10, docs/17): social sign-ups, accounts older than M10, and everyone after a version bump. The
/// choices are "Nõustun" or "Logi välja"; the documents open inside it.
class LegalConsentGate extends HookWidget {
  const LegalConsentGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final me = useOwnProfile();
    final profile = me.data;
    if (profile == null || !needsLegalAcceptance(profile)) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(child: _ConsentSheet(kind: legalConsentKind(profile))),
      ],
    );
  }
}

class _ConsentSheet extends HookWidget {
  const _ConsentSheet({required this.kind});
  final LegalConsentKind kind;

  @override
  Widget build(BuildContext context) {
    final accept = useAcceptLegal();
    final reading = useState<LegalDocument?>(null);
    final error = useState<String?>(null);
    final language = context.language;

    Future<void> agree() async {
      error.value = null;
      try {
        await accept.mutateAsync(null);
        haptic(HapticReason.success);
      } catch (e) {
        haptic(HapticReason.error);
        error.value = errorMessage(e);
      }
    }

    final isNew = kind == LegalConsentKind.newConsent;
    return Material(
      color: context.c.background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.screen),
          children: [
            if (reading.value != null) ...[
              AppButton(
                label: context.t('legal.back'),
                variant: ButtonVariant.tertiary,
                onPressed: () => reading.value = null,
              ),
              const SizedBox(height: Spacing.three),
              LegalDocumentView(blocks: legalBlocks(reading.value!, language)),
              const SizedBox(height: Spacing.three),
              AppButton(
                label: context.t('legal.back'),
                variant: ButtonVariant.secondary,
                onPressed: () => reading.value = null,
              ),
            ] else ...[
              AppText(
                context.t(isNew ? 'legal.consentTitleNew' : 'legal.consentTitleUpdated'),
                type: TextType.title,
                header: true,
              ),
              const SizedBox(height: Spacing.three),
              AppText(
                context.t(isNew ? 'legal.consentBodyNew' : 'legal.consentBodyUpdated'),
                themeColor: TextColor.muted,
              ),
              const SizedBox(height: Spacing.three),
              ListRow(
                icon: IconName.info,
                title: context.t('legal.terms'),
                hint: context.t('legal.openHint'),
                onPressed: () => reading.value = LegalDocument.terms,
              ),
              const SizedBox(height: Spacing.three),
              ListRow(
                icon: IconName.shield,
                title: context.t('legal.privacy'),
                hint: context.t('legal.openHint'),
                onPressed: () => reading.value = LegalDocument.privacy,
              ),
              const SizedBox(height: Spacing.three),
              FormError(error.value),
              const SizedBox(height: Spacing.two),
              AppButton(label: context.t('legal.accept'), loading: accept.isPending, onPressed: agree),
              const SizedBox(height: Spacing.two),
              AppButton(
                label: context.t('legal.signOut'),
                variant: ButtonVariant.tertiary,
                onPressed: AuthClient.instance.signOut,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
