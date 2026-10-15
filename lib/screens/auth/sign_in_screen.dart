import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/button.dart';
import '../../components/icon.dart';
import '../../components/screen.dart';
import '../../components/social_sign_in.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../components/text_field.dart';
import '../../core/auth/auth_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/theme.dart';
import '../../core/validation.dart';

/// Figma 01 / Account / Log In (6:168, M9): Apple first (when available), "või e-postiga", the form.
class SignInScreen extends HookWidget {
  const SignInScreen({super.key, this.notice});

  /// `password-reset` after a successful password reset.
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final email = useTextEditingController();
    final password = useTextEditingController();
    final errors = useState<FieldErrors>({});
    final formError = useState<String?>(null);
    final loading = useState(false);

    Future<void> submit() async {
      final invalid = validateSignIn(email: email.text, password: password.text);
      errors.value = invalid;
      formError.value = null;
      if (invalid.isNotEmpty) return;
      loading.value = true;
      final result = await AuthClient.instance.signInEmail(
        email: email.text.trim().toLowerCase(),
        password: password.text,
      );
      loading.value = false;
      formError.value = result.error;
    }

    return AppScreen(
      navBar: true,
      title: context.t('auth.signIn.title'),
      subtitle: context.t('auth.signIn.subtitle'),
      children: [
        if (notice == 'password-reset')
          AppText(context.t('auth.signIn.passwordChanged'), type: TextType.label, themeColor: TextColor.link),
        SocialSignIn(
          signInMode: true,
          onError: (e) => formError.value = e,
          footer: OrDivider(label: context.t('auth.orEmail')),
        ),
        FormError(formError.value),
        AutofillGroup(
          child: Column(
            children: [
              AppTextField(
                label: context.t('auth.email'),
                placeholder: context.t('auth.emailPlaceholder'),
                controller: email,
                error: errors.value['email'],
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                capitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: context.t('auth.password'),
                placeholder: context.t('auth.signIn.passwordPlaceholder'),
                controller: password,
                error: errors.value['password'],
                obscure: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
        ),
        AppButton(
          label: context.t('auth.signIn.submit'),
          trailingIcon: IconName.arrowRight,
          loading: loading.value,
          onPressed: submit,
        ),
        AppButton(
          label: context.t('auth.signIn.forgot'),
          variant: ButtonVariant.tertiary,
          onPressed: () => context.push('/welcome/reset-password'),
        ),
        AppButton(
          label: context.t('auth.signIn.createAccount'),
          variant: ButtonVariant.secondary,
          onPressed: () => context.pushReplacement('/welcome/sign-up'),
        ),
      ],
    );
  }
}
