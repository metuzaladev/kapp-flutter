import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/core/logic/map_clusters.dart';

class _P implements ClusterInput {
  _P(this.key, this.lat, this.lng);
  @override
  final String key;
  @override
  final double lat;
  @override
  final double lng;
}

void main() {
  // Two parks 100 m apart in Kadriorg and one in Kalamaja, ~3 km away.
  final items = [_P('a', 59.4380, 24.7900), _P('b', 59.4388, 24.7905), _P('c', 59.4480, 24.7350)];

  test('merges neighbours at city zoom and keeps distant pins apart', () {
    final result = clustersIn(items, worldBox, cityZoom);
    final clusters = result.whereType<ClusterBubble<_P>>().toList();
    expect(clusters, hasLength(1));
    expect(clusters.single.count, 2);
    expect(result.whereType<PinItem<_P>>().map((p) => p.key), ['c']);
  });

  test('splits everything above the last clustering zoom', () {
    final result = clustersIn(items, worldBox, clusterMaxZoom + 1);
    expect(result.every((r) => r is PinItem<_P>), isTrue);
    expect(result, hasLength(3));
  });

  test('leaves out pins outside the visible box', () {
    final result = clustersIn(items, (west: 24.70, south: 59.44, east: 24.76, north: 59.46), 18);
    expect(result.map((r) => r.key), ['c']);
  });

  test('skips points without a position', () {
    expect(clustersIn([_P('x', double.nan, 24.7)], worldBox, 12), isEmpty);
  });

  test('a tapped cluster zooms to where it splits, never past street level', () {
    final cluster = clustersIn(items, worldBox, cityZoom).whereType<ClusterBubble<_P>>().single;
    final zoom = expansionZoom(cluster, cityZoom);
    expect(zoom, greaterThan(cityZoom));
    expect(zoom, lessThanOrEqualTo(maxExpansionZoom));
    expect(clustersIn(cluster.members, worldBox, zoom).whereType<ClusterBubble<_P>>(), isEmpty);
  });

  test('bubble size grows with the count but stays a 44 pt target', () {
    expect(clusterSize(2), 44);
    expect(clusterSize(20), 50);
    expect(clusterSize(200), 56);
  });
}
