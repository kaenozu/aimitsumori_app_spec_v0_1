/// ストア購入情報をバックエンドで検証する。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum PurchaseVerificationResult { valid, invalid, retryable }

abstract interface class PurchaseVerifier {
  Future<PurchaseVerificationResult> verify(PurchaseDetails purchase);
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
      request.write(
        jsonEncode({
          'productId': purchase.productID,
          'purchaseId': purchase.purchaseID,
          'transactionDate': purchase.transactionDate,
          'source': purchase.verificationData.source,
          'serverVerificationData': verificationData,
          'localVerificationData':
              purchase.verificationData.localVerificationData,
        }),
      );
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
      final productMatches = decoded['productId'] == null ||
          decoded['productId'] == purchase.productID;
      if (decoded['valid'] == true && productMatches) {
        return PurchaseVerificationResult.valid;
      }
      if (decoded['valid'] == false || !productMatches) {
        return PurchaseVerificationResult.invalid;
      }
      return PurchaseVerificationResult.retryable;
    } on SocketException catch (error, stackTrace) {
      debugPrint('Purchase verification network failure: $error\n$stackTrace');
      return PurchaseVerificationResult.retryable;
    } on HttpException catch (error, stackTrace) {
      debugPrint('Purchase verification HTTP failure: $error\n$stackTrace');
      return PurchaseVerificationResult.retryable;
    } on FormatException catch (error, stackTrace) {
      debugPrint('Purchase verification response failure: $error\n$stackTrace');
      return PurchaseVerificationResult.retryable;
    } on Object catch (error, stackTrace) {
      debugPrint('Purchase verification failed: $error\n$stackTrace');
      return PurchaseVerificationResult.retryable;
    } finally {
      client.close(force: true);
    }
  }
}

class TestingPurchaseVerifier implements PurchaseVerifier {
  const TestingPurchaseVerifier({
    this.valid = true,
    this.result,
  });

  final bool valid;
  final PurchaseVerificationResult? result;

  @override
  Future<PurchaseVerificationResult> verify(PurchaseDetails purchase) async =>
      result ??
      (valid
          ? PurchaseVerificationResult.valid
          : PurchaseVerificationResult.invalid);
}
