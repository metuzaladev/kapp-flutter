import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'pressable.dart';

/// Figma "Segmented Control" (56:105): two equal segments in a surface pill, the chosen one filled
/// with the brand colour (Tulevased / Varasemad, Isane / Emane). Segments grow with large text.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.allowDeselect = false,
    this.semanticLabel,
  });

  final List<({T value, String label})> options;

  /// null = nothing chosen yet (e.g. a dog's sex is optional).
  final T? value;
  final ValueChanged<T?> onChanged;

  /// Tapping the chosen segment clears the choice (optional fields). Off for view switches.
  final bool allowDeselect;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Spacing.one),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: Spacing.one),
              Expanded(child: _segment(context, options[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, ({T value, String label}) option) {
    final c = context.c;
    final selected = option.value == value;
    return Pressable(
      semanticLabel: option.label,
      checked: selected,
      onPressed: () {
        if (selected && !allowDeselect) return;
        haptic(HapticReason.selection);
        onChanged(selected ? null : option.value);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.two, vertical: Spacing.one),
        decoration: BoxDecoration(
          color: selected ? c.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        alignment: Alignment.center,
        child: Text(
          option.label,
          textAlign: TextAlign.center,
          style: textStyle(TextType.label, color: selected ? c.onBrand : c.muted),
        ),
      ),
    );
  }
}
