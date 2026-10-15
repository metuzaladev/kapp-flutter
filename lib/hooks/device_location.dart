import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';

import 'parks.dart';

/// Tallinn city centre — used until (or unless) the user shares their location.
const LatLng tallinnCenter = (lat: 59.437, lng: 24.7536);

/// Rounds to 3 decimals (~100 m). Enough to sort nearby parks, and the API never receives the user's
/// exact position. Also keeps the query cache key stable while the user stands still.
double _round(double n) => (n * 1000).roundToDouble() / 1000;

enum LocationStatus { undetermined, granted, denied }

class DeviceLocation {
  const DeviceLocation({
    required this.origin,
    required this.usingFallback,
    required this.status,
    required this.statusKnown,
    required this.canAskAgain,
    required this.requestPermission,
  });

  final LatLng origin;
  final bool usingFallback;
  final LocationStatus status;

  /// false until the permission has been read — avoids flashing the permission screen at launch.
  final bool statusKnown;
  final bool canAskAgain;
  final Future<void> Function() requestPermission;
}

/// The last fix, shared by every screen so the second screen does not wait for GPS again.
final ValueNotifier<LatLng?> _lastFix = ValueNotifier(null);

/// Foreground ("while using the app") location only. Background location is never requested.
DeviceLocation useDeviceLocation() {
  final permission = useState<LocationPermission?>(null);
  final coords = useValueListenable(_lastFix);

  Future<void> locate() async {
    final last = await Geolocator.getLastKnownPosition().catchError((Object _) => null);
    if (last != null) _lastFix.value = (lat: _round(last.latitude), lng: _round(last.longitude));
    try {
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
      );
      _lastFix.value = (lat: _round(fresh.latitude), lng: _round(fresh.longitude));
    } catch (_) {}
  }

  useEffect(() {
    var active = true;
    Geolocator.checkPermission()
        .then((p) {
          if (!active) return;
          permission.value = p;
          if (p == LocationPermission.always || p == LocationPermission.whileInUse) unawaited(locate());
        })
        .catchError((Object _) {
          if (active) permission.value = LocationPermission.denied;
        });
    return () => active = false;
  }, const []);

  final p = permission.value;
  final status = switch (p) {
    LocationPermission.always || LocationPermission.whileInUse => LocationStatus.granted,
    LocationPermission.denied || LocationPermission.deniedForever => LocationStatus.denied,
    _ => LocationStatus.undetermined,
  };

  return DeviceLocation(
    origin: coords ?? tallinnCenter,
    usingFallback: coords == null,
    // Geolocator reports "denied" before the first question on iOS too; treat it as undetermined
    // until the user has actually been asked (canAskAgain stays true).
    status: status,
    statusKnown: p != null,
    canAskAgain: p != LocationPermission.deniedForever,
    requestPermission: () async {
      final next = await Geolocator.requestPermission();
      permission.value = next;
      if (next == LocationPermission.always || next == LocationPermission.whileInUse) await locate();
    },
  );
}
