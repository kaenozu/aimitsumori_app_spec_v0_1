/// ファイルパス: integration_test/sprint5_e2e_test.dart
/// 目的: Androidエミュレータ上で案件作成から比較、SQLite再読込までのコアフローを検証する。
/// 存在理由: Sprint 4の入力検証がUI・Repository・SQLiteを通して機能し、再起動後も永続化されることを保証する。
/// 関連ファイル: lib/main.dart, lib/screens/quote_input_screen.dart, lib/services/database_service.dart
library;

import 'dart:async';
import 'dart:io';

import 'package:aimitsumori_app/data/category_master.dart';
import 'package:aimitsumori_app/main.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/ocr_models.dart';
import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/comparison_screen.dart';
import 'package:aimitsumori_app/screens/quote_input_screen.dart';
import 'package:aimitsumori_app/services/database_initializer.dart';
import 'package:aimitsumori_app/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_helpers.dart';

void main() {
  if (Platform.isAndroid) {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  } else {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  setUpAll(initializeDatabase);
  tearDownAll(DatabaseService.instance.close);

  testWidgets('案件作成、入力検証、2件比較、SQLite再読込を完走できる', (tester) async {
    debugPrint('S5: start');
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    final database = DatabaseService.instance;
    await _awaitStep('db.deleteAllData (setup)', database.deleteAllData());
    debugPrint('S5: database ready');
    addTearDown(() async {
      await _awaitStep('db.deleteAllData (teardown)', database.deleteAllData());
      await _awaitStep('db.close (teardown)', database.close());
    });

    var repository = ProjectRepository(databaseService: database);
    await _awaitStep(
      'ui.pumpWidget initial app',
      tester.pumpWidget(
        AimitsumoriApp(repository: repository, adService: MockAdMobService()),
      ),
    );
    debugPrint('S5: app pumped');
    await _pumpForUi(tester);
    debugPrint('S5: initial UI ready');

    await _awaitStep(
      'ui.tap create-project-button',
      tester.tap(find.byKey(const ValueKey('create-project-button'))),
    );
    await _pumpForUi(tester);
    debugPrint('S5: create dialog ready');
    await _awaitStep(
      'ui.enterText project-name-field',
      tester.enterText(
        find.byKey(const ValueKey('project-name-field')),
        'Sprint 5 E2E案件',
      ),
    );
    await _awaitStep('ui.tap 次へ', tester.tap(find.text('次へ')));
    await _pumpForUi(tester);
    debugPrint('S5: requirements ready');
    await _awaitStep(
      'ui.tap skip-requirements-button',
      tester.tap(find.byKey(const ValueKey('skip-requirements-button'))),
    );
    await _pumpForUi(tester);
    await _waitForText(tester, '比較');
    debugPrint('S5: project created');
    // ComparisonScreen uses a Material AppBar, not the
    // CupertinoNavigationBarBackButton required by WidgetTester.pageBack().
    // This test owns the route stack, so pop the actual Navigator route and
    // verify the semantic result (the project list) before continuing.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    expect(navigator.canPop(), isTrue);
    debugPrint('S5: BEGIN ui.navigator.pop owned comparison route');
    navigator.pop();
    debugPrint('S5: END ui.navigator.pop owned comparison route');
    await _pumpForUi(tester);
    debugPrint('S5: comparison closed');
    expect(find.text('Sprint 5 E2E案件'), findsOneWidget);

    final createdProjects = await _awaitStep(
      'db.getProjects after route pop',
      repository.getProjects(),
    );
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
      expectCriticalConfirmation: true,
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

    final reloaded = await _awaitStep(
      'db.getProject after quote saves',
      repository.getProject(project.id),
    );
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

    await _awaitStep(
      'ui.pumpWidget dispose app',
      tester.pumpWidget(const SizedBox.shrink()),
    );
    await _pumpForUi(tester);
    await _awaitStep('db.close before reopen', database.close());

    repository = ProjectRepository(databaseService: database);
    await _awaitStep(
      'ui.pumpWidget reloaded app',
      tester.pumpWidget(
        AimitsumoriApp(repository: repository, adService: MockAdMobService()),
      ),
    );
    await _pumpForUi(tester);

    final projectCard = find.byKey(ValueKey('project-card-${project.id}'));
    expect(projectCard, findsOneWidget);
    final persisted = await _awaitStep(
      'db.getProject after app reload',
      repository.getProject(project.id),
    );
    expect(persisted, isNotNull);
    expect(persisted!.quotes, hasLength(2));

    await _awaitStep('ui.tap persisted project card', tester.tap(projectCard));
    await _pumpForUi(tester);
    expect(find.text('A社'), findsWidgets);
    expect(find.text('B社'), findsWidgets);
    expect(find.text('順位・総合点は付けず、条件差と不明点を確認します。'), findsOneWidget);
  }, skip: !Platform.isAndroid);
}

Future<void> _pumpForUi(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await _awaitStep(
      'ui.pump ${i + 1}/10',
      tester.pump(const Duration(milliseconds: 100)),
    );
  }
}

Future<void> _waitForText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  for (var i = 0; i < 60; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await _awaitStep(
      'ui.wait text $text',
      tester.pump(const Duration(milliseconds: 250)),
    );
  }
  fail('Timed out waiting for text: $text');
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
  bool expectCriticalConfirmation = false,
}) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  debugPrint('S5: BEGIN ui.navigator.push quote editor $contractorName');
  final result = navigator.push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => QuoteInputScreen(
        project: project,
        repository: repository,
        initialQuote: RawQuoteData(
          contractorName: '',
          totalAmountYen: int.parse(amount),
          extractedText: '',
          sourcePath: 'memory://$contractorName',
          createdAtEpochMillis: DateTime.now().millisecondsSinceEpoch,
          lineItems: [
            RawQuoteLineItem(
              rawLabel: '施工費',
              categoryId: CategoryMaster.categories.first.id,
              amountYen: int.parse(amount),
              inclusionStatus: InclusionStatus.included,
              quantity: double.parse(quantity),
              unit: '㎡',
            ),
          ],
        ),
        initialReviewBundle: expectCriticalConfirmation
            ? const OcrReviewBundle(
                lines: [],
                issues: [
                  OcrReviewIssue(
                    id: 's5-critical-confirmation',
                    reason: OcrReviewReason.totalMismatch,
                    severity: OcrReviewSeverity.critical,
                    message: 'Sprint 5 E2E critical review fixture',
                    initialStatus: OcrReviewStatus.pending,
                  ),
                ],
              )
            : null,
      ),
    ),
  );
  debugPrint('S5: END ui.navigator.push quote editor $contractorName');
  await _pumpForUi(tester);

  await _enterText(
    tester,
    const ValueKey('quote-contractor-field'),
    contractorName,
  );

  if (verifyValidation) {
    await _enterText(tester, const ValueKey('quote-total-field'), '金額不正');
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
    await _enterText(tester, const ValueKey('quote-line-quantity-0'), quantity);
    // Let the autovalidating FormField settle after correcting the invalid
    // quantity before driving the final save. Without this bounded wait, the
    // Android runner can still present the previous validation state when the
    // save handler synchronously calls FormState.validate().
    await _pumpForUi(tester);
  }

  final totalField = tester.widget<TextFormField>(
    find.byKey(const ValueKey('quote-total-field')),
  );
  final amountField = tester.widget<TextFormField>(
    find.byKey(const ValueKey('quote-line-amount-0')),
  );
  final quantityField = tester.widget<TextFormField>(
    find.byKey(const ValueKey('quote-line-quantity-0')),
  );
  expect(totalField.controller!.text, amount);
  expect(amountField.controller!.text, amount);
  expect(quantityField.controller!.text, quantity);
  expect(int.tryParse(totalField.controller!.text), greaterThan(0));
  expect(int.tryParse(amountField.controller!.text), greaterThan(0));
  expect(double.tryParse(quantityField.controller!.text), greaterThan(0));

  await _tapSave(
    tester,
    expectCriticalConfirmation: expectCriticalConfirmation,
  );
  expect(
    await _awaitRouteResult(
      tester,
      result,
      label: 'quote save route result $contractorName',
    ),
    isTrue,
  );
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
  await _pumpForUi(tester);

  expect(find.text('A社'), findsWidgets);
  expect(find.text('B社'), findsWidgets);
  expect(find.textContaining('A社 1,200,000円'), findsOneWidget);
  expect(find.textContaining('B社 1,350,000円'), findsOneWidget);
  expect(find.text('金額: 1,200,000円'), findsOneWidget);
  expect(find.text('金額: 1,350,000円'), findsOneWidget);
  expect(find.text('数量: 12.5㎡'), findsOneWidget);
  expect(find.text('数量: 13㎡'), findsOneWidget);
  expect(find.text('順位・総合点は付けず、条件差と不明点を確認します。'), findsOneWidget);
}

Future<void> _enterText(WidgetTester tester, Key key, String value) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) {
    await _awaitStep(
      'ui.scrollUntilVisible $key',
      tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      ),
    );
  } else {
    await _awaitStep('ui.ensureVisible $key', tester.ensureVisible(finder));
  }
  await _pumpForUi(tester);
  await _awaitStep('ui.enterText $key', tester.enterText(finder, value));
  await _awaitStep('ui.pump after enterText $key', tester.pump());
}

Future<void> _tapSave(
  WidgetTester tester, {
  bool expectCriticalConfirmation = false,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await _awaitStep('ui.pump before quote save', tester.pump());
  await _awaitStep(
    'ui.tap quote-save-button',
    tester.tap(find.byKey(const ValueKey('quote-save-button'))),
  );
  await _tapCriticalSaveConfirmation(
    tester,
    required: expectCriticalConfirmation,
  );
}

Future<void> _tapCriticalSaveConfirmation(
  WidgetTester tester, {
  required bool required,
}) async {
  const buttonLabel = '未確認のまま保存';
  const dialogTitle = '重大な未確認項目があります';
  debugPrint('S5: BEGIN ui.detect critical-save confirmation');
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  var pumpIndex = 0;
  Finder? visibleButton;
  while (DateTime.now().isBefore(deadline)) {
    final dialogs = find.byType(AlertDialog);
    final titles = find
        .descendant(of: dialogs, matching: find.text(dialogTitle))
        .hitTestable();
    final buttons = find
        .descendant(of: dialogs, matching: find.text(buttonLabel))
        .hitTestable();
    if (titles.evaluate().length == 1 && buttons.evaluate().length == 1) {
      visibleButton = buttons;
      break;
    }
    pumpIndex++;
    await _awaitStep(
      'ui.pump detecting critical-save confirmation $pumpIndex',
      tester.pump(const Duration(milliseconds: 100)),
    );
  }
  if (visibleButton == null) {
    final dialogText = find
        .byType(AlertDialog)
        .evaluate()
        .map((element) => element.widget.toStringShort());
    debugPrint(
      'S5: TIMEOUT ui.detect critical-save confirmation '
      'required=$required pumps=$pumpIndex dialogs=$dialogText',
    );
    if (required) {
      fail('Timed out waiting for visible critical-save confirmation');
    }
    debugPrint('S5: END ui.detect critical-save confirmation (not shown)');
    return;
  }

  debugPrint('S5: MARKER critical-save confirmation detected');
  await _awaitStep(
    'ui.tap critical-save confirmation',
    tester.tap(visibleButton),
  );
  await _pumpForUi(tester);
  debugPrint('S5: END ui.detect critical-save confirmation (tapped)');
}

Future<void> _expectQuoteCount(
  ProjectRepository repository,
  String projectId,
  int count,
) async {
  final project = await _awaitStep(
    'db.getProject verify count $count',
    repository.getProject(projectId),
  );
  expect(project, isNotNull);
  expect(project!.quotes, hasLength(count));
}

const _operationTimeout = Duration(seconds: 30);

Future<bool> _awaitRouteResult(
  WidgetTester tester,
  Future<bool?> result, {
  required String label,
}) async {
  var completed = false;
  bool? value;
  Object? error;
  result.then<void>(
    (routeValue) {
      completed = true;
      value = routeValue;
    },
    onError: (Object exception, StackTrace _) {
      completed = true;
      error = exception;
    },
  );

  debugPrint('S5: BEGIN ui.await $label');
  final deadline = DateTime.now().add(_operationTimeout);
  var pumpIndex = 0;
  while (!completed && DateTime.now().isBefore(deadline)) {
    pumpIndex++;
    await _awaitStep(
      'ui.pump awaiting $label $pumpIndex',
      tester.pump(const Duration(milliseconds: 100)),
    );
  }
  if (!completed) {
    debugPrint(
      'S5: TIMEOUT ui.await $label after ${_operationTimeout.inSeconds}s',
    );
    throw TimeoutException('Future not completed', _operationTimeout);
  }
  if (error != null) Error.throwWithStackTrace(error!, StackTrace.current);
  debugPrint('S5: END ui.await $label');
  return value ?? false;
}

Future<T> _awaitStep<T>(String label, Future<T> operation) async {
  debugPrint('S5: BEGIN $label');
  try {
    final result = await operation.timeout(_operationTimeout);
    debugPrint('S5: END $label');
    return result;
  } on TimeoutException {
    debugPrint('S5: TIMEOUT $label after ${_operationTimeout.inSeconds}s');
    rethrow;
  }
}

double _unitPrice(ContractorQuote quote) {
  final line = quote.lineItems.single;
  return line.amountYen! / line.quantity!;
}
