import 'package:flutter/painting.dart';

/// Design tokens mirrored from the Figma file "Käpp — Dog Park App · Design System & Screens"
/// (variables: Primitives, Color, Accent, Dimensions; text styles: Typography/*).
///
/// Source of truth: `packages/shared/src/tokens.ts` in the ICD0018-kapp repository. Names are kept
/// the same so design, the React Native app and this app can be compared 1:1;
/// `test/tokens_test.dart` pins the values to `assets/data/tokens.json` (exported from there).
class Primitives {
  const Primitives._();
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF14181F);
  static const gray50 = Color(0xFFF7F8FA);
  static const gray100 = Color(0xFFF2F4F7);
  static const gray200 = Color(0xFFE3E6EA);
  static const gray400 = Color(0xFFA3ACB9);
  static const gray600 = Color(0xFF5B6472);
  static const inkDeep = Color(0xFF0F1419);
  static const slate900 = Color(0xFF1A2028);
  static const slate700 = Color(0xFF2A323D);
  static const red = Color(0xFFAD4C42);
  static const rose = Color(0xFFFAE3DE);
}

/// One Figma "Accent" mode. `onBase` = text/icons on the brand fill, `ink` = the accent as text on
/// light backgrounds.
class Accent {
  const Accent({
    required this.base,
    required this.light,
    required this.soft,
    required this.softDark,
    required this.tint,
    required this.tintDark,
    required this.onBase,
    required this.ink,
  });

  final Color base;
  final Color light;
  final Color soft;
  final Color softDark;
  final Color tint;
  final Color tintDark;
  final Color onBase;
  final Color ink;
}

enum AccentName { terracotta, blue, green, violet, lime }

const Map<AccentName, Accent> accents = {
  AccentName.terracotta: Accent(
    base: Color(0xFFB5532A),
    light: Color(0xFFF0A27E),
    soft: Color(0xFFFBEEE8),
    softDark: Color(0xFF33241D),
    tint: Color(0xFFF6DCCF),
    tintDark: Color(0xFF6B3319),
    onBase: Color(0xFFFFFFFF),
    ink: Color(0xFFB5532A),
  ),
  AccentName.blue: Accent(
    base: Color(0xFF2F6BE0),
    light: Color(0xFF8DB2FF),
    soft: Color(0xFFEAF1FE),
    softDark: Color(0xFF1F2A3D),
    tint: Color(0xFFD6E4FD),
    tintDark: Color(0xFF24407A),
    onBase: Color(0xFFFFFFFF),
    ink: Color(0xFF2F6BE0),
  ),
  AccentName.green: Accent(
    base: Color(0xFF2E7D4F),
    light: Color(0xFF7FD1A0),
    soft: Color(0xFFE8F4EC),
    softDark: Color(0xFF1C2E24),
    tint: Color(0xFFCFE8D8),
    tintDark: Color(0xFF1F4A33),
    onBase: Color(0xFFFFFFFF),
    ink: Color(0xFF2E7D4F),
  ),
  AccentName.violet: Accent(
    base: Color(0xFF6B4EE6),
    light: Color(0xFFB3A4FF),
    soft: Color(0xFFEFECFD),
    softDark: Color(0xFF272340),
    tint: Color(0xFFDED8FB),
    tintDark: Color(0xFF3A2E85),
    onBase: Color(0xFFFFFFFF),
    ink: Color(0xFF6B4EE6),
  ),
  // Bright accent: its base is too light for white text, which is why every accent carries `onBase`
  // and `ink`. For the four darker accents both are simply white / the base.
  AccentName.lime: Accent(
    base: Color(0xFFC9F04A),
    light: Color(0xFFDFFF7A),
    soft: Color(0xFFF3FAD9),
    softDark: Color(0xFF232B12),
    tint: Color(0xFFE7F6B4),
    tintDark: Color(0xFF3A4A10),
    onBase: Color(0xFF10150A),
    ink: Color(0xFF4F7A00),
  ),
};

/// Figma variables "map/*" (modes Light / Dark), independent of the accent.
class MapPalette {
  const MapPalette._();
  static const parkLight = Color(0xFF4F8A5B), parkDark = Color(0xFF7FC28E);
  static const cafeLight = Color(0xFFC8743F), cafeDark = Color(0xFFF0A27E);
  static const beachLight = Color(0xFF3E7CB1), beachDark = Color(0xFF8EC5F0);
  static const serviceLight = Color(0xFFB5532A), serviceDark = Color(0xFFE07A4F);
  static const vetLight = Color(0xFFB4564B), vetDark = Color(0xFFEE9A90);
  static const pinInkLight = Color(0xFFFFFFFF), pinInkDark = Color(0xFF0F1419);
  static const pinRingLight = Color(0xFFFFFFFF), pinRingDark = Color(0xFFF2F4F7);
}

/// A Figma text style (Typography/*), aligned to the iOS type scale.
class TypeToken {
  const TypeToken(this.fontFamily, this.fontWeight, this.fontSize, this.lineHeight);
  final String fontFamily;
  final FontWeight fontWeight;
  final double fontSize;
  final double lineHeight;
}

class FigmaType {
  const FigmaType._();
  static const display = TypeToken('Manrope', FontWeight.w800, 56, 64);
  static const hero = TypeToken('Manrope', FontWeight.w700, 34, 41);
  static const title = TypeToken('Manrope', FontWeight.w700, 22, 28);
  static const heading = TypeToken('Manrope', FontWeight.w700, 17, 22);
  static const body = TypeToken('DM Sans', FontWeight.w400, 17, 22);
  static const label = TypeToken('DM Sans', FontWeight.w700, 15, 20);
  static const caption = TypeToken('DM Sans', FontWeight.w500, 13, 18);
  static const micro = TypeToken('DM Sans', FontWeight.w500, 11, 13);
}

/// Figma Dimensions: spacing scale (`space`) and radii (`radius`).
class Space {
  const Space._();
  static const double s0 = 0, s4 = 4, s8 = 8, s12 = 12, s16 = 16, s20 = 20, s24 = 24, s32 = 32, s40 = 40, s48 = 48;
}

class Radii {
  const Radii._();
  static const double r0 = 0, r12 = 12, r16 = 16, r24 = 24, r32 = 32, full = 999;
}

/// The app's spacing names (constants/theme.ts in the React Native app).
class Spacing {
  const Spacing._();
  static const double half = 2;
  static const double one = Space.s4;
  static const double two = Space.s8;
  static const double three = Space.s16;
  static const double four = Space.s24;
  static const double five = Space.s32;
  static const double six = 64;
  static const double screen = Space.s24;
}

/// Figma Dimensions → ios/* (Apple Human Interface Guidelines).
class IosDimensions {
  const IosDimensions._();
  static const double touchTargetMin = 44;
  static const double navBarHeight = 44;
  static const double tabBarHeight = 49;
  static const double screenMargin = 24;
}
