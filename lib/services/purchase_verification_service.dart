/// ストア購入情報をバックエンドで検証する。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

abstract interface class PurchaseVerifier {
  Future<bool> verify(PurchaseDetails purchase);
}

class PurchaseVerificationService implements PurchaseVerifier {
  const PurchaseVerificationService({
    this.endpoint = const String.fromEnvironment(
      'PURCHASE_VERIFICATION_URL',
    ),
  });

  final String endpoint;

  @override
  Future<bool> verify(PurchaseDetails purchase) async {
    final verificationData = purchase.verificationData.serverVerificationData;
    if (verificationData.isEmpty || purchase.productID.isEmpty) return false;

    if (endpoint.trim().isEmpty) {
      // デバッグではストアのサンドボックスデータを用いたUI確認を許可する。
      // Releaseでは検証先未設定をfail-closedにする。
      return !kReleaseMode;
    }

    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https') return false;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(uri).timeout(
            const Duration(seconds: 10),
          );
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
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return false;
      return decoded['valid'] == true &&
          (decoded['productId'] == null ||
              decoded['productId'] == purchase.productID);
    } on Object catch (error, stackTrace) {
      debugPrint('Purchase verification failed: $error\n$stackTrace');
      return false;
    } finally {
      client.close(force: true);
    }
  }
}

class TestingPurchaseVerifier implements PurchaseVerifier {
  const TestingPurchaseVerifier({this.valid = true});

  final bool valid;

  @override
  Future<bool> verify(PurchaseDetails purchase) async => valid;
}
