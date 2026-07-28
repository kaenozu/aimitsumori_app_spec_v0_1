/// OCR行を見積書の明細・集計・注記へ分類するサービス。
library;

import '../ocr_models.dart';
import '../quote_structure.dart';

class QuoteStructureService {
  const QuoteStructureService();

  List<StructuredQuoteRow> classify(Iterable<OcrRecognizedLine> lines) => [
    for (final line in lines) classifyLine(line),
  ];

  StructuredQuoteRow classifyLine(OcrRecognizedLine line) {
    final text = line.rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hasAmount = line.amountCandidates.isNotEmpty;

    if (_isPageNoise(text)) {
      return StructuredQuoteRow(type: QuoteRowType.pageNoise, line: line);
    }
    if (_isGrandTotal(text)) {
      return StructuredQuoteRow(type: QuoteRowType.grandTotal, line: line);
    }
    if (_isTax(text)) {
      return StructuredQuoteRow(type: QuoteRowType.tax, line: line);
    }
    if (_isSubtotal(text)) {
      return StructuredQuoteRow(type: QuoteRowType.subtotal, line: line);
    }
    if (_isNote(text)) {
      return StructuredQuoteRow(type: QuoteRowType.note, line: line);
    }
    if (_isSectionHeader(text, hasAmount)) {
      return StructuredQuoteRow(type: QuoteRowType.sectionHeader, line: line);
    }
    // Keep a recognizable item even when its price is on a neighboring OCR
    // row or could not be safely parsed. The editor can show an empty amount
    // for manual completion; dropping the item loses the actual estimate.
    if (line.categoryCandidates.isNotEmpty) {
      return StructuredQuoteRow(
        type: QuoteRowType.lineItem,
        line: line,
        categoryId: line.categoryCandidates.first,
      );
    }
    if (hasAmount && text.length >= 3) {
      return StructuredQuoteRow(
        type: QuoteRowType.unresolved,
        line: line,
        reason: '金額は読み取れましたが、明細名を特定できませんでした。',
      );
    }
    return StructuredQuoteRow(
      type: QuoteRowType.unresolved,
      line: line,
      reason: '項目名と金額の関係を特定できませんでした。',
    );
  }

  bool _isPageNoise(String text) =>
      RegExp(r'^(発行日|\d+\s*/\s*\d+|No\.)').hasMatch(text);

  bool _isGrandTotal(String text) =>
      RegExp(r'(御見積金額|税込合計|合計\s*税込|総額)').hasMatch(text);

  bool _isTax(String text) => RegExp(r'(消費税|税\s*10%|税額)').hasMatch(text);

  bool _isSubtotal(String text) =>
      RegExp(r'(小計|合計\s*税抜|工事\s*計|計(?:\s|¥|円|$))').hasMatch(text);

  bool _isNote(String text) =>
      RegExp(r'(補足事項|備考|既設物|無償|有償|ご了承ください)').hasMatch(text);

  bool _isSectionHeader(String text, bool hasAmount) =>
      (RegExp(r'^\d+[．.]').hasMatch(text) && text.contains('工事')) ||
      (!hasAmount && text.endsWith('工事'));
}
