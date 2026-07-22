import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/comparison_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  testWidgets('read-only comparison does not persist a comparison report', (
    tester,
  ) async {
    final project = createSampleComparisonProject();
    final database = MockDatabaseService(initialProjects: [project]);
    final repository = ProjectRepository(databaseService: database);

    await tester.pumpWidget(
      MaterialApp(
        home: ComparisonScreen(
          project: project,
          repository: repository,
          adService: MockAdMobService(adFree: true),
          persistReport: false,
          allowQuoteEditing: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(database.saveComparisonResultCallCount, 0);
    expect(find.byTooltip('見積を追加'), findsNothing);
  });
}
