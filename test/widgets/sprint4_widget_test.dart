import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/comparison_screen.dart';
import 'package:aimitsumori_app/screens/quote_input_screen.dart';
import 'package:aimitsumori_app/services/ocr_review_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  late MockDatabaseService database;
  late ProjectRepository repository;
  late Project project;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    project = createTestProject(status: ProjectStatus.collectingQuotes);
    database = MockDatabaseService(initialProjects: [project]);
    repository = ProjectRepository(databaseService: database);
  });

  testWidgets('空送信で項目直下にエラーを表示する', (tester) async {
    await tester.pumpWidget(
      _quoteScreen(
        project: project,
        repository: repository,
        quote: _rawQuote(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('quote-save-button')));
    await tester.pump();

    expect(find.text('業者名を入力してください。'), findsOneWidget);
    expect(find.text('金額を入力してください。'), findsOneWidget);
    expect((await repository.getProject(project.id))!.quotes, isEmpty);
  });

  testWidgets('不正値は保存されない', (tester) async {
    await tester.pumpWidget(
      _quoteScreen(
        project: project,
        repository: repository,
        quote: _rawQuote(contractorName: 'テスト業者'),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('quote-total-field')),
      '1,2O0',
    );
    await tester.tap(find.byKey(const ValueKey('quote-save-button')));
    await tester.pump();

    expect(find.text('金額を数値で入力してください。'), findsOneWidget);
    expect((await repository.getProject(project.id))!.quotes, isEmpty);
  });

  testWidgets('正常値の入力でバリデーションエラーが消える', (tester) async {
    await tester.pumpWidget(
      _quoteScreen(
        project: project,
        repository: repository,
        quote: _rawQuote(contractorName: 'テスト業者'),
      ),
    );

    final totalField = find.byKey(const ValueKey('quote-total-field'));
    await tester.enterText(totalField, '-1');
    await tester.tap(find.byKey(const ValueKey('quote-save-button')));
    await tester.pump();
    expect(find.text('金額に負の値は入力できません。'), findsOneWidget);

    await tester.enterText(totalField, '1200000');
    await tester.pump();
    expect(find.text('金額に負の値は入力できません。'), findsNothing);
  });

  testWidgets('見積0件では空状態を表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ComparisonScreen(
          project: project,
          repository: repository,
          adService: MockAdMobService(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('まず1社目の見積を入れます'), findsOneWidget);
    expect(find.text('見積書を追加する'), findsOneWidget);
  });

  testWidgets('比較対象が1件でも見積概要を表示する', (tester) async {
    final oneQuoteProject = project.copyWith(
      quotes: [createTestContractorQuote(contractorName: '1社目')],
    );
    final oneQuoteDatabase = MockDatabaseService(
      initialProjects: [oneQuoteProject],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ComparisonScreen(
          project: oneQuoteProject,
          repository: ProjectRepository(databaseService: oneQuoteDatabase),
          adService: MockAdMobService(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1社目'), findsWidgets);
    expect(find.text('まず1社目の見積を入れます'), findsNothing);
  });
}

Widget _quoteScreen({
  required Project project,
  required ProjectRepository repository,
  required RawQuoteData quote,
}) {
  return MaterialApp(
    home: QuoteInputScreen(
      project: project,
      repository: repository,
      reviewStore: OcrReviewStore(),
      initialQuote: quote,
    ),
  );
}

RawQuoteData _rawQuote({String contractorName = ''}) {
  return RawQuoteData(
    contractorName: contractorName,
    extractedText: '',
    sourcePath: 'memory://widget-test',
    createdAtEpochMillis: 1700000000000,
    lineItems: const [],
  );
}
