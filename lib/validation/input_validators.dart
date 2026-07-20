/// ファイルパス: lib/validation/input_validators.dart
/// 金額・数量・割合の入力値を画面間で統一して検証する。
library;

const double _maxAmount = 999999999999.99;
const double _maxQuantity = 999999999.999999;

String? validateAmount(
  String? value, {
  bool allowZero = false,
  int maxDecimalPlaces = 2,
}) {
  assert(maxDecimalPlaces >= 0, 'maxDecimalPlaces must not be negative.');
  return _validateNumber(
    value,
    label: '金額',
    allowZero: allowZero,
    maxDecimalPlaces: maxDecimalPlaces,
    maxValue: _maxAmount,
    maxValueLabel: '999,999,999,999.99',
  );
}

String? validateQuantity(String? value) {
  return _validateNumber(
    value,
    label: '数量',
    allowZero: false,
    maxDecimalPlaces: 6,
    maxValue: _maxQuantity,
    maxValueLabel: '999,999,999.999999',
  );
}

String? validatePercentage(String? value) {
  return _validateNumber(
    value,
    label: '割引率',
    allowZero: true,
    maxDecimalPlaces: 2,
    maxValue: 100,
    maxValueLabel: '100',
  );
}

String? _validateNumber(
  String? value, {
  required String label,
  required bool allowZero,
  required int maxDecimalPlaces,
  required double maxValue,
  required String maxValueLabel,
}) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return '$labelを入力してください。';

  final lower = raw.toLowerCase();
  if (lower.contains('nan') ||
      lower.contains('infinity') ||
      lower == 'inf' ||
      raw.contains('∞')) {
    return '$labelは有限の数値で入力してください。';
  }

  // 桁区切りは 1,234 の形だけを許可する。OCR誤認識を文字削除で救済しない。
  final numericPattern = RegExp(r'^-?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?$');
  if (!numericPattern.hasMatch(raw)) {
    return '$labelを数値で入力してください。';
  }

  final normalized = raw.replaceAll(',', '');
  final number = double.tryParse(normalized);
  if (number == null) return '$labelを数値で入力してください。';
  if (!number.isFinite) return '$labelは有限の数値で入力してください。';
  if (number < 0) return '$labelに負の値は入力できません。';
  if (!allowZero && number == 0) {
    return '$labelは0より大きい値を入力してください。';
  }

  final decimalPoint = normalized.indexOf('.');
  final decimalPlaces = decimalPoint < 0
      ? 0
      : normalized.length - decimalPoint - 1;
  if (decimalPlaces > maxDecimalPlaces) {
    if (maxDecimalPlaces == 0) return '$labelは整数で入力してください。';
    return '$labelは小数点以下$maxDecimalPlaces桁までで入力してください。';
  }

  if (number > maxValue) {
    return '$labelは$maxValueLabel以下で入力してください。';
  }
  return null;
}
