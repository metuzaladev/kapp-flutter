import '../core/api/api_client.dart';
import '../core/query/hooks.dart';
import '../core/query/query_client.dart';
import '../models/explore.dart';
import '../models/json.dart';
import '../models/services.dart';
import 'community.dart';
import 'parks.dart';

/// The service catalogue (M6): providers, their services and free times. Free times change whenever
/// someone books, so they are cached briefly; bookings invalidate ['services'].
class ServiceKeys {
  static const all = ['services'];
  static QueryKey providers(ServiceCategory? category, LatLng origin) => [
    'services',
    'providers',
    category?.name,
    {'lat': origin.lat, 'lng': origin.lng},
  ];
  static QueryKey provider(String providerId) => ['services', 'provider', providerId];
  static QueryKey slots(String serviceId) => ['services', 'slots', serviceId];
}

class BookingKeys {
  static const all = ['bookings'];
  static QueryKey list(String scope) => ['bookings', scope];
}

class RewardKeys {
  static const all = ['rewards'];
  static const summary = ['rewards', 'summary'];
  static const history = ['rewards', 'history'];
  static const invite = ['rewards', 'invite'];
}

class ShopKeys {
  static const all = ['shop'];
  static QueryKey overview(LatLng? origin) => [
    'shop',
    'overview',
    origin == null ? null : {'lat': origin.lat, 'lng': origin.lng},
  ];
  static QueryKey products(ProductCategory? category, String? providerId) => [
    'shop',
    'products',
    category?.name,
    providerId,
  ];
  static QueryKey product(String productId) => ['shop', 'product', productId];
  static const redemptions = ['redemptions'];
}

/// Days shown in the date picker: a week, like the plan-visit chips.
const _slotDays = 7;

/// Product images are signed URLs (15 min): refresh before they expire, like post photos.
const _signedUrlStale = Duration(minutes: 5);

QueryResult<List<ProviderSummary>> useProviders(ServiceCategory? category, LatLng origin, {bool enabled = true}) =>
    useQuery(
      ServiceKeys.providers(category, origin),
      () async => listOf(
        await apiGet<List<Object?>>('/service-providers', {
          'lat': origin.lat,
          'lng': origin.lng,
          'category': ?category?.name,
        }),
        ProviderSummary.fromJson,
      ),
      keepPreviousData: true,
      enabled: enabled,
    );

QueryResult<ProviderDetail> useProvider(String? providerId) => useQuery(
  ServiceKeys.provider(providerId ?? ''),
  () async => ProviderDetail.fromJson(await apiGet<Json>('/service-providers/$providerId')),
  enabled: providerId != null && providerId.isNotEmpty,
);

QueryResult<ServiceSlots> useServiceSlots(String? serviceId) => useQuery(
  ServiceKeys.slots(serviceId ?? ''),
  () async => ServiceSlots.fromJson(await apiGet<Json>('/services/$serviceId/slots', {'days': _slotDays})),
  enabled: serviceId != null && serviceId.isNotEmpty,
  // Someone else may book meanwhile; the server still has the final word (409 → refetch).
  staleTime: const Duration(seconds: 30),
);

QueryResult<List<Booking>> useBookings(String scope) => useQuery(
  BookingKeys.list(scope),
  () async => listOf(await apiGet<List<Object?>>('/me/bookings', {'scope': scope}), Booking.fromJson),
);

void _invalidateBookings() {
  queryClient.invalidateQueries(BookingKeys.all);
  queryClient.invalidateQueries(ServiceKeys.all);
  // Booking and cancelling write a row into the activity feed.
  queryClient.invalidateQueries(NotificationKeys.all);
  // A paw-discount code is marked used by a booking and released by its cancellation (M9b).
  queryClient.invalidateQueries(ShopKeys.redemptions);
  queryClient.invalidateQueries(RewardKeys.all);
}

/// Optional `redemptionId` (M9b "Kasuta käppi"): the answer carries the discount, still no payment.
MutationHandle<Json, Booking> useCreateBooking() => useMutation<Json, Booking>(
  (input) async => Booking.fromJson(await apiSend<Json>('POST', '/me/bookings', input)),
  // Also on error: a 409 means the free times shown are out of date.
  onSettled: (_, _, _) => _invalidateBookings(),
);

MutationHandle<String, Booking> useCancelBooking() => useMutation<String, Booking>(
  (bookingId) async => Booking.fromJson(await apiSend<Json>('POST', '/me/bookings/$bookingId/cancel')),
  onSettled: (_, _, _) => _invalidateBookings(),
);

/// GET /me/rewards also settles pending awards on the server, so it is the one place the balance
/// becomes current. Shared by every PointsBadge and the Käpad screen.
QueryResult<RewardsSummary> useRewards({bool enabled = true}) => useQuery(
  RewardKeys.summary,
  () async => RewardsSummary.fromJson(await apiGet<Json>('/me/rewards')),
  enabled: enabled,
);

/// The signed-in user's spendable Käpad, or null while unknown (the badge then hides itself).
int? usePointsBalance() => useRewards().data?.balance;

InfiniteQueryResult<RewardHistoryPage> useRewardHistory() => useInfiniteQuery<RewardHistoryPage>(
  RewardKeys.history,
  (cursor) async => RewardHistoryPage.fromJson(await apiGet<Json>('/me/rewards/history', {'before': ?cursor})),
  (last) => last.nextCursor,
);

QueryResult<Invite> useInvite() => useQuery(
  RewardKeys.invite,
  () async => Invite.fromJson(await apiGet<Json>('/me/invite')),
  // The code never changes; the amount comes from the server's rule table.
  staleTime: const Duration(minutes: 30),
);

MutationHandle<String, void> useClaimInvite() => useMutation<String, void>(
  (code) => apiSend<void>('POST', '/me/invite/claim', {'code': code}),
  onSuccess: (_, _) => queryClient.invalidateQueries(RewardKeys.all),
);

QueryResult<Shop> useShop(LatLng? origin) => useQuery(
  ShopKeys.overview(origin),
  () async =>
      Shop.fromJson(await apiGet<Json>('/shop', origin == null ? null : {'lat': origin.lat, 'lng': origin.lng})),
  staleTime: _signedUrlStale,
  keepPreviousData: true,
);

QueryResult<List<Product>> useProducts(ProductCategory? category, {String? providerId}) => useQuery(
  ShopKeys.products(category, providerId),
  () async => listOf(
    await apiGet<List<Object?>>('/shop/products', {'category': ?category?.name, 'providerId': ?providerId}),
    Product.fromJson,
  ),
  staleTime: _signedUrlStale,
  keepPreviousData: true,
);

QueryResult<Product> useProduct(String productId) => useQuery(
  ShopKeys.product(productId),
  () async => Product.fromJson(await apiGet<Json>('/shop/products/$productId')),
  staleTime: _signedUrlStale,
);

/// "Minu koodid", newest first. There is no single-code endpoint: the code screen reads this list.
QueryResult<List<Redemption>> useRedemptions() => useQuery(
  ShopKeys.redemptions,
  () async => listOf(await apiGet<List<Object?>>('/me/redemptions'), Redemption.fromJson),
);

void _invalidateWallet() {
  queryClient.invalidateQueries(ShopKeys.redemptions);
  queryClient.invalidateQueries(RewardKeys.all);
}

/// POST /me/redemptions with an idempotency key made once per tap (see core/logic/idempotency.dart).
MutationHandle<Json, Redemption> useRedeem() => useMutation<Json, Redemption>(
  (input) async => Redemption.fromJson(await apiSend<Json>('POST', '/me/redemptions', input)),
  onSuccess: (redemption, _) => queryClient.setQueryData<List<Redemption>>(
    ShopKeys.redemptions,
    (list) => [redemption, ...?list?.where((r) => r.id != redemption.id)],
  ),
  onSettled: (_, _, _) => _invalidateWallet(),
);

/// Cancels an unused code and refunds the points (idempotent on the server).
MutationHandle<String, Redemption> useCancelRedemption() => useMutation<String, Redemption>(
  (id) async => Redemption.fromJson(await apiSend<Json>('POST', '/me/redemptions/$id/cancel')),
  onSettled: (_, _, _) => _invalidateWallet(),
);
