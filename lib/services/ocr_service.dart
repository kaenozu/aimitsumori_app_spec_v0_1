/// ファイルパス: lib/services/ocr_service.dart
/// PDFまたは画像から見積書テキスト、位置情報、信頼度を抽出するサービス。
library;

import '../utils/app_logger.dart';

import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';

import '../models.dart';
import '../ocr_models.dart';
import '../quote_structure.dart';
import 'ocr_confidence_engine.dart';
import 'quote_structure_service.dart';

class OcrService {
  static const _maxInputBytes = 30 * 1024 * 1024;
  static const _maxPdfPages = 50;
  static const _supportedImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
  };

  static bool get isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  OcrService({
    TextRecognizer? recognizer,
    this.confidenceEngine = const OcrConfidenceEngine(),
  }) : _recognizer =
           recognizer ?? TextRecognizer(script: TextRecognitionScript.japanese);

  @visibleForTesting
  static RawQuoteData parseTextForTesting(String text) {
    final lines = _normalizedTextLines(text);
    return RawQuoteData(
      contractorName: _parseContractorName(lines),
      totalAmountYen: _parseTotalAmount(lines),
      extractedText: text.trim(),
      sourcePath: 'test://ocr-text',
      createdAtEpochMillis: 0,
    );
  }

  @visibleForTesting
  static double pdfRenderScaleForPageCount(int pageCount) {
    if (pageCount <= 0) {
      throw RangeError.range(pageCount, 1, _maxPdfPages, 'pageCount');
    }
    if (pageCount <= 5) return 2.0;
    // Multi-page estimates are commonly A4 documents. Keeping the render
    // size moderate prevents ML Kit from stalling on later pages on devices
    // with limited memory while preserving enough resolution for Japanese text.
    if (pageCount <= 15) return 1.25;
    if (pageCount <= 30) return 1.25;
    return 1.0;
  }

  final TextRecognizer _recognizer;
  final OcrConfidenceEngine confidenceEngine;
  final QuoteStructureService structureService = const QuoteStructureService();
  final List<String> _temporaryReviewImagePaths = [];

  OcrReviewBundle? lastReviewBundle;
  String? lastSourceFileHash;

  Future<RawQuoteData> extractQuote(String filePath) async {
    if (!isSupportedPlatform) {
      throw const OcrException('OCR取込はAndroid・iOSで利用できます。');
    }

    await _clearTemporaryReviewImages();
    lastReviewBundle = null;
    lastSourceFileHash = null;

    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw const OcrException('選択したファイルが見つかりません。もう一度選択してください。');
    }
    final inputBytes = await sourceFile.length();
    if (inputBytes <= 0) {
      throw const OcrException('空のファイルは読み取れません。');
    }
    if (inputBytes > _maxInputBytes) {
      throw const OcrException('ファイルが大きすぎます。30MB以下のPDFまたは画像を選択してください。');
    }

    final extension = p.extension(filePath).toLowerCase();
    if (extension != '.pdf' && !_supportedImageExtensions.contains(extension)) {
      throw const OcrException('対応しているPDFまたは画像ファイルを選択してください。');
    }

    final sourceBytes = await sourceFile.readAsBytes();
    lastSourceFileHash = sha256.convert(sourceBytes).toString();

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
    return _RecognizedDocument(
      text: result.text,
      lines: _mergeSameRowLines(interpretations),
    );
  }

  List<OcrLineInterpretation> _mergeSameRowLines(
    List<OcrLineInterpretation> input,
  ) {
    if (input.length < 2) return input;
    final sorted = [...input]
      ..sort((a, b) => a.recognizedLine.boundingRect.top.compareTo(
            b.recognizedLine.boundingRect.top,
          ));
    final groups = <List<OcrLineInterpretation>>[];
    for (final interpretation in sorted) {
      final rect = interpretation.recognizedLine.boundingRect;
      final group = groups.isEmpty ? null : groups.last;
      if (group == null) {
        groups.add([interpretation]);
        continue;
      }
      final previousRect = group.last.recognizedLine.boundingRect;
      final verticalOverlap =
          (math.min(rect.bottom, previousRect.bottom) -
                  math.max(rect.top, previousRect.top)) /
              math.max(rect.height, previousRect.height);
      if (verticalOverlap >= 0.45) {
        group.add(interpretation);
      } else {
        groups.add([interpretation]);
      }
    }

    return [
      for (final group in groups)
        if (group.length == 1)
          group.single
        else
          _reanalyzeMergedRow(group),
    ];
  }

  OcrLineInterpretation _reanalyzeMergedRow(
    List<OcrLineInterpretation> group,
  ) {
    final ordered = [...group]
      ..sort((a, b) => a.recognizedLine.boundingRect.left.compareTo(
            b.recognizedLine.boundingRect.left,
          ));
    final first = ordered.first.recognizedLine;
    final rects = ordered.map((item) => item.recognizedLine.boundingRect);
    final mergedRect = OcrBoundingRect(
      left: rects.map((rect) => rect.left).reduce(math.min),
      top: rects.map((rect) => rect.top).reduce(math.min),
      right: rects.map((rect) => rect.right).reduce(math.max),
      bottom: rects.map((rect) => rect.bottom).reduce(math.max),
    );
    final rawText = ordered
        .map((item) => item.recognizedLine.rawText)
        .join(' ');
    return confidenceEngine.analyze(
      rawText: rawText,
      pageNumber: first.pageNumber,
      boundingRect: mergedRect,
      sourceImagePath: first.sourceImagePath,
      nativeOcrConfidence: ordered
          .map((item) => item.recognizedLine.confidence)
          .reduce((a, b) => (a + b) / 2),
    );
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
        throw const OcrException('PDFに読み取り可能なページがありません。');
      }
      if (pageCount > _maxPdfPages) {
        throw const OcrException('PDFのページ数が多すぎます。50ページ以下のPDFを選択してください。');
      }
      final renderScale = pdfRenderScaleForPageCount(pageCount);
      for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        await renderer.openPage(pageIndex: pageIndex);
        try {
          final size = await renderer.getPageSize(pageIndex: pageIndex);
          final bytes = await renderer.renderPage(
            pageIndex: pageIndex,
            x: 0,
            y: 0,
            width: size.width,
            height: size.height,
            scale: renderScale,
          ).timeout(const Duration(seconds: 30));
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
          ).timeout(const Duration(seconds: 45));
          if (page.text.trim().isNotEmpty) {
            if (textBuffer.isNotEmpty) textBuffer.writeln();
            textBuffer.writeln(page.text.trim());
          }
          lines.addAll(page.lines);
        } catch (error, stackTrace) {
          // A single damaged or unusually large page must not leave the
          // whole import stuck indefinitely. Keep the successful pages and
          // let the review screen show the resulting partial extraction.
          AppLogger.debug('OCR page ${pageIndex + 1} skipped: $error\n$stackTrace');
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

  RawQuoteData _parse({
    required _RecognizedDocument document,
    required String sourcePath,
  }) {
    final textLines = _normalizedTextLines(document.text);
    final contractorName = _parseContractorName(textLines);
    final totalAmount = _parseTotalAmount(textLines);
    final items = <RawQuoteLineItem>[];

    final structuredRows = structureService.classify(
      document.lines.map((interpretation) => interpretation.recognizedLine),
    );
    final lineRows = structuredRows.where(
      (row) => row.type == QuoteRowType.lineItem,
    );

    for (final row in lineRows) {
      final interpretation = document.lines.firstWhere(
        (value) => value.recognizedLine.id == row.line.id,
      );
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
    // Unresolved amount-only fragments (addresses, page fragments, and
    // isolated numbers) remain in `extractedText` as evidence, but are not
    // actionable quote lines. Showing every one of them created the former
    // 200+ confirmation queue. Only a structurally identified line item
    // with a critical confidence issue requires user review.
    final reviewRows = structuredRows.where(
      (row) =>
          row.type == QuoteRowType.lineItem &&
          row.line.severity == OcrReviewSeverity.critical,
    );
    lastReviewBundle = OcrReviewBundle(
      lines: reviewRows.map((row) => row.line).toList(growable: false),
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

  static List<String> _normalizedTextLines(String text) => text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .toList();

  static String _parseContractorName(List<String> lines) {
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

  static int? _parseTotalAmount(List<String> lines) {
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
        if (!line.contains(keyword)) continue;
        final amounts = OcrConfidenceEngine.extractAmountCandidates(line);
        if (amounts.isNotEmpty) return amounts.last;
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
      } catch (error) {
        AppLogger.debug('Temporary OCR image cleanup failed: $error');
      }
    }
  }

  Future<void> dispose() async {
    if (isSupportedPlatform) {
      try {
        await _recognizer.close();
      } catch (error) {
        AppLogger.debug('OCR recognizer close failed: $error');
      }
    }
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
