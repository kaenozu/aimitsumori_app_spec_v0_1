import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/services/comparison_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CSV exports untrusted text as text rather than formulas', () {
    const project = Project(
      id: 'project-1',
      name: '=HYPERLINK("https://example.com")',
      status: ProjectStatus.comparing,
      createdAtEpochMillis: 1,
      updatedAtEpochMillis: 1,
      quotes: [
        ContractorQuote(
          id: 'quote-1',
          contractorName: '+SUM(A1:A2)',
          createdAtEpochMillis: 1,
          lineItems: [
            QuoteLineItem(
              id: 'line-1',
              categoryId: 'drainage',
              rawLabel: '@悪意ある項目',
              inclusionStatus: InclusionStatus.included,
              specification: '-1+1',
            ),
          ],
        ),
      ],
    );

    final csv = ComparisonExportService.toCsv(project);

    expect(csv, contains("'=HYPERLINK"));
    expect(csv, contains("'+SUM"));
    expect(csv, contains("'@悪意ある項目"));
    expect(csv, contains("'-1+1"));
  });
}
