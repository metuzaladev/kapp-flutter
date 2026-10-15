import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/button.dart';
import '../../components/icon.dart';
import '../../components/screen.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../components/text_field.dart';
import '../../core/auth/auth_client.dart';
import '../../core/config.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/validation.dart';

/// Figma reset steps card: what happens after "Saada taastamislink"; step 1 (this screen) is highlighted.
class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(Spacing.three),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.r16)),
      child: Column(
        children: [
          for (final step in [1, 2, 3]) ...[
            if (step > 1) const SizedBox(height: Spacing.three),
            Builder(
              builder: (context) {
                final title = context.t('auth.resetPassword.step${step}Title');
                final body = context.t('auth.resetPassword.step${step}Body', params: {'min': passwordMin});
                final current = step == 1;
                return Semantics(
                  label: context.t('auth.resetPassword.stepA11y', params: {'step': step, 'title': title, 'body': body}),
                  excludeSemantics: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: current ? c.brand : c.background, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: AppText('$step', type: TextType.caption, color: current ? c.onBrand : c.muted),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(title, type: TextType.label),
                            const SizedBox(height: 2),
                            AppText(body, type: TextType.caption, themeColor: TextColor.muted),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Figma 01 / Account / Reset Password (6:220, M9): lock tile, e-mail, submit, 3-step card.
class ResetPasswordScreen extends HookWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final email = useTextEditingController();
    final errors = useState<FieldErrors>({});
    final formError = useState<String?>(null);
    final loading = useState(false);

    Future<void> submit() async {
      final error = emailError(email.text);
      errors.value = {'email': ?error};
      formError.value = null;
      if (error != null) return;
      loading.value = true;
      // The emailed link opens the API, which redirects to kapp://new-password?token=…
      final result = await AuthClient.instance.requestPasswordReset(
        email: email.text.trim().toLowerCase(),
        redirectTo: '$appScheme://new-password',
      );
      loading.value = false;
      if (!result.ok) {
        formError.value = result.error;
        return;
      }
      // Same screen whether or not the address has an account — no account enumeration.
      if (context.mounted) context.pushReplacement('/welcome/reset-sent');
    }

    return AppScreen(
      navBar: true,
      title: context.t('auth.resetPassword.title'),
      subtitle: context.t('auth.resetPassword.subtitle'),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ExcludeSemantics(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(20)),
              alignment: Alignment.center,
              child: AppIcon(IconName.lock, size: 32, color: c.brand),
            ),
          ),
        ),
        FormError(formError.value),
        AppTextField(
          label: context.t('auth.email'),
          placeholder: context.t('auth.emailPlaceholder'),
          controller: email,
          error: errors.value['email'],
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          capitalization: TextCapitalization.none,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => submit(),
        ),
        AppButton(
          label: context.t('auth.resetPassword.submit'),
          trailingIcon: IconName.arrowRight,
          loading: loading.value,
          onPressed: submit,
        ),
        const _Steps(),
        AppButton(
          label: context.t('auth.backToSignIn'),
          variant: ButtonVariant.tertiary,
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}

/// Figma 01 / Reset sent. Wording does not confirm that the address exists.
class ResetSentScreen extends StatelessWidget {
  const ResetSentScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScreen(
    navBar: true,
    title: context.t('auth.resetSent.title'),
    subtitle: context.t('auth.resetSent.subtitle'),
    children: [AppButton(label: context.t('auth.backToSignIn'), onPressed: () => context.go('/welcome/sign-in'))],
  );
}

/// Opened from the reset email (deep link with ?token=…). Not in Figma yet — follows Reset Password.
class NewPasswordScreen extends HookWidget {
  const NewPasswordScreen({super.key, this.token, this.linkError});
  final String? token;
  final String? linkError;

  @override
  Widget build(BuildContext context) {
    final password = useTextEditingController();
    final errors = useState<FieldErrors>({});
    final formError = useState<String?>(
      token == null || linkError != null ? context.t('auth.newPassword.linkInvalid') : null,
    );
    final loading = useState(false);

    Future<void> submit() async {
      final error = passwordError(password.text);
      errors.value = {'newPassword': ?error};
      if (error != null || token == null) return;
      loading.value = true;
      final result = await AuthClient.instance.resetPassword(token: token!, newPassword: password.text);
      loading.value = false;
      if (!result.ok) {
        formError.value = result.error;
        return;
      }
      // All other sessions were revoked server-side (revokeSessionsOnPasswordReset).
      if (context.mounted) context.go('/welcome/sign-in?notice=password-reset');
    }

    return AppScreen(
      navBar: true,
      title: context.t('auth.newPassword.title'),
      subtitle: context.t('auth.newPassword.subtitle'),
      children: [
        FormError(formError.value),
        AppTextField(
          label: context.t('auth.newPassword.label'),
          placeholder: context.t('auth.passwordHint', params: {'min': passwordMin}),
          controller: password,
          error: errors.value['newPassword'],
          obscure: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => submit(),
        ),
        AppButton(
          label: context.t('auth.newPassword.submit'),
          loading: loading.value,
          onPressed: token == null ? null : submit,
        ),
        if (token == null)
          AppButton(
            label: context.t('auth.newPassword.requestNew'),
            variant: ButtonVariant.tertiary,
            onPressed: () => context.pushReplacement('/welcome/reset-password'),
          ),
      ],
    );
  }
}
