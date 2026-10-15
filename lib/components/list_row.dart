import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'icon.dart';
import 'photo_tile.dart';
import 'pressable.dart';
import 'text.dart';

/// Figma "List Row" (4:24): optional photo or icon, title, subtitle and chevron; at least 64 pt high.
/// One screen-reader element ("title, subtitle"); photo and chevron are decoration.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.photoUrl,
    this.photoName,
    this.showPhoto = false,
    this.icon,
    this.leading,
    this.trailing,
    this.alert = false,
    this.danger = false,
    this.onPressed,
    this.onLongPress,
    this.hint,
  });

  final String title;
  final String? subtitle;

  /// Figma List Row photo variant: a 44 pt rounded-square photo (radius 14) for dogs and people.
  final String? photoUrl;
  final String? photoName;
  final bool showPhoto;

  /// Figma List Row icon variant (Lucide, 24 pt) for menu rows.
  final IconName? icon;
  final Widget? leading;
  final Widget? trailing;

  /// Draws the subtitle in the danger colour (e.g. an overdue vaccination).
  final bool alert;

  /// Destructive menu row (M10 "Kustuta konto"): title and icon in the danger colour.
  final bool danger;

  /// Omitted → an informational row: no chevron, read as text.
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onPressed: onPressed,
      onLongPress: onLongPress,
      button: onPressed != null,
      dimWhenDisabled: false,
      semanticLabel: [title, if (subtitle != null && subtitle!.isNotEmpty) subtitle].join(', '),
      semanticHint: hint,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(Spacing.three),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.r16),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            if (showPhoto || photoUrl != null) ...[
              PhotoTile(url: photoUrl, name: photoName ?? title, size: 44, radius: 14),
              const SizedBox(width: Spacing.three),
            ],
            if (icon != null) ...[
              AppIcon(icon!, size: 24, color: danger ? c.danger : c.text),
              const SizedBox(width: Spacing.three),
            ],
            if (leading != null) ...[leading!, const SizedBox(width: Spacing.three)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(title, type: TextType.label, themeColor: danger ? TextColor.danger : null),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    AppText(subtitle!, type: TextType.caption, themeColor: alert ? TextColor.danger : TextColor.muted),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (onPressed != null) ...[
              const SizedBox(width: Spacing.two),
              AppIcon(IconName.chevronRight, size: 18, color: c.muted),
            ],
          ],
        ),
      ),
    );
  }
}
