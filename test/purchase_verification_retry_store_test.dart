import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aimitsumori_app/services/purchase_verification_retry_store.dart';

void main() {
  test('retry state survives a new store instance', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final first = PurchaseVerificationRetryStore(preferences);
    final now = DateTime.utc(2026, 8, 22, 7);

    await first.recordRetry('purchase-1', now: now);

    final second = PurchaseVerificationRetryStore(preferences);
    final loaded = second.load(now: now.add(const Duration(seconds: 1)));
    expect(loaded, hasLength(1));
    expect(loaded.single.identity, 'purchase-1');
    expect(loaded.single.attemptCount, 1);
  });

  test('duplicate callbacks update one idempotent retry record', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PurchaseVerificationRetryStore(
      await SharedPreferences.getInstance(),
    );
    final now = DateTime.utc(2026, 8, 22, 7);

    await store.recordRetry('purchase-1', now: now);
    final states = await store.recordRetry(
      'purchase-1',
      now: now.add(const Duration(minutes: 1)),
    );

    expect(states, hasLength(1));
    expect(states.single.attemptCount, 2);
    expect(
      states.single.firstSeenAtMillis,
      now.millisecondsSinceEpoch,
    );
  });

  test('backoff grows and is capped', () {
    expect(
      PurchaseVerificationRetryPolicy.delayForAttempt(1),
      const Duration(minutes: 1),
    );
    expect(
      PurchaseVerificationRetryPolicy.delayForAttempt(2),
      const Duration(minutes: 5),
    );
    expect(
      PurchaseVerificationRetryPolicy.delayForAttempt(999),
      const Duration(hours: 12),
    );
  });

  test('store transaction completion is delayed for transient outage', () {
    final firstSeen = DateTime.utc(2026, 8, 22, 7);
    final state = PurchaseVerificationRetryState(
      identity: 'purchase-1',
      firstSeenAtMillis: firstSeen.millisecondsSinceEpoch,
      attemptCount: 3,
      nextAttemptAtMillis: firstSeen.millisecondsSinceEpoch,
    );

    expect(
      PurchaseVerificationRetryPolicy.shouldCompleteStoreTransaction(
        state,
        firstSeen.add(const Duration(hours: 23, minutes: 59)),
      ),
      isFalse,
    );
    expect(
      PurchaseVerificationRetryPolicy.shouldCompleteStoreTransaction(
        state,
        firstSeen.add(const Duration(hours: 24)),
      ),
      isTrue,
    );
  });

  test('expired retry records are pruned on load', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PurchaseVerificationRetryStore(
      await SharedPreferences.getInstance(),
    );
    final now = DateTime.utc(2026, 8, 1);
    await store.recordRetry('purchase-1', now: now);

    expect(
      store.load(now: now.add(const Duration(days: 8))),
      isEmpty,
    );
  });

  test('successful or invalid verification can remove retry state', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PurchaseVerificationRetryStore(
      await SharedPreferences.getInstance(),
    );
    final now = DateTime.utc(2026, 8, 22, 7);
    await store.recordRetry('purchase-1', now: now);

    final states = await store.remove('purchase-1', now: now);

    expect(states, isEmpty);
    expect(store.load(now: now), isEmpty);
  });
}
