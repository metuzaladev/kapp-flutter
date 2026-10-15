import 'package:flutter/material.dart';

import 'tokens.dart';

/// Figma collection "Color" (modes Light / Dark), resolved for one accent — `semanticColors` in
/// `packages/shared/src/tokens.ts`. Registered as a [ThemeExtension] so `context.c` rebuilds a
/// widget when Settings → Välimus switches the scheme.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.border,
    required this.brand,
    required this.onBrand,
    required this.link,
    required this.accent,
    required this.soft,
    required this.tint,
    required this.danger,
    required this.dangerSoft,
    required this.mapPark,
    required this.mapCafe,
    required this.mapBeach,
    required this.mapService,
    required this.mapVet,
    required this.mapPinInk,
    required this.mapPinRing,
  });

  factory AppColors.resolve(Brightness scheme, AccentName accentName) {
    final a = accents[accentName]!;
    final light = scheme == Brightness.light;
    return AppColors(
      background: light ? Primitives.gray50 : Primitives.inkDeep,
      surface: light ? Primitives.white : Primitives.slate900,
      text: light ? Primitives.ink : Primitives.gray100,
      muted: light ? Primitives.gray600 : Primitives.gray400,
      border: light ? Primitives.gray200 : Primitives.slate700,
      brand: a.base,
      onBrand: a.onBase,
      link: light ? a.ink : a.light,
      accent: light ? a.ink : a.light,
      soft: light ? a.soft : a.softDark,
      tint: light ? a.tint : a.tintDark,
      danger: light ? Primitives.red : Primitives.rose,
      dangerSoft: light ? Primitives.rose : Primitives.red,
      mapPark: light ? MapPalette.parkLight : MapPalette.parkDark,
      mapCafe: light ? MapPalette.cafeLight : MapPalette.cafeDark,
      mapBeach: light ? MapPalette.beachLight : MapPalette.beachDark,
      mapService: light ? MapPalette.serviceLight : MapPalette.serviceDark,
      mapVet: light ? MapPalette.vetLight : MapPalette.vetDark,
      mapPinInk: light ? MapPalette.pinInkLight : MapPalette.pinInkDark,
      mapPinRing: light ? MapPalette.pinRingLight : MapPalette.pinRingDark,
    );
  }

  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color border;
  final Color brand;
  final Color onBrand;
  final Color link;

  /// Figma color/accent: the accent as readable text (points, "3 sõpra pargis").
  final Color accent;
  final Color soft;
  final Color tint;
  final Color danger;
  final Color dangerSoft;

  /// Figma "map/*": place categories on the map (pins, the park photo tag).
  final Color mapPark;
  final Color mapCafe;
  final Color mapBeach;
  final Color mapService;
  final Color mapVet;

  /// Icon/text on a category fill.
  final Color mapPinInk;

  /// Ring around a place pin, separates it from the map tiles.
  final Color mapPinRing;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      border: l(border, other.border),
      brand: l(brand, other.brand),
      onBrand: l(onBrand, other.onBrand),
      link: l(link, other.link),
      accent: l(accent, other.accent),
      soft: l(soft, other.soft),
      tint: l(tint, other.tint),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      mapPark: l(mapPark, other.mapPark),
      mapCafe: l(mapCafe, other.mapCafe),
      mapBeach: l(mapBeach, other.mapBeach),
      mapService: l(mapService, other.mapService),
      mapVet: l(mapVet, other.mapVet),
      mapPinInk: l(mapPinInk, other.mapPinInk),
      mapPinRing: l(mapPinRing, other.mapPinRing),
    );
  }
}
