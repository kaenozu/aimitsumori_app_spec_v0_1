import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/quote_revision_models.dart';
import 'package:aimitsumori_app/services/quote_revision_diff_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  QuoteLineItem item({
    required String id,
    String categoryId = 'fence',
    String label = 'フェンス工事',
    int? amount,
    double? quantity,
    String unit = 'm',
    String? specification,
    InclusionStatus inclusionStatus = InclusionStatus.included,
  }) {
    return QuoteLineItem(
      id: id,
      categoryId: categoryId,
      rawLabel: label,
      amountYen: amount,
      inclusionStatus: inclusionStatus,
      quantity: quantity,
      unit: unit,
      specification: specification,
    );
  }

  QuoteRevision revision({
    required int number,
    required int total,
    required List<QuoteLineItem> items,
    String? parentRevisionId,
  }) {
    return QuoteRevision(
      id: 'r$number',
      projectId: 'p1',
      quoteId: 'q$number',
      contractorName: 'A社',
      quoteGroupId: 'g1',
      revisionNumber: number,
      parentRevisionId:
          parentRevisionId ?? (number == 1 ? null : 'r${number - 1}'),
      sourceFileHash: 'hash$number',
      importedAt: number,
      quoteSnapshot: ContractorQuote(
        id: 'q$number',
        contractorName: 'A社',
        totalAmountYen: total,
        createdAtEpochMillis: number,
        lineItems: items,
      ),
    );
  }

  test(
    'diff reports total, amount, unit price, quantity and specification',
    () {
      final before = revision(
        number: 1,
        total: 100000,
        items: [
          item(
            id: 'i1',
            amount: 100000,
            quantity: 10,
            specification: 'H800',
          ),
        ],
      );
      final after = revision(
        number: 2,
        total: 144000,
        items: [
          item(
            id: 'i2',
            amount: 144000,
            quantity: 12,
            specification: 'H1000',
          ),
        ],
      );

      final diff = const QuoteRevisionDiffEngine().compare(before, after);

      expect(diff.totalDifferenceYen, 44000);
      expect(
        diff.changes.map((change) => change.type),
        containsAll([
          QuoteLineChangeType.amount,
          QuoteLineChangeType.unitPrice,
          QuoteLineChangeType.quantity,
          QuoteLineChangeType.specification,
        ]),
      );
      final unitPrice = diff.changes.singleWhere(
        (change) => change.type == QuoteLineChangeType.unitPrice,
      );
      expect(unitPrice.beforeUnitPriceYen, 10000);
      expect(unitPrice.afterUnitPriceYen, 12000);
    },
  );

  test('diff reports added, removed and inclusion status changes', () {
    final before = revision(
      number: 1,
      total: 100000,
      items: [
        item(id: 'i1', amount: 100000),
        item(
          id: 'i2',
          categoryId: 'gate',
          label: '門柱工事',
          inclusionStatus: InclusionStatus.included,
        ),
      ],
    );
    final after = revision(
      number: 2,
      total: 50000,
      items: [
        item(
          id: 'i3',
          categoryId: 'gate',
          label: '門柱工事',
          inclusionStatus: InclusionStatus.separate,
        ),
        item(
          id: 'i4',
          categoryId: 'drainage',
          label: '排水工事',
          amount: 50000,
        ),
      ],
    );

    final diff = const QuoteRevisionDiffEngine().compare(before, after);

    expect(
      diff.changes.map((change) => change.type),
      containsAll([
        QuoteLineChangeType.removed,
        QuoteLineChangeType.added,
        QuoteLineChangeType.inclusion,
      ]),
    );
  });

  test('a past revision can be the explicit parent of a new revision', () {
    final parent = revision(number: 1, total: 100000, items: const []);
    final intent = QuoteImportIntent.revision(
      parentQuote: parent.quoteSnapshot,
      quoteGroupId: parent.quoteGroupId,
      parentRevisionId: parent.id,
      changeReason: '第1版の仕様を基に再見積',
    );

    expect(intent.isRevision, isTrue);
    expect(intent.parentRevisionId, 'r1');
    expect(intent.quoteGroupId, 'g1');
    expect(intent.changeReason, '第1版の仕様を基に再見積');
  });

  test('new quote intents do not carry revision state', () {
    const intent = QuoteImportIntent.newQuote();

    expect(intent.isRevision, isFalse);
    expect(intent.parentQuote, isNull);
    expect(intent.quoteGroupId, isNull);
    expect(intent.parentRevisionId, isNull);
    expect(intent.changeReason, isNull);
  });
}
