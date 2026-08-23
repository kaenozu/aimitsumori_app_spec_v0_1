import 'dart:convert';

import 'package:aimitsumori_app/ocr_models.dart';
import 'package:aimitsumori_app/services/batch_ocr_service.dart';
import 'package:aimitsumori_app/services/ocr_review_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BatchOcrService.buildDocumentKey', () {
    test('ページファイルハッシュからパス非依存の安定キーを作る', () {
      final key = BatchOcrService.buildDocumentKey(
        pageFileHashes: ['hash-a', 'hash-b'],
        extractedText: '本文',
      );

      expect(
        key,
        sha256.convert(utf8.encode('hash-a|hash-b')).toString(),
      );
    });

    test('同じ入力なら同じキーになり、ページ順で変わる', () {
      final first = BatchOcrService.buildDocumentKey(
        pageFileHashes: ['hash-a', 'hash-b'],
        extractedText: '',
      );
      final same = BatchOcrService.buildDocumentKey(
        pageFileHashes: ['hash-a', 'hash-b'],
        extractedText: '',
      );
      final reversed = BatchOcrService.buildDocumentKey(
        pageFileHashes: ['hash-b', 'hash-a'],
        extractedText: '',
      );

      expect(first, same);
      expect(first, isNot(reversed));
    });

    test('ファイルハッシュが取れない場合は抽出テキストのSHA-256へフォールバックする', () {
      final key = BatchOcrService.buildDocumentKey(
        pageFileHashes: [],
        extractedText: '抽出テキスト',
      );

      expect(key, sha256.convert(utf8.encode('抽出テキスト')).toString());
    });

    test('documentKeyは64桁16進数のSHA-256形式', () {
      final key = BatchOcrService.buildDocumentKey(
        pageFileHashes: ['hash-a'],
        extractedText: 'text',
      );

      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  group('OcrReviewStore', () {
    test('新形式で保存した状態を読み戻せる', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = OcrReviewStore();

      await store.save('doc-key', {'line-1': OcrReviewStatus.confirmed});

      expect(await store.load('doc-key'), {
        'line-1': OcrReviewStatus.confirmed,
      });
    });

    test('旧形式（保存時刻なし）の状態も読める', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final storage = await SharedPreferences.getInstance();
      final legacyPayload = jsonEncode({'line-1': OcrReviewStatus.pending.code});
      await storage.setString(
        'ocr_review_states_v2_${sha256.convert(utf8.encode('doc-key'))}',
        legacyPayload,
      );
      final store = OcrReviewStore(preferences: storage);

      expect(await store.load('doc-key'), {
        'line-1': OcrReviewStatus.pending,
      });
    });

    test('件数上限を超えると古い確認状態から削除される', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final storage = await SharedPreferences.getInstance();
      final store = OcrReviewStore(preferences: storage);

      for (var index = 0; index < OcrReviewStore.maxEntries; index++) {
        await store.save('doc-$index', {'line': OcrReviewStatus.confirmed});
      }
      expect(await store.load('doc-0'), isNotEmpty);

      // 上限超過時、保存時刻が最も古いキー（doc-0）が削除される。
      await store.save('doc-new', {'line': OcrReviewStatus.confirmed});
      await store.pruneIfNeeded(storage, DateTime.now());

      expect(await store.load('doc-0'), isEmpty);
      expect(
        await store.load('doc-${OcrReviewStore.maxEntries - 1}'),
        isNotEmpty,
      );
      expect(await store.load('doc-new'), isNotEmpty);
    });

    test('TTL超過の確認状態は上限以内でも削除される', () async {
      final initial = <String, Object>{
        for (var index = 0; index <= OcrReviewStore.maxEntries; index++)
          'ocr_review_states_v2_${sha256.convert(utf8.encode('old-$index'))}':
              jsonEncode({
                'savedAt': DateTime.now()
                    .subtract(OcrReviewStore.maxAge * 2)
                    .millisecondsSinceEpoch,
                'statuses': {'line': OcrReviewStatus.confirmed.code},
              }),
      };
      SharedPreferences.setMockInitialValues(initial);
      final storage = await SharedPreferences.getInstance();
      final store = OcrReviewStore(preferences: storage);

      await store.save('fresh', {'line': OcrReviewStatus.confirmed});
      await store.pruneIfNeeded(storage, DateTime.now());

      expect(await store.load('old-0'), isEmpty);
      expect(await store.load('fresh'), isNotEmpty);
    });

    test('clearAllは現行・旧形式の両方を消す', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'ocr_review_states_v1_legacy': jsonEncode({
          'line': OcrReviewStatus.confirmed.code,
        }),
      });
      final storage = await SharedPreferences.getInstance();
      final store = OcrReviewStore(preferences: storage);
      await store.save('doc-key', {'line': OcrReviewStatus.confirmed});

      await store.clearAll();

      expect(await store.load('doc-key'), isEmpty);
      expect(
        storage.getKeys().where((key) => key.startsWith('ocr_review_states')),
        isEmpty,
      );
    });
  });
}
