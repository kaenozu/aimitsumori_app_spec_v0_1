import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/quote_revision_models.dart';
import 'package:aimitsumori_app/services/quote_revision_diff_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  QuoteLineItem item(String id, int sortOrder, int amount) => QuoteLineItem(
        id: id,
        categoryId: 'fence',
        rawLabel: 'フェンス工事',
        amountYen: amount,
        inclusionStatus: InclusionStatus.included,
        quantity: 10,
        unit: 'm',
        sortOrder: sortOrder,
      );

  QuoteRevision revision(int number, List<QuoteLineItem> items) => QuoteRevision(
        id: 'revision-$number',
        projectId: 'project-1',
        quoteId: 'quote-$number',
        contractorName: 'A社',
        quoteGroupId: 'group-1',
        revisionNumber: number,
        parentRevisionId: number == 1 ? null : 'revision-${number - 1}',
        sourceFileHash: 'hash-$number',
        importedAt: number,
        quoteSnapshot: ContractorQuote(
          id: 'quote-$number',
          contractorName: 'A社',
          createdAtEpochMillis: number,
          lineItems: items,
        ),
      );

  test('same category and label lines are all retained in the diff', () {
    final before = revision(1, [
      item('before-1', 1, 100000),
      item('before-2', 2, 200000),
    ]);
    final after = revision(2, [
      item('after-1', 1, 110000),
      item('after-2', 2, 220000),
      item('after-3', 3, 300000),
    ]);

    final diff = const QuoteRevisionDiffEngine().compare(before, after);
    expect(
      diff.changes.where((value) => value.type == QuoteLineChangeType.amount),
      hasLength(2),
    );
    expect(
      diff.changes.where((value) => value.type == QuoteLineChangeType.added),
      hasLength(1),
    );
  });
}
