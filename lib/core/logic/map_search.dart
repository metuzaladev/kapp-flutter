import 'dart:math' as math;

import '../../components/icon.dart';
import '../../models/explore.dart';

/// Pure helpers for the Kaart search suggestions (docs/19).

/// Wait this long after the last keystroke before asking the API: one request per pause.
const searchDebounce = Duration(milliseconds: 250);

/// The trimmed query when it is long enough to search, otherwise null (no request, no list).
String? searchableQuery(String text) {
  final q = text.trim();
  return q.length >= searchMinLength ? q : null;
}

IconName searchResultIcon(String kind, String? category) => switch (kind) {
  'park' => category == 'beach' ? IconName.waves : IconName.trees,
  'provider' => category == 'vet' ? IconName.stethoscope : IconName.scissors,
  'post' => switch (category) {
    'cafe' => IconName.coffee,
    'beach' => IconName.waves,
    'park' => IconName.trees,
    _ => IconName.store,
  },
  _ => IconName.mapPin,
};

/// Where the suggestion's detail action leads; addresses have no page (they only move the map).
String? searchResultRoute(String kind, String? id) {
  if (id == null) return null;
  return switch (kind) {
    'park' => '/parks/$id',
    'provider' => '/services/$id',
    'post' => '/place-posts/$id',
    _ => null,
  };
}

/// Zoom range for the + / − buttons (all of Estonia … a single yard), in flutter_map levels.
const minZoom = 7.0;
const maxZoom = 20.0;

/// One whole level per tap; fractional zooms (after a pinch) snap to the next whole level.
double stepZoom(double current, int direction) {
  final next = direction > 0 ? (current + 1e-6).floor() + 1 : (current - 1e-6).ceil() - 1;
  return math.min(maxZoom, math.max(minZoom, next.toDouble()));
}
