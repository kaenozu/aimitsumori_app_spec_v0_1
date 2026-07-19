library;

import '../models.dart';
import '../ocr_models.dart';

class OcrLineInterpretation {
  const OcrLineInterpretation({
    required this.recognizedLine,
    this.categoryId,
    this.amountYen,
    this.quantity,
    this.unit,
    this.unitPriceYen,
    required this.inclusionStatus,
    this.specification,
  });

  final OcrRecognizedLine recognizedLine;
  final String? categoryId;
  final int? amountYen;
  final double? quantity;
  final String? unit;
  final int? unitPriceYen;
  final InclusionStatus inclusionStatus;
  final String? specification;
}

class OcrConfidenceEngine {
  const OcrConfidenceEngine();

  static const Map<String, List<String>> categoryKeywords = {
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

  OcrLineInterpretation analyze({
    required String rawText,
    required int pageNumber,
    required OcrBoundingRect boundingRect,
    required String sourceImagePath,
    double? nativeOcrConfidence,
  }) {
    final text = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final categoryCandidates = <String>[
      for (final entry in categoryKeywords.entries)
        if (entry.value.any(text.contains)) entry.key,
    ];
    final amountCandidates = extractAmountCandidates(text);
    final quantityMatch = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(㎡|m2|m²|㎥|m3|m³|m|本|基|台|式|箇所|ヶ所|個)',
      caseSensitive: false,
    ).firstMatch(text);
    final quantity = double.tryParse(
      (quantityMatch?.group(1) ?? '').replaceAll(',', '.'),
    );
    final amount = amountCandidates.isEmpty ? null : amountCandidates.last;
    final unitPrice = amountCandidates.length >= 2
        ? amountCandidates[amountCandidates.length - 2]
        : null;

    final ocrConfidence = calculateOcrConfidence(
      text,
      nativeConfidence: nativeOcrConfidence,
    );
    final categoryConfidence = calculateCategoryConfidence(categoryCandidates);
    final amountConfidence = calculateAmountConfidence(amountCandidates);
    final reasons = <OcrReviewReason>[];
    if (ocrConfidence < 0.75) reasons.add(OcrReviewReason.lowOcrConfidence);
    if (categoryCandidates.isNotEmpty && categoryConfidence < 0.75) {
      reasons.add(OcrReviewReason.lowCategoryConfidence);
    }
    if (amountCandidates.isNotEmpty && amountConfidence < 0.75) {
      reasons.add(OcrReviewReason.lowAmountConfidence);
    }
    if (categoryCandidates.length > 1 || amountCandidates.length > 1) {
      reasons.add(OcrReviewReason.multipleCandidates);
    }
    if (hasQuantityUnitPriceMismatch(
      quantity: quantity,
      unitPriceYen: unitPrice,
      amountYen: amount,
    )) {
      reasons.add(OcrReviewReason.quantityUnitPriceMismatch);
    }

    final line = OcrRecognizedLine(
      pageNumber: pageNumber,
      boundingRect: boundingRect,
      confidence: ocrConfidence,
      rawText: text,
      sourceImagePath: sourceImagePath,
      categoryConfidence: categoryConfidence,
      amountConfidence: amountConfidence,
      categoryCandidates: categoryCandidates,
      amountCandidates: amountCandidates,
      reviewReasons: reasons,
      initialStatus: reasons.isEmpty
          ? OcrReviewStatus.autoConfirmed
          : OcrReviewStatus.pending,
    );

    return OcrLineInterpretation(
      recognizedLine: line,
      categoryId: categoryCandidates.isEmpty ? null : categoryCandidates.first,
      amountYen: amount,
      quantity: quantity,
      unit: quantityMatch?.group(2),
      unitPriceYen: unitPrice,
      inclusionStatus: parseInclusionStatus(text, amount),
      specification: extractSpecification(text),
    );
  }

  static double calculateOcrConfidence(
    String text, {
    double? nativeConfidence,
  }) {
    if (text.trim().isEmpty) return 0;
    if (nativeConfidence != null && nativeConfidence.isFinite) {
      return nativeConfidence.clamp(0.0, 1.0).toDouble();
    }

    var score = 0.96;
    final replacementCount = '�'.allMatches(text).length;
    score -= replacementCount * 0.22;
    if (RegExp(r'[|]{2,}|[_]{3,}|[?]{3,}').hasMatch(text)) score -= 0.18;
    final nonWord = RegExp(
      r'[^0-9A-Za-zぁ-んァ-ヶ一-龠々ー㎡㎥m²³¥￥,，.．:：/()（）\-\s]',
    ).allMatches(text).length;
    if (nonWord > text.length * 0.15) score -= 0.18;
    if (text.length <= 2) score -= 0.12;
    return score.clamp(0.05, 0.99).toDouble();
  }

  static double calculateCategoryConfidence(List<String> candidates) {
    if (candidates.isEmpty) return 0;
    if (candidates.length == 1) return 0.94;
    return 0.58;
  }

  static double calculateAmountConfidence(List<int> candidates) {
    if (candidates.isEmpty) return 0;
    if (candidates.length == 1) return 0.96;
    return 0.68;
  }

  static List<int> extractAmountCandidates(
    String line,
  ) => RegExp(r'(?:¥|￥)?\s*(-?\d{1,3}(?:,\d{3})+|-?\d{4,})\s*円?')
      .allMatches(
        line.replaceAll(RegExp(r'[\u00a0\u3000\s]'), '').replaceAll('，', ','),
      )
      .map((match) => int.tryParse((match.group(1) ?? '').replaceAll(',', '')))
      .whereType<int>()
      .toList(growable: false);

  static bool hasQuantityUnitPriceMismatch({
    required double? quantity,
    required int? unitPriceYen,
    required int? amountYen,
  }) {
    if (quantity == null || unitPriceYen == null || amountYen == null) {
      return false;
    }
    final expected = quantity * unitPriceYen;
    final tolerance = (amountYen.abs() * 0.02).clamp(500, 100000).toDouble();
    return (expected - amountYen).abs() > tolerance;
  }

  static List<OcrReviewIssue> buildAggregateIssues({
    required int? totalAmountYen,
    required Iterable<int> includedItemAmounts,
  }) {
    final amounts = includedItemAmounts.toList(growable: false);
    if (totalAmountYen == null || amounts.isEmpty) return const [];
    final sum = amounts.fold<int>(0, (value, amount) => value + amount);
    final tolerance = (totalAmountYen.abs() * 0.02).clamp(1000, 200000).toInt();
    if ((sum - totalAmountYen).abs() <= tolerance) return const [];
    return [
      OcrReviewIssue(
        id: 'total-mismatch-$totalAmountYen-$sum',
        reason: OcrReviewReason.totalMismatch,
        severity: OcrReviewSeverity.critical,
        message: '提示総額と抽出明細の合計が一致しません（提示総額: $totalAmountYen円、明細合計: $sum円）。',
      ),
    ];
  }

  static InclusionStatus parseInclusionStatus(String line, int? amount) {
    if (RegExp(r'(別途|別見積|含まず)').hasMatch(line)) {
      return InclusionStatus.separate;
    }
    if (RegExp(r'(オプション|任意)').hasMatch(line)) {
      return InclusionStatus.optional;
    }
    if (RegExp(r'(対象外|除外|施工なし)').hasMatch(line)) {
      return InclusionStatus.excluded;
    }
    if (RegExp(r'(該当なし|不要)').hasMatch(line)) {
      return InclusionStatus.notApplicable;
    }
    if (amount != null || RegExp(r'(含む|込み|一式)').hasMatch(line)) {
      return InclusionStatus.included;
    }
    return InclusionStatus.unknown;
  }

  static String? extractSpecification(String line) {
    var value = line
        .replaceAll(RegExp(r'(?:¥|￥)?\s*-?\d{1,3}(?:,\d{3})+\s*円?'), '')
        .replaceAll(RegExp(r'(?:¥|￥)?\s*-?\d{4,}\s*円?'), '')
        .trim();
    if (value.length > 120) value = value.substring(0, 120);
    return value.isEmpty ? null : value;
  }
}
