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

  NormalizedLine concreteLine(List<QuoteLineItem> items) => Normalizer()
      .normalize(projectWith(items))
      .single
      .lines
      .singleWhere((value) => value.category.id == 'concrete');

  test('same-category quantities with the same unit are summed', () {
    final line = concreteLine(const [
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
    ]);

    expect(line.quantity, 22);
    expect(line.unit, '㎡');
    expect(line.amountYen, 100000);
  });

  test('convertible length units are summed in meters', () {
    final line = concreteLine(const [
      QuoteLineItem(
        id: 'line-1',
        categoryId: 'concrete',
        rawLabel: '縁石1',
        inclusionStatus: InclusionStatus.included,
        quantity: 100,
        unit: 'cm',
      ),
      QuoteLineItem(
        id: 'line-2',
        categoryId: 'concrete',
        rawLabel: '縁石2',
        inclusionStatus: InclusionStatus.included,
        quantity: 1,
        unit: 'm',
      ),
    ]);

    expect(line.quantity, 2);
    expect(line.unit, 'm');
  });

  test('partial quantity data is not presented as a complete total', () {
    final line = concreteLine(const [
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
    ]);

    expect(line.quantity, isNull);
    expect(line.uncertaintyReasons, contains('数量または単位が未記載の明細を含むため、数量を合算できません'));
  });
}
