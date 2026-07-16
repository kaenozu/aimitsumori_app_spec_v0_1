/// 数値・単位・CSVセルを安全に正規化する共通ユーティリティ。
library;

class LocalizedNumberParser {
  const LocalizedNumberParser._();

  static String normalizeCharacters(String value) {
    const fullWidthDigits = '０１２３４５６７８９';
    const asciiDigits = '0123456789';
    var result = value
        .replaceAll('−', '-')
        .replaceAll('―', '-')
        .replaceAll('ー', '-')
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
    value = value.replaceAll(RegExp(r'[\s\u2007\u202f\']'), '');
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

  static int? tryParseYen(
    String input, {
    bool allowNegative = false,
  }) {
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

class UnitNormalizer {
  const UnitNormalizer._();

  static String? normalize(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    return switch (compact) {
      'm2' || 'm^2' || 'm²' || '㎡' => '㎡',
      'm3' || 'm^3' || 'm³' || '㎥' => '㎥',
      'メートル' || 'ｍ' || 'm' => 'm',
      'ミリ' || 'ミリメートル' || 'ｍｍ' || 'mm' => 'mm',
      'センチ' || 'センチメートル' || 'ｃｍ' || 'cm' => 'cm',
      'ヶ所' || 'ケ所' || 'か所' || '箇所' => '箇所',
      '一式' || '式' => '式',
      _ => compact,
    };
  }

  static _ConvertedQuantity? convert(double quantity, String? rawUnit) {
    final unit = normalize(rawUnit);
    if (unit == null) return null;
    return switch (unit) {
      'mm' => _ConvertedQuantity('length', quantity / 1000),
      'cm' => _ConvertedQuantity('length', quantity / 100),
      'm' => _ConvertedQuantity('length', quantity),
      '㎡' => _ConvertedQuantity('area', quantity),
      '㎥' => _ConvertedQuantity('volume', quantity),
      _ => _ConvertedQuantity('discrete:$unit', quantity),
    };
  }

  static bool equivalent(String? left, String? right) {
    final normalizedLeft = normalize(left);
    final normalizedRight = normalize(right);
    if (normalizedLeft == null || normalizedRight == null) return false;
    final leftConverted = convert(1, normalizedLeft);
    final rightConverted = convert(1, normalizedRight);
    return leftConverted?.dimension == rightConverted?.dimension;
  }

  static bool quantitiesEquivalent({
    required double expected,
    required String expectedUnit,
    required double actual,
    required String actualUnit,
  }) {
    final convertedExpected = convert(expected, expectedUnit);
    final convertedActual = convert(actual, actualUnit);
    if (convertedExpected == null || convertedActual == null) return false;
    if (convertedExpected.dimension != convertedActual.dimension) return false;
    final tolerance = (convertedExpected.value.abs() * 0.001).clamp(0.01, 1000.0);
    return (convertedExpected.value - convertedActual.value).abs() <= tolerance;
  }
}

class CsvCellSanitizer {
  const CsvCellSanitizer._();

  static final RegExp _formulaPrefix = RegExp(
    r'^[\s\t\r\n]*[=+\-@＝＋－＠]',
  );

  static String protect(String value) {
    if (value.isEmpty || !_formulaPrefix.hasMatch(value)) return value;
    return "'$value";
  }
}

class _ConvertedQuantity {
  const _ConvertedQuantity(this.dimension, this.value);

  final String dimension;
  final double value;
}
