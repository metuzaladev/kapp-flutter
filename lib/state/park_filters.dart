import 'package:flutter/foundation.dart';

/// Filters chosen on the "Filtrid" screen, shared by the map and the list.
@immutable
class ParkFilters {
  const ParkFilters({
    this.radiusKm = 5,
    this.fenced = false,
    this.smallDogArea = false,
    this.water = false,
    this.lighting = false,
  });

  final double radiusKm;
  final bool fenced;
  final bool smallDogArea;
  final bool water;
  final bool lighting;

  ParkFilters copyWith({double? radiusKm, bool? fenced, bool? smallDogArea, bool? water, bool? lighting}) =>
      ParkFilters(
        radiusKm: radiusKm ?? this.radiusKm,
        fenced: fenced ?? this.fenced,
        smallDogArea: smallDogArea ?? this.smallDogArea,
        water: water ?? this.water,
        lighting: lighting ?? this.lighting,
      );

  /// Number of active feature filters, shown on the "Filtrid" chip.
  int get activeCount => [fenced, smallDogArea, water, lighting].where((f) => f).length;

  /// Query parameters for GET /parks/nearby: only flags that are on ("off" = don't care).
  Map<String, Object> get featureParams => {
    if (fenced) 'fenced': 'true',
    if (smallDogArea) 'smallDogArea': 'true',
    if (water) 'water': 'true',
    if (lighting) 'lighting': 'true',
  };

  /// Stable value for query keys.
  Map<String, Object> toJson() => {
    'radiusKm': radiusKm,
    'fenced': fenced,
    'smallDogArea': smallDogArea,
    'water': water,
    'lighting': lighting,
  };

  @override
  bool operator ==(Object other) =>
      other is ParkFilters &&
      other.radiusKm == radiusKm &&
      other.fenced == fenced &&
      other.smallDogArea == smallDogArea &&
      other.water == water &&
      other.lighting == lighting;

  @override
  int get hashCode => Object.hash(radiusKm, fenced, smallDogArea, water, lighting);
}

const defaultParkFilters = ParkFilters();

final ValueNotifier<ParkFilters> parkFilters = ValueNotifier(defaultParkFilters);
