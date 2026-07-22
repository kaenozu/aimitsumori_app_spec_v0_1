import 'package:aimitsumori_app/data/category_master.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/requirements_models.dart';
import 'package:aimitsumori_app/services/requirements_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = RequirementsEngine();
  final category = CategoryMaster.require('drainage');

  NormalizedQuote quote({double? quantity, String? unit}) => NormalizedQuote(
    quoteId: 'quote-1',
    contractorName: 'A社',
    lines: [
      NormalizedLine(
        category: category,
        inclusionStatus: InclusionStatus.included,
        quantity: quantity,
        unit: unit,
        sourceLineItemIds: const ['line-1'],
      ),
    ],
  );

  test('compatible units are converted before quantity comparison', () {
    final result = engine.evaluate(
      requirements: const [
        ProjectRequirement(
          categoryId: 'drainage',
          priority: RequirementPriority.required,
          expectedQuantity: 1,
          expectedUnit: 'm',
        ),
      ],
      quotes: [quote(quantity: 1000, unit: 'mm')],
    );

    expect(result.single.mismatches, isEmpty);
  });

  test('missing quote unit is reported when a unit is required', () {
    final result = engine.evaluate(
      requirements: const [
        ProjectRequirement(
          categoryId: 'drainage',
          priority: RequirementPriority.required,
          expectedQuantity: 10,
          expectedUnit: 'm',
        ),
      ],
      quotes: [quote(quantity: 10)],
    );

    expect(
      result.single.mismatches.map((value) => value.type),
      contains(RequirementMismatchType.unit),
    );
  });
}
