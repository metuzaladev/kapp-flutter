import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/logic/map_categories.dart';
import '../core/logic/map_clusters.dart';
import '../core/theme/colors.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'icon.dart';
import 'photo_tile.dart';

/// Figma "Map Pin / Place" and "Map Pin / Dog" (Explore & Rewards, 56:177 / 56:189). Drawing only:
/// the map marker around them handles the tap and carries the label.

Color placeColor(AppColors c, PlaceKind kind) => switch (kind) {
  PlaceKind.park => c.mapPark,
  PlaceKind.cafe => c.mapCafe,
  PlaceKind.beach => c.mapBeach,
  PlaceKind.service => c.mapService,
  PlaceKind.vet => c.mapVet,
  // No Figma colour for shops: they share the service colour (different icon).
  PlaceKind.shop => c.mapService,
};

/// Small downward triangle under a pin (Figma "Tail").
class _Tail extends StatelessWidget {
  const _Tail({required this.color, required this.width});
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, (width * 0.6).roundToDouble()), painter: _TailPainter(color));
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

const _pinShadow = [BoxShadow(color: Color(0x29000000), blurRadius: 12, offset: Offset(0, 4))];

/// 40 pt circle in the category colour, 3 pt ring that separates it from the tiles, icon, tail.
class PlacePin extends StatelessWidget {
  const PlacePin({super.key, required this.kind, this.selected = false});
  final PlaceKind kind;
  final bool selected;

  static const size = Size(40, 47);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fill = placeColor(c, kind);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? c.text : c.mapPinRing, width: 3),
            boxShadow: _pinShadow,
          ),
          alignment: Alignment.center,
          child: AppIcon(placeIcon[kind]!, size: 20, color: c.mapPinInk),
        ),
        _Tail(color: fill, width: 12),
      ],
    );
  }
}

/// The address chosen in the map search (docs/19): a brand pin, slightly larger than place pins.
class SearchPin extends StatelessWidget {
  const SearchPin({super.key});

  static const size = Size(46, 54);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: c.brand,
            shape: BoxShape.circle,
            border: Border.all(color: c.mapPinRing, width: 3),
            boxShadow: _pinShadow,
          ),
          alignment: Alignment.center,
          child: AppIcon(IconName.mapPin, size: 22, color: c.onBrand),
        ),
        _Tail(color: c.brand, width: 14),
      ],
    );
  }
}

/// Dogs in a park: rounded-square photos with a brand border. Single = one 56 pt face with a tail;
/// group = up to three overlapping 48 pt faces and a brand "N koera" pill below.
class DogPin extends StatelessWidget {
  const DogPin({super.key, required this.faces, this.countLabel, this.selected = false});

  /// Up to three faces: bundled sample asset paths, or null → paw placeholder.
  final List<String?> faces;
  final String? countLabel;
  final bool selected;

  static Size sizeFor(int faces, bool hasCount) =>
      faces <= 1 && !hasCount ? const Size(56, 64) : Size(48 + (faces - 1) * 34, hasCount ? 84 : 48);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final border = (width: 3.0, color: selected ? c.text : c.brand);
    if (faces.length <= 1 && countLabel == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhotoTile(asset: faces.firstOrNull, size: 56, radius: 18, border: border),
          _Tail(color: border.color, width: 14),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          width: 48 + (faces.length - 1) * 34,
          child: Stack(
            children: [
              for (var i = 0; i < faces.length; i++)
                Positioned(
                  left: i * 34.0,
                  child: PhotoTile(asset: faces[i], size: 48, radius: 15, border: border),
                ),
            ],
          ),
        ),
        if (countLabel != null) ...[
          const SizedBox(height: Spacing.one),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.two, vertical: Spacing.one),
            decoration: BoxDecoration(color: border.color, borderRadius: BorderRadius.circular(Radii.full)),
            child: Text(countLabel!, style: textStyle(TextType.caption, color: selected ? c.background : c.onBrand)),
          ),
        ],
      ],
    );
  }
}

/// M11 cluster bubble: brand circle with the white pin ring, a small paw and the count. At least
/// 44 pt (touch target) and growing with the count.
class ClusterPin extends StatelessWidget {
  const ClusterPin({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = clusterSize(count);
    return Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.two),
      decoration: BoxDecoration(
        color: c.brand,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: c.mapPinRing, width: 3),
        boxShadow: _pinShadow,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(IconName.pawPrint, size: 12, color: c.onBrand),
          Text(formatNumber(count), style: textStyle(TextType.label, color: c.onBrand)),
        ],
      ),
    );
  }
}

/// "You are here", drawn on top of every pin.
class UserDot extends StatelessWidget {
  const UserDot({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: c.brand,
        shape: BoxShape.circle,
        border: Border.all(color: c.mapPinRing, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
    );
  }
}
