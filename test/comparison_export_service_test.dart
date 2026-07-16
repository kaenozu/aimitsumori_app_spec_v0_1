/// ファイルパス: test/comparison_export_service_test.dart
/// 比較結果の共有テキスト生成テスト
library;

import 'package:aimitsumori_app/comparison_engine.dart';
import 'package:aimitsumori_app/normalizer.dart';
import 'package:aimitsumori_app/question_generator.dart';
import 'package:aimitsumori_app/services/comparison_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  test('exports summary, contractors, category statuses and questions', () {
    final project = createSampleComparisonProject();
    final normalized = Normalizer().normalize(project);
    final questions = QuestionGenerator().generate(
      project: project,
      normalizedQuotes: normalized,
      nowEpochMillis: 1,
    );
    final report = ComparisonEngine().compare(
      project: project,
      normalizedQuotes: normalized,
      questions: questions,
    );

    final text = ComparisonExportService.toText(report);

    expect(text, contains('【新築外構 3社相見積もり】相見積もり比較'));
    expect(text, contains('A社: 2,530,000円'));
    expect(text, contains('B社: 3,450,000円'));
    expect(text, contains('C社: 2,785,000円'));
    expect(text, contains('【残土処分】'));
    expect(text, contains('A社: 別途'));
    expect(text, contains('■ 確認質問'));
  });
}
