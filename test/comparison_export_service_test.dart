/// ファイルパス: test/comparison_export_service_test.dart
/// 比較結果のテキスト・CSV・PDF生成テスト
library;

import 'dart:convert';

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

  test('exports an Excel-compatible UTF-8 BOM CSV', () {
    final csv = ComparisonExportService.toCsv(createSampleComparisonProject());

    expect(csv.codeUnitAt(0), 0xfeff);
    expect(csv, contains('案件名,新築外構 3社相見積もり'));
    expect(csv, contains('業者名,提示総額(円),カテゴリID,項目名'));
    expect(csv, contains('A社,2530000'));
    expect(csv, contains('\r\n'));
  });

  test('sanitizes project names for export file names', () {
    expect(
      ComparisonExportService.fileStem(' 見積 / A社:比較 '),
      '見積_A社_比較',
    );
    expect(ComparisonExportService.fileStem('   '), 'aimitsumori');
  });

  test('creates a PDF from a captured PNG image', () async {
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    final pdfBytes = await ComparisonExportService.toPdfFromImage(
      pngBytes,
      imageWidth: 1,
      imageHeight: 2,
    );

    expect(pdfBytes.length, greaterThan(100));
    expect(pdfBytes.sublist(0, 4), equals(<int>[0x25, 0x50, 0x44, 0x46]));
  });
}
