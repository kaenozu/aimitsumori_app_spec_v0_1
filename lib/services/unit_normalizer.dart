/// ファイルパス: lib/services/unit_normalizer.dart
/// 目的: 比較用単位と外部出力用単位を正規化・換算する。
/// 存在理由: 単位表記の揺れと長さ換算を一貫して扱うため。
/// 関連ファイル: value_normalizer.dart, text_normalizer.dart, requirements_engine.dart
library;

import 'text_normalizer.dart';

class UnitNormalizer {
  const UnitNormalizer._();

  static String? convert(String? raw) {
    final normalized = TextNormalizer.normalize(raw)?.toLowerCase();
    if (normalized == null) return null;
    final compact = normalized.replaceAll(RegExp(r'\s+'), '');
    return switch (compact) {
      '個' || '個入り' || 'pc' || 'pcs' || 'piece' || 'pieces' => 'pieces',
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

  static _ConvertedQuantity? _convert(double quantity, String? rawUnit) {
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
    final leftConverted = _convert(1, normalizedLeft);
    final rightConverted = _convert(1, normalizedRight);
    return leftConverted?.dimension == rightConverted?.dimension;
  }

  static bool quantitiesEquivalent({
    required double expected,
    required String expectedUnit,
    required double actual,
    required String actualUnit,
  }) {
    final convertedExpected = _convert(expected, expectedUnit);
    final convertedActual = _convert(actual, actualUnit);
    if (convertedExpected == null || convertedActual == null) return false;
    if (convertedExpected.dimension != convertedActual.dimension) return false;
    final tolerance = (convertedExpected.value.abs() * 0.001).clamp(
      0.01,
      1000.0,
    );
    return (convertedExpected.value - convertedActual.value).abs() <= tolerance;
  }
}

class _ConvertedQuantity {
  const _ConvertedQuantity(this.dimension, this.value);

  final String dimension;
  final double value;
}
