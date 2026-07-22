/// ファイルパス: test/text_normalizer_test.dart
/// 目的: TextNormalizer の変換規則と境界値を検証する。
/// 存在理由: OCR・手入力の表記揺れが比較結果へ混入する回帰を防ぐため。
library;

import 'package:aimitsumori_app/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextNormalizer.normalize', () {
    test('nullと空文字はnullになる', () {
      expect(TextNormalizer.normalize(null), isNull);
      expect(TextNormalizer.normalize(''), isNull);
      expect(TextNormalizer.normalize('　   '), isNull);
    });

    test('全角英数字を半角へ変換する', () {
      expect(TextNormalizer.normalize('ＡＢＣ１２３ａｂｃ'), 'ABC123abc');
    });

    test('全角記号を半角へ変換する', () {
      expect(TextNormalizer.normalize('！＃％＆＠：；'), '!#%&@:;');
    });

    test('全角スペースを半角スペースへ変換する', () {
      expect(TextNormalizer.normalize('見積　項目'), '見積 項目');
    });

    test('長音と各種ダッシュをハイフンへ統一する', () {
      expect(
        TextNormalizer.normalize('コンクリートー外構―工事−追加‐変更-修正–確認—完了'),
        'コンクリートー外構-工事-追加-変更-修正-確認-完了',
      );
    });

    test('全角かっこを半角へ変換する', () {
      expect(TextNormalizer.normalize('（A）［B］｛C｝'), '(A)[B]{C}');
    });

    test('日本語のかっこ類をASCIIへ変換する', () {
      expect(
        TextNormalizer.normalize('【A】「B」『C』〈D〉《E》'),
        '[A][B][C]<D><E>',
      );
    });

    test('前後の空白を除去する', () {
      expect(TextNormalizer.normalize('  見積項目  '), '見積項目');
    });

    test('特殊文字は保持する', () {
      expect(TextNormalizer.normalize('見積@#%&*+=/\\'), '見積@#%&*+=/\\');
    });

    test('絵文字は保持する', () {
      expect(TextNormalizer.normalize('見積😊🏠🔧'), '見積😊🏠🔧');
    });

    test('特殊文字と絵文字を含む複合入力を正規化する', () {
      expect(
        TextNormalizer.normalize('　Ａ社（１２３）ー見積@#%😊　'),
        'A社(123)ー見積@#%😊',
      );
    });

    test('改行とタブは破壊しない', () {
      expect(TextNormalizer.normalize('Ａ社\n\t１２３円'), 'A社\n\t123円');
    });

    test('変換済み文字列を再変換しても結果が変わらない', () {
      const input = 'A社(123)-見積😊';
      final once = TextNormalizer.normalize(input);
      final twice = TextNormalizer.normalize(once);
      expect(twice, once);
    });
  });
}
