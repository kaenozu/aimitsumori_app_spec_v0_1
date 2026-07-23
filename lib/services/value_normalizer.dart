/// 数値・単位・CSVセルを安全に正規化する共通ユーティリティ。
library;

export '../unit_normalizer.dart';

class LocalizedNumberParser {
  const LocalizedNumberParser._();

  static String normalizeCharacters(String value) {
    const fullWidthDigits = '０１２３４５６７８９';
    const asciiDigits = '0123456789';
    var result = value
        .replaceAll('−', '-')
        .replaceAll('―', '-')
        .replaceAll('＋', '+')
        .replaceAll('．', '.')
        .replaceAll('，', ',')
        .replaceAll('\u00a0', ' ');
    for (var index = 0; index < fullWidthDigits.length; index++) {
      result = result.replaceAll(fullWidthDigits[index], asciiDigits[index]);
    }
    return result;
  }

  /// 日本語入力で一般的な桁区切りと小数を区別して解析する。
  ///
  /// - `1,200` -> 1200
  /// - `1,200.5` -> 1200.5
  /// - `1.5` -> 1.5
  /// - `1,5` -> 1.5
  static double? tryParseDecimal(String input) {
    var value = normalizeCharacters(input).trim();
    if (value.isEmpty) return null;
    value = value.replaceAll(RegExp(r"[\s\u2007\u202f']"), '');
    if (!RegExp(r'^[+-]?[0-9.,]+$').hasMatch(value)) return null;

    final commaCount = ','.allMatches(value).length;
    final dotCount = '.'.allMatches(value).length;
    if (commaCount > 0 && dotCount > 0) {
      final commaIndex = value.lastIndexOf(',');
      final dotIndex = value.lastIndexOf('.');
      final decimalSeparator = commaIndex > dotIndex ? ',' : '.';
      final groupingSeparator = decimalSeparator == ',' ? '.' : ',';
      value = value.replaceAll(groupingSeparator, '');
      value = value.replaceAll(decimalSeparator, '.');
    } else if (commaCount > 0) {
      final grouped = RegExp(r'^[+-]?\d{1,3}(,\d{3})+$').hasMatch(value);
      value = grouped ? value.replaceAll(',', '') : value.replaceAll(',', '.');
    } else if (dotCount > 1) {
      return null;
    }

    final parsed = double.tryParse(value);
    return parsed?.isFinite == true ? parsed : null;
  }

  static int? tryParseYen(String input, {bool allowNegative = false}) {
    var value = normalizeCharacters(input).trim();
    if (value.isEmpty) return null;
    value = value
        .replaceAll(RegExp(r'[\s,，¥￥円]'), '')
        .replaceAll(RegExp(r'税込|税抜'), '');
    if (!RegExp(r'^[+-]?\d+$').hasMatch(value)) return null;
    final parsed = int.tryParse(value);
    if (parsed == null || (!allowNegative && parsed < 0)) return null;
    return parsed;
  }
}

class CsvCellSanitizer {
  const CsvCellSanitizer._();

  static final RegExp _formulaPrefix = RegExp(r'^[\s\t\r\n]*[=+\-@＝＋－＠]');

  static String protect(String value) {
    if (value.isEmpty || !_formulaPrefix.hasMatch(value)) return value;
    return "'$value";
  }
}
