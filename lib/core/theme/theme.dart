import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';

/// Figma "03 · Screens" is Light mode + Green accent since the M9 redesign (docs/05). Change it here
/// to try another Figma "Accent" mode.
const AccentName appAccent = AccentName.green;

/// Text in the Figma type scale. Names match the Figma text styles (Typography/*).
enum TextType { display, hero, title, heading, body, label, caption, micro }

TextStyle textStyle(TextType type, {Color? color}) {
  final t = switch (type) {
    TextType.display => FigmaType.display,
    TextType.hero => FigmaType.hero,
    TextType.title => FigmaType.title,
    TextType.heading => FigmaType.heading,
    TextType.body => FigmaType.body,
    TextType.label => FigmaType.label,
    TextType.caption => FigmaType.caption,
    TextType.micro => FigmaType.micro,
  };
  return TextStyle(
    fontFamily: t.fontFamily,
    fontWeight: t.fontWeight,
    fontSize: t.fontSize,
    height: t.lineHeight / t.fontSize,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData build(Brightness brightness) {
    final c = AppColors.resolve(brightness, appAccent);
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.brand,
        brightness: brightness,
        primary: c.brand,
        onPrimary: c.onBrand,
        surface: c.surface,
        onSurface: c.text,
        error: c.danger,
      ),
      extensions: [c],
      textTheme: base.textTheme.apply(fontFamily: 'DM Sans', bodyColor: c.text, displayColor: c.text),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.brand, selectionHandleColor: c.brand),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.text,
        centerTitle: true,
        titleTextStyle: textStyle(TextType.heading, color: c.text),
      ),
      dividerColor: c.border,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      // iOS-style push transitions on both platforms: the design follows Apple HIG.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: CupertinoThemeData(primaryColor: c.brand, brightness: brightness),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brand : null),
      ),
    );
  }
}

extension ThemeContext on BuildContext {
  /// The palette for the current scheme (system or Settings → Välimus).
  AppColors get c => Theme.of(this).extension<AppColors>()!;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
