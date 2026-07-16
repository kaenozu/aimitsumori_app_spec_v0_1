import 'package:aimitsumori_app/services/value_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalizedNumberParser', () {
    test('distinguishes thousands separators from decimal separators', () {
      expect(LocalizedNumberParser.tryParseDecimal('1,200'), 1200);
      expect(LocalizedNumberParser.tryParseDecimal('1,200.5'), 1200.5);
      expect(LocalizedNumberParser.tryParseDecimal('1.5'), 1.5);
      expect(LocalizedNumberParser.tryParseDecimal('1,5'), 1.5);
      expect(LocalizedNumberParser.tryParseDecimal('１，２００'), 1200);
    });

    test('rejects malformed and non-finite values', () {
      expect(LocalizedNumberParser.tryParseDecimal('1,2,3'), isNull);
      expect(LocalizedNumberParser.tryParseDecimal('abc'), isNull);
      expect(LocalizedNumberParser.tryParseDecimal(''), isNull);
    });

    test('yen parser rejects negative values unless explicitly allowed', () {
      expect(LocalizedNumberParser.tryParseYen('￥500'), 500);
      expect(LocalizedNumberParser.tryParseYen('1,200円'), 1200);
      expect(LocalizedNumberParser.tryParseYen('-500'), isNull);
      expect(
        LocalizedNumberParser.tryParseYen('-500', allowNegative: true),
        -500,
      );
    });
  });

  group('UnitNormalizer', () {
    test('normalizes equivalent unit spellings', () {
      expect(UnitNormalizer.normalize('m2'), '㎡');
      expect(UnitNormalizer.normalize('m²'), '㎡');
      expect(UnitNormalizer.normalize('ヶ所'), '箇所');
      expect(UnitNormalizer.normalize('一式'), '式');
    });

    test('converts compatible length quantities', () {
      expect(
        UnitNormalizer.quantitiesEquivalent(
          expected: 1,
          expectedUnit: 'm',
          actual: 1000,
          actualUnit: 'mm',
        ),
        isTrue,
      );
      expect(UnitNormalizer.equivalent('m', '㎡'), isFalse);
    });
  });

  test('CSV values beginning with formulas are converted to text', () {
    expect(CsvCellSanitizer.protect('=HYPERLINK("x")'), startsWith("'="));
    expect(CsvCellSanitizer.protect(' +SUM(A1:A2)'), startsWith("' "));
    expect(CsvCellSanitizer.protect('通常文字列'), '通常文字列');
  });
}
