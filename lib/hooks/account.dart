import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/api/api_client.dart';
import '../core/logic/account.dart';
import '../core/logic/idempotency.dart';
import '../core/query/hooks.dart';
import '../core/query/query_client.dart';
import '../models/explore.dart';
import '../models/json.dart';
import '../models/profile.dart';
import 'community.dart';
import 'services.dart';

/// M10 account hooks (docs/17): legal acceptance, confirmation resend, data export and deletion. The
/// profile itself is `useOwnProfile`, so the consent gate, the banner and settings share one GET /me.
MutationHandle<void, LegalAcceptance> useAcceptLegal() => useMutation<void, LegalAcceptance>(
  (_) async => LegalAcceptance.fromJson(await apiSend<Json>('PUT', '/me/legal-acceptance', currentLegalVersions())),
  onSuccess: (legal, _) => queryClient.setQueryData<Profile>(ownProfileKey, (me) => me?.copyWith(legal: legal)),
);

MutationHandle<void, void> useResendVerification() =>
    useMutation<void, void>((_) => apiSend<void>('POST', '/me/email-verification'));

/// Fetched on demand (not cached): the export can be large and must always be fresh.
MutationHandle<void, Json> useExportData() => useMutation<void, Json>((_) => apiGet<Json>('/me/export'));

MutationHandle<Map<String, Object>, void> useDeleteAccount() =>
    useMutation<Map<String, Object>, void>((body) => apiSend<void>('DELETE', '/me', body));

/// "Lunasta" with an idempotency key per tap: a retry after a lost answer reuses the key, so the
/// server returns the first code instead of spending the points again.
class RedeemOnce {
  RedeemOnce(this._redeem);
  final MutationHandle<Json, Redemption> _redeem;
  final IdempotencyTracker _tracker = IdempotencyTracker();

  bool get isPending => _redeem.isPending;

  Future<Redemption> run({required String offerType, required String offerId}) async {
    final key = _tracker.begin();
    try {
      final r = await _redeem.mutateAsync({'offerType': offerType, 'offerId': offerId, 'idempotencyKey': key});
      _tracker.settle(retryable: false);
      return r;
    } catch (e) {
      _tracker.settle(retryable: isRetryableStatus(e is ApiRequestError ? e.status : null));
      rethrow;
    }
  }
}

RedeemOnce useRedeemOnce() {
  final redeem = useRedeem();
  // One tracker per mounted screen (a ref in React).
  return useMemoized(() => RedeemOnce(redeem), [redeem]);
}
