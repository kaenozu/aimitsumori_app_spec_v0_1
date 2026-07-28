import 'package:aimitsumori_app/ocr_models.dart';
import 'package:aimitsumori_app/services/ocr_confidence_engine.dart';
import 'package:aimitsumori_app/services/ocr_review_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const engine = OcrConfidenceEngine();
  const rect = OcrBoundingRect(left: 10, top: 20, right: 200, bottom: 50);

  test('single category and amount are high confidence and auto confirmed', () {
    final result = engine.analyze(
      rawText: '土間コンクリート 20㎡ 500,000円',
      pageNumber: 1,
      boundingRect: rect,
      sourceImagePath: '/tmp/quote.png',
      nativeOcrConfidence: 0.97,
    );

    expect(result.categoryId, 'concrete');
    expect(result.amountYen, 500000);
    expect(result.recognizedLine.confidence, 0.97);
    expect(result.recognizedLine.categoryConfidence, greaterThan(0.9));
    expect(result.recognizedLine.amountConfidence, greaterThan(0.9));
    expect(result.recognizedLine.initialStatus, OcrReviewStatus.autoConfirmed);
  });

  test('thousands separated quantities are not parsed as decimals', () {
    final result = engine.analyze(
      rawText: '土間コンクリート 1,200㎡ 500,000円',
      pageNumber: 1,
      boundingRect: rect,
      sourceImagePath: '/tmp/quote.png',
    );

    expect(result.quantity, 1200);
    expect(result.unit, '㎡');
  });

  test('explicit yen values below four digits are extracted', () {
    expect(OcrConfidenceEngine.extractAmountCandidates('部材 500円'), [500]);
    expect(OcrConfidenceEngine.extractAmountCandidates('部材 ￥99'), [99]);
    expect(OcrConfidenceEngine.extractAmountCandidates('数量 500個'), isEmpty);
  });

  test('standalone numbers and address fragments are not prices', () {
    expect(OcrConfidenceEngine.extractAmountCandidates('1'), isEmpty);
    expect(OcrConfidenceEngine.extractAmountCandidates('熊谷市見晴町82-3'), isEmpty);
    expect(OcrConfidenceEngine.extractAmountCandidates('控ブロック7段C120'), isEmpty);
  });

  test('native OCR confidence below threshold requires review', () {
    final result = engine.analyze(
      rawText: 'フェンス 100,000円',
      pageNumber: 1,
      boundingRect: rect,
      sourceImagePath: '/tmp/quote.png',
      nativeOcrConfidence: 0.42,
    );

    expect(result.recognizedLine.confidence, 0.42);
    expect(
      result.recognizedLine.reviewReasons,
      contains(OcrReviewReason.lowOcrConfidence),
    );
    expect(result.recognizedLine.initialStatus, OcrReviewStatus.pending);
  });

  test('multiple categories and amounts require review', () {
    final result = engine.analyze(
      rawText: 'フェンス 門柱 ??? 100,000円 120,000円 130,000円',
      pageNumber: 1,
      boundingRect: rect,
      sourceImagePath: '/tmp/quote.png',
    );

    expect(
      result.recognizedLine.reviewReasons,
      contains(OcrReviewReason.multipleCandidates),
    );
    expect(
      result.recognizedLine.reviewReasons,
      contains(OcrReviewReason.lowAmountConfidence),
    );
    expect(result.recognizedLine.initialStatus, OcrReviewStatus.pending);
  });

  test('quantity multiplied by unit price mismatch is critical', () {
    final result = engine.analyze(
      rawText: 'フェンス 10m 20,000円 150,000円',
      pageNumber: 1,
      boundingRect: rect,
      sourceImagePath: '/tmp/quote.png',
    );

    expect(
      result.recognizedLine.reviewReasons,
      contains(OcrReviewReason.quantityUnitPriceMismatch),
    );
    expect(result.recognizedLine.severity, OcrReviewSeverity.critical);
  });

  test('total mismatch creates a critical issue', () {
    final issues = OcrConfidenceEngine.buildAggregateIssues(
      totalAmountYen: 1000000,
      includedItemAmounts: const [300000, 300000],
    );

    expect(issues, hasLength(1));
    expect(issues.single.reason, OcrReviewReason.totalMismatch);
    expect(issues.single.severity, OcrReviewSeverity.critical);
  });

  test('recognized line id is stable and uses a full SHA-256 digest', () {
    const first = OcrRecognizedLine(
      pageNumber: 2,
      boundingRect: rect,
      confidence: 0.9,
      rawText: '門柱 120,000円',
      sourceImagePath: '/tmp/render-1.png',
      categoryConfidence: 0.94,
      amountConfidence: 0.96,
    );
    const second = OcrRecognizedLine(
      pageNumber: 2,
      boundingRect: rect,
      confidence: 0.9,
      rawText: '門柱 120,000円',
      sourceImagePath: '/tmp/render-2.png',
      categoryConfidence: 0.94,
      amountConfidence: 0.96,
    );

    expect(first.id, second.id);
    expect(first.id, hasLength(64));
  });

  test('review state is persisted per document hash', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = OcrReviewStore(preferences: preferences);

    await store.save('document-sha-256', {
      'line-1': OcrReviewStatus.confirmed,
      'line-2': OcrReviewStatus.autoConfirmed,
    });
    final loaded = await store.load('document-sha-256');

    expect(loaded['line-1'], OcrReviewStatus.confirmed);
    expect(loaded['line-2'], OcrReviewStatus.autoConfirmed);
  });
}
