library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ocr_models.dart';

class OcrReviewStore {
  OcrReviewStore({this.preferences});

  final SharedPreferences? preferences;
  static const _prefix = 'ocr_review_states_v2_';

  /// `documentKey`にはファイル内容のSHA-256を優先して渡す。
  Future<Map<String, OcrReviewStatus>> load(String documentKey) async {
    final storage = preferences ?? await SharedPreferences.getInstance();
    final raw = storage.getString('$_prefix${_sourceKey(documentKey)}');
    if (raw == null || raw.isEmpty) return <String, OcrReviewStatus>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: OcrReviewStatus.fromCode(entry.value as String),
      };
    } catch (_) {
      return <String, OcrReviewStatus>{};
    }
  }

  Future<void> save(
    String documentKey,
    Map<String, OcrReviewStatus> statuses,
  ) async {
    final storage = preferences ?? await SharedPreferences.getInstance();
    final payload = jsonEncode({
      for (final entry in statuses.entries) entry.key: entry.value.code,
    });
    await storage.setString('$_prefix${_sourceKey(documentKey)}', payload);
  }

  static String _sourceKey(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
