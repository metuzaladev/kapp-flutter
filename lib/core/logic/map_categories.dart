import '../../components/icon.dart';
import '../../models/services.dart';

/// Kaart tab category chips (Figma "Explore / Map": Kõik, Pargid, Kohvikud, Teenused, Rannad,
/// Kliinikud) and what each one shows. Pure: unit-tested in test/logic/map_categories_test.dart.
enum MapCategory { all, parks, cafes, services, beaches, vets }

/// Category of a single place on the map → Figma "Map Pin / Place" variant and `map*` colour.
/// `shop` = recommended shops and other places (API tag `other`); Figma has no own colour for them,
/// so they share the service colour with a shop icon.
enum PlaceKind { park, cafe, beach, service, vet, shop }

const Map<MapCategory, IconName> categoryIcon = {
  MapCategory.all: IconName.layers,
  MapCategory.parks: IconName.trees,
  MapCategory.cafes: IconName.coffee,
  MapCategory.services: IconName.scissors,
  MapCategory.beaches: IconName.waves,
  MapCategory.vets: IconName.stethoscope,
};

const Map<PlaceKind, IconName> placeIcon = {
  PlaceKind.park: IconName.trees,
  PlaceKind.cafe: IconName.coffee,
  PlaceKind.beach: IconName.waves,
  PlaceKind.service: IconName.scissors,
  PlaceKind.vet: IconName.stethoscope,
  PlaceKind.shop: IconName.store,
};

/// A provider's service category on the map: clinics have their own chip and colour.
PlaceKind providerPlaceKind(ServiceCategory category) =>
    category == ServiceCategory.vet ? PlaceKind.vet : PlaceKind.service;

/// Which map category a place belongs to (for filtering); null = only under "Kõik" (shops).
MapCategory? categoryOf(PlaceKind kind) => switch (kind) {
  PlaceKind.park => MapCategory.parks,
  PlaceKind.cafe => MapCategory.cafes,
  PlaceKind.beach => MapCategory.beaches,
  PlaceKind.service => MapCategory.services,
  PlaceKind.vet => MapCategory.vets,
  PlaceKind.shop => null,
};

/// Pin kind of a park: an unfenced park with water is a dog swimming spot (koertepargid.ee
/// "ujumiskoht") and belongs under "Rannad"; every other park is a park.
PlaceKind parkKindOf({required bool fenced, required bool water}) =>
    water && !fenced ? PlaceKind.beach : PlaceKind.park;

bool categoryShows(MapCategory selected, PlaceKind kind) => selected == MapCategory.all || categoryOf(kind) == selected;

/// Whether the providers query is needed at all for the selected chip (saves a request).
bool needsProviders(MapCategory selected) =>
    selected == MapCategory.all || selected == MapCategory.services || selected == MapCategory.vets;

/// Faces drawn on a dog pin; more dogs are summarised by the "N koera" pill.
const maxPinFaces = 3;

/// How a park is drawn: with dogs there now it is a Figma "Map Pin / Dog" (one face, or a group of up
/// to three faces with an "N koera" pill), otherwise a "Map Pin / Place" park pin.
sealed class ParkPinModel {
  const ParkPinModel();
}

class PlacePinModel extends ParkPinModel {
  const PlacePinModel();
  @override
  bool operator ==(Object other) => other is PlacePinModel;
  @override
  int get hashCode => 1;
}

class DogsPinModel extends ParkPinModel {
  const DogsPinModel({required this.faces, required this.showCount, required this.count});
  final int faces;
  final bool showCount;
  final int count;
  @override
  bool operator ==(Object other) =>
      other is DogsPinModel && other.faces == faces && other.showCount == showCount && other.count == count;
  @override
  int get hashCode => Object.hash(faces, showCount, count);
}

ParkPinModel parkPinModel(num? activeDogs) {
  final count = (activeDogs ?? 0).floor().clamp(0, 1 << 30);
  if (count == 0) return const PlacePinModel();
  return DogsPinModel(faces: count < maxPinFaces ? count : maxPinFaces, showCount: count > 1, count: count);
}
