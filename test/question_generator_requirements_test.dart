import 'package:aimitsumori_app/data/category_master.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/question_generator.dart';
import 'package:aimitsumori_app/requirements_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'required missing scope is connected to the existing question generator',
    () {
      const project = Project(
        id: 'project-1',
        name: '外構工事',
        status: ProjectStatus.comparing,
        createdAtEpochMillis: 1,
        updatedAtEpochMillis: 1,
      );
      final normalized = [
        NormalizedQuote(
          quoteId: 'quote-1',
          contractorName: 'A社',
          lines: [
            NormalizedLine(
              category: CategoryMaster.require('drainage'),
              inclusionStatus: InclusionStatus.unknown,
              uncertaintyReasons: const ['見積明細に記載がありません'],
            ),
          ],
        ),
      ];

      final questions = QuestionGenerator().generate(
        project: project,
        normalizedQuotes: normalized,
        requirements: const [
          ProjectRequirement(
            categoryId: 'drainage',
            priority: RequirementPriority.required,
          ),
        ],
        nowEpochMillis: 10,
      );

      final requirementQuestion = questions.singleWhere(
        (question) => question.templateKey == 'REQUIREMENT_REQUIRED_MISSING',
      );
      expect(requirementQuestion.questionText, contains('排水'));
      expect(requirementQuestion.questionText, contains('見積内・別途・対象外'));
    },
  );

  test('requirement question ids are deterministic and de-duplicated', () {
    const project = Project(
      id: 'project-1',
      name: '外構工事',
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
          inclusionStatus: InclusionStatus.separate,
          amountYen: 50000,
          sourceLineItemIds: const ['line-1'],
        ),
      ],
    );
    const requirements = [
      ProjectRequirement(
        categoryId: 'drainage',
        priority: RequirementPriority.required,
      ),
    ];

    final first = QuestionGenerator().generate(
      project: project,
      normalizedQuotes: [quote],
      requirements: requirements,
      nowEpochMillis: 10,
    );
    final second = QuestionGenerator().generate(
      project: project,
      normalizedQuotes: [quote],
      requirements: requirements,
      nowEpochMillis: 20,
    );

    final firstRequirement = first.singleWhere(
      (question) => question.templateKey == 'REQUIREMENT_REQUIRED_SEPARATE',
    );
    final secondRequirement = second.singleWhere(
      (question) => question.templateKey == 'REQUIREMENT_REQUIRED_SEPARATE',
    );
    expect(firstRequirement.id, secondRequirement.id);
  });
}
