/// ファイルパス: test/unit_normalizer_test.dart
/// 目的: UnitNormalizer.convertの全変換ケースと境界値を検証する。
/// 存在理由: 容量・個数・長さの表記揺れによる比較誤差を防ぐため。
/// 関連ファイル: lib/services/unit_normalizer.dart
library;

import 'package:aimitsumori_app/services/unit_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnitNormalizer.convert', () {
    test('nullと空文字はnullになる', () {
      expect(UnitNormalizer.convert(null), isNull);
      expect(UnitNormalizer.convert(''), isNull);
      expect(UnitNormalizer.convert('　 '), isNull);
    });

    test('個数単位をpiecesへ変換する', () {
      for (final input in ['個', '個入り', 'pc', 'pcs', 'piece', 'pieces']) {
        expect(UnitNormalizer.convert(input), 'pieces', reason: input);
      }
    });

    test('ミリリットル表記をmlへ変換する', () {
      for (final input in ['ml', 'ｍｌ', 'ML', 'ミリリットル']) {
        expect(UnitNormalizer.convert(input), 'ml', reason: input);
      }
    });

    test('リットル表記をlへ変換する', () {
      for (final input in ['l', 'L', 'ｌ', 'ℓ', 'リットル']) {
        expect(UnitNormalizer.convert(input), 'l', reason: input);
      }
    });

    test('重量単位を変換する', () {
      expect(UnitNormalizer.convert('グラム'), 'g');
      expect(UnitNormalizer.convert('ｋｇ'), 'kg');
      expect(UnitNormalizer.convert('キログラム'), 'kg');
    });

    test('長さ・面積・体積単位を変換する', () {
      expect(UnitNormalizer.convert('ミリメートル'), 'mm');
      expect(UnitNormalizer.convert('cm'), 'cm');
      expect(UnitNormalizer.convert('メートル'), 'm');
      expect(UnitNormalizer.convert('㎡'), 'm2');
      expect(UnitNormalizer.convert('m³'), 'm3');
    });

    test('未知単位と絵文字を破壊しない', () {
      expect(UnitNormalizer.convert(' 箱 😊 '), '箱😊');
    });
  });
}
