import 'package:flutter/material.dart';

import '../core/theme/theme.dart';

/// Which palette colour a text uses (`themeColor` in the React Native ThemedText).
enum TextColor { text, muted, link, danger, accent, brand, onBrand }

/// Text in the Figma type scale. `type` names match the Figma text styles (Typography/*).
class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.type = TextType.body,
    this.color,
    this.themeColor,
    this.maxLines,
    this.textAlign,
    this.header = false,
    this.overflow,
  });

  final String text;
  final TextType type;
  final Color? color;
  final TextColor? themeColor;
  final int? maxLines;
  final TextAlign? textAlign;

  /// Announced as a heading by screen readers.
  final bool header;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final resolved =
        color ??
        switch (themeColor) {
          TextColor.muted => c.muted,
          TextColor.link => c.link,
          TextColor.danger => c.danger,
          TextColor.accent => c.accent,
          TextColor.brand => c.brand,
          TextColor.onBrand => c.onBrand,
          _ => c.text,
        };
    final widget = Text(
      text,
      style: textStyle(type, color: resolved),
      maxLines: maxLines,
      overflow: overflow ?? (maxLines != null ? TextOverflow.ellipsis : null),
      textAlign: textAlign,
    );
    return header ? Semantics(header: true, child: widget) : widget;
  }
}
