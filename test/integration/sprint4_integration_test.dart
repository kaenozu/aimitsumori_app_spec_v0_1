import 'package:aimitsumori_app/data/category_master.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/comparison_screen.dart';
import 'package:aimitsumori_app/screens/quote_input_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  testWidgets('2件保存後にWidgetを再生成してデータを確認できる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final project = createTestProject(status: ProjectStatus.collectingQuotes);
    final database = MockDatabaseService(initialProjects: [project]);
    final repository = ProjectRepository(databaseService: database);

    await _saveQuote(
      tester,
      project: project,
      repository: repository,
      contractorName: 'A社',
      amount: '1200000',
      quantity: '12.5',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await _saveQuote(
      tester,
      project: project,
      repository: repository,
      contractorName: 'B社',
      amount: '1350000',
      quantity: '13',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final reloaded = await repository.getProject(project.id);
    expect(reloaded, isNotNull);
    expect(reloaded!.quotes, hasLength(2));
    expect(
      reloaded.quotes.map((quote) => quote.contractorName),
      containsAll(<String>['A社', 'B社']),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ComparisonScreen(
          project: reloaded,
          repository: repository,
          adService: MockAdMobService(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('A社'), findsWidgets);
    expect(find.text('B社'), findsWidgets);
  });
}

Future<void> _saveQuote(
  WidgetTester tester, {
  required Project project,
  required ProjectRepository repository,
  required String contractorName,
  required String amount,
  required String quantity,
}) async {
  await tester.pumpWidget(
    _EditorHost(
      project: project,
      repository: repository,
      initialQuote: RawQuoteData(
        contractorName: '',
        extractedText: '',
        sourcePath: 'memory://$contractorName',
        createdAtEpochMillis: DateTime.now().millisecondsSinceEpoch,
        lineItems: [
          RawQuoteLineItem(
            rawLabel: '',
            categoryId: CategoryMaster.categories.first.id,
          ),
        ],
      ),
    ),
  );

  await tester.tap(find.byKey(const ValueKey('open-quote-editor')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('quote-contractor-field')),
    contractorName,
  );
  await tester.enterText(
    find.byKey(const ValueKey('quote-total-field')),
    amount,
  );
  await tester.enterText(
    find.byKey(const ValueKey('quote-line-label-0')),
    '施工費',
  );
  await tester.enterText(
    find.byKey(const ValueKey('quote-line-amount-0')),
    amount,
  );
  await tester.enterText(
    find.byKey(const ValueKey('quote-line-quantity-0')),
    quantity,
  );
  await tester.tap(find.byKey(const ValueKey('quote-save-button')));
  await tester.pumpAndSettle();
}

class _EditorHost extends StatelessWidget {
  const _EditorHost({
    required this.project,
    required this.repository,
    required this.initialQuote,
  });

  final Project project;
  final ProjectRepository repository;
  final RawQuoteData initialQuote;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('open-quote-editor'),
              onPressed: () => Navigator.push<bool>(
                context,
                MaterialPageRoute<bool>(
                  builder: (_) => QuoteInputScreen(
                    project: project,
                    repository: repository,
                    initialQuote: initialQuote,
                  ),
                ),
              ),
              child: const Text('見積を作成'),
            ),
          ),
        ),
      ),
    );
  }
}
