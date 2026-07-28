/// ファイルパス: lib/utils/formatting.dart
/// 通貨・数量等の共通フォーマット関数。comparison_screen.dart と quote_revision_screen.dart
/// で重複していた _formatYen / _yen を一元化するためのユーティリティ。
library;

import 'package:intl/intl.dart';

String formatYen(int? value) =>
    value == null ? '未入力' : '${NumberFormat('#,##0', 'ja_JP').format(value)}円';

String formatQuantity(double? quantity, String? unit) {
  if (quantity == null) return '数量未入力';
  final text = quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toString();
  return unit == null || unit.isEmpty ? text : '$text$unit';
}

String formatDate(int epoch) => DateFormat(
      'yyyy/MM/dd HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(epoch));