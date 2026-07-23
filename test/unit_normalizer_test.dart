/// ファイルパス: test/unit_normalizer_test.dart
/// 目的: UnitNormalizer の単位変換、未知単位、境界値を検証する。
/// 存在理由: 容量・個数・長さの表記揺れによる比較誤差を防ぐため。
library;

import 'package:aimitsumori_app/unit_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnitNormalizer.convert', () {
    test('nullと空文字はnullになる', () {
      expect(UnitNormalizer.convert(null), isNull);
      expect(UnitNormalizer.convert(''), isNull);
      expect(UnitNormalizer.convert('　 '), isNull);
    });

    test('個数単位をpiecesへ変換する', () {
      for (final input in [
        '個',
        '個入り',
        'pc',
        'pcs',
        'piece',
        'pieces',
        'ＰＣ',
        'ＰＣＳ',
      ]) {
        expect(UnitNormalizer.convert(input), 'pieces', reason: input);
      }
    });

    test('ミリリットル表記をmlへ変換する', () {
      for (final input in ['ml', 'ｍｌ', 'ML', 'ＭＬ', 'ミリリットル']) {
        expect(UnitNormalizer.convert(input), 'ml', reason: input);
      }
    });

    test('リットル表記をlへ変換する', () {
      for (final input in ['l', 'L', 'ｌ', 'Ｌ', 'ℓ', 'リットル']) {
        expect(UnitNormalizer.convert(input), 'l', reason: input);
      }
    });

    test('グラム表記をgへ変換する', () {
      for (final input in ['g', 'G', 'ｇ', 'Ｇ', 'グラム']) {
        expect(UnitNormalizer.convert(input), 'g', reason: input);
      }
    });

    test('キログラム表記をkgへ変換する', () {
      for (final input in ['kg', 'KG', 'ｋｇ', 'ＫＧ', 'キログラム']) {
        expect(UnitNormalizer.convert(input), 'kg', reason: input);
      }
    });

    test('長さ単位を変換する', () {
      expect(UnitNormalizer.convert('mm'), 'mm');
      expect(UnitNormalizer.convert('ｍｍ'), 'mm');
      expect(UnitNormalizer.convert('ミリ'), 'mm');
      expect(UnitNormalizer.convert('ミリメートル'), 'mm');
      expect(UnitNormalizer.convert('cm'), 'cm');
      expect(UnitNormalizer.convert('ｃｍ'), 'cm');
      expect(UnitNormalizer.convert('センチ'), 'cm');
      expect(UnitNormalizer.convert('センチメートル'), 'cm');
      expect(UnitNormalizer.convert('m'), 'm');
      expect(UnitNormalizer.convert('ｍ'), 'm');
      expect(UnitNormalizer.convert('メートル'), 'm');
    });

    test('面積単位をm2へ変換する', () {
      for (final input in ['m2', 'M2', 'ｍ２', 'm^2', 'm²', '㎡']) {
        expect(UnitNormalizer.convert(input), 'm2', reason: input);
      }
    });

    test('体積単位をm3へ変換する', () {
      for (final input in ['m3', 'M3', 'ｍ３', 'm^3', 'm³', '㎥']) {
        expect(UnitNormalizer.convert(input), 'm3', reason: input);
      }
    });

    test('単位内の空白を除去する', () {
      expect(UnitNormalizer.convert(' m l '), 'ml');
      expect(UnitNormalizer.convert(' k g '), 'kg');
      expect(UnitNormalizer.convert(' 個 入 り '), 'pieces');
    });

    test('未知の単位は正規化後の文字列を返す', () {
      expect(UnitNormalizer.convert('箱'), '箱');
      expect(UnitNormalizer.convert('セット'), 'セット');
      expect(UnitNormalizer.convert('袋入り'), '袋入り');
    });

    test('特殊文字と絵文字を破壊しない', () {
      expect(UnitNormalizer.convert('箱😊'), '箱😊');
      expect(UnitNormalizer.convert('袋@#'), '袋@#');
      expect(UnitNormalizer.convert(' 箱 😊 '), '箱😊');
    });

    test('変換済み単位を再変換しても結果が変わらない', () {
      for (final input in [
        'pieces',
        'ml',
        'l',
        'g',
        'kg',
        'mm',
        'cm',
        'm',
        'm2',
        'm3',
      ]) {
        final once = UnitNormalizer.convert(input);
        final twice = UnitNormalizer.convert(once);
        expect(twice, once, reason: input);
      }
    });
  });

  group('UnitNormalizer.normalize', () {
    test('nullと空文字はnullになる', () {
      expect(UnitNormalizer.normalize(null), isNull);
      expect(UnitNormalizer.normalize(''), isNull);
      expect(UnitNormalizer.normalize('   '), isNull);
    });

    test('外構用の面積・体積単位へ正規化する', () {
      expect(UnitNormalizer.normalize('m2'), '㎡');
      expect(UnitNormalizer.normalize('m²'), '㎡');
      expect(UnitNormalizer.normalize('㎡'), '㎡');
      expect(UnitNormalizer.normalize('m3'), '㎥');
      expect(UnitNormalizer.normalize('m³'), '㎥');
      expect(UnitNormalizer.normalize('㎥'), '㎥');
    });

    test('箇所表記を統一する', () {
      for (final input in ['ヶ所', 'ケ所', 'か所', '箇所']) {
        expect(UnitNormalizer.normalize(input), '箇所', reason: input);
      }
    });

    test('一式と式を式へ統一する', () {
      expect(UnitNormalizer.normalize('一式'), '式');
      expect(UnitNormalizer.normalize('式'), '式');
    });
  });

  group('UnitNormalizer.equivalent', () {
    test('同じ長さ次元の単位は互換と判定する', () {
      expect(UnitNormalizer.equivalent('mm', 'cm'), isTrue);
      expect(UnitNormalizer.equivalent('cm', 'm'), isTrue);
      expect(UnitNormalizer.equivalent('m', 'mm'), isTrue);
    });

    test('異なる次元の単位は非互換と判定する', () {
      expect(UnitNormalizer.equivalent('m', '㎡'), isFalse);
      expect(UnitNormalizer.equivalent('㎡', '㎥'), isFalse);
      expect(UnitNormalizer.equivalent('式', '箇所'), isFalse);
    });

    test('nullを含む場合はfalseになる', () {
      expect(UnitNormalizer.equivalent(null, 'm'), isFalse);
      expect(UnitNormalizer.equivalent('m', null), isFalse);
    });
  });

  group('UnitNormalizer.quantitiesEquivalent', () {
    test('1000mmと1mを同値と判定する', () {
      expect(
        UnitNormalizer.quantitiesEquivalent(
          expected: 1000,
          expectedUnit: 'mm',
          actual: 1,
          actualUnit: 'm',
        ),
        isTrue,
      );
    });

    test('100cmと1mを同値と判定する', () {
      expect(
        UnitNormalizer.quantitiesEquivalent(
          expected: 100,
          expectedUnit: 'cm',
          actual: 1,
          actualUnit: 'm',
        ),
        isTrue,
      );
    });

    test('異なる長さを非同値と判定する', () {
      expect(
        UnitNormalizer.quantitiesEquivalent(
          expected: 50,
          expectedUnit: 'cm',
          actual: 1,
          actualUnit: 'm',
        ),
        isFalse,
      );
    });

    test('異なる次元を非同値と判定する', () {
      expect(
        UnitNormalizer.quantitiesEquivalent(
          expected: 1,
          expectedUnit: 'm',
          actual: 1,
          actualUnit: '㎡',
        ),
        isFalse,
      );
    });
  });
}
