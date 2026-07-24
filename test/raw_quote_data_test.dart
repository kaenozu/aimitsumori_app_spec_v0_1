import 'package:aimitsumori_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated quote ID is used consistently by line item IDs', () {
    const raw = RawQuoteData(
      contractorName: 'A社',
      totalAmountYen: 100000,
      extractedText: '見積書',
      sourcePath: '/tmp/quote.jpg',
      createdAtEpochMillis: 1,
      lineItems: [
        RawQuoteLineItem(
          rawLabel: '土間コンクリート',
          categoryId: 'concrete',
          amountYen: 100000,
        ),
      ],
    );

    final quote = raw.toContractorQuote();

    expect(quote.id, startsWith('quote-'));
    expect(quote.id, isNot('null'));
    expect(quote.lineItems.single.id, '${quote.id}-line-1');
    expect(quote.lineItems.single.id, isNot(contains('null')));
  });

  test('explicit quote ID is preserved', () {
    const raw = RawQuoteData(
      contractorName: 'A社',
      extractedText: '',
      sourcePath: 'test://quote',
      createdAtEpochMillis: 1,
      lineItems: [RawQuoteLineItem(rawLabel: 'フェンス', categoryId: 'fence')],
    );

    final quote = raw.toContractorQuote(id: 'quote-fixed');

    expect(quote.id, 'quote-fixed');
    expect(quote.lineItems.single.id, 'quote-fixed-line-1');
  });
}
