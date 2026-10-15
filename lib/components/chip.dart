import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/logic/motion.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'icon.dart';
import 'pressable.dart';

/// Figma "Chip" (Selected = True | False). At least 44 pt high for the HIG touch target.
///
/// Width comes from the label (no fixed width): Russian labels are up to twice as long, and a row of
/// chips wraps rather than breaking a word. Selecting cross-fades the colours (instant with Reduce
/// Motion) and plays the selection haptic.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    required this.onPressed,
    this.hint,
    this.radio = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final String? hint;

  /// An exclusive choice (radio) instead of a toggle button.
  final bool radio;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final duration = motionDuration(MotionDurations.quick, reduceMotion: MediaQuery.of(context).disableAnimations);
    return Pressable(
      onPressed: () {
        haptic(HapticReason.selection);
        onPressed();
      },
      semanticLabel: label,
      semanticHint: hint,
      selected: radio ? null : selected,
      checked: radio ? selected : null,
      child: AnimatedContainer(
        duration: duration,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.three, vertical: Spacing.two),
        decoration: BoxDecoration(
          color: selected ? c.brand : c.surface,
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(color: c.border, width: 0.5),
        ),
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: duration,
          style: textStyle(TextType.caption, color: selected ? c.onBrand : c.text),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// Figma "Chip / Icon" (56:134): 18 pt icon + label in a pill. Selected = brand fill and onBrand
/// text, unselected = surface with a hairline border. Drawn 40 pt high inside a 44 pt target.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onPressed,
    this.hint,
    this.radio = false,
  });

  final IconName icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final String? hint;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final duration = motionDuration(MotionDurations.quick, reduceMotion: MediaQuery.of(context).disableAnimations);
    return Pressable(
      onPressed: () {
        haptic(HapticReason.selection);
        onPressed();
      },
      semanticLabel: label,
      semanticHint: hint,
      selected: radio ? null : selected,
      checked: radio ? selected : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: AnimatedContainer(
          duration: duration,
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.only(left: 12, right: Spacing.three, top: Spacing.one, bottom: Spacing.one),
          decoration: BoxDecoration(
            color: selected ? c.brand : c.surface,
            borderRadius: BorderRadius.circular(Radii.full),
            border: Border.all(color: selected ? c.brand : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 18, color: selected ? c.onBrand : c.text),
              const SizedBox(width: 6),
              Text(label, maxLines: 1, style: textStyle(TextType.label, color: selected ? c.onBrand : c.text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of chips (Figma Chip Row over the map, list filters). Never wraps;
/// bleeds to the screen edges so the first chip lines up with the content.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.bleed = Spacing.screen});

  final List<Widget> children;

  /// Horizontal margin of the parent to bleed through (0 when the parent has none).
  final double bleed;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(-bleed, 0),
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: bleed),
          child: Row(children: _gap(children, Spacing.two)),
        ),
      ),
    );
  }
}

/// Wrapping chips (Figma chip groups in forms).
class ChipWrap extends StatelessWidget {
  const ChipWrap({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: Spacing.two, runSpacing: Spacing.two, children: children);
}

List<Widget> _gap(List<Widget> children, double gap) => [
  for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: gap), children[i]],
];
