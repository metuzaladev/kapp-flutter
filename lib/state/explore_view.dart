import 'package:flutter/foundation.dart';

import '../core/logic/map_categories.dart';

/// Which half of the Kaart tab is showing: the full-screen map or the Avasta feed (docs/16).
///
/// A module store, not a route: the two views are one tab (Figma draws Kaart / Avasta as a Segmented
/// Control), switching must not push history, and other screens need to steer the tab in one call —
/// "Kaardil" on a post centres the map on it, Pood's mini map opens the map on Teenused,
/// "Kogukonna soovitused" opens the feed.
enum ExploreView { map, feed }

/// A one-shot request for the map: centre on a point and/or select a chip. Consumed by the map.
@immutable
class MapFocus {
  const MapFocus({this.lat, this.lng, this.category, required this.nonce});
  final double? lat;
  final double? lng;
  final MapCategory? category;
  final int nonce;
}

@immutable
class ExploreState {
  const ExploreState({required this.view, this.focus});
  final ExploreView view;
  final MapFocus? focus;
}

final ValueNotifier<ExploreState> exploreState = ValueNotifier(const ExploreState(view: ExploreView.map));
int _nonce = 0;

void setExploreView(ExploreView view) {
  if (exploreState.value.view != view) exploreState.value = ExploreState(view: view, focus: exploreState.value.focus);
}

/// Switch to the map and ask it to centre on a place and/or select a chip.
void focusMap({double? lat, double? lng, MapCategory? category}) {
  _nonce += 1;
  exploreState.value = ExploreState(
    view: ExploreView.map,
    focus: MapFocus(lat: lat, lng: lng, category: category, nonce: _nonce),
  );
}

/// Called by the map once it has applied the focus.
void clearMapFocus(int handled) {
  if (exploreState.value.focus?.nonce == handled) exploreState.value = ExploreState(view: exploreState.value.view);
}
