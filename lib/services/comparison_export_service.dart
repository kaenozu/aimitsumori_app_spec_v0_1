/// ファイルパス: lib/services/comparison_export_service.dart
/// 比較レポートをテキスト・CSV・PDFへ変換する
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models.dart';

class ComparisonExportService {
  ComparisonExportService._();

  static final NumberFormat _yenFormat = NumberFormat('#,##0', 'ja_JP');
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

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
          ..writeln(
            '${snapshot.contractorName}: ${_formatYen(snapshot.totalAmountYen)}',
          )
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

  /// ExcelやNumbersで文字化けしにくいUTF-8 BOM付きCSVを生成する。
  static String toCsv(Project project) {
    final rows = <List<Object?>>[
      ['案件名', project.name],
      ['案件ID', project.id],
      ['ステータス', project.status.labelJa],
      [
        '作成日時',
        _dateFormat.format(
          DateTime.fromMillisecondsSinceEpoch(project.createdAtEpochMillis),
        ),
      ],
      [
        '更新日時',
        _dateFormat.format(
          DateTime.fromMillisecondsSinceEpoch(project.updatedAtEpochMillis),
        ),
      ],
      const [],
      const [
        '業者名',
        '提示総額(円)',
        'カテゴリID',
        '項目名',
        '区分',
        '金額(円)',
        '数量',
        '単位',
        '仕様',
        '備考',
      ],
    ];

    for (final quote in project.quotes) {
      if (quote.lineItems.isEmpty) {
        rows.add([
          quote.contractorName,
          quote.totalAmountYen,
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          quote.note,
        ]);
        continue;
      }

      for (final item in quote.lineItems) {
        rows.add([
          quote.contractorName,
          quote.totalAmountYen,
          item.categoryId,
          item.rawLabel,
          item.inclusionStatus.labelJa,
          item.amountYen,
          item.quantity,
          item.unit,
          item.specification,
          item.note,
        ]);
      }
    }

    return '\uFEFF${rows.map(_encodeCsvRow).join('\r\n')}\r\n';
  }

  static Uint8List toCsvBytes(Project project) =>
      Uint8List.fromList(utf8.encode(toCsv(project)));

  /// 比較画面のキャプチャ画像を、その縦横比を保った1ページPDFへ変換する。
  /// 日本語フォントを外部取得せず、画面上の表示をそのままPDF化できる。
  static Future<Uint8List> toPdfFromImage(
    Uint8List pngBytes, {
    required double imageWidth,
    required double imageHeight,
  }) async {
    if (pngBytes.isEmpty) {
      throw ArgumentError.value(pngBytes, 'pngBytes', '画像が空です。');
    }
    if (imageWidth <= 0 || imageHeight <= 0) {
      throw ArgumentError('画像サイズは0より大きい必要があります。');
    }

    final pageWidth = PdfPageFormat.a4.width;
    final scaledHeight = pageWidth * imageHeight / imageWidth;
    final pageHeight = scaledHeight
        .clamp(PdfPageFormat.a4.height, 14400.0)
        .toDouble();
    final document = pw.Document();
    final image = pw.MemoryImage(pngBytes);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight, marginAll: 0),
        build: (_) => pw.Image(
          image,
          width: pageWidth,
          height: pageHeight,
          fit: pw.BoxFit.contain,
        ),
      ),
    );

    return document.save();
  }

  static String fileStem(String projectName) {
    final sanitized = projectName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return sanitized.isEmpty ? 'aimitsumori' : sanitized;
  }

  static String _encodeCsvRow(List<Object?> values) =>
      values.map(_encodeCsvCell).join(',');

  static String _encodeCsvCell(Object? value) {
    final text = value?.toString() ?? '';
    if (!text.contains(RegExp(r'[,"\r\n]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }

  static String _formatYen(int? value) =>
      value == null ? '未入力' : '${_yenFormat.format(value)}円';

  static String _formatQuantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();
}
