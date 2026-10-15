import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/auth/auth_client.dart';
import '../core/config.dart';
import '../core/i18n/i18n.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'button.dart';

/// Continue with Apple / Google.
///
/// Apple: native sheet (sign_in_with_apple) → identity token → Better Auth verifies it. Uses Apple's
/// own button, as App Store guideline 4.8 and the HIG require.
/// Google: browser flow through the API (flutter_web_auth_2), the session cookie comes back in the
/// `kapp://` redirect like with the Expo plugin.
/// Both are hidden unless the API has credentials configured (`--dart-define=AUTH_APPLE=true` …).
class SocialSignIn extends HookWidget {
  const SocialSignIn({
    super.key,
    required this.onError,
    this.signInMode = false,
    this.showGoogle = true,
    this.footer,
    this.onSuccess,
  });

  final ValueChanged<String?> onError;

  /// Apple's button text: "Sign in with Apple" (log in) instead of "Continue with Apple".
  final bool signInMode;

  /// Welcome shows only Apple (Figma); the account screens add Google.
  final bool showGoogle;

  /// Drawn under the buttons when at least one is shown (Figma "või e-postiga" divider).
  final Widget? footer;

  /// M10 re-authentication before deleting the account: called after a successful sign-in.
  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context) {
    final appleAvailable =
        useFuture(useMemoized(() async => Platform.isIOS && authAppleEnabled && await SignInWithApple.isAvailable()))
            .data ??
        false;
    final google = showGoogle && authGoogleEnabled;
    if (!appleAvailable && !google) return const SizedBox.shrink();

    Future<void> signInWithApple() async {
      onError(null);
      try {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [AppleIDAuthorizationScopes.fullName, AppleIDAuthorizationScopes.email],
        );
        final token = credential.identityToken;
        if (token == null) throw StateError('missing identity token');
        final result = await AuthClient.instance.signInWithIdToken(provider: 'apple', token: token);
        onError(result.error);
        if (result.ok) onSuccess?.call();
      } on SignInWithAppleAuthorizationException catch (e) {
        // The user closing the Apple sheet is not an error.
        if (e.code == AuthorizationErrorCode.canceled) return;
        onError(tr('auth.social.appleFailed'));
      } catch (_) {
        onError(tr('auth.social.appleFailed'));
      }
    }

    Future<void> signInWithGoogle() async {
      onError(null);
      final start = await AuthClient.instance.socialAuthorizationUrl('google');
      if (!start.ok) return onError(start.error);
      try {
        final callback = await FlutterWebAuth2.authenticate(url: start.data! as String, callbackUrlScheme: appScheme);
        await AuthClient.instance.completeBrowserSignIn(Uri.parse(callback));
        if (AuthClient.instance.value.signedIn) onSuccess?.call();
      } catch (_) {
        // Closing the browser sheet cancels without an error message.
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (appleAvailable)
          SizedBox(
            height: 52,
            child: SignInWithAppleButton(
              text: signInMode ? 'Sign in with Apple' : 'Continue with Apple',
              style: context.isDark ? SignInWithAppleButtonStyle.white : SignInWithAppleButtonStyle.black,
              borderRadius: const BorderRadius.all(Radius.circular(Radii.r16)),
              onPressed: signInWithApple,
            ),
          ),
        if (appleAvailable && google) const SizedBox(height: Spacing.two),
        if (google)
          AppButton(
            label: context.t('auth.social.google'),
            variant: ButtonVariant.secondary,
            onPressed: signInWithGoogle,
          ),
        if (footer != null) ...[const SizedBox(height: Spacing.two), footer!],
      ],
    );
  }
}
