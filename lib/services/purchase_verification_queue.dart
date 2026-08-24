/// ファイルパス: lib/services/purchase_verification_queue.dart
/// 購入検証が一時的に失敗した（retryable）購入を永続化し、
/// 指数バックオフで再試行するためのキュー。
///
/// リトライ方針:
/// - 初回失敗時にレコードを作成し、SharedPreferencesへ永続化する。
/// - 再試行間隔は 1分, 2分, 4分 ... と指数的に伸び、最大4時間で頭打ち。
/// - 最大試行回数（10回）または24時間のリトライ窓を超えたら自動再試行を止め、
///   レコードは削除せず status=needsConfirmation（要確認）として保持し、
///   サポート対応に備える。
/// - 検証に成功したらレコードを削除し、権利を付与する。
/// - 検証が invalid なら権利を付与せずレコードのみ削除する。
library;

import '../utils/app_logger.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'purchase_verification_service.dart';

enum PendingVerificationStatus {
  pending,
  needsConfirmation;

  static PendingVerificationStatus fromSerialized(String value) =>
      value == needsConfirmation.name ? needsConfirmation : pending;

  String get labelJa => this == needsConfirmation ? '要確認' : '確認中';
}

/// ストア検証の再試行待ち1件分のレコード。不変かつJSONへ相互変換可能。
@immutable
class PendingVerificationRecord {
  const PendingVerificationRecord({
    required this.id,
    required this.productId,
    required this.serverVerificationData,
    required this.firstAttemptAt,
    required this.nextAttemptAt,
    this.purchaseId,
    this.transactionDate,
    this.source,
    this.attempts = 0,
    this.status = PendingVerificationStatus.pending,
    this.lastAttemptAt,
  });

  final String id;
  final String productId;
  final String serverVerificationData;
  final String? purchaseId;
  final String? transactionDate;
  final String? source;

  /// 検証を試みた回数（初回失敗を含む）。キュー登録時点で1。
  final int attempts;
  final PendingVerificationStatus status;
  final DateTime firstAttemptAt;
  final DateTime? lastAttemptAt;
  final DateTime nextAttemptAt;

  bool get needsConfirmation =>
      status == PendingVerificationStatus.needsConfirmation;

  PendingVerificationRecord copyWith({
    int? attempts,
    PendingVerificationStatus? status,
    DateTime? lastAttemptAt,
    DateTime? nextAttemptAt,
  }) {
    return PendingVerificationRecord(
      id: id,
      productId: productId,
      serverVerificationData: serverVerificationData,
      purchaseId: purchaseId,
      transactionDate: transactionDate,
      source: source,
      attempts: attempts ?? this.attempts,
      status: status ?? this.status,
      firstAttemptAt: firstAttemptAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'productId': productId,
    'serverVerificationData': serverVerificationData,
    'purchaseId': purchaseId,
    'transactionDate': transactionDate,
    'source': source,
    'attempts': attempts,
    'status': status.name,
    'firstAttemptAt': firstAttemptAt.millisecondsSinceEpoch,
    if (lastAttemptAt != null)
      'lastAttemptAt': lastAttemptAt!.millisecondsSinceEpoch,
    'nextAttemptAt': nextAttemptAt.millisecondsSinceEpoch,
  };

  /// 不正なJSONで保存済みデータ全体が読めなくならないよう、
  /// 壊れたエントリはnullを返してスキップする。
  static PendingVerificationRecord? tryFromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'];
      final productId = json['productId'];
      final serverVerificationData = json['serverVerificationData'];
      final firstAttemptAt = json['firstAttemptAt'];
      final nextAttemptAt = json['nextAttemptAt'];
      if (id is! String ||
          productId is! String ||
          serverVerificationData is! String ||
          firstAttemptAt is! int ||
          nextAttemptAt is! int) {
        return null;
      }
      final attempts = json['attempts'];
      final status = json['status'];
      final lastAttemptAt = json['lastAttemptAt'];
      return PendingVerificationRecord(
        id: id,
        productId: productId,
        serverVerificationData: serverVerificationData,
        purchaseId: json['purchaseId'] is String
            ? json['purchaseId'] as String
            : null,
        transactionDate: json['transactionDate'] is String
            ? json['transactionDate'] as String
            : null,
        source: json['source'] is String ? json['source'] as String : null,
        attempts: attempts is int ? attempts : 0,
        status: status is String
            ? PendingVerificationStatus.fromSerialized(status)
            : PendingVerificationStatus.pending,
        firstAttemptAt: DateTime.fromMillisecondsSinceEpoch(firstAttemptAt),
        lastAttemptAt: lastAttemptAt is int
            ? DateTime.fromMillisecondsSinceEpoch(lastAttemptAt)
            : null,
        nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(nextAttemptAt),
      );
    } catch (error) {
      AppLogger.debug('Pending verification record parse failed: $error');
      return null;
    }
  }
}

/// 再試行スケジュールの方針。試行n回目の失敗後に
/// initialDelay * 2^(n-1) を待つ（maxDelayで頭打ち）。
class VerificationBackoffPolicy {
  const VerificationBackoffPolicy({
    this.initialDelay = const Duration(minutes: 1),
    this.maxDelay = const Duration(hours: 4),
    this.retryWindow = const Duration(hours: 24),
    this.maxAttempts = 10,
  });

  final Duration initialDelay;
  final Duration maxDelay;
  final Duration retryWindow;
  final int maxAttempts;

  Duration delayForAttempt(int attempt) {
    if (attempt <= 1) return initialDelay;
    final exponent = attempt - 1;
    if (exponent >= 31) return maxDelay;
    final doubled = initialDelay.inMilliseconds * (1 << exponent);
    if (doubled <= 0 || doubled > maxDelay.inMilliseconds) return maxDelay;
    return Duration(milliseconds: doubled);
  }

  bool shouldStopRetrying({
    required int attempts,
    required DateTime firstAttemptAt,
    required DateTime now,
  }) {
    if (attempts >= maxAttempts) return true;
    return now.difference(firstAttemptAt) >= retryWindow;
  }
}

/// SharedPreferencesへ単一キーで pending レコード群を保存するストア。
class PendingVerificationStore {
  PendingVerificationStore({Future<SharedPreferences> Function()? loader})
    : _loader = loader ?? SharedPreferences.getInstance;

  static const String storageKey = 'pending_purchase_verifications_v1';

  final Future<SharedPreferences> Function() _loader;

  Future<List<PendingVerificationRecord>> loadAll() async {
    try {
      final preferences = await _loader();
      final raw = preferences.getString(storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const [];
      final records = <PendingVerificationRecord>[];
      for (final value in decoded.values) {
        if (value is! Map<String, dynamic>) continue;
        final record = PendingVerificationRecord.tryFromJson(value);
        if (record != null) records.add(record);
      }
      records.sort((a, b) => a.firstAttemptAt.compareTo(b.firstAttemptAt));
      return records;
    } catch (error) {
      AppLogger.debug('Pending verification store load failed: $error');
      return const [];
    }
  }

  Future<void> save(PendingVerificationRecord record) {
    return _mutate((entries) => entries[record.id] = record.toJson());
  }

  Future<void> remove(String id) {
    return _mutate((entries) => entries.remove(id));
  }

  Future<void> _mutate(
    void Function(Map<String, dynamic> entries) mutation,
  ) async {
    final preferences = await _loader();
    final entries = await _readEntries(preferences);
    mutation(entries);
    try {
      final saved = await preferences.setString(
        storageKey,
        jsonEncode(entries),
      );
      if (!saved) {
        AppLogger.debug('Pending verification store save was not persisted.');
      }
    } catch (error) {
      AppLogger.debug('Pending verification store save failed: $error');
    }
  }

  Future<Map<String, dynamic>> _readEntries(
    SharedPreferences preferences,
  ) async {
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (error) {
      AppLogger.debug('Pending verification store decode failed: $error');
    }
    return <String, dynamic>{};
  }
}

class QueueProcessingReport {
  const QueueProcessingReport({
    this.verifiedRecordIds = const [],
    this.rejectedRecordIds = const [],
    this.rescheduledRecordIds = const [],
    this.escalatedRecordIds = const [],
  });

  final List<String> verifiedRecordIds;
  final List<String> rejectedRecordIds;
  final List<String> rescheduledRecordIds;
  final List<String> escalatedRecordIds;

  bool get isEmpty =>
      verifiedRecordIds.isEmpty &&
      rejectedRecordIds.isEmpty &&
      rescheduledRecordIds.isEmpty &&
      escalatedRecordIds.isEmpty;
}

class PurchaseVerificationQueue {
  PurchaseVerificationQueue({
    required this.verifier,
    PendingVerificationStore? store,
    this.backoffPolicy = const VerificationBackoffPolicy(),
    DateTime Function()? now,
  }) : store = store ?? PendingVerificationStore(),
       now = now ?? DateTime.now;

  final PurchaseVerifier verifier;
  final PendingVerificationStore store;
  final VerificationBackoffPolicy backoffPolicy;

  /// テストで時刻を固定できるよう注入可能なクロック。
  final DateTime Function() now;
  bool _processing = false;

  /// 同じ購入トークンから常に同じIDを導出し、冪等化する。
  static String recordIdFor({
    required String productId,
    required String serverVerificationData,
  }) {
    return sha256
        .convert(utf8.encode('$productId:$serverVerificationData'))
        .toString();
  }

  Future<List<PendingVerificationRecord>> loadRecords() => store.loadAll();

  /// retryable だった購入をキューへ登録する。既存レコードがあれば
  /// 試行回数とバックオフを維持したままそれを返す（重複登録しない）。
  Future<PendingVerificationRecord?> enqueue({
    required String productId,
    required String serverVerificationData,
    String? purchaseId,
    String? transactionDate,
    String? source,
  }) async {
    if (productId.isEmpty || serverVerificationData.trim().isEmpty) return null;
    final id = recordIdFor(
      productId: productId,
      serverVerificationData: serverVerificationData,
    );
    for (final existing in await store.loadAll()) {
      if (existing.id == id) return existing;
    }
    final current = now();
    // ストリーム配信時の初回検証がすでに失敗しているため、attemptsは1から開始する。
    final record = PendingVerificationRecord(
      id: id,
      productId: productId,
      serverVerificationData: serverVerificationData,
      purchaseId: purchaseId,
      transactionDate: transactionDate,
      source: source,
      attempts: 1,
      status: PendingVerificationStatus.pending,
      firstAttemptAt: current,
      lastAttemptAt: current,
      nextAttemptAt: current.add(backoffPolicy.delayForAttempt(1)),
    );
    await store.save(record);
    return record;
  }

  /// due になった pending レコードを再検証する。
  /// アプリ起動時・レジューム時・購入復元時に呼び出される。
  Future<QueueProcessingReport> processPending() async {
    if (_processing) return const QueueProcessingReport();
    _processing = true;
    try {
      final processedAt = now();
      final verified = <String>[];
      final rejected = <String>[];
      final rescheduled = <String>[];
      final escalated = <String>[];

      for (final record in await store.loadAll()) {
        if (record.status != PendingVerificationStatus.pending) continue;
        if (record.nextAttemptAt.isAfter(processedAt)) continue;
        if (processedAt.difference(record.firstAttemptAt) >=
            backoffPolicy.retryWindow) {
          // 端末が長期間オフラインだったケース。検証を消費せず要確認へ昇格する。
          final stale = record.copyWith(
            status: PendingVerificationStatus.needsConfirmation,
            lastAttemptAt: record.lastAttemptAt ?? record.firstAttemptAt,
          );
          await store.save(stale);
          escalated.add(stale.id);
          continue;
        }

        final result = await _verifySafely(record);
        switch (result) {
          case PurchaseVerificationResult.valid:
            await store.remove(record.id);
            verified.add(record.id);
            break;
          case PurchaseVerificationResult.invalid:
            await store.remove(record.id);
            rejected.add(record.id);
            break;
          case PurchaseVerificationResult.retryable:
            final attempts = record.attempts + 1;
            final stop = backoffPolicy.shouldStopRetrying(
              attempts: attempts,
              firstAttemptAt: record.firstAttemptAt,
              now: processedAt,
            );
            final updated = record.copyWith(
              attempts: attempts,
              status: stop
                  ? PendingVerificationStatus.needsConfirmation
                  : PendingVerificationStatus.pending,
              lastAttemptAt: processedAt,
              nextAttemptAt: processedAt.add(
                backoffPolicy.delayForAttempt(attempts),
              ),
            );
            await store.save(updated);
            if (stop) {
              escalated.add(updated.id);
            } else {
              rescheduled.add(updated.id);
            }
            break;
        }
      }
      return QueueProcessingReport(
        verifiedRecordIds: verified,
        rejectedRecordIds: rejected,
        rescheduledRecordIds: rescheduled,
        escalatedRecordIds: escalated,
      );
    } finally {
      _processing = false;
    }
  }

  Future<PurchaseVerificationResult> _verifySafely(
    PendingVerificationRecord record,
  ) async {
    try {
      return await verifier.verifyReceipt(record);
    } catch (error, stackTrace) {
      AppLogger.debug('Receipt verification retry failed: $error\n$stackTrace');
      return PurchaseVerificationResult.retryable;
    }
  }
}
