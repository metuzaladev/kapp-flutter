import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'icon.dart';
import 'pressable.dart';

/// `danger`: irreversible actions only (M10 "Kustuta konto"), never as the default choice.
enum ButtonVariant { primary, secondary, tertiary, danger }

/// Figma component "Button" (Style = Primary | Secondary | Tertiary). At least 52 pt high (≥ 44 pt
/// target) and grows with Dynamic Type: a minimum height, never a fixed one, and the label wraps
/// instead of being clipped ("Отправить" must fit at 160 % text size).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.loading = false,
    this.trailingIcon,
    this.hint,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;

  /// Shows a spinner and blocks presses — prevents double submits while a request runs.
  final bool loading;

  /// Figma "Button / Arrow": an icon after the label (decorative).
  final IconName? trailingIcon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final background = switch (variant) {
      ButtonVariant.primary => c.brand,
      ButtonVariant.secondary => c.soft,
      ButtonVariant.danger => c.danger,
      ButtonVariant.tertiary => Colors.transparent,
    };
    // Danger fill is dark red in light mode (white text) and light rose in dark mode (dark text).
    final color = switch (variant) {
      ButtonVariant.primary => c.onBrand,
      ButtonVariant.tertiary => c.link,
      ButtonVariant.danger => context.isDark ? c.background : Colors.white,
      ButtonVariant.secondary => c.text,
    };
    final inactive = onPressed == null || loading;
    return Pressable(
      onPressed: inactive ? null : onPressed,
      semanticLabel: label,
      semanticHint: hint,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.three, vertical: Spacing.two),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(Radii.r16)),
        alignment: Alignment.center,
        child: loading
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: color))
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: textStyle(TextType.label, color: color),
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: Spacing.two),
                    AppIcon(trailingIcon!, size: 20, color: color),
                  ],
                ],
              ),
      ),
    );
  }
}
