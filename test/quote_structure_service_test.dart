import 'package:aimitsumori_app/ocr_models.dart';
import 'package:aimitsumori_app/quote_structure.dart';
import 'package:aimitsumori_app/services/ocr_confidence_engine.dart';
import 'package:aimitsumori_app/services/quote_structure_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = QuoteStructureService();
  const rect = OcrBoundingRect(left: 0, top: 0, right: 200, bottom: 20);

  OcrRecognizedLine line(String text) => const OcrConfidenceEngine()
      .analyze(
        rawText: text,
        pageNumber: 1,
        boundingRect: rect,
        sourceImagePath: 'fixture://estimate-page-1',
      )
      .recognizedLine;

  test('keeps a priced category line as a line item', () {
    final result = service.classifyLine(line('土間コンクリート 36.3㎡ 6,750円 245,025円'));

    expect(result.type, QuoteRowType.lineItem);
    expect(result.categoryId, 'concrete');
  });

  test('recognizes representative estimate detail names', () {
    final texts = [
      '残土処分 場外処分 13㎥ 8,125円 105,625円',
      '化粧ブロック施工 13.1m 800円 10,480円',
      'サイクルポート本体 1式 132,496円',
      '重機損料 9日 500円 4,500円',
    ];

    final rows = [for (final text in texts) service.classifyLine(line(text))];
    expect(rows.map((row) => row.type), everyElement(QuoteRowType.lineItem));
  });

  test('does not present subtotals and tax as line items', () {
    expect(
      service.classifyLine(line('土間コンクリート計 245,025円')).type,
      QuoteRowType.subtotal,
    );
    expect(
      service.classifyLine(line('消費税 10% 196,604円')).type,
      QuoteRowType.tax,
    );
    expect(
      service.classifyLine(line('合計 税込 2,162,644円')).type,
      QuoteRowType.grandTotal,
    );
  });

  test('separates a price whose item cannot be identified', () {
    final result = service.classifyLine(line('定価 50,000円'));

    expect(result.type, QuoteRowType.unresolved);
    expect(result.requiresReview, isTrue);
    expect(result.reason, contains('明細'));
  });

  test(
    'does not require confirmation for a low-confidence but structured item',
    () {
      final recognized = const OcrConfidenceEngine()
          .analyze(
            rawText: 'フェンス 10m 20,000円 200,000円',
            pageNumber: 1,
            boundingRect: rect,
            sourceImagePath: 'fixture://estimate-page-1',
            nativeOcrConfidence: 0.6,
          )
          .recognizedLine;

      final row = service.classifyLine(recognized);
      expect(row.type, QuoteRowType.lineItem);
      expect(recognized.needsReview, isTrue);
      expect(recognized.severity, OcrReviewSeverity.warning);
    },
  );

  test('keeps a recognizable item when its amount is unavailable', () {
    const recognized = OcrRecognizedLine(
      pageNumber: 1,
      boundingRect: rect,
      confidence: 0.9,
      rawText: 'ブロック7段C120',
      sourceImagePath: 'fixture://estimate-page-1',
      categoryConfidence: 0.94,
      amountConfidence: 0,
      categoryCandidates: ['fence'],
    );

    expect(service.classifyLine(recognized).type, QuoteRowType.lineItem);
  });
}
