library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ocr_models.dart';

class OcrReviewStore {
  OcrReviewStore({this.preferences});

  final SharedPreferences? preferences;
  static const _prefix = 'ocr_review_states_v2_';
  static const _legacyPrefixes = <String>['ocr_review_states_v1_'];
  static const int maxEntries = 100;
  static const Duration maxAge = Duration(days: 90);

  /// `documentKey`にはファイル内容のSHA-256を優先して渡す。
  Future<Map<String, OcrReviewStatus>> load(String documentKey) async {
    final storage = preferences ?? await SharedPreferences.getInstance();
    final raw = storage.getString('$_prefix${_sourceKey(documentKey)}');
    if (raw == null || raw.isEmpty) return <String, OcrReviewStatus>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, OcrReviewStatus>{};
      }
      return _statusesOf(decoded);
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
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'statuses': {
        for (final entry in statuses.entries) entry.key: entry.value.code,
      },
    });
    final saved = await storage.setString(
      '$_prefix${_sourceKey(documentKey)}',
      payload,
    );
    if (!saved) {
      throw StateError('OCR確認状態を保存できませんでした。');
    }
    await pruneIfNeeded(storage, DateTime.now());
  }

  Map<String, OcrReviewStatus> _statusesOf(Map<String, dynamic> decoded) {
    final statuses = decoded['statuses'];
    if (statuses is Map<String, dynamic>) {
      return {
        for (final entry in statuses.entries)
          entry.key: OcrReviewStatus.fromCode(entry.value as String),
      };
    }
    // 旧形式（保存時刻なしの状態Map）もそのまま読める。
    return {
      for (final entry in decoded.entries)
        entry.key: OcrReviewStatus.fromCode(entry.value as String),
    };
  }

  /// 削除済み撮影ファイル由来キーの蓄積を防ぐため、
  /// TTL超過・件数上限の確認状態を掃除する。
  @visibleForTesting
  Future<void> pruneIfNeeded(SharedPreferences storage, DateTime now) async {
    final keys = storage
        .getKeys()
        .where((key) => key.startsWith(_prefix))
        .toList(growable: false);
    if (keys.length <= maxEntries) return;

    final savedAtByKey = <String, int>{
      for (final key in keys) key: _savedAtOf(storage.getString(key)),
    };
    final expiryMillis = now.subtract(maxAge).millisecondsSinceEpoch;
    final victims = <String>{
      for (final entry in savedAtByKey.entries)
        if (entry.value > 0 && entry.value < expiryMillis) entry.key,
    };
    final retained =
        savedAtByKey.entries.where((entry) => !victims.contains(entry.key)).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    victims.addAll(retained.skip(maxEntries).map((entry) => entry.key));

    for (final victim in victims) {
      await storage.remove(victim);
    }
  }

  /// 旧形式（保存時刻なし）は年齢不明として0を返し、上限超過時に優先削除する。
  int _savedAtOf(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> &&
          decoded['savedAt'] is num &&
          decoded['statuses'] is Map) {
        return (decoded['savedAt'] as num).toInt();
      }
    } catch (_) {}
    return 0;
  }

  /// 「全データを削除」に合わせて、現行・旧形式のOCR確認状態を消去する。
  Future<void> clearAll() async {
    final storage = preferences ?? await SharedPreferences.getInstance();
    final prefixes = <String>{_prefix, ..._legacyPrefixes};
    final keys = storage
        .getKeys()
        .where((key) => prefixes.any(key.startsWith))
        .toList(growable: false);
    for (final key in keys) {
      final removed = await storage.remove(key);
      if (!removed) {
        throw StateError('OCR確認状態を削除できませんでした。');
      }
    }
  }

  static String _sourceKey(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
