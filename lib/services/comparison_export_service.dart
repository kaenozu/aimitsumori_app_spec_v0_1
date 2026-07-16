/// ファイルパス: lib/services/comparison_export_service.dart
/// 比較レポートを共有用のプレーンテキストへ変換する
library;

import 'package:intl/intl.dart';

import '../models.dart';

class ComparisonExportService {
  ComparisonExportService._();

  static final NumberFormat _yenFormat = NumberFormat('#,##0', 'ja_JP');

  static String toText(ComparisonReport report) {
    final buffer = StringBuffer()
      ..writeln('【${report.projectName}】相見積もり比較')
      ..writeln()
      ..writeln('■ サマリー');

    for (var index = 0; index < report.summaryLines.length; index++) {
      buffer.writeln('${index + 1}. ${report.summaryLines[index]}');
    }

    buffer
      ..writeln()
      ..writeln('■ 見積概要');
    if (report.quoteSnapshots.isEmpty) {
      buffer.writeln('見積は未登録です。');
    } else {
      for (final snapshot in report.quoteSnapshots) {
        buffer
          ..writeln('${snapshot.contractorName}: ${_formatYen(snapshot.totalAmountYen)}')
          ..writeln('  見積内: ${snapshot.includedCategoryCount}カテゴリ')
          ..writeln(
            '  別途: ${snapshot.separateCategoryNames.isEmpty ? "なし" : snapshot.separateCategoryNames.join("、")}',
          )
          ..writeln(
            '  不明: ${snapshot.unknownCategoryNames.isEmpty ? "なし" : snapshot.unknownCategoryNames.join("、")}',
          );
      }
    }

    buffer
      ..writeln()
      ..writeln('■ カテゴリ別');
    for (final comparison in report.categoryComparisons) {
      buffer.writeln('【${comparison.category.nameJa}】');
      for (final cell in comparison.cells) {
        final quantity = cell.quantity == null
            ? '未入力'
            : '${_formatQuantity(cell.quantity!)}${cell.unit ?? ''}';
        buffer.writeln(
          '- ${cell.contractorName}: ${cell.inclusionStatus.labelJa} / '
          '金額 ${_formatYen(cell.amountYen)} / 数量 $quantity / '
          '仕様 ${cell.specification ?? "未入力"}',
        );
      }
    }

    if (report.clarificationQuestions.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('■ 確認質問');
      for (final question in report.clarificationQuestions) {
        buffer.writeln('- ${question.questionText}');
      }
    }

    return buffer.toString().trimRight();
  }

  static String _formatYen(int? value) =>
      value == null ? '未入力' : '${_yenFormat.format(value)}円';

  static String _formatQuantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
