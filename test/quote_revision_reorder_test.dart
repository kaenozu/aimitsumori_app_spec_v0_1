import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/quote_revision_models.dart';
import 'package:aimitsumori_app/services/quote_revision_diff_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  QuoteRevision revision({
    required String id,
    required int number,
    required List<QuoteLineItem> items,
  }) => QuoteRevision(
    id: id,
    projectId: 'project-1',
    quoteId: 'quote-$number',
    contractorName: 'A社',
    quoteGroupId: 'group-1',
    revisionNumber: number,
    sourceFileHash: 'hash-$number',
    importedAt: number,
    quoteSnapshot: ContractorQuote(
      id: 'quote-$number',
      contractorName: 'A社',
      totalAmountYen: 30000,
      createdAtEpochMillis: number,
      lineItems: items,
    ),
  );

  test('reordering same-label lines does not create amount changes', () {
    final before = revision(
      id: 'revision-1',
      number: 1,
      items: const [
        QuoteLineItem(
          id: 'old-a',
          categoryId: 'fence',
          rawLabel: 'フェンス',
          amountYen: 10000,
          quantity: 1,
          unit: '式',
          sortOrder: 1,
        ),
        QuoteLineItem(
          id: 'old-b',
          categoryId: 'fence',
          rawLabel: 'フェンス',
          amountYen: 20000,
          quantity: 2,
          unit: '式',
          sortOrder: 2,
        ),
      ],
    );
    final after = revision(
      id: 'revision-2',
      number: 2,
      items: const [
        QuoteLineItem(
          id: 'new-b',
          categoryId: 'fence',
          rawLabel: 'フェンス',
          amountYen: 20000,
          quantity: 2,
          unit: '式',
          sortOrder: 1,
        ),
        QuoteLineItem(
          id: 'new-a',
          categoryId: 'fence',
          rawLabel: 'フェンス',
          amountYen: 10000,
          quantity: 1,
          unit: '式',
          sortOrder: 2,
        ),
      ],
    );

    final diff = const QuoteRevisionDiffEngine().compare(before, after);

    expect(diff.changes, isEmpty);
  });
}
