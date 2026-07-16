import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  testWidgets('project search filters by project and contractor name', (
    tester,
  ) async {
    final database = MockDatabaseService(
      initialProjects: [
        createTestProject(id: 'garden', name: '庭まわり改修'),
        createTestProject(
          id: 'parking',
          name: '駐車場拡張',
          quotes: [
            createTestContractorQuote(contractorName: '熊谷建設'),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: ProjectRepository(databaseService: database),
          adService: MockAdMobService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('project-search-field')),
      '庭',
    );
    await tester.pump();

    expect(find.text('庭まわり改修'), findsOneWidget);
    expect(find.text('駐車場拡張'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('project-search-field')),
      '熊谷',
    );
    await tester.pump();

    expect(find.text('庭まわり改修'), findsNothing);
    expect(find.text('駐車場拡張'), findsOneWidget);
  });
}
