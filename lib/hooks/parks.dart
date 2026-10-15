import '../core/api/api_client.dart';
import '../core/query/hooks.dart';
import '../core/query/query_client.dart';
import '../models/json.dart';
import '../models/parks.dart';
import '../state/park_filters.dart';

typedef LatLng = ({double lat, double lng});

/// Park data hooks. Query keys are hierarchical (['parks', …]) so one invalidation of ['parks']
/// refreshes every park view after a change.
class ParkKeys {
  static const all = ['parks'];
  static QueryKey nearby(LatLng origin, ParkFilters filters) => [
    'parks',
    'nearby',
    {'lat': origin.lat, 'lng': origin.lng},
    filters.toJson(),
  ];
  static QueryKey detail(String parkId) => ['parks', 'detail', parkId];
  static const favorites = ['parks', 'favorites'];
  static QueryKey activity(List<String> ids) => ['parks', 'activity', ids];
}

QueryResult<List<Park>> useNearbyParks(LatLng origin, ParkFilters filters, {bool enabled = true}) => useQuery(
  ParkKeys.nearby(origin, filters),
  () async => listOf(
    await apiGet<List<Object?>>('/parks/nearby', {
      'lat': origin.lat,
      'lng': origin.lng,
      'radiusKm': filters.radiusKm,
      ...filters.featureParams,
    }),
    Park.fromJson,
  ),
  // Show the previous result while a new radius/filter loads, instead of an empty map.
  keepPreviousData: true,
  enabled: enabled,
);

QueryResult<ParkDetail> useParkDetail(String parkId) =>
    useQuery(ParkKeys.detail(parkId), () async => ParkDetail.fromJson(await apiGet<Json>('/parks/$parkId')));

QueryResult<List<Park>> useFavoriteParks() =>
    useQuery(ParkKeys.favorites, () async => listOf(await apiGet<List<Object?>>('/me/favorites'), Park.fromJson));

/// M11 "Lemmikparkides täna" (docs/18): dogs now and today's planned visits per part of day.
QueryResult<ParkActivityResponse> useParkActivity(List<String> ids) => useQuery(
  ParkKeys.activity(ids),
  () async => ParkActivityResponse.fromJson(await apiGet<Json>('/parks/activity', {'ids': ids.join(',')})),
  enabled: ids.isNotEmpty,
  keepPreviousData: true,
);

/// Toggle with an optimistic update: the heart changes instantly and rolls back if the request fails.
/// PUT/DELETE are idempotent, so a retry after a timeout cannot double-add.
MutationHandle<bool, void> useToggleFavorite(String parkId) => useMutation<bool, void>(
  (favorite) => apiSend<void>(favorite ? 'PUT' : 'DELETE', '/me/favorites/$parkId'),
  onMutate: (favorite) {
    queryClient.cancelQueries(ParkKeys.detail(parkId));
    final previous = queryClient.getQueryData<ParkDetail>(ParkKeys.detail(parkId));
    if (previous != null) {
      queryClient.setQueryData<ParkDetail>(ParkKeys.detail(parkId), (_) => previous.withFavorite(favorite));
    }
    return previous;
  },
  onError: (_, _, previous) {
    if (previous is ParkDetail) queryClient.setQueryData<ParkDetail>(ParkKeys.detail(parkId), (_) => previous);
  },
  onSettled: (_, _, _) {
    queryClient.invalidateQueries(ParkKeys.detail(parkId));
    queryClient.invalidateQueries(ParkKeys.favorites);
  },
);
