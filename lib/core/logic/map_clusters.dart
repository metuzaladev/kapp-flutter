import 'dart:math' as math;

import 'explore.dart';

/// Pin clustering for the Kaart tab (M11). With the 71 real parks plus community places the Tallinn
/// view was an unreadable pile of pins; nearby pins now merge into one count bubble that zooms in
/// when tapped.
///
/// A greedy pixel-distance clustering per integer zoom (the same idea as supercluster, which the
/// React Native app uses): points are projected to Web Mercator pixels at the zoom, each unassigned
/// point starts a cluster and absorbs every point within [clusterRadius] pixels. Pure, unit-tested in
/// test/logic/map_clusters_test.dart.

/// Anything with a stable key and a position can be clustered (parks, places).
abstract interface class ClusterInput {
  String get key;
  double get lat;
  double get lng;
}

sealed class ClusterItem<T extends ClusterInput> {
  const ClusterItem({required this.key, required this.lat, required this.lng});
  final String key;
  final double lat;
  final double lng;
}

class PinItem<T extends ClusterInput> extends ClusterItem<T> {
  const PinItem({required super.key, required super.lat, required super.lng, required this.item});
  final T item;
}

class ClusterBubble<T extends ClusterInput> extends ClusterItem<T> {
  const ClusterBubble({
    required super.key,
    required super.lat,
    required super.lng,
    required this.count,
    required this.members,
  });
  final int count;
  final List<T> members;
}

/// Pixel radius pins merge within (a 40 pt pin + its neighbour's half), and the last clustering zoom.
/// Zooms here are flutter_map zooms (256 px tiles): one level above the React Native (MapLibre) values.
const clusterRadius = 56.0;
const clusterMaxZoom = 16;

/// The map opens here: a city view (≈ Tallinn's centre on a phone), not a fit of every park.
const cityZoom = 13.5;

/// Tapping a cluster never zooms further than this (street level).
const maxExpansionZoom = 18.0;

const worldBox = (west: -180.0, south: -85.0, east: 180.0, north: 85.0);

/// Web Mercator pixel coordinates at `zoom` (256 px tiles).
math.Point<double> project(double lat, double lng, double zoom) {
  final scale = 256 * math.pow(2, zoom).toDouble();
  final x = (lng + 180) / 360 * scale;
  final sinLat = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
  final y = (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
  return math.Point(x, y);
}

bool _inBox(ClusterInput p, LngLatBox box) =>
    p.lat >= box.south && p.lat <= box.north && p.lng >= box.west && p.lng <= box.east;

/// Clusters and single pins inside `bounds` at `zoom`. Integer zooms like supercluster: pins split
/// when the next whole level is reached, not before. Above [clusterMaxZoom] nothing clusters.
List<ClusterItem<T>> clustersIn<T extends ClusterInput>(List<T> items, LngLatBox bounds, double zoom) {
  final valid = items.where((i) => i.lat.isFinite && i.lng.isFinite).toList();
  final z = (zoom.isFinite ? zoom : 0).floor().clamp(0, 22);
  if (z > clusterMaxZoom) {
    return [
      for (final i in valid)
        if (_inBox(i, bounds)) PinItem<T>(key: i.key, lat: i.lat, lng: i.lng, item: i),
    ];
  }
  // Stable order (by key) so the same input always gives the same clusters.
  valid.sort((a, b) => a.key.compareTo(b.key));
  final points = [for (final i in valid) project(i.lat, i.lng, z.toDouble())];
  final used = List.filled(valid.length, false);
  final result = <ClusterItem<T>>[];
  for (var i = 0; i < valid.length; i++) {
    if (used[i]) continue;
    used[i] = true;
    final members = [valid[i]];
    for (var j = i + 1; j < valid.length; j++) {
      if (used[j]) continue;
      if (points[i].distanceTo(points[j]) <= clusterRadius) {
        used[j] = true;
        members.add(valid[j]);
      }
    }
    if (members.length == 1) {
      final m = members.single;
      if (_inBox(m, bounds)) result.add(PinItem<T>(key: m.key, lat: m.lat, lng: m.lng, item: m));
      continue;
    }
    final lat = members.map((m) => m.lat).reduce((a, b) => a + b) / members.length;
    final lng = members.map((m) => m.lng).reduce((a, b) => a + b) / members.length;
    if (lat < bounds.south || lat > bounds.north || lng < bounds.west || lng > bounds.east) continue;
    result.add(
      ClusterBubble<T>(
        key: 'cluster-${members.first.key}-${members.length}',
        lat: lat,
        lng: lng,
        count: members.length,
        members: members,
      ),
    );
  }
  return result;
}

/// The zoom where a cluster splits: the first level at which its members no longer all merge.
double expansionZoom<T extends ClusterInput>(ClusterBubble<T> cluster, double currentZoom) {
  for (var z = currentZoom.floor() + 1; z <= clusterMaxZoom + 1; z++) {
    final split = clustersIn<T>(cluster.members, worldBox, z.toDouble());
    if (split.length > 1) return math.min(maxExpansionZoom, z.toDouble());
  }
  return math.min(maxExpansionZoom, currentZoom.floor() + 2.0);
}

/// Bubble diameter grows a little with the count; never under the 44 pt touch target.
double clusterSize(int count) {
  if (count < 10) return 44;
  if (count < 50) return 50;
  return 56;
}
