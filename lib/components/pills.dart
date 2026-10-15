import 'package:flutter/material.dart';

import '../core/i18n/i18n.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'icon.dart';

/// The paw-discount pill of Pood rows and Product Cards (Figma "Discount": paw + "−15%").
/// Decorative: the row's label reads "−15% käppadega".
class DiscountPill extends StatelessWidget {
  const DiscountPill({super.key, required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.full)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(IconName.pawPrint, size: 12, color: c.brand),
            const SizedBox(width: 4),
            Text(
              context.t('shop.discount', params: {'percent': percent}),
              style: textStyle(TextType.caption, color: c.accent),
            ),
          ],
        ),
      ),
    );
  }
}
