import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/format.dart';
import '../core/i18n/i18n.dart';
import '../core/logic/explore.dart';
import '../core/logic/map_categories.dart';
import '../core/logic/map_clusters.dart';
import '../core/logic/map_search.dart';
import '../models/explore.dart';
import '../models/parks.dart';
import 'map_pins.dart';
import 'map_tiles.dart';

/// What goes into the cluster index: quiet parks and places. Parks with dogs are drawn on their own.
class Clusterable implements ClusterInput {
  Clusterable.park(Park this.park) : place = null, key = 'park-${park.id}', lat = park.lat, lng = park.lng;
  Clusterable.place(MapPlace this.place)
    : park = null,
      key = '${place.kind}-${place.id}',
      lat = place.lat,
      lng = place.lng;

  final Park? park;
  final MapPlace? place;
  @override
  final String key;
  @override
  final double lat;
  @override
  final double lng;
}

/// One-shot "centre here" (post "Kaardil", a search result).
class MapFocusRequest {
  const MapFocusRequest({required this.lat, required this.lng, required this.nonce, this.zoom});
  final double lat;
  final double lng;
  final int nonce;
  final double? zoom;
}

/// Figma "Explore / Map" (10:148): a full-screen map. Parks with dogs now are dog pins (faces +
/// "N koera"), quiet parks are green park pins, providers are service / clinic pins.
///
/// M11: quiet pins are clustered so the 71 real parks no longer pile up over the map labels; tapping
/// a count bubble zooms in until it splits. Parks with dogs present are never clustered: live
/// presence is the app's main signal. The map opens on the user (or Tallinn) at city zoom.
///
/// Each pin is one screen-reader button ("Kadrioru koertepark, 6 koera praegu").
class ParkMap extends StatefulWidget {
  const ParkMap({
    super.key,
    required this.parks,
    this.places = const [],
    this.selectedPlaceId,
    required this.center,
    required this.showUserLocation,
    this.userPosition,
    required this.onParkPressed,
    this.onPlacePressed,
    this.onRegionChange,
    this.focus,
    this.onFocusApplied,
    required this.overlayTop,
    required this.overlayBottom,
    this.locateSignal = 0,
    this.zoomSignal,
    this.searchPin,
  });

  final List<Park> parks;
  final List<MapPlace> places;
  final String? selectedPlaceId;
  final ({double lat, double lng}) center;
  final bool showUserLocation;
  final ({double lat, double lng})? userPosition;
  final void Function(Park park) onParkPressed;
  final void Function(MapPlace place)? onPlacePressed;

  /// Visible box after the user (or the camera) moved the map: drives the places query.
  final void Function(LngLatBox bounds)? onRegionChange;
  final MapFocusRequest? focus;
  final void Function(int nonce)? onFocusApplied;

  /// Space covered by floating UI (search + chips above, nearest-park card and tab bar below).
  final double overlayTop;
  final double overlayBottom;

  /// Incremented by the locate button: the camera returns to `center`.
  final int locateSignal;

  /// + / − buttons: each new nonce zooms one level in (1) or out (−1).
  final ({int direction, int nonce})? zoomSignal;
  final ({double lat, double lng, String name})? searchPin;

  @override
  State<ParkMap> createState() => _ParkMapState();
}

class _ParkMapState extends State<ParkMap> {
  final _controller = MapController();
  bool _ready = false;

  /// After a focus or the user's own pan/zoom, the camera is theirs: never re-centre it.
  bool _handedOver = false;
  LngLatBox _bounds = worldBox;
  double _zoom = cityZoom;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ParkMap old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    final focus = widget.focus;
    if (focus != null && focus.nonce != old.focus?.nonce) _applyFocus(focus);
    if (!_handedOver &&
        widget.focus == null &&
        (widget.center.lat != old.center.lat || widget.center.lng != old.center.lng)) {
      _move(LatLng(widget.center.lat, widget.center.lng), cityZoom);
    }
    if (widget.locateSignal != old.locateSignal && widget.locateSignal > 0) {
      _move(LatLng(widget.center.lat, widget.center.lng), 15);
    }
    final z = widget.zoomSignal;
    if (z != null && z.nonce != old.zoomSignal?.nonce) {
      _handedOver = true;
      _move(_controller.camera.center, stepZoom(_controller.camera.zoom, z.direction));
    }
  }

  void _applyFocus(MapFocusRequest focus) {
    _handedOver = true;
    _move(LatLng(focus.lat, focus.lng), focus.zoom ?? 16);
    widget.onFocusApplied?.call(focus.nonce);
  }

  /// Moves the camera so that `target` sits in the middle of the area not covered by overlays.
  void _move(LatLng target, double zoom) {
    final offset = (widget.overlayBottom - widget.overlayTop) / 2;
    _controller.move(target, zoom, offset: Offset(0, -offset));
    _onCamera(_controller.camera, gesture: false);
  }

  void _onReady() {
    _ready = true;
    final focus = widget.focus;
    if (focus != null) {
      _applyFocus(focus);
    } else {
      _move(LatLng(widget.center.lat, widget.center.lng), cityZoom);
    }
  }

  void _onCamera(MapCamera camera, {required bool gesture}) {
    if (gesture) _handedOver = true;
    final b = camera.visibleBounds;
    final bounds = (west: b.west, south: b.south, east: b.east, north: b.north);
    _debounce?.cancel();
    // Coalesce a burst of camera updates into one clustering pass and one places request.
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _bounds = bounds;
        _zoom = camera.zoom;
      });
      widget.onRegionChange?.call(bounds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final busyParks = widget.parks.where((p) => (p.activeDogs ?? 0) > 0).toList();
    final clusterable = [
      for (final p in widget.parks)
        if ((p.activeDogs ?? 0) == 0) Clusterable.park(p),
      for (final place in widget.places) Clusterable.place(place),
    ];
    final items = clustersIn<Clusterable>(clusterable, _bounds, _zoom);

    final markers = <Marker>[
      for (final entry in items)
        switch (entry) {
          ClusterBubble<Clusterable>() => Marker(
            key: ValueKey(entry.key),
            point: LatLng(entry.lat, entry.lng),
            width: 64,
            height: 64,
            child: Semantics(
              button: true,
              label: context.t('map.cluster', count: entry.count),
              child: GestureDetector(
                onTap: () {
                  _handedOver = true;
                  _move(LatLng(entry.lat, entry.lng), expansionZoom(entry, _zoom));
                },
                child: Center(child: ClusterPin(count: entry.count)),
              ),
            ),
          ),
          PinItem<Clusterable>(:final item) when item.park != null => _placeMarker(
            key: entry.key,
            lat: entry.lat,
            lng: entry.lng,
            kind: parkKindOf(fenced: item.park!.fenced, water: item.park!.water),
            label: context.t('map.markerQuiet', params: {'name': item.park!.name}),
            hint: context.t('parkRow.hint'),
            onTap: () => widget.onParkPressed(item.park!),
          ),
          PinItem<Clusterable>(:final item) => _placeMarker(
            key: entry.key,
            lat: entry.lat,
            lng: entry.lng,
            kind: placeKindOf(item.place!.tag),
            selected: item.place!.id == widget.selectedPlaceId,
            label: context.t(
              'map.placeMarker',
              params: {
                'name': item.place!.name,
                'kind': context.t('map.placeKinds.${placeKindOf(item.place!.tag).name}'),
              },
            ),
            hint: item.place!.kind == 'provider' ? context.t('map.providerHint') : null,
            onTap: () => widget.onPlacePressed?.call(item.place!),
          ),
        },
      for (final park in busyParks)
        if (parkPinModel(park.activeDogs) case DogsPinModel(:final faces, :final showCount, :final count))
          Marker(
            key: ValueKey('dogs-${park.id}'),
            point: LatLng(park.lat, park.lng),
            width: DogPin.sizeFor(faces, showCount).width + 8,
            height: DogPin.sizeFor(faces, showCount).height,
            alignment: Alignment.topCenter,
            child: Semantics(
              button: true,
              label: context.t('map.marker', params: {'name': park.name, 'dogs': dogsLabel(count)}),
              hint: context.t('parkRow.hint'),
              child: GestureDetector(
                onTap: () => widget.onParkPressed(park),
                // Visitors' dog photos are not part of the park API: faces are paw placeholders.
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: DogPin(faces: List.filled(faces, null), countLabel: showCount ? dogsLabel(count) : null),
                ),
              ),
            ),
          ),
      if (widget.searchPin case final pin?)
        Marker(
          point: LatLng(pin.lat, pin.lng),
          width: SearchPin.size.width,
          height: SearchPin.size.height,
          alignment: Alignment.topCenter,
          child: Semantics(
            label: context.t('map.searchPin', params: {'name': pin.name}),
            child: const SearchPin(),
          ),
        ),
      if (widget.showUserLocation && widget.userPosition != null)
        Marker(
          point: LatLng(widget.userPosition!.lat, widget.userPosition!.lng),
          width: 18,
          height: 18,
          child: Semantics(label: context.t('map.myLocation'), child: const UserDot()),
        ),
    ];

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: LatLng(widget.center.lat, widget.center.lng),
        initialZoom: cityZoom,
        minZoom: minZoom,
        maxZoom: maxZoom,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onMapReady: _onReady,
        onPositionChanged: (camera, hasGesture) => _onCamera(camera, gesture: hasGesture),
      ),
      children: [
        const KappTileLayer(),
        MarkerLayer(markers: markers),
        KappAttribution(bottom: widget.overlayBottom + 8),
      ],
    );
  }

  Marker _placeMarker({
    required String key,
    required double lat,
    required double lng,
    required PlaceKind kind,
    required String label,
    String? hint,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    // Pins point at their place with the tail (bottom anchor), so they stand above it, not over it.
    return Marker(
      key: ValueKey(key),
      point: LatLng(lat, lng),
      width: PlacePin.size.width + 4,
      height: PlacePin.size.height,
      alignment: Alignment.topCenter,
      child: Semantics(
        button: true,
        label: label,
        hint: hint,
        child: GestureDetector(
          onTap: onTap,
          child: PlacePin(kind: kind, selected: selected),
        ),
      ),
    );
  }
}

/// Figma Pood "Map / Nearby services" (85:8533): a small, non-interactive map with the partners'
/// pins. The caller wraps it in a button that opens the Kaart tab.
class MiniMap extends StatelessWidget {
  const MiniMap({super.key, required this.pins, required this.center, this.height = 160});
  final List<({String id, double lat, double lng, PlaceKind kind})> pins;
  final ({double lat, double lng}) center;
  final double height;

  @override
  Widget build(BuildContext context) {
    final points = [LatLng(center.lat, center.lng), for (final p in pins) LatLng(p.lat, p.lng)];
    return ExcludeSemantics(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: height,
            child: FlutterMap(
              options: staticMapOptions(
                center: LatLng(center.lat, center.lng),
                fit: pins.isEmpty
                    ? null
                    : CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.fromLTRB(32, 56, 32, 16),
                        maxZoom: 16,
                      ),
              ),
              children: [
                const KappTileLayer(),
                MarkerLayer(
                  markers: [
                    for (final p in pins)
                      Marker(
                        point: LatLng(p.lat, p.lng),
                        width: PlacePin.size.width,
                        height: PlacePin.size.height,
                        alignment: Alignment.topCenter,
                        child: PlacePin(kind: p.kind),
                      ),
                  ],
                ),
                const KappAttribution(bottom: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Soovita kohta" location: a small map with a fixed pin in the middle — the user drags the map
/// until the pin sits on the place ("move the map, not the pin"). The chosen point is the map centre.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.value,
    required this.recenter,
    required this.kind,
    required this.onChanged,
  });

  final ({double lat, double lng}) value;

  /// A new key moves the camera to `value` ("Kasuta minu asukohta").
  final String recenter;
  final PlaceKind kind;

  /// `byUser` is false for camera moves the app made (load, recenter).
  final void Function(({double lat, double lng}) point, bool byUser) onChanged;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _controller = MapController();

  @override
  void didUpdateWidget(LocationPicker old) {
    super.didUpdateWidget(old);
    if (widget.recenter != old.recenter) _controller.move(LatLng(widget.value.lat, widget.value.lng), 17);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: LatLng(widget.value.lat, widget.value.lng),
                  initialZoom: 17,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onMapEvent: (event) {
                    if (event is MapEventMoveEnd ||
                        event is MapEventFlingAnimationEnd ||
                        event is MapEventDoubleTapZoomEnd ||
                        event is MapEventScrollWheelZoom) {
                      final c = event.camera.center;
                      widget.onChanged((
                        lat: c.latitude,
                        lng: c.longitude,
                      ), event.source != MapEventSource.mapController);
                    }
                  },
                ),
                children: const [KappTileLayer(), KappAttribution()],
              ),
              // The pin's tip marks the centre: lift it by its own height.
              IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 47),
                    child: PlacePin(kind: widget.kind),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
