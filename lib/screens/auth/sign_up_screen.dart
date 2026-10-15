import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/icon.dart';
import '../../components/photo_tile.dart';
import '../../components/screen.dart';
import '../../components/social_sign_in.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../components/text_field.dart';
import '../../core/auth/auth_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/logic/account.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/validation.dart';

/// Figma "Liitu 1 200 koeraomanikuga Tallinnas" strip, without the number: there is no member count
/// API, and a made-up figure would mislead (docs/11).
class _SocialProof extends StatelessWidget {
  const _SocialProof();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const dogs = ['luna', 'rex', 'charlie'];
    return Semantics(
      label: context.t('auth.signUp.socialProof'),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.r16)),
        child: Row(
          children: [
            SizedBox(
              width: 32 + 3 * 24,
              height: 32,
              child: Stack(
                children: [
                  PhotoTile(
                    asset: 'assets/images/welcome-dog.jpg',
                    size: 32,
                    radius: 9,
                    border: (width: 2, color: c.soft),
                  ),
                  for (final (i, d) in dogs.indexed)
                    Positioned(
                      left: (i + 1) * 24.0,
                      child: PhotoTile(
                        asset: 'assets/images/sample-dogs/$d.jpg',
                        size: 32,
                        radius: 9,
                        border: (width: 2, color: c.soft),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: AppText(context.t('auth.signUp.socialProof'), type: TextType.label)),
          ],
        ),
      ),
    );
  }
}

/// Figma 01 / Account / Sign Up (6:131, M9): social proof, Apple first, "või e-postiga", the form. On
/// success the router switches to the app automatically.
class SignUpScreen extends HookWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController();
    final email = useTextEditingController();
    final password = useTextEditingController();
    final errors = useState<FieldErrors>({});
    final formError = useState<String?>(null);
    final loading = useState(false);

    Future<void> submit() async {
      final invalid = validateSignUp(name: name.text, email: email.text, password: password.text);
      errors.value = invalid;
      formError.value = null;
      if (invalid.isNotEmpty) return;
      loading.value = true;
      // M10: the accepted legal versions are recorded with the account, and the language makes the
      // confirmation email arrive in the app's language (Better Auth additionalFields).
      final result = await AuthClient.instance.signUpEmail(
        name: name.text.trim(),
        email: email.text.trim().toLowerCase(),
        password: password.text,
        extra: {...currentLegalVersions(), 'language': currentLanguage().name},
      );
      loading.value = false;
      formError.value = result.error;
    }

    return AppScreen(
      navBar: true,
      title: context.t('auth.signUp.title'),
      subtitle: context.t('auth.signUp.subtitle'),
      children: [
        const _SocialProof(),
        SocialSignIn(
          onError: (e) => formError.value = e,
          footer: OrDivider(label: context.t('auth.orEmail')),
        ),
        FormError(formError.value),
        AppTextField(
          label: context.t('auth.signUp.name'),
          placeholder: context.t('auth.signUp.namePlaceholder'),
          controller: name,
          error: errors.value['name'],
          autofillHints: const [AutofillHints.name],
          capitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        AppTextField(
          label: context.t('auth.email'),
          placeholder: context.t('auth.signUp.emailPlaceholder'),
          controller: email,
          error: errors.value['email'],
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          capitalization: TextCapitalization.none,
          textInputAction: TextInputAction.next,
        ),
        AppTextField(
          label: context.t('auth.password'),
          placeholder: context.t('auth.passwordHint', params: {'min': passwordMin}),
          controller: password,
          error: errors.value['password'],
          obscure: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => submit(),
        ),
        AppText(context.t('auth.signUp.terms'), type: TextType.caption, themeColor: TextColor.muted),
        const LegalLinks(),
        AppButton(
          label: context.t('auth.signUp.submit'),
          trailingIcon: IconName.arrowRight,
          loading: loading.value,
          onPressed: submit,
        ),
        AppButton(
          label: context.t('auth.signUp.haveAccount'),
          variant: ButtonVariant.tertiary,
          onPressed: () => context.pushReplacement('/welcome/sign-in'),
        ),
      ],
    );
  }
}
