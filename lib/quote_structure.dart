/// OCRの生行を、見積書の意味を持つ行へ分類するモデル。
library;

import 'ocr_models.dart';

enum QuoteRowType {
  sectionHeader,
  lineItem,
  subtotal,
  tax,
  grandTotal,
  note,
  pageNoise,
  unresolved,
}

class StructuredQuoteRow {
  const StructuredQuoteRow({
    required this.type,
    required this.line,
    this.categoryId,
    this.reason,
  });

  final QuoteRowType type;
  final OcrRecognizedLine line;
  final String? categoryId;
  final String? reason;

  bool get requiresReview =>
      type == QuoteRowType.lineItem || type == QuoteRowType.unresolved;
}
