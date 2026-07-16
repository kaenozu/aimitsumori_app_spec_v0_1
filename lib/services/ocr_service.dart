/// ファイルパス: lib/services/ocr_service.dart
/// PDFまたは画像から見積書テキスト、位置情報、信頼度を抽出するサービス
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';

import '../models.dart';
import '../ocr_models.dart';
import 'ocr_confidence_engine.dart';

class OcrService {
  OcrService({
    TextRecognizer? recognizer,
    this.confidenceEngine = const OcrConfidenceEngine(),
  }) : _recognizer =
           recognizer ?? TextRecognizer(script: TextRecognitionScript.japanese);

  final TextRecognizer _recognizer;
  final OcrConfidenceEngine confidenceEngine;
  final List<String> _temporaryReviewImagePaths = [];

  OcrReviewBundle? lastReviewBundle;
  String? lastSourceFileHash;

  Future<RawQuoteData> extractQuote(String filePath) async {
    await _clearTemporaryReviewImages();
    lastReviewBundle = null;
    lastSourceFileHash = null;

    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw const OcrException('選択したファイルが見つかりません。もう一度選択してください。');
    }
    final sourceBytes = await sourceFile.readAsBytes();
    if (sourceBytes.isEmpty) {
      throw const OcrException('選択したファイルが空です。別のファイルを選択してください。');
    }
    lastSourceFileHash = sha256.convert(sourceBytes).toString();

    final extension = p.extension(filePath).toLowerCase();
    final document = extension == '.pdf'
        ? await _recognizePdf(filePath)
        : await _recognizeImage(filePath, pageNumber: 1);

    if (document.text.trim().isEmpty) {
      throw const OcrException('文字を認識できませんでした。画像の明るさや解像度を確認してください。');
    }

    return _parse(document: document, sourcePath: filePath);
  }

  Future<_RecognizedDocument> _recognizeImage(
    String filePath, {
    required int pageNumber,
  }) async {
    final image = InputImage.fromFilePath(filePath);
    final result = await _recognizer.processImage(image);
    final interpretations = <OcrLineInterpretation>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final rect = line.boundingBox;
        interpretations.add(
          confidenceEngine.analyze(
            rawText: line.text,
            pageNumber: pageNumber,
            boundingRect: OcrBoundingRect(
              left: rect.left,
              top: rect.top,
              right: rect.right,
              bottom: rect.bottom,
            ),
            sourceImagePath: filePath,
            nativeOcrConfidence: line.confidence,
          ),
        );
      }
    }
    return _RecognizedDocument(text: result.text, lines: interpretations);
  }

  Future<_RecognizedDocument> _recognizePdf(String filePath) async {
    final renderer = PdfImageRenderer(path: filePath);
    final temporaryDirectory = await getTemporaryDirectory();
    final textBuffer = StringBuffer();
    final lines = <OcrLineInterpretation>[];

    await renderer.open();
    try {
      final pageCount = await renderer.getPageCount();
      if (pageCount <= 0) {
        throw const OcrException('PDFに読み取れるページがありません。');
      }
      if (pageCount > 100) {
        throw const OcrException('PDFのページ数が多すぎます。100ページ以下に分割してください。');
      }
      for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        await renderer.openPage(pageIndex: pageIndex);
        try {
          final size = await renderer.getPageSize(pageIndex: pageIndex);
          final scale = _renderScale(size.width, size.height);
          final bytes = await renderer.renderPage(
            pageIndex: pageIndex,
            x: 0,
            y: 0,
            width: size.width,
            height: size.height,
            scale: scale,
          );
          if (bytes == null || bytes.isEmpty) continue;

          final renderedFile = File(
            p.join(
              temporaryDirectory.path,
              'aimitsumori-review-'
              '${DateTime.now().microsecondsSinceEpoch}-$pageIndex.png',
            ),
          );
          await renderedFile.writeAsBytes(bytes, flush: true);
          _temporaryReviewImagePaths.add(renderedFile.path);

          final page = await _recognizeImage(
            renderedFile.path,
            pageNumber: pageIndex + 1,
          );
          if (page.text.trim().isNotEmpty) {
            if (textBuffer.isNotEmpty) textBuffer.writeln();
            textBuffer.writeln(page.text.trim());
          }
          lines.addAll(page.lines);
        } finally {
          await renderer.closePage(pageIndex: pageIndex);
        }
      }
    } finally {
      await renderer.close();
    }

    return _RecognizedDocument(
      text: textBuffer.toString().trim(),
      lines: lines,
    );
  }

  double _renderScale(double width, double height) {
    const targetScale = 2.0;
    const maxDimension = 6000.0;
    final longest = width > height ? width : height;
    if (longest <= 0) return 1;
    return (maxDimension / longest).clamp(1.0, targetScale).toDouble();
  }

  RawQuoteData _parse({
    required _RecognizedDocument document,
    required String sourcePath,
  }) {
    final textLines = document.text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final contractorName = _parseContractorName(textLines);
    final totalAmount = _parseTotalAmount(textLines);
    final items = <RawQuoteLineItem>[];

    for (final interpretation in document.lines) {
      final categoryId = interpretation.categoryId;
      if (categoryId == null) continue;
      final line = interpretation.recognizedLine;
      items.add(
        RawQuoteLineItem(
          rawLabel: line.rawText,
          categoryId: categoryId,
          amountYen: interpretation.amountYen,
          inclusionStatus: interpretation.inclusionStatus,
          quantity: interpretation.quantity,
          unit: interpretation.unit,
          specification: interpretation.specification,
          note: line.needsReview ? 'OCR信頼度を確認してください' : null,
        ),
      );
    }

    final aggregateIssues = OcrConfidenceEngine.buildAggregateIssues(
      totalAmountYen: totalAmount,
      includedItemAmounts: items
          .where((item) => item.inclusionStatus == InclusionStatus.included)
          .map((item) => item.amountYen)
          .whereType<int>(),
    );
    lastReviewBundle = OcrReviewBundle(
      lines: document.lines
          .map((interpretation) => interpretation.recognizedLine)
          .toList(growable: false),
      issues: aggregateIssues,
    );

    return RawQuoteData(
      contractorName: contractorName,
      totalAmountYen: totalAmount,
      lineItems: items,
      extractedText: document.text.trim(),
      sourcePath: sourcePath,
      createdAtEpochMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String _parseContractorName(List<String> lines) {
    final companyPattern = RegExp(r'(株式会社|有限会社|合同会社|工務店|建設|建築|外構|エクステリア|造園)');
    final excluded = RegExp(r'(御?見積|見積書|請求|合計|工事名|お客様|様$)');

    for (final line in lines.take(15)) {
      if (companyPattern.hasMatch(line) &&
          !excluded.hasMatch(line) &&
          line.length <= 50) {
        return line;
      }
    }

    return lines.firstWhere(
      (line) => !excluded.hasMatch(line) && line.length <= 50,
      orElse: () => '業者名未確認',
    );
  }

  int? _parseTotalAmount(List<String> lines) {
    const totalKeywords = [
      '御見積金額',
      '見積金額',
      'お見積金額',
      '総合計',
      '税込合計',
      '合計金額',
      '総額',
    ];
    for (final keyword in totalKeywords) {
      for (final line in lines) {
        if (line.contains(keyword)) {
          final amounts = OcrConfidenceEngine.extractAmountCandidates(line);
          if (amounts.isNotEmpty) return amounts.last;
        }
      }
    }

    for (final line in lines) {
      if (RegExp(r'(^|\s)合計($|\s|[:：])').hasMatch(line)) {
        final amounts = OcrConfidenceEngine.extractAmountCandidates(line);
        if (amounts.isNotEmpty) return amounts.last;
      }
    }
    return null;
  }

  Future<void> _clearTemporaryReviewImages() async {
    final paths = List<String>.from(_temporaryReviewImagePaths);
    _temporaryReviewImagePaths.clear();
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // 一時ファイル削除失敗は次回OSクリーンアップへ委ねる。
      }
    }
  }

  Future<void> dispose() async {
    await _recognizer.close();
    await _clearTemporaryReviewImages();
  }
}

class _RecognizedDocument {
  const _RecognizedDocument({required this.text, required this.lines});

  final String text;
  final List<OcrLineInterpretation> lines;
}

class OcrException implements Exception {
  const OcrException(this.message);

  final String message;

  @override
  String toString() => message;
}
