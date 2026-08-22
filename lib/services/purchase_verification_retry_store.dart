import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PurchaseVerificationRetryState {
  const PurchaseVerificationRetryState({
    required this.identity,
    required this.firstSeenAtMillis,
    required this.attemptCount,
    required this.nextAttemptAtMillis,
  });

  final String identity;
  final int firstSeenAtMillis;
  final int attemptCount;
  final int nextAttemptAtMillis;

  Map<String, Object> toJson() => {
    'identity': identity,
    'firstSeenAtMillis': firstSeenAtMillis,
    'attemptCount': attemptCount,
    'nextAttemptAtMillis': nextAttemptAtMillis,
  };

  factory PurchaseVerificationRetryState.fromJson(Map<String, dynamic> json) {
    final identity = json['identity'];
    final firstSeenAtMillis = json['firstSeenAtMillis'];
    final attemptCount = json['attemptCount'];
    final nextAttemptAtMillis = json['nextAttemptAtMillis'];
    if (identity is! String || identity.isEmpty) {
      throw const FormatException('retry identity is invalid');
    }
    if (firstSeenAtMillis is! int ||
        attemptCount is! int ||
        attemptCount < 1 ||
        nextAttemptAtMillis is! int) {
      throw const FormatException('retry state is invalid');
    }
    return PurchaseVerificationRetryState(
      identity: identity,
      firstSeenAtMillis: firstSeenAtMillis,
      attemptCount: attemptCount,
      nextAttemptAtMillis: nextAttemptAtMillis,
    );
  }
}

class PurchaseVerificationRetryPolicy {
  static const Duration storeCompletionWindow = Duration(hours: 24);
  static const Duration retentionWindow = Duration(days: 7);

  static const List<Duration> _backoff = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(hours: 1),
    Duration(hours: 4),
    Duration(hours: 12),
  ];

  static Duration delayForAttempt(int attemptCount) {
    final index = (attemptCount - 1).clamp(0, _backoff.length - 1);
    return _backoff[index];
  }

  static bool shouldCompleteStoreTransaction(
    PurchaseVerificationRetryState state,
    DateTime now,
  ) =>
      now.millisecondsSinceEpoch - state.firstSeenAtMillis >=
      storeCompletionWindow.inMilliseconds;

  static bool isExpired(PurchaseVerificationRetryState state, DateTime now) =>
      now.millisecondsSinceEpoch - state.firstSeenAtMillis >=
      retentionWindow.inMilliseconds;
}

class PurchaseVerificationRetryStore {
  PurchaseVerificationRetryStore(this.preferences);

  static const String _key = 'purchase_verification_retry_v1';

  final SharedPreferences preferences;

  List<PurchaseVerificationRetryState> load({DateTime? now}) {
    final raw = preferences.getString(_key);
    if (raw == null) return const [];
    final current = now ?? DateTime.now();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return const [];
      final states = decoded
          .map(
            (item) => PurchaseVerificationRetryState.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .where(
            (state) =>
                !PurchaseVerificationRetryPolicy.isExpired(state, current),
          )
          .toList();
      return states;
    } on Object {
      return const [];
    }
  }

  Future<List<PurchaseVerificationRetryState>> recordRetry(
    String identity, {
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final states = load(now: current).toList();
    final index = states.indexWhere((state) => state.identity == identity);
    final previous = index >= 0 ? states[index] : null;
    final attemptCount = (previous?.attemptCount ?? 0) + 1;
    final firstSeenAtMillis =
        previous?.firstSeenAtMillis ?? current.millisecondsSinceEpoch;
    final next = current.add(
      PurchaseVerificationRetryPolicy.delayForAttempt(attemptCount),
    );
    final updated = PurchaseVerificationRetryState(
      identity: identity,
      firstSeenAtMillis: firstSeenAtMillis,
      attemptCount: attemptCount,
      nextAttemptAtMillis: next.millisecondsSinceEpoch,
    );
    if (index >= 0) {
      states[index] = updated;
    } else {
      states.add(updated);
    }
    await _save(states);
    return states;
  }

  Future<List<PurchaseVerificationRetryState>> remove(
    String identity, {
    DateTime? now,
  }) async {
    final states = load(
      now: now,
    ).where((state) => state.identity != identity).toList();
    await _save(states);
    return states;
  }

  Future<void> prune({DateTime? now}) async {
    await _save(load(now: now));
  }

  Future<void> _save(List<PurchaseVerificationRetryState> states) async {
    final encoded = jsonEncode(states.map((state) => state.toJson()).toList());
    final saved = await preferences.setString(_key, encoded);
    if (!saved) {
      throw StateError('purchase verification retry state was not persisted');
    }
  }
}
