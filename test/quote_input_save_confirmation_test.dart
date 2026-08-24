import 'package:aimitsumori_app/data/category_master.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/ocr_models.dart';
import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/quote_input_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  testWidgets(
    'save asks for confirmation when a critical review item is pending',
    (tester) async {
      final project = createTestProject(status: ProjectStatus.collectingQuotes);
      final repository = ProjectRepository(
        databaseService: MockDatabaseService(initialProjects: [project]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuoteInputScreen(
            project: project,
            repository: repository,
            initialQuote: RawQuoteData(
              contractorName: '',
              extractedText: '',
              sourcePath: 'memory://critical-confirmation',
              createdAtEpochMillis: 1,
              lineItems: [
                RawQuoteLineItem(
                  rawLabel: '施工費',
                  categoryId: CategoryMaster.categories.first.id,
                ),
              ],
            ),
            initialReviewBundle: const OcrReviewBundle(
              lines: [],
              issues: [
                OcrReviewIssue(
                  id: 'critical-total-mismatch',
                  reason: OcrReviewReason.totalMismatch,
                  severity: OcrReviewSeverity.critical,
                  message: 'critical fixture',
                  initialStatus: OcrReviewStatus.pending,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('quote-contractor-field')),
        'A社',
      );
      await tester.enterText(
        find.byKey(const ValueKey('quote-total-field')),
        '1200000',
      );
      final amountField = find.byKey(const ValueKey('quote-line-amount-0'));
      await tester.scrollUntilVisible(
        amountField,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(amountField, '1200000');
      final quantityField = find.byKey(const ValueKey('quote-line-quantity-0'));
      await tester.scrollUntilVisible(
        quantityField,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(quantityField, '12.5');
      await tester.tap(find.byKey(const ValueKey('quote-save-button')));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('重大な未確認項目があります'), findsOneWidget);
      expect(find.text('未確認のまま保存'), findsOneWidget);
    },
  );
}
