import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'map_pins.dart';

/// Base map: OpenFreeMap vector tiles — free, no API key, OSM data — with the same styles as the React
/// Native app: "positron" in light mode (a quiet grey base, so the coloured category pins and dog pins
/// carry the information) and "dark" in dark mode. Kept in one place so a switch to MapTiler (paid,
/// SLA) is a one-line change. Styles are read once per scheme and cached for the session.
const mapStyleUrl = (
  light: 'https://tiles.openfreemap.org/styles/positron',
  dark: 'https://tiles.openfreemap.org/styles/dark',
);

final Map<bool, Future<Style>> _styles = {};

Future<Style> _style(bool dark) =>
    _styles[dark] ??= StyleReader(uri: dark ? mapStyleUrl.dark : mapStyleUrl.light).read().catchError((Object e) {
      // A failed read must not be cached: the next map tries again (e.g. after going online).
      _styles.remove(dark);
      throw e;
    });

class KappTileLayer extends HookWidget {
  const KappTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final style = useFuture(useMemoized(() => _style(dark), [dark])).data;
    if (style == null) return const SizedBox.shrink();
    return VectorTileLayer(
      theme: style.theme,
      sprites: style.sprites,
      tileProviders: style.providers,
      tileOffset: TileOffset.mapbox,
    );
  }
}

class KappAttribution extends StatelessWidget {
  const KappAttribution({super.key, this.bottom = 8});
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Positioned(
      right: 8,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: c.surface.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6)),
          child: Text('© OpenFreeMap © OpenStreetMap', style: textStyle(TextType.micro, color: c.muted)),
        ),
      ),
    );
  }
}

/// A non-interactive map (previews): no gestures, hidden from screen readers.
/// MapLibre zooms count 512 px tiles, flutter_map 256 px ones: the same view is one level higher here.
/// Every zoom taken from the React Native app or the API (search results) is converted with this.
const maplibreZoomOffset = 1.0;

MapOptions staticMapOptions({required LatLng center, double zoom = 14, CameraFit? fit}) => MapOptions(
  initialCenter: center,
  initialZoom: zoom,
  initialCameraFit: fit,
  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
);

/// Illustrative dog groups around Tallinn's centre (Figma "3 koera", "6 koera", "2 koera"). Marketing
/// illustration on the intro and permission screens — not live data, hidden from screen readers.
const _sampleGroups = [
  (lat: 59.4392, lng: 24.741, dogs: 3, faces: ['charlie', 'pug', 'aussie']),
  (lat: 59.4398, lng: 24.765, dogs: 6, faces: ['luna', 'rex', 'bella']),
  (lat: 59.4338, lng: 24.753, dogs: 2, faces: ['rex', 'charlie']),
];

String sampleDog(String name) => 'assets/images/sample-dogs/$name.jpg';

/// Figma Onboarding / Discover and Permissions / Location map preview: a real map of central Tallinn
/// with dog pins, non-interactive. Faces are bundled sample photos, not real users.
class MapPreview extends StatelessWidget {
  const MapPreview({super.key, this.height = 220, required this.dogsLabel});
  final double height;
  final String Function(int count) dogsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ExcludeSemantics(
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.r24),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: FlutterMap(
          options: staticMapOptions(center: const LatLng(59.4372, 24.753), zoom: 12.6 + maplibreZoomOffset),
          children: [
            const KappTileLayer(),
            MarkerLayer(
              markers: [
                for (final g in _sampleGroups)
                  Marker(
                    point: LatLng(g.lat, g.lng),
                    width: 160,
                    height: 90,
                    alignment: Alignment.topCenter,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: DogPin(faces: g.faces.map(sampleDog).toList(), countLabel: dogsLabel(g.dogs)),
                    ),
                  ),
              ],
            ),
            const KappAttribution(),
          ],
        ),
      ),
    );
  }
}
