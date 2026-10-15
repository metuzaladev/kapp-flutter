import '../core/api/api_client.dart';
import '../core/query/hooks.dart';
import '../core/query/query_client.dart';
import '../models/json.dart';
import '../models/visits.dart';
import 'parks.dart';

/// Visit data (check-ins, visitors, history, plans) and park feedback (reviews, reports). Everything
/// that changes who is in a park also invalidates ['parks'] (lists and pins show "koera praegu").
class VisitKeys {
  static const all = ['visits'];
  static const active = ['visits', 'active'];
  static const history = ['visits', 'history'];
  static const plans = ['visits', 'plans'];
  static QueryKey visitors(String parkId) => ['visits', 'visitors', parkId];
  static QueryKey reviews(String parkId) => ['parks', 'reviews', parkId];
}

QueryResult<ActiveCheckIn?> useActiveCheckIn() => useQuery<ActiveCheckIn?>(VisitKeys.active, () async {
  final data = await apiGet<Json?>('/me/check-ins/active');
  return data == null ? null : ActiveCheckIn.fromJson(data);
});

QueryResult<ParkVisitors> useParkVisitors(String parkId, {bool enabled = true}) => useQuery(
  VisitKeys.visitors(parkId),
  () async => ParkVisitors.fromJson(await apiGet<Json>('/parks/$parkId/visitors')),
  enabled: enabled,
  // People come and go; refresh more often than static park data.
  staleTime: const Duration(seconds: 30),
);

QueryResult<List<VisitHistoryItem>> useVisitHistory() => useQuery(
  VisitKeys.history,
  () async => listOf(await apiGet<List<Object?>>('/me/visits'), VisitHistoryItem.fromJson),
);

QueryResult<List<PlannedVisit>> usePlannedVisits() => useQuery(
  VisitKeys.plans,
  () async => listOf(await apiGet<List<Object?>>('/me/planned-visits'), PlannedVisit.fromJson),
);

QueryResult<List<Review>> useParkReviews(String parkId) => useQuery(
  VisitKeys.reviews(parkId),
  () async => listOf(await apiGet<List<Object?>>('/parks/$parkId/reviews'), Review.fromJson),
);

void _invalidatePresence() {
  queryClient.invalidateQueries(VisitKeys.all);
  queryClient.invalidateQueries(ParkKeys.all);
}

MutationHandle<Json, ActiveCheckIn> useCheckIn() => useMutation<Json, ActiveCheckIn>(
  (input) async => ActiveCheckIn.fromJson(await apiSend<Json>('POST', '/me/check-ins', input)),
  onSuccess: (_, _) => _invalidatePresence(),
);

MutationHandle<String, void> useEndCheckIn() => useMutation<String, void>(
  (checkInId) => apiSend<void>('POST', '/me/check-ins/$checkInId/end'),
  onSuccess: (_, _) => _invalidatePresence(),
);

MutationHandle<Json, PlannedVisit> usePlanVisit() => useMutation<Json, PlannedVisit>(
  (input) async => PlannedVisit.fromJson(await apiSend<Json>('POST', '/me/planned-visits', input)),
  onSuccess: (_, _) => queryClient.invalidateQueries(VisitKeys.plans),
);

MutationHandle<String, void> useCancelPlan() => useMutation<String, void>(
  (planId) => apiSend<void>('DELETE', '/me/planned-visits/$planId'),
  onSuccess: (_, _) => queryClient.invalidateQueries(VisitKeys.plans),
);

MutationHandle<Json, Review> useSubmitReview(String parkId) => useMutation<Json, Review>(
  (input) async => Review.fromJson(await apiSend<Json>('PUT', '/parks/$parkId/reviews/mine', input)),
  onSuccess: (_, _) {
    queryClient.invalidateQueries(VisitKeys.reviews(parkId));
    queryClient.invalidateQueries(ParkKeys.detail(parkId));
    queryClient.invalidateQueries(VisitKeys.history);
  },
);

MutationHandle<Json, void> useReportPark(String parkId) =>
    useMutation<Json, void>((input) => apiSend<void>('POST', '/parks/$parkId/reports', input));
