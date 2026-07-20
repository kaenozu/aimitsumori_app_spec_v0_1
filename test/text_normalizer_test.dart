/// ファイルパス: test/text_normalizer_test.dart
/// 目的: TextNormalizerの全変換規則と境界値を検証する。
/// 存在理由: OCR・手入力の表記揺れが比較結果へ混入する回帰を防ぐため。
/// 関連ファイル: lib/services/text_normalizer.dart
library;

import 'package:aimitsumori_app/services/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextNormalizer.normalize', () {
    test('nullと空文字はnullになる', () {
      expect(TextNormalizer.normalize(null), isNull);
      expect(TextNormalizer.normalize(''), isNull);
      expect(TextNormalizer.normalize('　   '), isNull);
    });

    test('全角英数と記号を半角へ変換する', () {
      expect(TextNormalizer.normalize('ＡＢＣ１２３ａｂｃ！'), 'ABC123abc!');
    });

    test('長音と各種ダッシュをハイフンへ統一する', () {
      expect(
        TextNormalizer.normalize('コンクリートー外構―工事−追加'),
        'コンクリート-外構-工事-追加',
      );
    });

    test('括弧類をASCIIへ変換する', () {
      expect(
        TextNormalizer.normalize('（A）［B］｛C｝【D】「E」『F』〈G〉'),
        '(A)[B]{C}[D][E][F]<G>',
      );
    });

    test('特殊文字と絵文字は保持する', () {
      expect(TextNormalizer.normalize('見積@#%😊'), '見積@#%😊');
    });

    test('複合入力を一度に正規化する', () {
      expect(TextNormalizer.normalize('　Ａ社（１２３）ー😊　'), 'A社(123)-😊');
    });
  });
}
