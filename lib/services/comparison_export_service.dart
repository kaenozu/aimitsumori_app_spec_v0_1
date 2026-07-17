/// ファイルパス: lib/services/comparison_export_service.dart
/// 比較レポートをテキスト・CSV・PDFへ変換する
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models.dart';
import 'value_normalizer.dart';

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
  /// 外部入力が数式として評価されないよう、危険な先頭文字を無害化する。
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

  /// 比較画面のキャプチャ画像をA4比率で分割し、標準A4の複数ページPDFへ変換する。
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

    final pageImages = await _splitPngIntoA4Pages(pngBytes);
    final document = pw.Document();
    for (final pageBytes in pageImages) {
      final image = pw.MemoryImage(pageBytes);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    return document.save();
  }

  static Future<List<Uint8List>> _splitPngIntoA4Pages(
    Uint8List pngBytes,
  ) async {
    final codec = await ui.instantiateImageCodec(pngBytes);
    try {
      final frame = await codec.getNextFrame();
      final source = frame.image;
      try {
        final a4AspectRatio = PdfPageFormat.a4.height / PdfPageFormat.a4.width;
        final sliceHeight = (source.width * a4AspectRatio)
            .floor()
            .clamp(1, source.height)
            .toInt();
        final pages = <Uint8List>[];
        for (var top = 0; top < source.height; top += sliceHeight) {
          final currentHeight = (source.height - top)
              .clamp(1, sliceHeight)
              .toInt();
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          canvas.drawImageRect(
            source,
            ui.Rect.fromLTWH(
              0,
              top.toDouble(),
              source.width.toDouble(),
              currentHeight.toDouble(),
            ),
            ui.Rect.fromLTWH(
              0,
              0,
              source.width.toDouble(),
              currentHeight.toDouble(),
            ),
            ui.Paint(),
          );
          final picture = recorder.endRecording();
          final pageImage = await picture.toImage(source.width, currentHeight);
          try {
            final data = await pageImage.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (data == null) {
              throw StateError('PDFページ用の画像を生成できませんでした。');
            }
            pages.add(data.buffer.asUint8List());
          } finally {
            pageImage.dispose();
            picture.dispose();
          }
        }
        return pages;
      } finally {
        source.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  static String fileStem(String projectName) {
    final sanitized = projectName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final value = sanitized.isEmpty ? 'aimitsumori' : sanitized;
    return value.length <= 80 ? value : value.substring(0, 80);
  }

  static String _encodeCsvRow(List<Object?> values) =>
      values.map(_encodeCsvCell).join(',');

  static String _encodeCsvCell(Object? value) {
    final raw = value?.toString() ?? '';
    final text = CsvCellSanitizer.protect(raw);
    if (!text.contains(RegExp(r'[,"\r\n]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }

  static String _formatYen(int? value) =>
      value == null ? '未入力' : '${_yenFormat.format(value)}円';

  static String _formatQuantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
