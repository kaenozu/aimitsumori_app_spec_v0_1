/// ファイルパス: test/comparison_engine_test.dart
/// 比較ロジックのユニットテスト
library;

import 'package:aimitsumori_app/comparison_engine.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/normalizer.dart';
import 'package:aimitsumori_app/question_generator.dart';
import 'package:aimitsumori_app/data/category_master.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  final normalizer = Normalizer();
  final questionGenerator = QuestionGenerator();
  final engine = ComparisonEngine();

  test(
    'compare keeps input company order and creates exactly three summary lines',
    () {
      final project = createSampleComparisonProject();
      final normalized = normalizer.normalize(project);
      final questions = questionGenerator.generate(
        project: project,
        normalizedQuotes: normalized,
        nowEpochMillis: 1,
      );

      final report = engine.compare(
        project: project,
        normalizedQuotes: normalized,
        questions: questions,
      );

      expect(report.quoteSnapshots.map((s) => s.contractorName).toList(), [
        'A社',
        'B社',
        'C社',
      ]);
      expect(report.summaryLines.length, 3);
      expect(report.summaryLines[0], contains('A社 2,530,000円'));
      expect(report.summaryLines[0], contains('B社 3,450,000円'));
      expect(report.summaryLines[0], contains('C社 2,785,000円'));
    },
  );

  test('compare does not hide separate items behind low total', () {
    final project = createSampleComparisonProject();
    final normalized = normalizer.normalize(project);
    final questions = questionGenerator.generate(
      project: project,
      normalizedQuotes: normalized,
      nowEpochMillis: 1,
    );

    final report = engine.compare(
      project: project,
      normalizedQuotes: normalized,
      questions: questions,
    );
    final companyA = report.quoteSnapshots.firstWhere(
      (s) => s.contractorName == 'A社',
    );

    expect(companyA.totalAmountYen, 2530000);
    expect(companyA.separateCategoryNames, contains('残土処分'));
    expect(companyA.separateCategoryNames, contains('排水'));
    expect(
      report.clarificationQuestions.any(
        (q) => q.contractorName == 'A社' && q.templateKey == 'SEPARATE_SCOPE',
      ),
      isTrue,
    );
  });

  test('normalization preserves unknown values without guessing', () {
    final project = createSampleComparisonProject();
    final companyC = normalizer
        .normalize(project)
        .firstWhere((q) => q.contractorName == 'C社');
    final concrete = companyC.lines.firstWhere(
      (l) => l.category.id == 'concrete',
    );
    final drainage = companyC.lines.firstWhere(
      (l) => l.category.id == 'drainage',
    );

    expect(concrete.quantity, isNull);
    expect(concrete.unit, isNull);
    expect(concrete.specification, isNull);
    expect(concrete.uncertaintyReasons.any((r) => r.contains('数量')), isTrue);
    expect(concrete.uncertaintyReasons.any((r) => r.contains('仕様')), isTrue);

    expect(drainage.inclusionStatus, InclusionStatus.unknown);
    expect(drainage.amountYen, isNull);
  });

  test(
    'report contains all 18 categories and no synthetic score or ranking',
    () {
      final project = createSampleComparisonProject();
      final normalized = normalizer.normalize(project);
      final questions = questionGenerator.generate(
        project: project,
        normalizedQuotes: normalized,
        nowEpochMillis: 1,
      );
      final report = engine.compare(
        project: project,
        normalizedQuotes: normalized,
        questions: questions,
      );

      expect(report.categoryComparisons.length, 18);
      expect(report.summaryLines.any((l) => l.contains('総合点')), isFalse);
      expect(report.summaryLines.any((l) => l.contains('ランキング')), isFalse);
      expect(report.summaryLines.any((l) => l.contains('1位')), isFalse);
    },
  );

  test('compare returns fixed empty-state report when no quotes exist', () {
    final project = createTestProject(quotes: const []);

    final report = engine.compare(
      project: project,
      normalizedQuotes: const <NormalizedQuote>[],
      questions: const <ClarificationQuestion>[],
    );

    expect(report.projectId, project.id);
    expect(report.projectName, project.name);
    expect(report.quoteSnapshots, isEmpty);
    expect(report.categoryComparisons.length, 18);
    expect(
      report.categoryComparisons.every(
        (comparison) => comparison.cells.isEmpty,
      ),
      isTrue,
    );
    expect(report.clarificationQuestions, isEmpty);
    expect(report.summaryLines, const [
      '見積総額: 見積は未登録です。',
      '範囲差: 比較対象がないため判定できません。',
      '要確認: まず見積書を登録してください。質問テンプレートは0件です。',
    ]);
  });

  test('compare completes with a single quote', () {
    final quote = createTestContractorQuote(
      id: 'quote-single',
      contractorName: '単独社',
      totalAmountYen: 1200000,
    );
    final project = createTestProject(quotes: [quote]);
    final normalizedQuote = _createNormalizedQuote(
      quoteId: quote.id,
      contractorName: quote.contractorName,
      totalAmountYen: quote.totalAmountYen,
    );

    final report = engine.compare(
      project: project,
      normalizedQuotes: [normalizedQuote],
      questions: const <ClarificationQuestion>[],
    );

    expect(report.quoteSnapshots, hasLength(1));
    expect(report.quoteSnapshots.single.quoteId, 'quote-single');
    expect(report.quoteSnapshots.single.contractorName, '単独社');
    expect(report.quoteSnapshots.single.totalAmountYen, 1200000);

    expect(report.categoryComparisons, hasLength(18));
    expect(
      report.categoryComparisons.every(
        (comparison) => comparison.cells.length == 1,
      ),
      isTrue,
    );

    expect(report.summaryLines, hasLength(3));
    expect(report.summaryLines[0], contains('単独社 1,200,000円'));
    expect(report.summaryLines[0], contains('総額差は算出不能'));
  });

  test(
    'compare displays unknown and does not calculate spread for null totals',
    () {
      final quoteA = createTestContractorQuote(
        id: 'quote-null-a',
        contractorName: '金額不明A社',
        totalAmountYen: null,
      );
      final quoteB = createTestContractorQuote(
        id: 'quote-null-b',
        contractorName: '金額不明B社',
        totalAmountYen: null,
      );
      final project = createTestProject(quotes: [quoteA, quoteB]);

      final report = engine.compare(
        project: project,
        normalizedQuotes: [
          _createNormalizedQuote(
            quoteId: quoteA.id,
            contractorName: quoteA.contractorName,
            totalAmountYen: quoteA.totalAmountYen,
          ),
          _createNormalizedQuote(
            quoteId: quoteB.id,
            contractorName: quoteB.contractorName,
            totalAmountYen: quoteB.totalAmountYen,
          ),
        ],
        questions: const <ClarificationQuestion>[],
      );

      expect(
        report.quoteSnapshots.map((snapshot) => snapshot.totalAmountYen),
        everyElement(isNull),
      );
      expect(report.summaryLines[0], '見積総額: 金額不明A社 未入力 / 金額不明B社 未入力、総額差は算出不能。');
    },
  );

  test('compare reports zero-yen spread when multiple totals are equal', () {
    final quoteA = createTestContractorQuote(
      id: 'quote-equal-a',
      contractorName: '同額A社',
      totalAmountYen: 1500000,
    );
    final quoteB = createTestContractorQuote(
      id: 'quote-equal-b',
      contractorName: '同額B社',
      totalAmountYen: 1500000,
    );
    final project = createTestProject(quotes: [quoteA, quoteB]);

    final report = engine.compare(
      project: project,
      normalizedQuotes: [
        _createNormalizedQuote(
          quoteId: quoteA.id,
          contractorName: quoteA.contractorName,
          totalAmountYen: quoteA.totalAmountYen,
        ),
        _createNormalizedQuote(
          quoteId: quoteB.id,
          contractorName: quoteB.contractorName,
          totalAmountYen: quoteB.totalAmountYen,
        ),
      ],
      questions: const <ClarificationQuestion>[],
    );

    expect(
      report.summaryLines[0],
      '見積総額: 同額A社 1,500,000円 / 同額B社 1,500,000円、'
      '提示総額の幅は0円。',
    );
  });

  test('compare throws StateError when a normalized category is missing', () {
    final quote = createTestContractorQuote(
      id: 'quote-missing-category',
      contractorName: 'カテゴリ不足社',
      totalAmountYen: 1000000,
    );
    final project = createTestProject(quotes: [quote]);

    final normalizedQuote = _createNormalizedQuote(
      quoteId: quote.id,
      contractorName: quote.contractorName,
      totalAmountYen: quote.totalAmountYen,
      omittedCategoryIds: const {'tax'},
    );

    expect(
      () => engine.compare(
        project: project,
        normalizedQuotes: [normalizedQuote],
        questions: const <ClarificationQuestion>[],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('compare preserves discount and tax category statuses and amounts', () {
    final quote = createTestContractorQuote(
      id: 'quote-discount-tax',
      contractorName: '値引税確認社',
      totalAmountYen: 1050000,
    );
    final project = createTestProject(quotes: [quote]);

    final normalizedQuote = _createNormalizedQuote(
      quoteId: quote.id,
      contractorName: quote.contractorName,
      totalAmountYen: quote.totalAmountYen,
      inclusionStatuses: const {
        'discount': InclusionStatus.optional,
        'tax': InclusionStatus.included,
      },
      amounts: const {'discount': -50000, 'tax': 100000},
    );

    final report = engine.compare(
      project: project,
      normalizedQuotes: [normalizedQuote],
      questions: const <ClarificationQuestion>[],
    );

    final snapshot = report.quoteSnapshots.single;
    final discountComparison = report.categoryComparisons.firstWhere(
      (comparison) => comparison.category.id == 'discount',
    );
    final taxComparison = report.categoryComparisons.firstWhere(
      (comparison) => comparison.category.id == 'tax',
    );

    expect(snapshot.includedCategoryCount, 1);
    expect(snapshot.optionalCategoryNames, contains('値引き'));
    expect(snapshot.unknownCategoryNames, isEmpty);

    expect(
      discountComparison.cells.single.inclusionStatus,
      InclusionStatus.optional,
    );
    expect(discountComparison.cells.single.amountYen, -50000);

    expect(
      taxComparison.cells.single.inclusionStatus,
      InclusionStatus.included,
    );
    expect(taxComparison.cells.single.amountYen, 100000);
  });
}

NormalizedQuote _createNormalizedQuote({
  required String quoteId,
  required String contractorName,
  required int? totalAmountYen,
  Map<String, InclusionStatus> inclusionStatuses = const {},
  Map<String, int?> amounts = const {},
  Set<String> omittedCategoryIds = const {},
}) {
  return NormalizedQuote(
    quoteId: quoteId,
    contractorName: contractorName,
    totalAmountYen: totalAmountYen,
    lines: CategoryMaster.categories
        .where((category) => !omittedCategoryIds.contains(category.id))
        .map(
          (category) => NormalizedLine(
            category: category,
            inclusionStatus:
                inclusionStatuses[category.id] ?? InclusionStatus.notApplicable,
            amountYen: amounts[category.id],
            quantity: null,
            unit: null,
            specification: null,
            sourceLineItemIds: const [],
            uncertaintyReasons: const [],
          ),
        )
        .toList(),
  );
}
