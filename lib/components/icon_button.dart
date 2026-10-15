import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// Figma "Icon Button" (56:112): 52 × 52 pt, radius 18, soft shadow — the floating map controls.
/// Solid = primary action (brand), glass = secondary (surface + border).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.hint,
    this.solid = false,
    this.badge = false,
  });

  final IconName icon;

  /// Required: an icon alone says nothing to a screen reader.
  final String label;
  final String? hint;
  final VoidCallback onPressed;
  final bool solid;

  /// Small dot for an active state (e.g. filters applied); the label must say the same.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onPressed: onPressed,
      semanticLabel: label,
      semanticHint: hint,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: solid ? c.brand : c.surface,
          borderRadius: BorderRadius.circular(18),
          border: solid ? null : Border.all(color: c.border),
          // Figma drop shadow 0 8 12 rgba(0,0,0,0.16).
          boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 12, offset: Offset(0, 8))],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AppIcon(icon, size: 24, color: solid ? c.onBrand : c.text),
            if (badge)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
