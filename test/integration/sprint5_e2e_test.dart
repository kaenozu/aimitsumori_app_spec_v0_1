/// ファイルパス: test/integration/sprint5_e2e_test.dart
/// 目的: Androidエミュレータ上で案件作成から比較、SQLite再読込までのコアフローを検証する。
/// 存在理由: Sprint 4の入力検証がUI・Repository・SQLiteを通して機能し、再起動後も永続化されることを保証する。
/// 関連ファイル: lib/main.dart, lib/screens/quote_input_screen.dart, lib/services/database_service.dart
library;

import 'package:aimitsumori_app/data/category_master.dart';
import 'package:aimitsumori_app/main.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/comparison_screen.dart';
import 'package:aimitsumori_app/screens/quote_input_screen.dart';
import 'package:aimitsumori_app/services/database_initializer.dart';
import 'package:aimitsumori_app/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeDatabase);
  tearDownAll(DatabaseService.instance.close);

  testWidgets('案件作成、入力検証、2件比較、SQLite再読込を完走できる', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    final database = DatabaseService.instance;
    await database.deleteAllData();
    addTearDown(() async {
      await database.deleteAllData();
      await database.close();
    });

    var repository = ProjectRepository(databaseService: database);
    await tester.pumpWidget(
      AimitsumoriApp(
        repository: repository,
        adService: MockAdMobService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-project-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('project-name-field')),
      'Sprint 5 E2E案件',
    );
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('skip-requirements-button')));
    await tester.pumpAndSettle();

    final createdProjects = await repository.getProjects();
    expect(createdProjects, hasLength(1));
    final project = createdProjects.single;

    await _saveQuoteThroughEditor(
      tester,
      project: project,
      repository: repository,
      contractorName: 'A社',
      amount: '1200000',
      quantity: '12.5',
      expectedQuoteCountBeforeSave: 0,
      verifyValidation: true,
    );
    await _saveQuoteThroughEditor(
      tester,
      project: project,
      repository: repository,
      contractorName: 'B社',
      amount: '1350000',
      quantity: '13',
      expectedQuoteCountBeforeSave: 1,
    );

    final reloaded = await repository.getProject(project.id);
    expect(reloaded, isNotNull);
    final persistedProject = reloaded!;
    expect(persistedProject.quotes, hasLength(2));

    final quoteA = persistedProject.quotes.singleWhere(
      (quote) => quote.contractorName == 'A社',
    );
    final quoteB = persistedProject.quotes.singleWhere(
      (quote) => quote.contractorName == 'B社',
    );
    expect(_unitPrice(quoteA), 96000);
    expect(_unitPrice(quoteB), closeTo(103846.1538, 0.0001));

    await _openAndVerifyComparison(
      tester,
      project: persistedProject,
      repository: repository,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();

    repository = ProjectRepository(databaseService: database);
    await tester.pumpWidget(
      AimitsumoriApp(
        repository: repository,
        adService: MockAdMobService(),
      ),
    );
    await tester.pumpAndSettle();

    final projectCard = find.byKey(ValueKey('project-card-${project.id}'));
    expect(projectCard, findsOneWidget);
    final persisted = await repository.getProject(project.id);
    expect(persisted, isNotNull);
    expect(persisted!.quotes, hasLength(2));

    await tester.tap(projectCard);
    await tester.pumpAndSettle();
    expect(find.text('A社'), findsWidgets);
    expect(find.text('B社'), findsWidgets);
    expect(
      find.text('順位・総合点は付けず、条件差と不明点を確認します。'),
      findsOneWidget,
    );
  });
}

Future<void> _saveQuoteThroughEditor(
  WidgetTester tester, {
  required Project project,
  required ProjectRepository repository,
  required String contractorName,
  required String amount,
  required String quantity,
  required int expectedQuoteCountBeforeSave,
  bool verifyValidation = false,
}) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  final result = navigator.push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => QuoteInputScreen(
        project: project,
        repository: repository,
        initialQuote: RawQuoteData(
          contractorName: '',
          extractedText: '',
          sourcePath: 'memory://$contractorName',
          createdAtEpochMillis: DateTime.now().millisecondsSinceEpoch,
          lineItems: [
            RawQuoteLineItem(
              rawLabel: '施工費',
              categoryId: CategoryMaster.categories.first.id,
              inclusionStatus: InclusionStatus.included,
              unit: '㎡',
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await _enterText(
    tester,
    const ValueKey('quote-contractor-field'),
    contractorName,
  );

  if (verifyValidation) {
    await _enterText(
      tester,
      const ValueKey('quote-total-field'),
      '金額不正',
    );
    await _tapSave(tester);
    expect(find.text('金額を数値で入力してください。'), findsOneWidget);
    await _expectQuoteCount(
      repository,
      project.id,
      expectedQuoteCountBeforeSave,
    );
  }

  await _enterText(tester, const ValueKey('quote-total-field'), amount);
  await _enterText(tester, const ValueKey('quote-line-amount-0'), amount);
  await _enterText(
    tester,
    const ValueKey('quote-line-quantity-0'),
    verifyValidation ? '0' : quantity,
  );

  if (verifyValidation) {
    await _tapSave(tester);
    expect(find.text('数量は0より大きい値を入力してください。'), findsOneWidget);
    await _expectQuoteCount(
      repository,
      project.id,
      expectedQuoteCountBeforeSave,
    );
    await _enterText(
      tester,
      const ValueKey('quote-line-quantity-0'),
      quantity,
    );
  }

  await _tapSave(tester);
  expect(await result, isTrue);
  await _expectQuoteCount(
    repository,
    project.id,
    expectedQuoteCountBeforeSave + 1,
  );
}

Future<void> _openAndVerifyComparison(
  WidgetTester tester, {
  required Project project,
  required ProjectRepository repository,
}) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ComparisonScreen(
        project: project,
        repository: repository,
        adService: MockAdMobService(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('A社'), findsWidgets);
  expect(find.text('B社'), findsWidgets);
  expect(find.textContaining('A社 1,200,000円'), findsOneWidget);
  expect(find.textContaining('B社 1,350,000円'), findsOneWidget);
  expect(find.text('金額: 1,200,000円'), findsOneWidget);
  expect(find.text('金額: 1,350,000円'), findsOneWidget);
  expect(find.text('数量: 12.5㎡'), findsOneWidget);
  expect(find.text('数量: 13㎡'), findsOneWidget);
  expect(
    find.text('順位・総合点は付けず、条件差と不明点を確認します。'),
    findsOneWidget,
  );
}

Future<void> _enterText(WidgetTester tester, Key key, String value) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
  await tester.enterText(finder, value);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('quote-save-button')));
  await tester.pumpAndSettle();
}

Future<void> _expectQuoteCount(
  ProjectRepository repository,
  String projectId,
  int count,
) async {
  final project = await repository.getProject(projectId);
  expect(project, isNotNull);
  expect(project!.quotes, hasLength(count));
}

double _unitPrice(ContractorQuote quote) {
  final line = quote.lineItems.single;
  return line.amountYen! / line.quantity!;
}
