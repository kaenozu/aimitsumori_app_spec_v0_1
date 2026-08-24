/// ストア購入情報をバックエンドで検証する。
library;

import '../utils/app_logger.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_verification_queue.dart';

enum PurchaseVerificationResult { valid, invalid, retryable }

abstract interface class PurchaseVerifier {
  Future<PurchaseVerificationResult> verify(PurchaseDetails purchase);

  /// 永続化されたリトライ用レコードを検証する（バックエンドAPI契約は共通）。
  Future<PurchaseVerificationResult> verifyReceipt(
    PendingVerificationRecord record,
  );
}

class PurchaseVerificationService implements PurchaseVerifier {
  const PurchaseVerificationService({
    this.endpoint = const String.fromEnvironment('PURCHASE_VERIFICATION_URL'),
  });

  final String endpoint;

  @override
  Future<PurchaseVerificationResult> verify(PurchaseDetails purchase) async {
    final verificationData = purchase.verificationData.serverVerificationData;
    if (verificationData.isEmpty || purchase.productID.isEmpty) {
      return PurchaseVerificationResult.invalid;
    }
    return verifyPayload(<String, dynamic>{
      'productId': purchase.productID,
      'purchaseId': purchase.purchaseID,
      'transactionDate': purchase.transactionDate,
      'source': purchase.verificationData.source,
      'serverVerificationData': verificationData,
      'localVerificationData': purchase.verificationData.localVerificationData,
    });
  }

  @override
  Future<PurchaseVerificationResult> verifyReceipt(
    PendingVerificationRecord record,
  ) async {
    if (record.serverVerificationData.isEmpty || record.productId.isEmpty) {
      return PurchaseVerificationResult.invalid;
    }
    return verifyPayload(<String, dynamic>{
      'productId': record.productId,
      'purchaseId': record.purchaseId,
      'transactionDate': record.transactionDate,
      'source': record.source,
      'serverVerificationData': record.serverVerificationData,
    });
  }

  /// バックエンド検証APIの共通実装。レスポンス契約は verify/verifyReceipt で共通。
  Future<PurchaseVerificationResult> verifyPayload(
    Map<String, dynamic> payload,
  ) async {
    final endpoint = this.endpoint;

    if (endpoint.trim().isEmpty) {
      return kReleaseMode
          ? PurchaseVerificationResult.invalid
          : PurchaseVerificationResult.valid;
    }

    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return PurchaseVerificationResult.invalid;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode == HttpStatus.requestTimeout ||
          response.statusCode == HttpStatus.tooManyRequests ||
          response.statusCode >= HttpStatus.internalServerError) {
        return PurchaseVerificationResult.retryable;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return PurchaseVerificationResult.invalid;
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return PurchaseVerificationResult.retryable;
      }
      final productId = payload['productId'];
      final productMatches =
          decoded['productId'] == null || decoded['productId'] == productId;
      if (decoded['valid'] == true && productMatches) {
        return PurchaseVerificationResult.valid;
      }
      if (decoded['valid'] == false || !productMatches) {
        return PurchaseVerificationResult.invalid;
      }
      return PurchaseVerificationResult.retryable;
    } on SocketException catch (error, stackTrace) {
      AppLogger.debug(
        'Purchase verification network failure: $error\n$stackTrace',
      );
      return PurchaseVerificationResult.retryable;
    } on HttpException catch (error, stackTrace) {
      AppLogger.debug(
        'Purchase verification HTTP failure: $error\n$stackTrace',
      );
      return PurchaseVerificationResult.retryable;
    } on FormatException catch (error, stackTrace) {
      AppLogger.debug(
        'Purchase verification response failure: $error\n$stackTrace',
      );
      return PurchaseVerificationResult.retryable;
    } on Object catch (error, stackTrace) {
      AppLogger.debug('Purchase verification failed: $error\n$stackTrace');
      return PurchaseVerificationResult.retryable;
    } finally {
      client.close(force: true);
    }
  }
}

class TestingPurchaseVerifier implements PurchaseVerifier {
  const TestingPurchaseVerifier({this.valid = true, this.result});

  final bool valid;
  final PurchaseVerificationResult? result;

  @override
  Future<PurchaseVerificationResult> verify(PurchaseDetails purchase) async =>
      _resolve();

  @override
  Future<PurchaseVerificationResult> verifyReceipt(
    PendingVerificationRecord record,
  ) async => _resolve();

  PurchaseVerificationResult _resolve() =>
      result ??
      (valid
          ? PurchaseVerificationResult.valid
          : PurchaseVerificationResult.invalid);
}
