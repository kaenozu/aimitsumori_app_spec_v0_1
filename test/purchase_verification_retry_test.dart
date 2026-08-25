import 'dart:async';

import 'package:aimitsumori_app/services/ad_service.dart';
import 'package:aimitsumori_app/services/purchase_verification_queue.dart';
import 'package:aimitsumori_app/services/purchase_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _productId = 'remove_ads';

final _testBaseTime = DateTime.now().subtract(const Duration(hours: 1));

DateTime _baseTime() => _testBaseTime;

class _MutableClock {
  _MutableClock(this._now);

  DateTime _now;

  DateTime call() => _now;

  void advance(Duration duration) => _now = _now.add(duration);
}

class _ScriptedVerifier implements PurchaseVerifier {
  _ScriptedVerifier({
    this.defaultResult = PurchaseVerificationResult.retryable,
  });

  final List<PurchaseVerificationResult> script = [];
  final PurchaseVerificationResult defaultResult;
  Completer<void>? receiptGate;

  int verifyCalls = 0;
  int receiptCalls = 0;
  final List<PendingVerificationRecord> receivedRecords = [];

  @override
  Future<PurchaseVerificationResult> verify(PurchaseDetails purchase) async {
    verifyCalls += 1;
    return _next();
  }

  @override
  Future<PurchaseVerificationResult> verifyReceipt(
    PendingVerificationRecord record,
  ) async {
    receiptCalls += 1;
    receivedRecords.add(record);
    final gate = receiptGate;
    if (gate != null) await gate.future;
    return _next();
  }

  PurchaseVerificationResult _next() =>
      script.isNotEmpty ? script.removeAt(0) : defaultResult;
}

PendingVerificationRecord _record({
  String serverVerificationData = 'token-a',
  int attempts = 1,
  PendingVerificationStatus status = PendingVerificationStatus.pending,
  DateTime? firstAttemptAt,
  DateTime? lastAttemptAt,
  DateTime? nextAttemptAt,
}) {
  final base = firstAttemptAt ?? _baseTime();
  return PendingVerificationRecord(
    id: PurchaseVerificationQueue.recordIdFor(
      productId: _productId,
      serverVerificationData: serverVerificationData,
    ),
    productId: _productId,
    serverVerificationData: serverVerificationData,
    purchaseId: 'purchase-1',
    source: 'google_play',
    attempts: attempts,
    status: status,
    firstAttemptAt: base,
    lastAttemptAt: lastAttemptAt ?? base,
    nextAttemptAt: nextAttemptAt ?? base.add(const Duration(minutes: 1)),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('VerificationBackoffPolicy', () {
    const policy = VerificationBackoffPolicy();

    test('初回失敗後は1分、以降は指数的に伸びる', () {
      expect(policy.delayForAttempt(1), const Duration(minutes: 1));
      expect(policy.delayForAttempt(2), const Duration(minutes: 2));
      expect(policy.delayForAttempt(3), const Duration(minutes: 4));
      expect(policy.delayForAttempt(4), const Duration(minutes: 8));
      expect(policy.delayForAttempt(5), const Duration(minutes: 16));
    });

    test('再試行間隔は最大4時間で頭打ちになる', () {
      expect(policy.delayForAttempt(9), const Duration(hours: 4));
      expect(policy.delayForAttempt(20), const Duration(hours: 4));
      expect(policy.delayForAttempt(100), const Duration(hours: 4));
    });

    test('最大試行回数に達したら自動再試行を打ち切る', () {
      final now = _baseTime();
      expect(
        policy.shouldStopRetrying(
          attempts: policy.maxAttempts - 1,
          firstAttemptAt: now,
          now: now,
        ),
        isFalse,
      );
      expect(
        policy.shouldStopRetrying(
          attempts: policy.maxAttempts,
          firstAttemptAt: now,
          now: now,
        ),
        isTrue,
      );
    });

    test('24時間のリトライ窓を超えたら自動再試行を打ち切る', () {
      final firstAttemptAt = _baseTime();
      expect(
        policy.shouldStopRetrying(
          attempts: 1,
          firstAttemptAt: firstAttemptAt,
          now: firstAttemptAt.add(policy.retryWindow),
        ),
        isTrue,
      );
      expect(
        policy.shouldStopRetrying(
          attempts: 1,
          firstAttemptAt: firstAttemptAt,
          now: firstAttemptAt.add(
            policy.retryWindow - const Duration(milliseconds: 1),
          ),
        ),
        isFalse,
      );
    });
  });

  group('PendingVerificationStore', () {
    test('保存したレコードを読み戻せる', () async {
      final store = PendingVerificationStore();

      await store.save(_record());

      final loaded = await store.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, _record().id);
      expect(loaded.single.serverVerificationData, 'token-a');
      expect(loaded.single.attempts, 1);
      expect(loaded.single.status, PendingVerificationStatus.pending);
    });

    test('プロセス再起動後もレコードが残る（アプリ再起動をまたいで保持）', () async {
      final store = PendingVerificationStore();
      await store.save(_record());

      // 新しいインスタンス＝プロセス再起動後の読み込みを模擬する。
      final restartedStore = PendingVerificationStore();
      final loaded = await restartedStore.loadAll();

      expect(loaded, hasLength(1));
      expect(loaded.single.id, _record().id);
    });

    test('壊れたJSONは無視し、空として扱う', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PendingVerificationStore.storageKey: '{not-json',
      });
      final store = PendingVerificationStore();

      expect(await store.loadAll(), isEmpty);

      // 壊れた状態からの保存も正しく動く。
      await store.save(_record(serverVerificationData: 'token-b'));
      expect(await store.loadAll(), hasLength(1));
    });

    test('removeでレコードを削除できる', () async {
      final store = PendingVerificationStore();
      final record = _record();
      await store.save(record);

      await store.remove(record.id);

      expect(await store.loadAll(), isEmpty);
    });
  });

  group('PurchaseVerificationQueue', () {
    test('検証がretryableのときレコードが永続化される（障害シミュレーション）', () async {
      final clock = _MutableClock(_baseTime());
      final queue = PurchaseVerificationQueue(
        verifier: _ScriptedVerifier(),
        now: clock.call,
      );

      final record = await queue.enqueue(
        productId: _productId,
        serverVerificationData: 'token-outage',
        purchaseId: 'purchase-outage',
        source: 'google_play',
      );

      expect(record, isNotNull);
      expect(record!.attempts, 1, reason: 'ストリーム配信時の初回失敗を含む');
      expect(record.nextAttemptAt, _baseTime().add(const Duration(minutes: 1)));
      expect(await queue.loadRecords(), hasLength(1));

      final persisted = (await queue.loadRecords()).single;
      expect(persisted.serverVerificationData, 'token-outage');
      expect(persisted.status, PendingVerificationStatus.pending);
    });

    test('次回試行時刻までは再検証せず、レコードを維持する', () async {
      final clock = _MutableClock(_baseTime());
      final verifier = _ScriptedVerifier();
      final queue = PurchaseVerificationQueue(
        verifier: verifier,
        now: clock.call,
      );
      await queue.enqueue(
        productId: _productId,
        serverVerificationData: 'token-a',
      );

      final report = await queue.processPending();

      expect(report.isEmpty, isTrue);
      expect(verifier.receiptCalls, 0);
      expect(await queue.loadRecords(), hasLength(1));
    });

    test('retryableが続く間はバックオフに従って再スケジュールされる', () async {
      final clock = _MutableClock(_baseTime());
      final verifier = _ScriptedVerifier(
        defaultResult: PurchaseVerificationResult.retryable,
      );
      final queue = PurchaseVerificationQueue(
        verifier: verifier,
        now: clock.call,
      );
      await queue.enqueue(
        productId: _productId,
        serverVerificationData: 'token-a',
      );

      clock.advance(const Duration(minutes: 2));
      final report = await queue.processPending();

      expect(report.rescheduledRecordIds, hasLength(1));
      expect(verifier.receiptCalls, 1);
      var persisted = (await queue.loadRecords()).single;
      expect(persisted.attempts, 2);
      expect(
        persisted.nextAttemptAt,
        DateTime.fromMillisecondsSinceEpoch(
          clock().add(const Duration(minutes: 2)).millisecondsSinceEpoch,
        ),
      );

      clock.advance(const Duration(minutes: 2));
      await queue.processPending();

      persisted = (await queue.loadRecords()).single;
      expect(persisted.attempts, 3);
      expect(
        persisted.nextAttemptAt,
        DateTime.fromMillisecondsSinceEpoch(
          clock().add(const Duration(minutes: 4)).millisecondsSinceEpoch,
        ),
      );
      expect(persisted.status, PendingVerificationStatus.pending);
    });

    test('retryableからvalidへ回復したらレコードを削除して報告する', () async {
      final clock = _MutableClock(_baseTime());
      final verifier = _ScriptedVerifier()
        ..script.add(PurchaseVerificationResult.valid);
      final queue = PurchaseVerificationQueue(
        verifier: verifier,
        now: clock.call,
      );
      final queued = await queue.enqueue(
        productId: _productId,
        serverVerificationData: 'token-a',
      );

      clock.advance(const Duration(minutes: 2));
      final report = await queue.processPending();

      expect(report.verifiedRecordIds, [queued!.id]);
      expect(verifier.receiptCalls, 1);
      expect(verifier.receivedRecords.single.serverVerificationData, 'token-a');
      expect(await queue.loadRecords(), isEmpty);
    });

    test('retryableからinvalidになったら権利は付与せずレコードのみ削除する', () async {
      final clock = _MutableClock(_baseTime());
      final verifier = _ScriptedVerifier()
        ..script.add(PurchaseVerificationResult.invalid);
      final queue = PurchaseVerificationQueue(
        verifier: verifier,
        now: clock.call,
      );
      await queue.enqueue(
        productId: _productId,
        serverVerificationData: 'token-a',
      );

      clock.advance(const Duration(minutes: 2));
      final report = await queue.processPending();

      expect(report.rejectedRecordIds, hasLength(1));
      expect(report.verifiedRecordIds, isEmpty);
      expect(await queue.loadRecords(), isEmpty);
    });

    test('最大試行回数に達したら要確認へ昇格し、レコードは保持される', () async {
      final clock = _MutableClock(_baseTime());
      const policy = VerificationBackoffPolicy(maxAttempts: 3);
      final verifier = _ScriptedVerifier();
      final queue = PurchaseVerificationQueue(
        verifier: verifier,
        backoffPolicy: policy,
        now: clock.call,
      );
      await queue.enqueue(
        productId: _productId,
        serverVerificationData: 'token-a',
      );

      // 初回(attempts=1)から数えてmaxAttemptsまで失敗させる。
      var loopGuard = 0;
      while (true) {
        clock.advance(const Duration(hours: 4));
        final report = await queue.processPending();
        if (report.escalatedRecordIds.isNotEmpty) break;
        expect(report.rescheduledRecordIds, hasLength(1));
        loopGuard += 1;
        expect(loopGuard, lessThan(10), reason: '無限ループ防止');
      }

      expect(verifier.receiptCalls, policy.maxAttempts - 1);
      final persisted = (await queue.loadRecords()).single;
      expect(persisted.attempts, policy.maxAttempts);
      expect(persisted.status, PendingVerificationStatus.needsConfirmation);
    });

    test('24時間窓を超えたpendingは検証を消費せず要確認へ昇格する', () async {
      final base = _baseTime();
      final clock = _MutableClock(base);
      final verifier = _ScriptedVerifier();
      final queue = PurchaseVerificationQueue(
        verifier: verifier,
        now: clock.call,
      );
      final stale = _record(
        firstAttemptAt: base.subtract(const Duration(hours: 25)),
        nextAttemptAt: base.subtract(const Duration(minutes: 30)),
      );
      final store = PendingVerificationStore();
      await store.save(stale);

      final report = await queue.processPending();

      expect(report.escalatedRecordIds, [stale.id]);
      expect(verifier.receiptCalls, 0, reason: '窓外のレコードは検証しない');
      final persisted = (await store.loadAll()).single;
      expect(persisted.status, PendingVerificationStatus.needsConfirmation);
      expect(persisted.attempts, stale.attempts);
    });

    test('要確認レコードは自動再試行の対象にならない', () async {
      final base = _baseTime();
      final clock = _MutableClock(base);
      final verifier = _ScriptedVerifier();
      final queue = PurchaseVerificationQueue(
        verifier: verifier,
        now: clock.call,
      );
      final escalated = _record(
        status: PendingVerificationStatus.needsConfirmation,
        nextAttemptAt: base.subtract(const Duration(hours: 1)),
      );
      await PendingVerificationStore().save(escalated);

      clock.advance(const Duration(days: 2));
      final report = await queue.processPending();

      expect(report.isEmpty, isTrue);
      expect(verifier.receiptCalls, 0);
      expect(await queue.loadRecords(), hasLength(1));
    });

    test('同じ購入トークンの重複登録は冪等（試行回数とバックオフを維持）', () async {
      final clock = _MutableClock(_baseTime());
      final queue = PurchaseVerificationQueue(
        verifier: _ScriptedVerifier(),
        now: clock.call,
      );

      final first = await queue.enqueue(
        productId: _productId,
        serverVerificationData: 'token-a',
        purchaseId: 'purchase-1',
      );
      final duplicate = await queue.enqueue(
        productId: _productId,
        serverVerificationData: 'token-a',
        purchaseId: 'purchase-1-replayed',
      );

      expect(duplicate, isNotNull);
      expect(duplicate!.id, first!.id);
      expect(duplicate.attempts, first.attempts);
      expect(await queue.loadRecords(), hasLength(1));
    });

    test('異なる購入トークンは別レコードになる', () async {
      final clock = _MutableClock(_baseTime());
      final queue = PurchaseVerificationQueue(
        verifier: _ScriptedVerifier(),
        now: clock.call,
      );

      await queue.enqueue(
        productId: _productId,
        serverVerificationData: 'token-a',
      );
      await queue.enqueue(
        productId: _productId,
        serverVerificationData: 'token-b',
      );

      expect(await queue.loadRecords(), hasLength(2));
    });

    test('検証トークンが空の購入はキューに入れない', () async {
      final clock = _MutableClock(_baseTime());
      final queue = PurchaseVerificationQueue(
        verifier: _ScriptedVerifier(),
        now: clock.call,
      );

      final record = await queue.enqueue(
        productId: _productId,
        serverVerificationData: '',
      );

      expect(record, isNull);
      expect(await queue.loadRecords(), isEmpty);
    });

    test('同時に複数回実行しても検証は一度だけ行われる', () async {
      final clock = _MutableClock(_baseTime());
      final verifier = _ScriptedVerifier()
        ..script.add(PurchaseVerificationResult.valid)
        ..receiptGate = Completer<void>();
      final queue = PurchaseVerificationQueue(
        verifier: verifier,
        now: clock.call,
      );
      final queued = await queue.enqueue(
        productId: _productId,
        serverVerificationData: 'token-a',
      );
      clock.advance(const Duration(minutes: 2));

      final first = queue.processPending();
      final second = queue.processPending();

      expect((await second).isEmpty, isTrue, reason: '処理中は後発呼び出しを何もしない');
      verifier.receiptGate!.complete();
      final report = await first;

      expect(report.verifiedRecordIds, [queued!.id]);
      expect(verifier.receiptCalls, 1);
    });
  });

  group('AdServiceとの連携', () {
    test('起動時の再試行で検証が成功すると権利を付与し、レコードを消す', () async {
      final store = PendingVerificationStore();
      await store.save(_record());
      final verifier = _ScriptedVerifier()
        ..script.add(PurchaseVerificationResult.valid);
      final service = AdService.testing(
        adFree: false,
        verifier: verifier,
        verificationStore: store,
      );

      await service.retryPendingVerifications();

      expect(service.adFree.value, isTrue);
      expect(service.pendingVerificationCount.value, 0);
      expect(service.purchaseNeedsConfirmation.value, isFalse);
      expect(await store.loadAll(), isEmpty);

      // 再実行しても権利付与は冪等。
      await service.retryPendingVerifications();
      expect(service.adFree.value, isTrue);
      service.dispose();
    });

    test('起動時も検証が失敗する間は権利を付与せず、レコードを保持する', () async {
      final store = PendingVerificationStore();
      await store.save(_record());
      final service = AdService.testing(
        adFree: false,
        verifier: _ScriptedVerifier(),
        verificationStore: store,
      );

      await service.retryPendingVerifications();

      expect(service.adFree.value, isFalse);
      expect(service.purchaseNeedsConfirmation.value, isFalse);
      expect(service.pendingVerificationCount.value, 1);
      final persisted = (await store.loadAll()).single;
      expect(persisted.attempts, 2);
      service.dispose();
    });

    test('自動再試行が終了した購入は要確認としてUI状態に現れる', () async {
      final store = PendingVerificationStore();
      final base = _baseTime();
      await store.save(
        _record(
          attempts: const VerificationBackoffPolicy().maxAttempts - 1,
          firstAttemptAt: base,
          lastAttemptAt: base,
          nextAttemptAt: base.subtract(const Duration(minutes: 5)),
        ),
      );
      final service = AdService.testing(
        adFree: false,
        verifier: _ScriptedVerifier(),
        verificationStore: store,
      );

      await service.retryPendingVerifications();

      expect(service.purchaseNeedsConfirmation.value, isTrue);
      expect(
        service.pendingVerificationCount.value,
        1,
        reason: '要確認レコードは保持される',
      );
      expect(service.adFree.value, isFalse);
      expect(
        (await store.loadAll()).single.status,
        PendingVerificationStatus.needsConfirmation,
      );
      service.dispose();
    });

    test('再試行でinvalid判定なら権利を取り消してレコードを消す', () async {
      final store = PendingVerificationStore();
      await store.save(_record());
      final verifier = _ScriptedVerifier()
        ..script.add(PurchaseVerificationResult.invalid);
      final service = AdService.testing(
        adFree: true,
        verifier: verifier,
        verificationStore: store,
      );
      service.adFree.value = true;

      await service.retryPendingVerifications();

      expect(service.adFree.value, isFalse);
      expect(service.pendingVerificationCount.value, 0);
      expect(await store.loadAll(), isEmpty);
      service.dispose();
    });
  });
}
