import 'package:aimitsumori_app/validation/input_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateAmount', () {
    test('空文字を拒否する', () {
      expect(validateAmount(null), isNotNull);
      expect(validateAmount(''), isNotNull);
      expect(validateAmount('   '), isNotNull);
    });

    test('正常値と桁区切りを受け付ける', () {
      expect(validateAmount('1'), isNull);
      expect(validateAmount('1,234'), isNull);
      expect(validateAmount('1234.5'), isNull);
      expect(validateAmount('1234.56'), isNull);
    });

    test('ゼロ境界はallowZeroに従う', () {
      expect(validateAmount('0'), isNotNull);
      expect(validateAmount('0', allowZero: true), isNull);
    });

    test('小数桁数と上限を検証する', () {
      expect(validateAmount('1.234'), isNotNull);
      expect(validateAmount('1.2', maxDecimalPlaces: 0), isNotNull);
      expect(validateAmount('999,999,999,999.99'), isNull);
      expect(validateAmount('1,000,000,000,000'), isNotNull);
    });

    test('負数・非有限値・不正形式を拒否する', () {
      for (final value in [
        '-1',
        'NaN',
        'Infinity',
        '-Infinity',
        '∞',
        '1e3',
        '1,23',
        '1,2O0',
        '--100',
        '１００',
      ]) {
        expect(validateAmount(value), isNotNull, reason: value);
      }
    });
  });

  group('validateQuantity', () {
    test('正の正常値と境界値を受け付ける', () {
      expect(validateQuantity('0.000001'), isNull);
      expect(validateQuantity('1,200'), isNull);
      expect(validateQuantity('999,999,999.999999'), isNull);
    });

    test('空・ゼロ・負数・範囲外・過剰小数を拒否する', () {
      for (final value in [
        '',
        '0',
        '-0.1',
        '0.0000001',
        '1,000,000,000',
        'NaN',
        'Infinity',
        '1,2O0',
      ]) {
        expect(validateQuantity(value), isNotNull, reason: value);
      }
    });
  });

  group('validatePercentage', () {
    test('0から100までを受け付ける', () {
      expect(validatePercentage('0'), isNull);
      expect(validatePercentage('12.34'), isNull);
      expect(validatePercentage('100'), isNull);
    });

    test('空・負数・100超・過剰小数・OCR異常値を拒否する', () {
      for (final value in [
        '',
        '-0.01',
        '100.01',
        '1.234',
        'NaN',
        'Infinity',
        '1O',
      ]) {
        expect(validatePercentage(value), isNotNull, reason: value);
      }
    });
  });
}
