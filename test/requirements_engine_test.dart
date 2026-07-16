import 'package:aimitsumori_app/data/category_master.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/requirements_models.dart';
import 'package:aimitsumori_app/services/requirements_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = RequirementsEngine();
  final drainage = CategoryMaster.require('drainage');

  NormalizedQuote quote({
    InclusionStatus status = InclusionStatus.included,
    int? amountYen = 100000,
    double? quantity = 10,
    String? unit = 'm',
    String? specification = '暗渠排水 VP100',
    List<String> sourceIds = const ['line-1'],
  }) =>
      NormalizedQuote(
        quoteId: 'quote-1',
        contractorName: 'A社',
        lines: [
          NormalizedLine(
            category: drainage,
            inclusionStatus: status,
            amountYen: amountYen,
            quantity: quantity,
            unit: unit,
            specification: specification,
            sourceLineItemIds: sourceIds,
          ),
        ],
      );

  test('required included is reported without a ranking or score', () {
    final result = engine.evaluate(
      requirements: const [
        ProjectRequirement(
          categoryId: 'drainage',
          priority: RequirementPriority.required,
        ),
      ],
      quotes: [quote()],
    );

    expect(result.single.status, RequirementCoverageStatus.requiredIncluded);
    expect(result.single.mismatches, isEmpty);
  });

  test('required separate and missing are distinguished', () {
    const requirement = ProjectRequirement(
      categoryId: 'drainage',
      priority: RequirementPriority.required,
    );

    final separate = engine.evaluate(
      requirements: [requirement],
      quotes: [quote(status: InclusionStatus.separate)],
    );
    final missing = engine.evaluate(
      requirements: [requirement],
      quotes: [
        quote(
          status: InclusionStatus.unknown,
          amountYen: null,
          quantity: null,
          unit: null,
          specification: null,
          sourceIds: const [],
        ),
      ],
    );

    expect(separate.single.status, RequirementCoverageStatus.requiredSeparate);
    expect(missing.single.status, RequirementCoverageStatus.requiredMissing);
  });

  test('unnecessary charged item is flagged', () {
    final result = engine.evaluate(
      requirements: const [
        ProjectRequirement(
          categoryId: 'drainage',
          priority: RequirementPriority.unnecessary,
        ),
      ],
      quotes: [quote()],
    );

    expect(
      result.single.status,
      RequirementCoverageStatus.unnecessaryIncluded,
    );
  });

  test('quantity, unit, and specification differences are reported', () {
    final result = engine.evaluate(
      requirements: const [
        ProjectRequirement(
          categoryId: 'drainage',
          priority: RequirementPriority.required,
          expectedQuantity: 20,
          expectedUnit: 'm',
          desiredSpecification: 'VP150',
        ),
      ],
      quotes: [quote(quantity: 10, unit: '式', specification: 'VP100')],
    );

    expect(
      result.single.mismatches.map((value) => value.type),
      containsAll([
        RequirementMismatchType.quantity,
        RequirementMismatchType.unit,
        RequirementMismatchType.specification,
      ]),
    );
  });
}
