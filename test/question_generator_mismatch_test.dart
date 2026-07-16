import 'package:aimitsumori_app/data/category_master.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/question_generator.dart';
import 'package:aimitsumori_app/requirements_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quantity and unit mismatches generate separate questions', () {
    final project = Project(
      id: 'project-1',
      name: '案件',
      status: ProjectStatus.comparing,
      createdAtEpochMillis: 1,
      updatedAtEpochMillis: 1,
    );
    final quote = NormalizedQuote(
      quoteId: 'quote-1',
      contractorName: 'A社',
      lines: [
        NormalizedLine(
          category: CategoryMaster.require('drainage'),
          inclusionStatus: InclusionStatus.included,
          quantity: 5,
          unit: '式',
          specification: 'VP100',
          sourceLineItemIds: const ['line-1'],
        ),
      ],
    );

    final questions = QuestionGenerator().generate(
      project: project,
      normalizedQuotes: [quote],
      requirements: const [
        ProjectRequirement(
          categoryId: 'drainage',
          priority: RequirementPriority.required,
          expectedQuantity: 10,
          expectedUnit: 'm',
        ),
      ],
      nowEpochMillis: 1,
    );

    expect(
      questions.map((value) => value.templateKey),
      containsAll([
        'REQUIREMENT_QUANTITY_MISMATCH',
        'REQUIREMENT_UNIT_MISMATCH',
      ]),
    );
    expect(questions.map((value) => value.id).toSet(), hasLength(questions.length));
    expect(questions.every((value) => value.id.length == 36), isTrue);
  });
}
