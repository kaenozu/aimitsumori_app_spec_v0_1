/// ファイルパス: lib/unit_normalizer.dart
/// 比較用単位と外部出力用単位を正規化・換算する。
library;

import 'text_normalizer.dart';

class CanonicalQuantity {
  const CanonicalQuantity({
    required this.dimension,
    required this.value,
    required this.unit,
  });

  final String dimension;
  final double value;
  final String unit;
}

class UnitNormalizer {
  const UnitNormalizer._();

  /// 外部連携用の安定した英数字単位へ変換する。
  static String? convert(String? raw) {
    final normalized = TextNormalizer.normalize(raw)?.toLowerCase();
    if (normalized == null) return null;

    final compact = normalized.replaceAll(RegExp(r'\s+'), '');
    return switch (compact) {
      '個' ||
      '個入り' ||
      'pc' ||
      'pcs' ||
      'piece' ||
      'pieces' => 'pieces',
      'ml' || 'ミリリットル' => 'ml',
      'l' || 'ℓ' || 'リットル' => 'l',
      'g' || 'グラム' => 'g',
      'kg' || 'キログラム' => 'kg',
      'mm' || 'ミリ' || 'ミリメートル' => 'mm',
      'cm' || 'センチ' || 'センチメートル' => 'cm',
      'm' || 'メートル' => 'm',
      'm2' || 'm^2' || 'm²' || '㎡' => 'm2',
      'm3' || 'm^3' || 'm³' || '㎥' => 'm3',
      _ => compact,
    };
  }

  /// 画面表示と比較に使用する日本語寄りの単位へ正規化する。
  static String? normalize(String? raw) {
    final value = TextNormalizer.normalize(raw)?.toLowerCase();
    if (value == null || value.isEmpty) return null;

    final compact = value.replaceAll(RegExp(r'\s+'), '');
    return switch (compact) {
      'm2' || 'm^2' || 'm²' || '㎡' => '㎡',
      'm3' || 'm^3' || 'm³' || '㎥' => '㎥',
      'メートル' || 'm' => 'm',
      'ミリ' || 'ミリメートル' || 'mm' => 'mm',
      'センチ' || 'センチメートル' || 'cm' => 'cm',
      'ヶ所' || 'ケ所' || 'か所' || '箇所' => '箇所',
      '一式' || '式' => '式',
      '個入り' || 'pc' || 'pcs' || 'piece' || 'pieces' => '個',
      _ => compact,
    };
  }

  /// 換算可能な単位を標準量へ変換する。
  static CanonicalQuantity? toCanonical(double quantity, String? rawUnit) {
    if (!quantity.isFinite) return null;
    final unit = normalize(rawUnit);
    if (unit == null) return null;

    return switch (unit) {
      'mm' => CanonicalQuantity(
        dimension: 'length',
        value: quantity / 1000,
        unit: 'm',
      ),
      'cm' => CanonicalQuantity(
        dimension: 'length',
        value: quantity / 100,
        unit: 'm',
      ),
      'm' => CanonicalQuantity(
        dimension: 'length',
        value: quantity,
        unit: 'm',
      ),
      '㎡' => CanonicalQuantity(
        dimension: 'area',
        value: quantity,
        unit: '㎡',
      ),
      '㎥' => CanonicalQuantity(
        dimension: 'volume',
        value: quantity,
        unit: '㎥',
      ),
      _ => CanonicalQuantity(
        dimension: 'discrete:$unit',
        value: quantity,
        unit: unit,
      ),
    };
  }

  static bool equivalent(String? left, String? right) {
    final leftConverted = toCanonical(1, left);
    final rightConverted = toCanonical(1, right);
    if (leftConverted == null || rightConverted == null) return false;
    return leftConverted.dimension == rightConverted.dimension;
  }

  static bool quantitiesEquivalent({
    required double expected,
    required String expectedUnit,
    required double actual,
    required String actualUnit,
  }) {
    final convertedExpected = toCanonical(expected, expectedUnit);
    final convertedActual = toCanonical(actual, actualUnit);
    if (convertedExpected == null || convertedActual == null) return false;
    if (convertedExpected.dimension != convertedActual.dimension) return false;

    final tolerance = (convertedExpected.value.abs() * 0.001)
        .clamp(0.01, 1000.0)
        .toDouble();
    return (convertedExpected.value - convertedActual.value).abs() <= tolerance;
  }
}
