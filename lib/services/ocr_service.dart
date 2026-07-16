/// ファイルパス: lib/services/ocr_service.dart
/// PDFまたは画像から見積書テキストと構造化データを抽出するサービス
library;

import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';

import '../models.dart';

class OcrService {
  OcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.japanese);

  final TextRecognizer _recognizer;

  static const Map<String, List<String>> _categoryKeywords = {
    'concrete': ['土間コンクリート', 'コンクリート', '生コン', '刷毛引き', '金鏝'],
    'gravel_paving': ['砂利', '砕石', '舗装', '防草シート', 'アスファルト'],
    'carport': ['カーポート', 'サイクルポート', '駐輪場'],
    'fence': ['フェンス', '目隠し', 'メッシュフェンス'],
    'gate': ['門柱', '門扉', '機能門柱', 'ポスト', '表札'],
    'approach': ['アプローチ', 'インターロッキング', '平板', 'タイル'],
    'earthwork': ['造成', '掘削', '根切', '盛土', '整地'],
    'soil_disposal': ['残土', '発生土', '土処分'],
    'drainage': ['排水', '雨水', '桝', '側溝', '水勾配'],
    'lighting': ['照明', '電気', 'ライト', '配線', 'コンセント'],
    'planting': ['植栽', '芝', '樹木', '庭木'],
    'demolition': ['解体', '撤去', '処分'],
    'protection': ['養生'],
    'machinery_transport': ['重機回送', '重機運搬', '回送費'],
    'overhead': ['諸経費', '現場管理費', '一般管理費'],
    'application': ['申請', '届出', '許可'],
    'discount': ['値引', '割引', '出精値引'],
    'tax': ['消費税', '税額'],
  };

  Future<RawQuoteData> extractQuote(String filePath) async {
    final extension = p.extension(filePath).toLowerCase();
    final text = extension == '.pdf'
        ? await _recognizePdf(filePath)
        : await _recognizeImage(filePath);

    if (text.trim().isEmpty) {
      throw const OcrException('文字を認識できませんでした。画像の明るさや解像度を確認してください。');
    }

    return _parse(text: text, sourcePath: filePath);
  }

  Future<String> _recognizeImage(String filePath) async {
    final image = InputImage.fromFilePath(filePath);
    final result = await _recognizer.processImage(image);
    return result.text;
  }

  Future<String> _recognizePdf(String filePath) async {
    final renderer = PdfImageRenderer(path: filePath);
    final temporaryDirectory = await getTemporaryDirectory();
    final buffer = StringBuffer();

    await renderer.open();
    try {
      final pageCount = await renderer.getPageCount();
      for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        await renderer.openPage(pageIndex: pageIndex);
        File? renderedFile;
        try {
          final size = await renderer.getPageSize(pageIndex: pageIndex);
          final bytes = await renderer.renderPage(
            pageIndex: pageIndex,
            x: 0,
            y: 0,
            width: size.width,
            height: size.height,
            scale: 2,
          );
          if (bytes == null || bytes.isEmpty) continue;

          renderedFile = File(
            p.join(
              temporaryDirectory.path,
              'aimitsumori-ocr-${DateTime.now().microsecondsSinceEpoch}-$pageIndex.png',
            ),
          );
          await renderedFile.writeAsBytes(bytes, flush: true);
          final pageText = await _recognizeImage(renderedFile.path);
          if (pageText.trim().isNotEmpty) {
            if (buffer.isNotEmpty) buffer.writeln();
            buffer.writeln(pageText.trim());
          }
        } finally {
          if (renderedFile != null && await renderedFile.exists()) {
            await renderedFile.delete();
          }
          await renderer.closePage(pageIndex: pageIndex);
        }
      }
    } finally {
      await renderer.close();
    }

    return buffer.toString().trim();
  }

  RawQuoteData _parse({required String text, required String sourcePath}) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final contractorName = _parseContractorName(lines);
    final totalAmount = _parseTotalAmount(lines);
    final items = <RawQuoteLineItem>[];

    for (final line in lines) {
      final categoryId = _findCategoryId(line);
      if (categoryId == null) continue;

      final quantityMatch = RegExp(
        r'(\d+(?:\.\d+)?)\s*(㎡|m2|m²|㎥|m3|m³|m|本|基|台|式|箇所|ヶ所|個)',
        caseSensitive: false,
      ).firstMatch(line);
      final amount = _extractAmount(line);
      final inclusion = _parseInclusionStatus(line, amount);

      items.add(
        RawQuoteLineItem(
          rawLabel: line,
          categoryId: categoryId,
          amountYen: amount,
          inclusionStatus: inclusion,
          quantity: double.tryParse(quantityMatch?.group(1) ?? ''),
          unit: quantityMatch?.group(2),
          specification: _extractSpecification(line),
          note: inclusion == InclusionStatus.unknown ? 'OCR結果を確認してください' : null,
        ),
      );
    }

    return RawQuoteData(
      contractorName: contractorName,
      totalAmountYen: totalAmount,
      lineItems: items,
      extractedText: text.trim(),
      sourcePath: sourcePath,
      createdAtEpochMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String _parseContractorName(List<String> lines) {
    final companyPattern = RegExp(
      r'(株式会社|有限会社|合同会社|工務店|建設|建築|外構|エクステリア|造園)',
    );
    final excluded = RegExp(r'(御?見積|見積書|請求|合計|工事名|お客様|様$)');

    for (final line in lines.take(15)) {
      if (companyPattern.hasMatch(line) && !excluded.hasMatch(line) && line.length <= 50) {
        return line;
      }
    }

    return lines.firstWhere(
      (line) => !excluded.hasMatch(line) && line.length <= 50,
      orElse: () => '業者名未確認',
    );
  }

  int? _parseTotalAmount(List<String> lines) {
    const totalKeywords = ['御見積金額', '見積金額', 'お見積金額', '総合計', '税込合計', '合計金額', '総額'];
    for (final keyword in totalKeywords) {
      for (final line in lines) {
        if (line.contains(keyword)) {
          final amount = _extractAmount(line);
          if (amount != null) return amount;
        }
      }
    }

    for (final line in lines) {
      if (RegExp(r'(^|\s)合計($|\s|[:：])').hasMatch(line)) {
        final amount = _extractAmount(line);
        if (amount != null) return amount;
      }
    }
    return null;
  }

  String? _findCategoryId(String line) {
    for (final entry in _categoryKeywords.entries) {
      if (entry.value.any(line.contains)) return entry.key;
    }
    return null;
  }

  int? _extractAmount(String line) {
    final matches = RegExp(
      r'(?:¥|￥)?\s*(-?\d{1,3}(?:,\d{3})+|-?\d{4,})\s*円?',
    ).allMatches(line).toList();
    if (matches.isEmpty) return null;

    final raw = matches.last.group(1)?.replaceAll(',', '');
    return raw == null ? null : int.tryParse(raw);
  }

  InclusionStatus _parseInclusionStatus(String line, int? amount) {
    if (RegExp(r'(別途|別見積|含まず)').hasMatch(line)) return InclusionStatus.separate;
    if (RegExp(r'(オプション|任意)').hasMatch(line)) return InclusionStatus.optional;
    if (RegExp(r'(対象外|除外|施工なし)').hasMatch(line)) return InclusionStatus.excluded;
    if (RegExp(r'(該当なし|不要)').hasMatch(line)) return InclusionStatus.notApplicable;
    if (amount != null || RegExp(r'(含む|込み|一式)').hasMatch(line)) {
      return InclusionStatus.included;
    }
    return InclusionStatus.unknown;
  }

  String? _extractSpecification(String line) {
    var value = line
        .replaceAll(RegExp(r'(?:¥|￥)?\s*-?\d{1,3}(?:,\d{3})+\s*円?'), '')
        .replaceAll(RegExp(r'(?:¥|￥)?\s*-?\d{4,}\s*円?'), '')
        .trim();
    if (value.length > 120) value = value.substring(0, 120);
    return value.isEmpty ? null : value;
  }

  Future<void> dispose() => _recognizer.close();
}

class OcrException implements Exception {
  const OcrException(this.message);

  final String message;

  @override
  String toString() => message;
}
