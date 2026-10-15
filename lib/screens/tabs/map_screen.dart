import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/chip.dart';
import '../../components/explore_feed.dart';
import '../../components/icon.dart';
import '../../components/icon_button.dart';
import '../../components/location_prompt.dart';
import '../../components/map_tiles.dart';
import '../../components/park_cards.dart';
import '../../components/park_map.dart';
import '../../components/pressable.dart';
import '../../components/screen.dart';
import '../../components/service_cards.dart';
import '../../components/states.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/logic/explore.dart';
import '../../core/logic/map_categories.dart';
import '../../core/query/hooks.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../hooks/device_location.dart';
import '../../hooks/explore.dart';
import '../../hooks/parks.dart';
import '../../models/explore.dart';
import '../../models/parks.dart';
import '../../state/explore_view.dart';
import '../../state/park_filters.dart';

/// Floating UI heights used to keep pins clear of it (search 52 + chips 44 + gaps).
const _topUi = 52 + Spacing.two + 44 + Spacing.two;
const _bottomCard = 74.0;

/// The Kaart tab has two halves (M9b): the full-screen map and the Avasta feed. Which one shows is a
/// tab-local choice (state/explore_view.dart) — switching never pushes a screen, so the back gesture
/// never flips between them and other screens can steer the tab.
class KaartTab extends HookWidget {
  const KaartTab({super.key});

  @override
  Widget build(BuildContext context) {
    final view = useStore(exploreState).view;
    final bottom = MediaQuery.of(context).padding.bottom + Spacing.three;
    return view == ExploreView.feed ? ExploreFeed(bottomInset: bottom) : const MapScreen();
  }
}

/// Figma 02 / Explore / Map (10:148) and 09 / Explore & Rewards map (81:7510): an edge-to-edge map,
/// floating search + Käpad badge + filters, category chips, zoom/locate/list buttons and the
/// "Lähim park" card above the tab bar. Parks with dogs come from the nearby list (live dog counts);
/// everything else from GET /map/places for the visible box. A service pin opens the provider sheet.
class MapScreen extends HookWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final media = MediaQuery.of(context);
    final location = useDeviceLocation();
    final filters = useStore(parkFilters);
    final focus = useStore(exploreState).focus;
    final nearby = useNearbyParks(location.origin, filters);
    final parks = nearby.data ?? const <Park>[];
    final category = useState<MapCategory>(focus?.category ?? MapCategory.all);
    final region = useState<Bbox?>(null);
    final bbox =
        region.value ??
        (focus?.lat != null && focus?.lng != null
            ? bboxAround(lat: focus!.lat!, lng: focus.lng!)
            : bboxAround(lat: location.origin.lat, lng: location.origin.lng));
    final placesQuery = useMapPlaces(bbox, mapTagsFor(category.value));
    final selected = useState<MapPlace?>(null);
    final query = useTextEditingController();
    final queryText = useValueListenable(query).text;
    final searchFocusNode = useFocusNode();
    final searchOpen = useState(false);
    final searchFocus = useState<MapFocusRequest?>(null);
    final searchPin = useState<({double lat, double lng, String name})?>(null);
    final zoomSignal = useState<({int direction, int nonce})?>(null);
    final searchOrigin = region.value == null
        ? location.origin
        : (
            lat: (region.value!.minLat + region.value!.maxLat) / 2,
            lng: (region.value!.minLng + region.value!.maxLng) / 2,
          );
    final search = useMapSearch(queryText, searchOrigin);
    final showSuggestions = searchOpen.value && canSearch(queryText);
    final locateSignal = useState(0);
    // Per session: "Mitte praegu" hides the permission screen until the next launch.
    final promptDismissed = useState(false);
    final promptRequested = useState(false);
    final featureCount = filters.activeCount;

    // A focus request selects its chip once; its point is applied by the map.
    final handledFocus = useRef<int?>(focus?.nonce);
    if (focus != null && focus.nonce != handledFocus.value) {
      handledFocus.value = focus.nonce;
      if (focus.category != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => category.value = focus.category!);
      }
    }
    // A chip-only focus (Pood → "Lähedal kaardil") has nothing left for the map: clear it.
    useEffect(() {
      if (focus != null && focus.lat == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => clearMapFocus(focus.nonce));
      }
      return null;
    }, [focus?.nonce]);

    // The search moves the map instead of hiding pins (docs/19).
    final visibleParks = parks
        .where((p) => categoryShows(category.value, parkKindOf(fenced: p.fenced, water: p.water)))
        .toList();
    final drawn = parks.map((p) => p.id).toSet();
    // Parks already drawn from the nearby list (with their dog counts) are not drawn twice.
    final visiblePlaces = (placesQuery.data ?? const <MapPlace>[])
        .where((p) => !(p.kind == 'park' && drawn.contains(p.id)))
        .toList();
    // The API sorts by distance, so the first visible park is the nearest; a swimming spot only if nothing else.
    final nearest =
        visibleParks.where((p) => parkKindOf(fenced: p.fenced, water: p.water) == PlaceKind.park).firstOrNull ??
        visibleParks.firstOrNull;

    // Full-screen explanation before the one-time system dialog; only while undecided.
    final showPrompt =
        location.statusKnown &&
        location.status != LocationStatus.granted &&
        ((location.status == LocationStatus.undetermined && !promptDismissed.value) || promptRequested.value);
    if (showPrompt) {
      return LocationPrompt(
        status: location.status,
        canAskAgain: location.canAskAgain,
        onRequest: () async {
          await location.requestPermission();
          promptRequested.value = false;
          promptDismissed.value = true;
        },
        onDismiss: () {
          promptDismissed.value = true;
          promptRequested.value = false;
        },
      );
    }

    // The outer Scaffold extends under the tab bar and adds its height to the bottom padding.
    final tabBarSpace = media.padding.bottom + Spacing.two;
    const bottomBlock = _bottomCard + Spacing.three + 52;
    final mapError = nearby.error ?? placesQuery.error;

    void chooseResult(SearchResult result) {
      FocusScope.of(context).unfocus();
      searchOpen.value = false;
      query.text = result.name;
      searchFocus.value = MapFocusRequest(
        lat: result.lat,
        lng: result.lng,
        zoom: result.zoom + maplibreZoomOffset,
        nonce: DateTime.now().microsecondsSinceEpoch,
      );
      searchPin.value = result.kind == 'address' ? (lat: result.lat, lng: result.lng, name: result.name) : null;
      if (result.kind == 'provider' && result.id != null) {
        selected.value = MapPlace(
          id: result.id!,
          kind: 'provider',
          tag: result.category == 'vet' ? MapTag.clinics : MapTag.services,
          category: result.category ?? 'grooming',
          name: result.name,
          lat: result.lat,
          lng: result.lng,
        );
      } else {
        selected.value = null;
      }
    }

    void zoom(int direction) => zoomSignal.value = (direction: direction, nonce: DateTime.now().microsecondsSinceEpoch);

    Widget floatingCard(Widget child) => Container(
      padding: const EdgeInsets.all(Spacing.three),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.r16),
        border: Border.all(color: c.border),
      ),
      child: child,
    );

    return Scaffold(
      backgroundColor: c.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: ParkMap(
              parks: visibleParks,
              places: visiblePlaces,
              selectedPlaceId: selected.value?.id,
              center: location.origin,
              showUserLocation: !location.usingFallback,
              userPosition: location.usingFallback ? null : location.origin,
              onParkPressed: (park) => context.push('/parks/${park.id}'),
              onPlacePressed: (place) => place.kind == 'provider'
                  ? selected.value = place
                  : context.push(placeRoute(id: place.id, kind: place.kind)),
              onRegionChange: (bounds) => region.value = bboxFromRegion(bounds),
              focus:
                  searchFocus.value ??
                  (focus?.lat != null && focus?.lng != null
                      ? MapFocusRequest(lat: focus!.lat!, lng: focus.lng!, nonce: focus.nonce)
                      : null),
              onFocusApplied: (nonce) {
                if (searchFocus.value?.nonce == nonce) {
                  searchFocus.value = null;
                } else {
                  clearMapFocus(nonce);
                }
              },
              zoomSignal: zoomSignal.value,
              searchPin: searchPin.value,
              overlayTop: media.padding.top + _topUi,
              overlayBottom: tabBarSpace + bottomBlock,
              locateSignal: locateSignal.value,
            ),
          ),
          // Figma top fade, down to the chips row: the status bar stays legible.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Fade(up: true, height: media.padding.top + _topUi + Spacing.three),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(Spacing.three, media.padding.top + Spacing.two, Spacing.three, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 52),
                          padding: const EdgeInsets.only(left: Spacing.three, right: 10),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: c.border),
                            boxShadow: const [
                              BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 8)),
                            ],
                          ),
                          child: Row(
                            children: [
                              AppIcon(IconName.search, size: 20, color: c.muted),
                              const SizedBox(width: Spacing.two),
                              Expanded(
                                child: Semantics(
                                  label: context.t('map.searchLabel'),
                                  hint: context.t('map.searchHint'),
                                  textField: true,
                                  child: TextField(
                                    controller: query,
                                    focusNode: searchFocusNode,
                                    onChanged: (text) {
                                      searchOpen.value = true;
                                      if (text.trim().isEmpty) searchPin.value = null;
                                    },
                                    onTap: () => searchOpen.value = true,
                                    // Enter takes the first suggestion, like a search field on the web.
                                    onSubmitted: (_) {
                                      final first = search.data?.results.firstOrNull;
                                      if (first != null) chooseResult(first);
                                    },
                                    textInputAction: TextInputAction.search,
                                    autocorrect: false,
                                    style: textStyle(TextType.body, color: c.text),
                                    cursorColor: c.brand,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      hintText: context.t('map.searchPlaceholder'),
                                      hintStyle: textStyle(TextType.body, color: c.muted),
                                      contentPadding: const EdgeInsets.symmetric(vertical: Spacing.two),
                                      suffixIcon: queryText.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: context.t('common.close'),
                                              icon: AppIcon(IconName.x, size: 18, color: c.muted),
                                              onPressed: () {
                                                query.clear();
                                                searchPin.value = null;
                                              },
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              PointsBadge(onPressed: () => context.push('/rewards')),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppIconButton(
                        icon: IconName.slidersHorizontal,
                        label: featureCount > 0
                            ? context.t('map.filtersCount', count: featureCount)
                            : context.t('map.filters'),
                        hint: context.t('map.filtersHint'),
                        badge: featureCount > 0,
                        onPressed: () => context.push('/park-filters'),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.two),
                  if (showSuggestions)
                    SearchSuggestions(
                      results: search.data?.results,
                      loading: search.isFetching,
                      addressesAvailable: search.data?.addressesAvailable ?? true,
                      failed: search.isError && search.data == null,
                      onSelect: chooseResult,
                      maxHeight: media.size.height * 0.45,
                    )
                  else
                    ChipRow(
                      bleed: Spacing.three,
                      children: [
                        for (final key in MapCategory.values)
                          IconChip(
                            radio: true,
                            icon: categoryIcon[key]!,
                            label: context.t('map.categories.${key.name}'),
                            selected: category.value == key,
                            onPressed: () {
                              category.value = key;
                              selected.value = null;
                            },
                          ),
                      ],
                    ),
                  const SizedBox(height: Spacing.two),
                  const OfflineBanner(),
                  // Cached pins stay on the map when a refresh fails (offline); only report the error.
                  if (mapError != null && (parks.isNotEmpty || visiblePlaces.isNotEmpty))
                    FormError(errorMessage(mapError)),
                ],
              ),
            ),
          ),
          if (selected.value != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProviderSheet(providerId: selected.value!.id, onClose: () => selected.value = null),
                  // The sheet covers the tab bar area like Figma.
                  Container(height: tabBarSpace - Spacing.three, color: c.background),
                ],
              ),
            )
          else
            Positioned(
              left: Spacing.three,
              right: Spacing.three,
              bottom: tabBarSpace,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // + / − next to the pinch gesture: one-handed use, and screen-reader users cannot pinch.
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 52,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: c.border),
                        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 8))],
                      ),
                      child: Column(
                        children: [
                          Pressable(
                            semanticLabel: context.t('map.zoomIn'),
                            onPressed: () => zoom(1),
                            child: SizedBox(
                              height: 48,
                              child: Center(child: AppIcon(IconName.plus, size: 22, color: c.text)),
                            ),
                          ),
                          Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: 10), color: c.border),
                          Pressable(
                            semanticLabel: context.t('map.zoomOut'),
                            onPressed: () => zoom(-1),
                            child: SizedBox(
                              height: 48,
                              child: Center(child: AppIcon(IconName.minus, size: 22, color: c.text)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.three),
                  Row(
                    children: [
                      // The entry takes the free width and shrinks only when the label must wrap.
                      const Expanded(
                        child: Align(alignment: Alignment.centerLeft, child: CommunityEntry()),
                      ),
                      AppIconButton(
                        icon: IconName.map,
                        label: context.t('map.openList'),
                        hint: context.t('map.openListHint'),
                        onPressed: () => context.push('/parks'),
                      ),
                      const SizedBox(width: 12),
                      AppIconButton(
                        icon: IconName.navigation,
                        label: context.t('map.locate'),
                        onPressed: () => location.status == LocationStatus.granted
                            ? locateSignal.value++
                            : promptRequested.value = true,
                      ),
                    ],
                  ),
                  if (nearby.error != null && parks.isEmpty && categoryShows(category.value, PlaceKind.park)) ...[
                    const SizedBox(height: Spacing.three),
                    floatingCard(
                      ErrorState(
                        message: errorMessage(nearby.error),
                        onRetry: nearby.refetch,
                        retrying: nearby.isFetching,
                      ),
                    ),
                  ],
                  if (!nearby.isPending &&
                      nearby.error == null &&
                      category.value == MapCategory.parks &&
                      visibleParks.isEmpty) ...[
                    const SizedBox(height: Spacing.three),
                    floatingCard(
                      EmptyState(
                        title: context.t('map.empty'),
                        actionLabel: featureCount > 0 || filters.radiusKm != defaultParkFilters.radiusKm
                            ? context.t('map.emptyAction')
                            : null,
                        onAction: () => parkFilters.value = defaultParkFilters,
                      ),
                    ),
                  ],
                  if (!placesQuery.isPending &&
                      category.value != MapCategory.all &&
                      category.value != MapCategory.parks &&
                      visiblePlaces.isEmpty) ...[
                    const SizedBox(height: Spacing.three),
                    floatingCard(EmptyState(title: context.t('map.emptyPlaces'))),
                  ],
                  if (nearest != null) ...[
                    const SizedBox(height: Spacing.three),
                    NearestParkCard(park: nearest, usingFallback: location.usingFallback, floating: true),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
