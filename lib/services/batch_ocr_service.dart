library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';
import '../ocr_models.dart';
import 'ocr_confidence_engine.dart';
import 'ocr_service.dart';

class BatchOcrResult {
  const BatchOcrResult({
    required this.quote,
    required this.reviewBundle,
    required this.documentKey,
  });

  final RawQuoteData quote;
  final OcrReviewBundle reviewBundle;

  /// OCR確認状態・改訂履歴で使うファイル内容ベースの安定キー（SHA-256）。
  final String documentKey;
}

class BatchOcrService {
  BatchOcrService({OcrService? ocrService})
    : ocrService = ocrService ?? OcrService();

  final OcrService ocrService;

  Future<BatchOcrResult> extractPages(List<String> paths) async {
    if (paths.isEmpty) throw const OcrException('撮影ページがありません。');

    final results = <RawQuoteData>[];
    final reviewLines = <OcrRecognizedLine>[];
    final pageFileHashes = <String>[];
    for (var index = 0; index < paths.length; index++) {
      final result = await ocrService.extractQuote(paths[index]);
      results.add(result);
      final pageHash = ocrService.lastSourceFileHash;
      if (pageHash != null) pageFileHashes.add(pageHash);
      final bundle = ocrService.lastReviewBundle;
      if (bundle != null) {
        reviewLines.addAll(
          bundle.lines.map((line) => _withPageNumber(line, index + 1)),
        );
      }
    }

    final contractor = results
        .map((result) => result.contractorName)
        .firstWhere(
          (name) => name != '業者名未確認',
          orElse: () => results.first.contractorName,
        );
    int? total;
    for (final result in results.reversed) {
      if (result.totalAmountYen != null) {
        total = result.totalAmountYen;
        break;
      }
    }

    // 同じ名称・金額の明細が複数ページに存在することは正当なので、
    // OCR結果を値だけで重複排除しない。
    final items = <RawQuoteLineItem>[
      for (final result in results) ...result.lineItems,
    ];

    final quote = RawQuoteData(
      contractorName: contractor,
      totalAmountYen: total,
      lineItems: items,
      extractedText: results
          .map((result) => result.extractedText)
          .join('\n\n--- page ---\n\n'),
      sourcePath: paths.join('|'),
      createdAtEpochMillis: DateTime.now().millisecondsSinceEpoch,
    );
    final issues = OcrConfidenceEngine.buildAggregateIssues(
      totalAmountYen: total,
      includedItemAmounts: items
          .where((item) => item.inclusionStatus == InclusionStatus.included)
          .map((item) => item.amountYen)
          .whereType<int>(),
    );

    return BatchOcrResult(
      quote: quote,
      reviewBundle: OcrReviewBundle(lines: reviewLines, issues: issues),
      documentKey: buildDocumentKey(
        pageFileHashes: pageFileHashes,
        extractedText: quote.extractedText,
      ),
    );
  }

  /// 撮影ファイルのパスに依存しない安定キーを作る。
  /// ページファイルはセッション終了後に削除されるため、
  /// パス結合キーだとOCR確認状態が二度とヒットしない。
  @visibleForTesting
  static String buildDocumentKey({
    required List<String> pageFileHashes,
    required String extractedText,
  }) {
    if (pageFileHashes.isEmpty) {
      return sha256.convert(utf8.encode(extractedText)).toString();
    }
    return sha256.convert(utf8.encode(pageFileHashes.join('|'))).toString();
  }

  OcrRecognizedLine _withPageNumber(OcrRecognizedLine line, int pageNumber) {
    return OcrRecognizedLine(
      pageNumber: pageNumber,
      boundingRect: line.boundingRect,
      confidence: line.confidence,
      rawText: line.rawText,
      sourceImagePath: line.sourceImagePath,
      categoryConfidence: line.categoryConfidence,
      amountConfidence: line.amountConfidence,
      categoryCandidates: line.categoryCandidates,
      amountCandidates: line.amountCandidates,
      reviewReasons: line.reviewReasons,
      initialStatus: line.initialStatus,
    );
  }

  Future<void> dispose() => ocrService.dispose();
}
