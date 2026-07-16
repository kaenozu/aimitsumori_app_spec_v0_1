/// ファイルパス: test/comparison_engine_test.dart
/// 比較ロジックのユニットテスト

import 'package:flutter_test/flutter_test.dart';
import 'package:aimitsumori_app/data/sample_data.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/normalizer.dart';
import 'package:aimitsumori_app/comparison_engine.dart';
import 'package:aimitsumori_app/question_generator.dart';

void main() {
  final normalizer = Normalizer();
  final questionGenerator = QuestionGenerator();
  final engine = ComparisonEngine();

  test('compare keeps input company order and creates exactly three summary lines', () {
    final project = SampleData.project();
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

    expect(report.quoteSnapshots.map((s) => s.contractorName).toList(), ['A社', 'B社', 'C社']);
    expect(report.summaryLines.length, 3);
    expect(report.summaryLines[0], contains('A社 2,530,000円'));
    expect(report.summaryLines[0], contains('B社 3,450,000円'));
    expect(report.summaryLines[0], contains('C社 2,785,000円'));
  });

  test('compare does not hide separate items behind low total', () {
    final project = SampleData.project();
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
    final companyA = report.quoteSnapshots.firstWhere((s) => s.contractorName == 'A社');

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
    final project = SampleData.project();
    final companyC = normalizer.normalize(project).firstWhere((q) => q.contractorName == 'C社');
    final concrete = companyC.lines.firstWhere((l) => l.category.id == 'concrete');
    final drainage = companyC.lines.firstWhere((l) => l.category.id == 'drainage');

    expect(concrete.quantity, isNull);
    expect(concrete.unit, isNull);
    expect(concrete.specification, isNull);
    expect(concrete.uncertaintyReasons.any((r) => r.contains('数量')), isTrue);
    expect(concrete.uncertaintyReasons.any((r) => r.contains('仕様')), isTrue);

    expect(drainage.inclusionStatus, InclusionStatus.unknown);
    expect(drainage.amountYen, isNull);
  });

  test('report contains all 18 categories and no synthetic score or ranking', () {
    final project = SampleData.project();
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
  });
}
