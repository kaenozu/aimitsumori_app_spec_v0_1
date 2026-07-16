library;

import '../models.dart';
import '../ocr_models.dart';
import 'ocr_confidence_engine.dart';
import 'ocr_service.dart';

class BatchOcrResult {
  const BatchOcrResult({
    required this.quote,
    required this.reviewBundle,
  });

  final RawQuoteData quote;
  final OcrReviewBundle reviewBundle;
}

class BatchOcrService {
  BatchOcrService({OcrService? ocrService})
      : ocrService = ocrService ?? OcrService();

  final OcrService ocrService;

  Future<BatchOcrResult> extractPages(List<String> paths) async {
    if (paths.isEmpty) throw const OcrException('撮影ページがありません。');

    final results = <RawQuoteData>[];
    final reviewLines = <OcrRecognizedLine>[];
    for (var index = 0; index < paths.length; index++) {
      final result = await ocrService.extractQuote(paths[index]);
      results.add(result);
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

    final seen = <String>{};
    final items = <RawQuoteLineItem>[];
    for (final result in results) {
      for (final item in result.lineItems) {
        final key = [
          item.categoryId,
          item.rawLabel,
          item.amountYen,
          item.quantity,
          item.unit,
        ].join('|');
        if (seen.add(key)) items.add(item);
      }
    }

    final quote = RawQuoteData(
      contractorName: contractor,
      totalAmountYen: total,
      lineItems: items,
      extractedText:
          results.map((result) => result.extractedText).join('\n\n--- page ---\n\n'),
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
      reviewBundle: OcrReviewBundle(
        lines: reviewLines,
        issues: issues,
      ),
    );
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
