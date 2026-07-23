import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Project projectWith(List<QuoteLineItem> items) => Project(
    id: 'project-1',
    name: '外構工事',
    status: ProjectStatus.comparing,
    createdAtEpochMillis: 1,
    updatedAtEpochMillis: 1,
    quotes: [
      ContractorQuote(
        id: 'quote-1',
        contractorName: 'A社',
        totalAmountYen: 100000,
        createdAtEpochMillis: 1,
        lineItems: items,
      ),
    ],
  );

  test('same-category quantities with the same unit are summed', () {
    final normalized = Normalizer().normalize(
      projectWith(const [
        QuoteLineItem(
          id: 'line-1',
          categoryId: 'concrete',
          rawLabel: '土間1',
          amountYen: 50000,
          inclusionStatus: InclusionStatus.included,
          quantity: 10,
          unit: '㎡',
        ),
        QuoteLineItem(
          id: 'line-2',
          categoryId: 'concrete',
          rawLabel: '土間2',
          amountYen: 50000,
          inclusionStatus: InclusionStatus.included,
          quantity: 12,
          unit: 'm2',
        ),
      ]),
    );

    final line = normalized.single.lines.singleWhere(
      (value) => value.category.id == 'concrete',
    );
    expect(line.quantity, 22);
    expect(line.unit, '㎡');
    expect(line.amountYen, 100000);
  });

  test('partial quantity data is not presented as a complete total', () {
    final normalized = Normalizer().normalize(
      projectWith(const [
        QuoteLineItem(
          id: 'line-1',
          categoryId: 'concrete',
          rawLabel: '土間1',
          inclusionStatus: InclusionStatus.included,
          quantity: 10,
          unit: '㎡',
        ),
        QuoteLineItem(
          id: 'line-2',
          categoryId: 'concrete',
          rawLabel: '土間2',
          inclusionStatus: InclusionStatus.included,
          unit: '㎡',
        ),
      ]),
    );

    final line = normalized.single.lines.singleWhere(
      (value) => value.category.id == 'concrete',
    );
    expect(line.quantity, isNull);
    expect(
      line.uncertaintyReasons,
      contains('数量未記載の明細を含むため、数量を合算できません'),
    );
  });
}
